# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a cross-platform dotfiles repository by Thisaru Guruge that sets up a complete development environment on **macOS** and **Ubuntu/Debian** with Zsh, Starship prompt, modern CLI tools, and encrypted secret management using SOPS + age.

### Platform Strategy
- **macOS**: Uses Homebrew for all packages
- **Ubuntu/Debian**: Uses APT for system packages + Linuxbrew for developer tools

## Common Commands

### Installation
```bash
./init.sh                              # Full interactive installation (auto-detects OS)
./init.sh --dry-run                    # Test script without changes
```

### Ubuntu-specific Prerequisites
```bash
sudo apt update && sudo apt install -y git curl   # Minimal requirements before running init.sh
```

### Validation & Testing
```bash
test-zsh                               # Run comprehensive environment validation
./bin/test-zsh-config                  # Direct test script execution
zsh -n zsh/.zshrc                      # Check zsh config syntax
bash -n zsh/.functions.sh              # Check functions syntax
bash -n zsh/.aliases.sh                # Check aliases syntax
```

### Linting & Formatting
```bash
shellcheck -e SC1091,SC2039 <file>.sh  # Lint shell scripts
shfmt -i 4 -ci <file>.sh               # Format with 4-space indent
shfmt -d -i 4 -ci <file>.sh            # Check formatting (diff mode)
```

### Package Management
```bash
./bin/manage-packages list             # List all packages
./bin/manage-packages enable <pkg>     # Enable a package
./bin/manage-packages disable <pkg>    # Disable a package
./bin/generate-brewfile                # Regenerate Brewfile from packages.json
brew bundle --file=Brewfile            # Install all enabled packages (both platforms)
```

### Ubuntu APT Operations (system packages)
```bash
sudo apt update                        # Update package list
sudo apt upgrade                       # Upgrade system packages
sudo apt install <package>             # Install system package
```

### Stow Operations
```bash
stow -t $HOME zsh                      # Link zsh configurations
stow -t $HOME vim                      # Link vim configuration
stow -t $HOME git                      # Link git configuration
stow -t $HOME tmux                     # Link tmux configuration
stow -t $HOME direnv                   # Link direnv configuration
stow -t $HOME .config                  # Link XDG configs (Starship, Lazygit)
stow -n -t $HOME <package>             # Dry-run (show what would be linked)
```

### Performance Profiling
```bash
./bin/profile-startup                  # Profile shell startup time
./bin/profile-zsh-startup              # Detailed zsh profiling
time zsh -i -c exit                    # Quick startup timing
```

## Architecture

### Directory Structure
- **zsh/** - Shell configurations (`.zshrc`, `.aliases.sh`, `.functions.sh`, `.paths.sh`)
- **vim/** - Vim configuration (`.vimrc`)
- **git/** - Git configuration (`.gitconfig`, `.gitignore_global`, `.gitconfig.local.example`)
- **tmux/** - Terminal multiplexer configuration
- **direnv/** - Project-specific environment management
- **.config/** - XDG-compliant configs (Starship, Lazygit, Ripgrep, Oh My Posh)
- **bin/** - Utility scripts (validation, package management, profiling)

### Configuration Flow
1. `init.sh` detects OS (macOS/Ubuntu) and orchestrates installation
2. On Ubuntu: APT installs system prerequisites, then Linuxbrew for dev tools
3. On macOS: Homebrew handles all packages
4. `packages.json` is the single source of truth for package definitions
5. GNU Stow creates symlinks from package directories to `$HOME`

### Homebrew/Linuxbrew Paths
- **macOS Apple Silicon**: `/opt/homebrew/bin/brew`
- **macOS Intel**: `/usr/local/bin/brew`
- **Linux (system)**: `/home/linuxbrew/.linuxbrew/bin/brew`
- **Linux (user)**: `~/.linuxbrew/bin/brew`

### Secret Management
- Uses SOPS + age encryption for `.env` files
- Keys stored in `~/.config/sops/age/keys.txt`
- Configuration in `~/.sops.yaml`
- Shell auto-decrypts and sources encrypted `.env` on startup

## Code Style

### Shell Scripts
- 4 spaces for indentation (no tabs)
- Format with `shfmt -i 4 -ci`
- Use `[[ ]]` for conditionals
- Quote variables: `"$variable"`
- Use `local` for function-scoped variables
- Scripts must pass shellcheck (exclusions: SC1091, SC2039)

### Commit Messages
Uses Conventional Commits format:
```
<type>(<scope>): <subject>

Types: feat, fix, docs, style, refactor, perf, test, chore, ci
Scopes: init, zsh, ci, docs, packages, security, prompt, git, vim, tmux
```

## CI/CD

GitHub Actions workflows in `.github/workflows/`:
- **validate.yml** - Runs on push/PR to main/develop
  - shellcheck validation
  - shfmt formatting check
  - JSON syntax validation
  - Security checks (hardcoded paths, secrets)
  - macOS compatibility tests (PR only)

## Key Files

- `init.sh` - Main installation script with all setup logic
- `packages.json` - Centralized package definitions with enabled/disabled states
- `zsh/.zshrc` - Main shell configuration entry point
- `zsh/.functions.sh` - Custom shell functions (58k+ lines)
- `zsh/.aliases.sh` - Shell aliases organized by category
- `bin/test-zsh-config` - Comprehensive validation suite
