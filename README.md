# Claude Account Switcher

Advanced account manager for Claude Code CLI. Switch between multiple Claude accounts with ease, supporting dynamic account management, exports, and imports.

**Manages both authentication and settings:**
- `~/.claude.json` (authentication/session data)
- `~/.claude/settings.json` (user preferences, themes, environment variables)

## How it works

| File/Directory | Purpose |
|---|---|
| `~/.claude.json` | Active authentication config (read by Claude) |
| `~/.claude/settings.json` | Active settings: preferences, themes, env vars |
| `~/.claude-profiles/` | Directory containing all saved account profiles |
| `~/.claude-profiles/<name>.json` | Account authentication data |
| `~/.claude-profiles/<name>.settings.json` | Account settings and preferences |
| `~/.claude-profiles/accounts.list` | List of all registered accounts |
| `~/.claude.json.active` | Tracks which profile is currently active |
| `~/.claude-profiles/export_*/` | Exported setups with timestamps |

The script **saves both files** before switching, ensuring authentication AND settings are preserved per account.

## Features

✨ **Dual-File Management**
- Saves both authentication (`~/.claude.json`) AND settings (`~/.claude/settings.json`)
- Each account preserves: API endpoints, auth tokens, themes, preferences, environment variables

✨ **Dynamic Account Management**
- Add unlimited accounts with custom names
- Remove accounts you no longer need
- List all accounts with sizes and active status

🔄 **Flexible Switching**
- Switch by account name
- Switch by account number (e.g., `--switch-to 1`)
- Cycle through accounts sequentially

💾 **Export & Import**
- Export current setup (both files) with custom names
- Import saved setups as new accounts
- Timestamp-based export tracking

🔒 **Safe Operations**
- Automatic backup before switching
- Prevents removal of active account
- First-run detection and setup

## First run

If no profiles exist, it will prompt you to identify which account is currently active.

## Usage

### Account Management

```bash
# Add current ~/.claude.json as a new account
./switch-claude.sh --add-account work

# Add account interactively (will prompt for name)
./switch-claude.sh --add-account

# List all accounts with status
./switch-claude.sh --list

# Remove an account
./switch-claude.sh --remove-account work
```

### Switching Accounts

```bash
# Switch by account name (backwards compatible)
./switch-claude.sh account2
./switch-claude.sh account1

# Switch by account number
./switch-claude.sh --switch-to 1
./switch-claude.sh --switch-to 2

# Switch interactively (will show list)
./switch-claude.sh --switch-to

# Cycle to next account
./switch-claude.sh --switch

# Show current status
./switch-claude.sh status
./switch-claude.sh --list
```

### Export & Import

```bash
# Export current setup (both auth and settings) with a name
./switch-claude.sh --export my-important-setup

# Export interactively (will prompt for name)
./switch-claude.sh --export

# Import a saved setup as new account
./switch-claude.sh --import ~/.claude-profiles/export_my-important-setup_20260311_143022 new-account

# Import interactively
./switch-claude.sh --import
```

### Help

```bash
# Show detailed help
./switch-claude.sh --help
./switch-claude.sh -h
```

## Typical workflows

### Basic switching
```bash
# Before starting Claude, switch to the account you want:
./switch-claude.sh work
claude
```

### Setting up a new account
```bash
# 1. Log in to Claude with your new account credentials
claude logout
claude

# 2. Once logged in, add it as a profile
./switch-claude.sh --add-account personal

# 3. Now you can switch between accounts anytime
./switch-claude.sh work
./switch-claude.sh personal
```

### Quick cycling between accounts
```bash
# Cycle through all your accounts
./switch-claude.sh --switch
claude

# When done, cycle to the next one
./switch-claude.sh --switch
claude
```

### Backing up configurations
```bash
# Export your current setup before making changes
./switch-claude.sh --export before-update

# Make changes, test...
# If something breaks, import the backup
./switch-claude.sh --import ~/.claude-profiles/export_before-update_* restored
./switch-claude.sh restored
```

## What gets saved per account?

Each account profile stores:

**Authentication** (`<name>.json`):
- Session tokens
- Login credentials
- Account identification

**Settings** (`<name>.settings.json`):
- Always thinking mode preference
- Custom environment variables (API endpoints, tokens, model names)
- Git attribution settings
- Theme preferences
- Telemetry/error reporting settings
- Any other user preferences

## Setup (one-time)

```bash
# Make the script executable
chmod +x switch-claude.sh

# Optional: add an alias to your shell config (~/.zshrc or ~/.bashrc)
alias claude-switch="$PWD/switch-claude.sh"
alias cs="$PWD/switch-claude.sh"  # short version

# Or create a symlink in your PATH
sudo ln -s "$PWD/switch-claude.sh" /usr/local/bin/claude-switch
```

## Notes

- Profiles are stored in `~/.claude-profiles/` directory
- Both authentication AND settings are managed per account
- Always run this script **before** starting Claude to ensure the right account is loaded
- The script prevents you from removing the currently active account
- Export directories include timestamps for easy version tracking
- No API keys are stored in this repository – only local `~/.` files are managed
- Backwards compatible: `./switch-claude.sh accountname` still works

## Why manage settings.json?

Different accounts may need different configurations:
- **API endpoints**: Personal account vs. corporate proxy
- **Auth tokens**: Different authentication mechanisms
- **Model preferences**: Different default models per account
- **Themes/preferences**: Keep your work setup separate from personal
- **Environment variables**: Custom API keys, base URLs, etc.

## Comparison with cc-account-switcher

This tool is inspired by [cc-account-switcher](https://github.com/ming86/cc-account-switcher) but simplified for direct `.claude.json` management:

| Feature | This Tool | cc-account-switcher |
|---|---|---|
| Multiple accounts | ✅ Unlimited | ✅ Unlimited |
| Add/remove accounts | ✅ | ✅ |
| List accounts | ✅ | ✅ |
| Cycle switching | ✅ | ✅ |
| Export/import | ✅ | ❌ |
| Keychain integration | ❌ | ✅ (macOS only) |
| OAuth handling | ❌ | ✅ |
| Platform | macOS/Linux/WSL | macOS/Linux/WSL |

Choose this tool if you want a simple, transparent config file manager. Choose cc-account-switcher if you need full keychain and OAuth integration.