#!/usr/bin/env bash
# switch-claude.sh
# Switches the active Claude account by swapping ~/.claude.json and ~/.claude/settings.json
# Enhanced with dynamic account management features

CLAUDE_JSON="$HOME/.claude.json"
CLAUDE_SETTINGS="$HOME/.claude/settings.json"
BACKUP_DIR="$HOME/.claude-profiles"
STATE_FILE="$HOME/.claude.json.active"
ACCOUNTS_FILE="$BACKUP_DIR/accounts.list"

# Ensure backup directory exists
mkdir -p "$BACKUP_DIR"

# ── helpers ──────────────────────────────────────────────────────────────────

# Get list of all accounts
list_accounts() {

  if [[ -f "$ACCOUNTS_FILE" ]]; then
    cat "$ACCOUNTS_FILE"
  fi
}

current_profile() {
  if [[ -f "$STATE_FILE" ]]; then
    cat "$STATE_FILE"
  else
    echo "unknown"
  fi
}

profile_path() {
  local name="$1"
  echo "$BACKUP_DIR/${name}.json"
}

profile_settings_path() {
  local name="$1"
  echo "$BACKUP_DIR/${name}.settings.json"
}

save_current() {
  local current
  current=$(current_profile)

  # Check if files exist
  local has_json=false
  local has_settings=false
  [[ -f "$CLAUDE_JSON" ]] && has_json=true
  [[ -f "$CLAUDE_SETTINGS" ]] && has_settings=true

  if [[ "$has_json" == false ]] && [[ "$has_settings" == false ]]; then
    echo "  No ~/.claude.json or ~/.claude/settings.json found – nothing to save."
    return
  fi

  if [[ "$current" == "unknown" ]]; then
    # First run: ask user which account is currently active
    echo ""
    echo "  First run detected – which account is in ~/.claude.json right now?"
    local accounts=($(list_accounts))
    if [[ ${#accounts[@]} -eq 0 ]]; then
      echo "  No accounts configured yet. Use --add-account to add one."
      return
    fi

    local i=1
    for acc in "${accounts[@]}"; do
      echo "    $i) $acc"
      ((i++))
    done
    echo "    $i) skip (don't save)"

    read -r -p "  Choice [1-$i]: " choice
    if [[ "$choice" =~ ^[0-9]+$ ]] && [[ "$choice" -ge 1 ]] && [[ "$choice" -lt "$i" ]]; then
      local selected="${accounts[$((choice-1))]}"

      # Save both files
      [[ "$has_json" == true ]] && cp "$CLAUDE_JSON" "$(profile_path "$selected")" && echo "  Saved ~/.claude.json → $selected"
      [[ "$has_settings" == true ]] && cp "$CLAUDE_SETTINGS" "$(profile_settings_path "$selected")" && echo "  Saved ~/.claude/settings.json → $selected"

      echo "$selected" > "$STATE_FILE"
    else
      echo "  Skipped saving current config."
    fi
  else
    # Save to known profile
    local saved_files=()

    if [[ "$has_json" == true ]]; then
      cp "$CLAUDE_JSON" "$(profile_path "$current")"
      saved_files+=("auth")
    fi

    if [[ "$has_settings" == true ]]; then
      cp "$CLAUDE_SETTINGS" "$(profile_settings_path "$current")"
      saved_files+=("settings")
    fi

    if [[ ${#saved_files[@]} -gt 0 ]]; then
      echo "  Saved current config → $current (${saved_files[*]})"
    fi
  fi
}

activate_profile() {
  local profile="$1"
  local json_file settings_file
  json_file=$(profile_path "$profile")
  settings_file=$(profile_settings_path "$profile")

  # Check if at least one file exists
  if [[ ! -f "$json_file" ]] && [[ ! -f "$settings_file" ]]; then
    echo "  Profile not found: $profile"
    echo "  Available profiles:"
    list_accounts | sed 's/^/    - /'
    exit 1
  fi

  # Restore files
  local restored=()

  if [[ -f "$json_file" ]]; then
    cp "$json_file" "$CLAUDE_JSON"
    restored+=("auth")
  fi

  if [[ -f "$settings_file" ]]; then
    cp "$settings_file" "$CLAUDE_SETTINGS"
    restored+=("settings")
  fi

  echo "$profile" > "$STATE_FILE"
  echo "  Activated profile → $profile (${restored[*]})"

  # Check for proxy configuration
  check_proxy
}

check_proxy() {
  if [[ -f "$CLAUDE_SETTINGS" ]]; then
    if grep -q '"ANTHROPIC_BASE_URL".*"http://localhost:6655/anthropic/"' "$CLAUDE_SETTINGS" 2>/dev/null; then
      echo ""
      echo "  ⚠️  Proxy detected in settings (localhost:6655)"

      # Check if proxy is already running
      if lsof -i :6655 >/dev/null 2>&1; then
        echo "  ✓ Proxy is already running"
      else
        echo "  ⚡ Proxy is not running"
        read -r -p "  Start proxy with 'hai proxy start'? [Y/n]: " start_proxy
        if [[ -z "$start_proxy" ]] || [[ "$start_proxy" =~ ^[Yy]$ ]]; then
          echo ""
          echo "  Starting proxy..."
          hai proxy start
        else
          echo "  Skipped. Start manually with: hai proxy start"
        fi
      fi
    fi
  fi
}

show_status() {
  local current
  current=$(current_profile)
  echo ""
  echo "  Current active profile : $current"

  # Show active file sizes
  if [[ -f "$CLAUDE_JSON" ]]; then
    echo "  ~/.claude.json         : $(wc -c < "$CLAUDE_JSON" | tr -d ' ') bytes"
  fi
  if [[ -f "$CLAUDE_SETTINGS" ]]; then
    echo "  ~/.claude/settings.json: $(wc -c < "$CLAUDE_SETTINGS" | tr -d ' ') bytes"
  fi

  echo ""
  echo "  Available profiles:"
  local accounts=($(list_accounts))
  if [[ ${#accounts[@]} -eq 0 ]]; then
    echo "    (none - use --add-account to add one)"
  else
    local i=1
    for acc in "${accounts[@]}"; do
      local marker=" "
      [[ "$acc" == "$current" ]] && marker="*"

      local json_file settings_file
      json_file=$(profile_path "$acc")
      settings_file=$(profile_settings_path "$acc")

      local files=()
      [[ -f "$json_file" ]] && files+=("auth:$(wc -c < "$json_file" | tr -d ' ')b")
      [[ -f "$settings_file" ]] && files+=("settings:$(wc -c < "$settings_file" | tr -d ' ')b")

      local file_info=""
      [[ ${#files[@]} -gt 0 ]] && file_info=" (${files[*]})"

      echo "    $marker [$i] $acc$file_info"
      ((i++))
    done
  fi
  echo ""
}

add_account() {
  local name="$1"

  if [[ -z "$name" ]]; then
    read -r -p "  Enter account name: " name
  fi

  if [[ -z "$name" ]]; then
    echo "  Error: Account name cannot be empty"
    exit 1
  fi

  # Check if account already exists
  if list_accounts | grep -q "^${name}$"; then
    echo "  Account '$name' already exists"
    exit 1
  fi

  # Check if files exist
  local has_json=false
  local has_settings=false
  [[ -f "$CLAUDE_JSON" ]] && has_json=true
  [[ -f "$CLAUDE_SETTINGS" ]] && has_settings=true

  if [[ "$has_json" == false ]] && [[ "$has_settings" == false ]]; then
    echo "  Error: No ~/.claude.json or ~/.claude/settings.json found."
    echo "  Please log in to Claude first."
    exit 1
  fi

  # Save files
  local saved=()
  [[ "$has_json" == true ]] && cp "$CLAUDE_JSON" "$(profile_path "$name")" && saved+=("auth")
  [[ "$has_settings" == true ]] && cp "$CLAUDE_SETTINGS" "$(profile_settings_path "$name")" && saved+=("settings")

  echo "$name" >> "$ACCOUNTS_FILE"
  echo "$name" > "$STATE_FILE"

  echo "  ✓ Added account: $name (${saved[*]})"
}

remove_account() {
  local name="$1"

  if [[ -z "$name" ]]; then
    echo "  Available accounts:"
    list_accounts | sed 's/^/    - /'
    read -r -p "  Enter account name to remove: " name
  fi

  if [[ -z "$name" ]]; then
    echo "  Error: Account name cannot be empty"
    exit 1
  fi

  if ! list_accounts | grep -q "^${name}$"; then
    echo "  Account '$name' not found"
    exit 1
  fi

  local current
  current=$(current_profile)
  if [[ "$current" == "$name" ]]; then
    echo "  Error: Cannot remove currently active account"
    echo "  Switch to another account first"
    exit 1
  fi

  # Remove from accounts list
  local temp_file="${ACCOUNTS_FILE}.tmp"
  grep -v "^${name}$" "$ACCOUNTS_FILE" > "$temp_file"
  mv "$temp_file" "$ACCOUNTS_FILE"

  # Remove profile files
  rm -f "$(profile_path "$name")"
  rm -f "$(profile_settings_path "$name")"

  echo "  ✓ Removed account: $name"
}

switch_next() {
  local accounts=($(list_accounts))
  if [[ ${#accounts[@]} -eq 0 ]]; then
    echo "  No accounts configured"
    exit 1
  fi

  local current
  current=$(current_profile)

  # Find current index
  local current_idx=-1
  for i in "${!accounts[@]}"; do
    if [[ "${accounts[$i]}" == "$current" ]]; then
      current_idx=$i
      break
    fi
  done

  # Get next account (wrap around)
  local next_idx=$(( (current_idx + 1) % ${#accounts[@]} ))
  local next_account="${accounts[$next_idx]}"

  echo "  Switching to next account: $next_account"
  save_current
  activate_profile "$next_account"
}

# ── main ─────────────────────────────────────────────────────────────────────

CMD="$1"
ARG="$2"

# Handle commands
case "$CMD" in
  --add-account)
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  Add New Account"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    add_account "$ARG"
    exit 0
    ;;
  --list)
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  Claude Account Switcher"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    show_status
    exit 0
    ;;
  --remove-account)
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  Remove Account"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    remove_account "$ARG"
    exit 0
    ;;
  --switch)
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  Claude Account Switcher"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    switch_next
    show_status
    echo "  Done. You can now start Claude."
    exit 0
    ;;
  --switch-to)
    TARGET="$ARG"
    if [[ -z "$TARGET" ]]; then
      echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
      echo "  Switch To Account"
      echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
      show_status
      read -r -p "  Enter account name or number: " TARGET
    fi

    # Check if it's a number
    if [[ "$TARGET" =~ ^[0-9]+$ ]]; then
      local accounts=($(list_accounts))
      if [[ "$TARGET" -ge 1 ]] && [[ "$TARGET" -le "${#accounts[@]}" ]]; then
        TARGET="${accounts[$((TARGET-1))]}"
      else
        echo "  Invalid account number"
        exit 1
      fi
    fi
    ;;
  --export)
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  Export Current Setup"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    local export_name="$ARG"
    if [[ -z "$export_name" ]]; then
      read -r -p "  Enter name for this setup: " export_name
    fi

    if [[ -z "$export_name" ]]; then
      echo "  Error: Export name cannot be empty"
      exit 1
    fi

    # Check if files exist
    local has_json=false
    local has_settings=false
    [[ -f "$CLAUDE_JSON" ]] && has_json=true
    [[ -f "$CLAUDE_SETTINGS" ]] && has_settings=true

    if [[ "$has_json" == false ]] && [[ "$has_settings" == false ]]; then
      echo "  Error: No ~/.claude.json or ~/.claude/settings.json found"
      exit 1
    fi

    # Create export with timestamp
    local timestamp=$(date +"%Y%m%d_%H%M%S")
    local export_dir="$BACKUP_DIR/export_${export_name}_${timestamp}"
    mkdir -p "$export_dir"

    local exported=()
    if [[ "$has_json" == true ]]; then
      cp "$CLAUDE_JSON" "$export_dir/claude.json"
      exported+=("auth")
    fi

    if [[ "$has_settings" == true ]]; then
      cp "$CLAUDE_SETTINGS" "$export_dir/settings.json"
      exported+=("settings")
    fi

    echo "  ✓ Exported current setup (${exported[*]}) to:"
    echo "    $export_dir"
    echo ""
    echo "  To use this export later:"
    echo "    ./switch-claude.sh --import \"$export_dir\" <account-name>"
    exit 0
    ;;
  --import)
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  Import Setup"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    local import_path="$ARG"
    local account_name="$3"

    if [[ -z "$import_path" ]]; then
      echo "  Available exports:"
      ls -1d "$BACKUP_DIR"/export_* 2>/dev/null | sed 's/^/    - /' || echo "    (none)"
      read -r -p "  Enter path to import directory: " import_path
    fi

    if [[ ! -d "$import_path" ]]; then
      echo "  Error: Directory not found: $import_path"
      exit 1
    fi

    if [[ -z "$account_name" ]]; then
      read -r -p "  Enter account name for this import: " account_name
    fi

    if [[ -z "$account_name" ]]; then
      echo "  Error: Account name cannot be empty"
      exit 1
    fi

    # Check what files are available in the export
    local has_json=false
    local has_settings=false
    [[ -f "$import_path/claude.json" ]] && has_json=true
    [[ -f "$import_path/settings.json" ]] && has_settings=true

    if [[ "$has_json" == false ]] && [[ "$has_settings" == false ]]; then
      echo "  Error: No claude.json or settings.json found in export directory"
      exit 1
    fi

    # Check if account already exists
    if list_accounts | grep -q "^${account_name}$"; then
      read -r -p "  Account '$account_name' exists. Overwrite? [y/N]: " confirm
      if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
        echo "  Import cancelled"
        exit 0
      fi
    else
      echo "$account_name" >> "$ACCOUNTS_FILE"
    fi

    # Import files
    local imported=()
    if [[ "$has_json" == true ]]; then
      cp "$import_path/claude.json" "$(profile_path "$account_name")"
      imported+=("auth")
    fi

    if [[ "$has_settings" == true ]]; then
      cp "$import_path/settings.json" "$(profile_settings_path "$account_name")"
      imported+=("settings")
    fi

    echo "  ✓ Imported setup (${imported[*]}) as account: $account_name"
    exit 0
    ;;
  --help|-h|help)
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  Claude Account Switcher - Help"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "  Manages both ~/.claude.json (auth) and ~/.claude/settings.json (preferences)"
    echo ""
    echo "  Usage: ./switch-claude.sh [COMMAND] [OPTIONS]"
    echo ""
    echo "  Commands:"
    echo "    --add-account [name]       Add current config as new account"
    echo "    --list                     Show all accounts and current status"
    echo "    --switch                   Cycle to next account"
    echo "    --switch-to <name|number>  Switch to specific account"
    echo "    --remove-account [name]    Remove an account"
    echo "    --export [name]            Export current setup with a name"
    echo "    --import <dir> [name]      Import a saved setup as account"
    echo "    --help                     Show this help message"
    echo ""
    echo "  Direct switch (backwards compatible):"
    echo "    <account-name>             Switch to account by name"
    echo "    status                     Show current status"
    echo ""
    echo "  Examples:"
    echo "    ./switch-claude.sh --add-account work"
    echo "    ./switch-claude.sh --switch"
    echo "    ./switch-claude.sh --switch-to 1"
    echo "    ./switch-claude.sh --export my-setup"
    echo "    ./switch-claude.sh work"
    echo ""
    exit 0
    ;;
  status)
    show_status
    exit 0
    ;;
  "")
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  Claude Account Switcher"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    show_status
    echo "  Usage: ./switch-claude.sh [COMMAND] [OPTIONS]"
    echo "  Run with --help for detailed usage information"
    echo ""
    exit 0
    ;;
  *)
    # Assume it's an account name (backwards compatible)
    TARGET="$CMD"
    ;;
esac

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Claude Account Switcher"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

current=$(current_profile)
if [[ "$current" == "$TARGET" ]]; then
  echo "  Profile '$TARGET' is already active."
  show_status
  exit 0
fi

# Verify target account exists
if ! list_accounts | grep -q "^${TARGET}$"; then
  echo "  Error: Account '$TARGET' not found"
  echo ""
  show_status
  exit 1
fi

echo ""
echo "  Saving current profile ($current)..."
save_current

echo "  Activating profile: $TARGET ..."
activate_profile "$TARGET"

show_status
echo "  Done. You can now start Claude."