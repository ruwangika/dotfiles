#!/bin/bash

# Dotfiles Initialization Script
# This script sets up the complete development environment with dependency checking
# Supports both macOS and Ubuntu/Debian Linux

set -e # Exit on any error

# Ensure script is run from ~/.dotfiles directory
basename_dir="$(basename "$PWD")"
if [[ ! "$basename_dir" == "dotfiles" && ! "$basename_dir" == ".dotfiles" ]]; then
    echo "❌ This script must be run from your dotfiles directory"
    echo "Please run:"
    echo "  cd ~/dotfiles  # or ~/.dotfiles"
    echo "  ./init.sh"
    exit 1
fi

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Unicode symbols
CHECK="✅"
CROSS="❌"
ARROW="➜"
INFO="ℹ️"
WARNING="⚠️"

DOTFILES_DIR="$(pwd)"

# Detect operating system
detect_os() {
    if [[ "$OSTYPE" == "darwin"* ]]; then
        OS="macos"
        OS_NAME="macOS"
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        if [ -f /etc/os-release ]; then
            . /etc/os-release
            if [[ "$ID" == "ubuntu" || "$ID_LIKE" == *"ubuntu"* || "$ID_LIKE" == *"debian"* || "$ID" == "debian" ]]; then
                OS="ubuntu"
                OS_NAME="Ubuntu/Debian"
            else
                OS="linux"
                OS_NAME="Linux"
            fi
        else
            OS="linux"
            OS_NAME="Linux"
        fi
    else
        OS="unknown"
        OS_NAME="Unknown"
    fi
}

# Run OS detection immediately
detect_os

# Logging functions
log_success() {
    echo -e "  ${GREEN}${CHECK}  $1${NC}"
}

log_warning() {
    echo -e "  ${YELLOW}${WARNING}  $1${NC}"
}

log_info() {
    echo -e "  ${CYAN}${INFO}  $1${NC}"
}

log_error() {
    echo -e "  ${RED}${CROSS}  $1${NC}"
}

log_step() {
    echo ""
    echo -e "${PURPLE}═══════════════════════════════════════════${NC}"
    echo -e " ${BLUE}${ARROW}  $1${NC}"
    echo -e "${PURPLE}═══════════════════════════════════════════${NC}"
    echo ""
}

# Enhanced user confirmation function with single key press
confirm() {
    while true; do
        echo ""
        echo -en "  ${YELLOW}$1 (y/n/q): ${NC}"
        read -r -n 1 -s key # Read single character without echo
        echo                # Print newline after keypress

        case "$key" in
            [Yy])
                echo -e "  ${GREEN}→ Yes${NC}"
                echo ""
                return 0
                ;;
            [Nn])
                echo -e "  ${RED}→ No${NC}"
                echo ""
                return 1
                ;;
            [Qq])
                echo -e "  ${YELLOW}→ Quit${NC}"
                echo ""
                log_info "Installation cancelled by user"
                exit 0
                ;;
            *)
                echo -e "  ${YELLOW}${WARNING} Please press 'y' for yes, 'n' for no, or 'q' to quit.${NC}"
                ;;
        esac
    done
}

# Check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check if running on supported OS
check_os() {
    case "$OS" in
        macos)
            log_success "Running on macOS"
            ;;
        ubuntu)
            log_success "Running on $OS_NAME"
            ;;
        linux)
            log_warning "Running on unsupported Linux distribution: $OS_NAME"
            log_info "This script is optimized for Ubuntu/Debian. Some features may not work."
            if ! confirm "Continue anyway?"; then
                exit 1
            fi
            ;;
        *)
            log_error "Unsupported operating system: $OSTYPE"
            exit 1
            ;;
    esac
}

# Check if Xcode Command Line Tools are installed (macOS only)
check_xcode_tools() {
    if [[ "$OS" != "macos" ]]; then
        return 0
    fi

    log_step "Checking Xcode Command Line Tools"

    if xcode-select -p >/dev/null 2>&1; then
        log_success "Xcode Command Line Tools already installed"
        return 0
    fi

    log_warning "Xcode Command Line Tools not found"
    if confirm "Install Xcode Command Line Tools? (Required for development)"; then
        log_info "Installing Xcode Command Line Tools..."
        xcode-select --install
        log_info "Please complete the installation in the dialog that opened, then run this script again"
        exit 0
    else
        log_error "Xcode Command Line Tools are required. Exiting."
        exit 1
    fi
}

# Install Ubuntu/Debian prerequisites via APT
install_ubuntu_prerequisites() {
    if [[ "$OS" != "ubuntu" ]]; then
        return 0
    fi

    log_step "Installing Ubuntu Prerequisites via APT"

    # Essential build tools required for Linuxbrew and general development
    local apt_packages=(
        "build-essential"
        "curl"
        "file"
        "git"
        "procps"
        "zsh"
        "stow"
        "jq"
        "unzip"
        "zip"
        "fontconfig"
    )

    local missing_packages=()

    # Check which packages are missing
    for pkg in "${apt_packages[@]}"; do
        if ! dpkg -s "$pkg" >/dev/null 2>&1; then
            missing_packages+=("$pkg")
        else
            log_success "$pkg already installed"
        fi
    done

    if [ ${#missing_packages[@]} -eq 0 ]; then
        log_success "All APT prerequisites already installed"
        return 0
    fi

    log_info "Missing APT packages: ${missing_packages[*]}"
    if confirm "Install missing APT packages? (sudo required)"; then
        log_info "Updating APT package list..."
        sudo apt-get update
        log_info "Installing: ${missing_packages[*]}"
        sudo apt-get install -y "${missing_packages[@]}"
        log_success "APT prerequisites installed"
    else
        log_error "APT prerequisites are required. Exiting."
        exit 1
    fi

    # Set Zsh as default shell if not already
    if [[ "$SHELL" != *"zsh"* ]]; then
        log_info "Current shell is not Zsh"
        if confirm "Set Zsh as your default shell?"; then
            chsh -s "$(which zsh)"
            log_success "Zsh set as default shell (will take effect on next login)"
        fi
    else
        log_success "Zsh is already the default shell"
    fi
}

# Check and install Homebrew/Linuxbrew
setup_homebrew() {
    log_step "Checking Homebrew/Linuxbrew"

    if command_exists brew; then
        log_success "Homebrew already installed: $(brew --version | head -n 1)"
        return 0
    fi

    log_warning "Homebrew not found"

    local brew_description="Homebrew"
    if [[ "$OS" == "ubuntu" ]]; then
        brew_description="Linuxbrew (Homebrew for Linux)"
        log_info "Linuxbrew will be used for developer tools (APT handles system packages)"
    fi

    if confirm "Install $brew_description? (Required package manager for dev tools)"; then
        log_info "Installing $brew_description..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

        # Add Homebrew to PATH for this session based on OS
        if [[ "$OS" == "macos" ]]; then
            if [[ -f "/opt/homebrew/bin/brew" ]]; then
                eval "$(/opt/homebrew/bin/brew shellenv)"
                log_success "Homebrew installed successfully (Apple Silicon)"
            elif [[ -f "/usr/local/bin/brew" ]]; then
                eval "$(/usr/local/bin/brew shellenv)"
                log_success "Homebrew installed successfully (Intel)"
            else
                log_warning "Homebrew installed but could not be found in expected locations"
            fi
        elif [[ "$OS" == "ubuntu" ]]; then
            # Linuxbrew installs to /home/linuxbrew/.linuxbrew or ~/.linuxbrew
            if [[ -f "/home/linuxbrew/.linuxbrew/bin/brew" ]]; then
                eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
                log_success "Linuxbrew installed successfully"
            elif [[ -f "$HOME/.linuxbrew/bin/brew" ]]; then
                eval "$("$HOME/.linuxbrew/bin/brew" shellenv)"
                log_success "Linuxbrew installed successfully (user install)"
            else
                log_warning "Linuxbrew installed but could not be found in expected locations"
                log_info "You may need to manually add Linuxbrew to your PATH"
                log_info "Try: eval \"\$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)\""
            fi
        fi

        log_info "Note: Your .zshrc is configured to load Homebrew on shell startup"
    else
        log_error "Homebrew/Linuxbrew is required for developer tools. Exiting."
        exit 1
    fi
}

# Install GNU Stow (already installed via APT on Ubuntu)
install_stow() {
    log_step "Checking GNU Stow and jq"

    # On Ubuntu, these should already be installed via APT prerequisites
    if command_exists stow; then
        log_success "GNU Stow already installed: $(stow --version | head -n 1)"
    else
        log_warning "GNU Stow not found"
        if confirm "Install GNU Stow? (Required for dotfiles management)"; then
            log_info "Installing GNU Stow..."
            if [[ "$OS" == "ubuntu" ]]; then
                sudo apt-get install -y stow
            else
                brew install stow
            fi
            log_success "GNU Stow installed successfully"
        else
            log_error "GNU Stow is required for this dotfiles setup. Exiting."
            exit 1
        fi
    fi

    # Install jq for JSON parsing (used for dynamic package reading)
    if command_exists jq; then
        log_success "jq already installed: $(jq --version 2>/dev/null || echo 'unknown version')"
    else
        log_warning "jq not found (needed for dynamic package configuration)"
        if confirm "Install jq? (Enables dynamic package reading from packages.json)"; then
            log_info "Installing jq..."
            if [[ "$OS" == "ubuntu" ]]; then
                sudo apt-get install -y jq
            else
                brew install jq
            fi
            log_success "jq installed successfully"
        else
            log_warning "jq not installed - will use fallback package lists"
        fi
    fi
}

# Install core dependencies
install_core_dependencies() {
    log_step "Installing Core Dependencies"

    # Read packages from packages.json if available, fallback to hardcoded list
    local packages=()
    if command_exists jq && [ -f "$DOTFILES_DIR/packages.json" ]; then
        # Extract enabled packages from core and security categories in single jq call
        log_info "Reading package list from packages.json..."
        local enabled_packages_list
        enabled_packages_list="$(jq -r '.categories.core.packages, .categories.security.packages | to_entries[] | select(.value.enabled == true) | .key' "$DOTFILES_DIR/packages.json" 2>/dev/null || true)"

        # Build packages array manually for maximum compatibility
        local pkg
        for pkg in $enabled_packages_list; do
            if [ -n "$pkg" ]; then
                packages[${#packages[@]}]="$pkg"
            fi
        done
    else
        # Fallback to hardcoded list if jq or packages.json not available
        log_warning "Using fallback package list (jq or packages.json not found)"
        packages=("starship" "fzf" "zoxide" "tree" "bat" "eza" "ripgrep" "fd" "git-delta" "lazygit" "tmux" "htop" "direnv" "atuin" "gh" "stow" "sops" "age")
    fi
    local missing_packages=()

    # Check which packages are missing
    for package in "${packages[@]}"; do
        if ! brew list "$package" >/dev/null 2>&1; then
            missing_packages+=("$package")
        else
            log_success "$package already installed"
        fi
    done

    if [ ${#missing_packages[@]} -eq 0 ]; then
        log_success "All core dependencies already installed"
        return 0
    fi

    log_info "Missing packages: ${missing_packages[*]}"
    if confirm "Install missing core dependencies?"; then
        log_info "Installing: ${missing_packages[*]}"
        brew install "${missing_packages[@]}"
        log_success "Core dependencies installed"
    else
        log_warning "Skipped core dependencies installation"
    fi
}

# Install development tools
install_dev_tools() {
    log_step "Installing Development Tools (Optional)"

    local dev_tools=("pyenv" "rbenv" "nvm")
    local missing_tools=()

    # Check which tools are missing
    for tool in "${dev_tools[@]}"; do
        if ! brew list "$tool" >/dev/null 2>&1; then
            missing_tools+=("$tool")
        else
            log_success "$tool already installed"
        fi
    done

    if [ ${#missing_tools[@]} -eq 0 ]; then
        log_success "All development tools already installed"
    else
        log_info "Missing development tools: ${missing_tools[*]}"
        if confirm "Install development tools? (Python, Ruby, Node.js version managers)"; then
            log_info "Installing: ${missing_tools[*]}"
            brew install "${missing_tools[@]}"
            log_success "Development tools installed"
        else
            log_warning "Skipped development tools installation"
        fi
    fi

    # Install SDKMAN
    install_sdkman

    # Install Ballerina
    install_ballerina
}

# Install SDKMAN
install_sdkman() {
    log_step "Installing SDKMAN (Java SDK Manager)"

    if [ -d "$HOME/.sdkman" ]; then
        log_success "SDKMAN already installed"
        return 0
    fi

    if confirm "Install SDKMAN? (Java, Gradle, Maven, Kotlin version manager)"; then
        log_info "Installing SDKMAN..."
        curl -s "https://get.sdkman.io" | bash

        # Source SDKMAN for this session
        if [ -f "$HOME/.sdkman/bin/sdkman-init.sh" ]; then
            source "$HOME/.sdkman/bin/sdkman-init.sh"
            log_success "SDKMAN installed successfully"

            if confirm "Install Java 21 LTS via SDKMAN?"; then
                log_info "Installing Java 21 LTS..."
                sdk install java 21.0.5-tem
                log_success "Java 21 installed"
            fi
        else
            log_error "SDKMAN installation failed"
        fi
    else
        log_warning "Skipped SDKMAN installation"
    fi
}

# Install Ballerina
install_ballerina() {
    log_step "Installing Ballerina (Cloud-Native Programming Language)"

    # Check if Ballerina is already installed
    if command -v bal >/dev/null 2>&1; then
        local bal_version
        bal_version=$(bal version 2>&1 | head -n 1)
        log_success "Ballerina already installed: $bal_version"
        return 0
    fi

    if confirm "Install Ballerina programming language?"; then
        if [[ "$OS" == "macos" ]]; then
            log_info "Installing Ballerina via Homebrew..."
            if brew install ballerina; then
                log_success "Ballerina installed successfully"
            else
                log_error "Ballerina installation failed"
                return 1
            fi
        elif [[ "$OS" == "ubuntu" ]]; then
            log_info "Installing Ballerina via official installer..."
            # Download and install the latest Ballerina for Linux
            local bal_version="2201.10.0"
            local bal_url="https://dist.ballerina.io/downloads/${bal_version}/ballerina-${bal_version}-swan-lake-linux-x64.deb"
            local tmp_deb="/tmp/ballerina.deb"

            if curl -fsSL "$bal_url" -o "$tmp_deb"; then
                sudo dpkg -i "$tmp_deb" || sudo apt-get install -f -y
                rm -f "$tmp_deb"
                log_success "Ballerina installed successfully"
            else
                log_warning "Could not download Ballerina. You can install manually from https://ballerina.io/downloads/"
                return 1
            fi
        fi

        # Verify installation
        if command -v bal >/dev/null 2>&1; then
            local bal_version
            bal_version=$(bal version 2>&1 | head -n 1)
            log_success "Ballerina version: $bal_version"
        else
            log_warning "Ballerina installed but not found in PATH. You may need to restart your terminal."
        fi
    else
        log_warning "Skipped Ballerina installation"
    fi
}

# Install terminal applications
# Enhanced tool installation with individual confirmation and legacy detection
install_terminal_apps() {
    log_step "Installing Development Tools (Optional)"

    # Different tool lists for macOS vs Ubuntu
    # macOS uses casks for GUI apps, Ubuntu uses APT/deb or Linuxbrew
    local tools_list=()

    if [[ "$OS" == "macos" ]]; then
        tools_list=(
            "cursor|Code Editor|/Applications/Cursor.app|--cask cursor|Legacy: installer download"
            "visual-studio-code|Code Editor|/Applications/Visual Studio Code.app|--cask visual-studio-code|Legacy: installer download"
            "warp|Terminal|/Applications/Warp.app|--cask warp|Legacy: none"
            "iterm2|Terminal|/Applications/iTerm.app|--cask iterm2|Legacy: none"
            "github-cli|Development|gh command|gh|Legacy: none"
            "postgresql|Database|postgres command|postgresql@16|Legacy: installer or postgres.app"
            "redis|Database|redis-server command|redis|Legacy: manual install"
            "aws-vault|AWS Tool|aws-vault command|aws-vault|Legacy: manual install"
        )
    elif [[ "$OS" == "ubuntu" ]]; then
        # On Ubuntu, use Linuxbrew for CLI tools (Docker handled separately)
        tools_list=(
            "github-cli|Development|gh command|gh|brew"
            "postgresql|Database|postgres command|postgresql@16|brew"
            "redis|Database|redis-server command|redis|brew"
            "aws-vault|AWS Tool|aws-vault command|aws-vault|brew"
            "awscli|AWS CLI|aws command|awscli|brew"
        )
    fi

    # Check each tool individually (compatible approach)
    echo ""
    echo "📋 Tool Installation Status:"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

    local -a to_install
    local tool_info

    for tool_info in "${tools_list[@]}"; do
        IFS='|' read -r tool category app_path install_cmd legacy_info <<<"$tool_info"
        local installed=false

        # Check if tool is installed
        case "$tool" in
            "cursor" | "visual-studio-code" | "warp" | "iterm2")
                if [ -d "$app_path" ]; then
                    installed=true
                # Check for legacy installations
                elif [ "$tool" = "visual-studio-code" ] && command -v code >/dev/null 2>&1; then
                    installed=true
                    legacy_info="Legacy: command 'code' found"
                fi
                ;;
            *)
                local cmd_name
                case "$tool" in
                    "github-cli") cmd_name="gh" ;;
                    "postgresql") cmd_name="postgres" ;;
                    "redis") cmd_name="redis-server" ;;
                    "aws-vault") cmd_name="aws-vault" ;;
                    "awscli") cmd_name="aws" ;;
                    "docker") cmd_name="docker" ;;
                esac
                if command -v "$cmd_name" >/dev/null 2>&1; then
                    installed=true
                fi
                ;;
        esac

        # Display status and ask for installation
        if [ "$installed" = "true" ]; then
            log_success "$tool already installed"
        else
            log_info "$tool not found - $category tool"
            if confirm "Install $tool?"; then
                to_install+=("$tool|$install_cmd|$legacy_info")
            else
                log_info "Skipped $tool installation"
            fi
        fi
    done

    # Install selected tools
    if [ ${#to_install[@]} -gt 0 ]; then
        log_info "Installing selected tools..."

        for tool_install in "${to_install[@]}"; do
            IFS='|' read -r tool install_cmd install_method <<<"$tool_install"
            log_info "Installing $tool..."

            # Use brew for tool installation
            if brew install $install_cmd; then
                log_success "$tool installed successfully"
            else
                log_warning "Failed to install $tool - you may need to install it manually"
            fi
        done
    else
        log_success "All desired tools are already installed or skipped"
    fi
}

# Install GUI applications from packages.json
install_gui_applications() {
    log_step "Installing GUI Applications (Optional)"

    if ! command_exists jq || [ ! -f "$DOTFILES_DIR/packages.json" ]; then
        log_warning "jq or packages.json not found, skipping GUI application installation"
        return 0
    fi

    # Categories with GUI apps (cask type)
    local gui_categories=("browsers" "editors" "database-clients" "productivity" "terminals" "containers")

    for category in "${gui_categories[@]}"; do
        local category_desc
        category_desc=$(jq -r ".categories.\"$category\".description // \"$category\"" "$DOTFILES_DIR/packages.json")

        # Get all cask packages from this category
        local packages_json
        packages_json=$(jq -r ".categories.\"$category\".packages // {} | to_entries[] | select(.value.type == \"cask\") | .key" "$DOTFILES_DIR/packages.json" 2>/dev/null)

        if [ -z "$packages_json" ]; then
            continue
        fi

        echo ""
        log_info "Category: $category_desc"

        for package in $packages_json; do
            local description
            description=$(jq -r ".categories.\"$category\".packages.\"$package\".description" "$DOTFILES_DIR/packages.json")

            # Check if already installed
            local installed=false

            if [[ "$OS" == "macos" ]]; then
                # Check if cask is installed or app exists
                if brew list --cask "$package" >/dev/null 2>&1; then
                    installed=true
                fi
                # Check common app locations
                case "$package" in
                    "google-chrome")
                        [ -d "/Applications/Google Chrome.app" ] && installed=true ;;
                    "visual-studio-code")
                        [ -d "/Applications/Visual Studio Code.app" ] && installed=true ;;
                    "intellij-idea")
                        [ -d "/Applications/IntelliJ IDEA.app" ] && installed=true ;;
                    "postman")
                        [ -d "/Applications/Postman.app" ] && installed=true ;;
                    "dbeaver-community")
                        [ -d "/Applications/DBeaver.app" ] && installed=true ;;
                    "pgadmin4")
                        [ -d "/Applications/pgAdmin 4.app" ] && installed=true ;;
                    "mongodb-compass")
                        [ -d "/Applications/MongoDB Compass.app" ] && installed=true ;;
                esac
            elif [[ "$OS" == "ubuntu" ]]; then
                # Check using dpkg or command
                case "$package" in
                    "google-chrome")
                        command -v google-chrome >/dev/null 2>&1 && installed=true ;;
                    "visual-studio-code")
                        command -v code >/dev/null 2>&1 && installed=true ;;
                    "intellij-idea")
                        [ -d "$HOME/.local/share/JetBrains/Toolbox" ] && installed=true ;;
                    "postman")
                        [ -d "/opt/Postman" ] || command -v postman >/dev/null 2>&1 && installed=true ;;
                    "dbeaver-community")
                        dpkg -s dbeaver-ce >/dev/null 2>&1 && installed=true ;;
                    "pgadmin4")
                        dpkg -s pgadmin4-desktop >/dev/null 2>&1 && installed=true ;;
                    "mongodb-compass")
                        command -v mongodb-compass >/dev/null 2>&1 && installed=true ;;
                esac
            fi

            if [ "$installed" = true ]; then
                log_success "$package already installed"
            else
                if confirm "Install $package? ($description)"; then
                    install_gui_app "$package" "$category"
                else
                    log_info "Skipped $package"
                fi
            fi
        done
    done
}

# Install a single GUI application
install_gui_app() {
    local package="$1"
    local category="$2"

    if [[ "$OS" == "macos" ]]; then
        log_info "Installing $package via Homebrew Cask..."
        if brew install --cask "$package"; then
            log_success "$package installed successfully"
        else
            log_error "Failed to install $package"
        fi
    elif [[ "$OS" == "ubuntu" ]]; then
        # Get Ubuntu-specific installation info from packages.json
        local ubuntu_config
        ubuntu_config=$(jq -r ".categories.\"$category\".packages.\"$package\".ubuntu // empty" "$DOTFILES_DIR/packages.json")

        if [ -z "$ubuntu_config" ]; then
            log_warning "No Ubuntu installation method defined for $package"
            return 1
        fi

        local method
        method=$(echo "$ubuntu_config" | jq -r ".method")

        case "$method" in
            "deb")
                local deb_url
                deb_url=$(echo "$ubuntu_config" | jq -r ".url")
                local tmp_deb="/tmp/${package}.deb"

                log_info "Downloading $package..."
                if curl -fsSL "$deb_url" -o "$tmp_deb"; then
                    log_info "Installing $package..."
                    if sudo dpkg -i "$tmp_deb" || sudo apt-get install -f -y; then
                        log_success "$package installed successfully"
                    else
                        log_error "Failed to install $package"
                    fi
                    rm -f "$tmp_deb"
                else
                    log_error "Failed to download $package"
                fi
                ;;
            "apt-repo")
                local apt_package setup_commands
                apt_package=$(echo "$ubuntu_config" | jq -r ".package")

                log_info "Setting up repository for $package..."
                # Run setup commands
                local cmd_count
                cmd_count=$(echo "$ubuntu_config" | jq -r ".setup_commands | length")

                for ((i = 0; i < cmd_count; i++)); do
                    local cmd
                    cmd=$(echo "$ubuntu_config" | jq -r ".setup_commands[$i]")
                    log_info "Running: $cmd"
                    if ! eval "$cmd"; then
                        log_error "Setup command failed for $package"
                        return 1
                    fi
                done

                log_info "Installing $apt_package..."
                if sudo apt-get install -y "$apt_package"; then
                    log_success "$package installed successfully"
                else
                    log_error "Failed to install $package"
                fi
                ;;
            "tarball")
                local tarball_url install_dir binary_name
                tarball_url=$(echo "$ubuntu_config" | jq -r ".url")
                install_dir=$(echo "$ubuntu_config" | jq -r ".install_dir // \"/opt/$package\"")
                binary_name=$(echo "$ubuntu_config" | jq -r ".binary_name // \"$package\"")
                local tmp_tar="/tmp/${package}.tar.gz"

                log_info "Downloading $package..."
                if curl -fsSL "$tarball_url" -o "$tmp_tar"; then
                    log_info "Extracting to $install_dir..."
                    sudo mkdir -p "$install_dir"
                    sudo tar -xzf "$tmp_tar" -C "$(dirname "$install_dir")" --strip-components=0
                    rm -f "$tmp_tar"

                    # Create desktop entry if requested
                    local create_desktop
                    create_desktop=$(echo "$ubuntu_config" | jq -r ".desktop_file // false")
                    if [ "$create_desktop" = "true" ]; then
                        local desktop_file="$HOME/.local/share/applications/${package}.desktop"
                        mkdir -p "$HOME/.local/share/applications"
                        cat > "$desktop_file" <<EOF
[Desktop Entry]
Name=$binary_name
Exec=$install_dir/$binary_name
Icon=$install_dir/app/resources/app/assets/icon.png
Type=Application
Categories=Development;
EOF
                        log_info "Created desktop entry: $desktop_file"
                    fi

                    # Create symlink to /usr/local/bin
                    if [ -f "$install_dir/$binary_name" ]; then
                        sudo ln -sf "$install_dir/$binary_name" "/usr/local/bin/${package,,}"
                    fi

                    log_success "$package installed successfully"
                else
                    log_error "Failed to download $package"
                fi
                ;;
            "jetbrains-toolbox")
                log_info "Installing JetBrains Toolbox..."
                local toolbox_url="https://data.services.jetbrains.com/products/download?platform=linux&code=TBA"
                local tmp_tar="/tmp/jetbrains-toolbox.tar.gz"

                if curl -fsSL -o "$tmp_tar" "$toolbox_url"; then
                    log_info "Extracting JetBrains Toolbox..."
                    local extract_dir="/tmp/jetbrains-toolbox-extract"
                    mkdir -p "$extract_dir"
                    tar -xzf "$tmp_tar" -C "$extract_dir" --strip-components=1
                    rm -f "$tmp_tar"

                    # Run the toolbox installer
                    local toolbox_bin
                    toolbox_bin=$(find "$extract_dir" -name "jetbrains-toolbox" -type f | head -n 1)
                    if [ -n "$toolbox_bin" ]; then
                        log_info "Launching JetBrains Toolbox installer..."
                        "$toolbox_bin" &
                        log_success "JetBrains Toolbox launched. Use it to install IntelliJ IDEA Ultimate."
                        log_info "The Toolbox will manage IDE installations and updates automatically."
                    else
                        log_error "Could not find JetBrains Toolbox executable"
                    fi
                    rm -rf "$extract_dir"
                else
                    log_error "Failed to download JetBrains Toolbox"
                fi
                ;;
            "mongodb-compass")
                log_info "Fetching latest MongoDB Compass version..."
                # Get the latest version from MongoDB download center
                local compass_version
                compass_version=$(curl -fsSL "https://www.mongodb.com/try/download/compass" 2>/dev/null | grep -oP 'mongodb-compass_\K[0-9]+\.[0-9]+\.[0-9]+' | head -1)

                if [ -z "$compass_version" ]; then
                    # Fallback to a known stable version
                    compass_version="1.44.5"
                    log_warning "Could not detect latest version, using $compass_version"
                fi

                local compass_url="https://downloads.mongodb.com/compass/mongodb-compass_${compass_version}_amd64.deb"
                local tmp_deb="/tmp/mongodb-compass.deb"

                log_info "Downloading MongoDB Compass v${compass_version}..."
                if curl -fsSL "$compass_url" -o "$tmp_deb"; then
                    log_info "Installing MongoDB Compass..."
                    if sudo dpkg -i "$tmp_deb" || sudo apt-get install -f -y; then
                        log_success "MongoDB Compass installed successfully"
                    else
                        log_error "Failed to install MongoDB Compass"
                    fi
                    rm -f "$tmp_deb"
                else
                    log_error "Failed to download MongoDB Compass"
                fi
                ;;
            *)
                log_warning "Unknown installation method: $method for $package"
                return 1
                ;;
        esac
    fi
}

# Install Docker on Ubuntu
install_docker_ubuntu() {
    if [[ "$OS" != "ubuntu" ]]; then
        return 0
    fi

    if command_exists docker; then
        log_success "Docker already installed: $(docker --version)"
        return 0
    fi

    log_step "Installing Docker"

    if confirm "Install Docker Engine? (Recommended for containerized development)"; then
        log_info "Installing Docker using official script..."

        # Remove old versions if present
        sudo apt-get remove -y docker docker-engine docker.io containerd runc 2>/dev/null || true

        # Install using official convenience script
        curl -fsSL https://get.docker.com -o /tmp/get-docker.sh
        sudo sh /tmp/get-docker.sh
        rm /tmp/get-docker.sh

        # Add current user to docker group
        sudo usermod -aG docker "$USER"
        log_success "Docker installed successfully"
        log_warning "You may need to log out and back in for docker group membership to take effect"
    else
        log_warning "Skipped Docker installation"
    fi
}

# Install Nerd Fonts
install_fonts() {
    log_step "Installing Nerd Fonts"

    local font_installed=false

    if [[ "$OS" == "macos" ]]; then
        # Check if FiraCode Nerd Font is installed on macOS
        if ls "$HOME/Library/Fonts/FiraCodeNerdFont"*.ttf >/dev/null 2>&1 ||
            brew list --cask font-fira-code-nerd-font >/dev/null 2>&1; then
            font_installed=true
        fi
    elif [[ "$OS" == "ubuntu" ]]; then
        # Check if FiraCode Nerd Font is installed on Linux
        if fc-list | grep -qi "FiraCode Nerd" 2>/dev/null; then
            font_installed=true
        fi
    fi

    if [ "$font_installed" = true ]; then
        log_success "FiraCode Nerd Font already installed"
        return 0
    fi

    log_warning "Nerd Font not found"
    if confirm "Install FiraCode Nerd Font? (Required for proper prompt display)"; then
        if [[ "$OS" == "macos" ]]; then
            log_info "Installing FiraCode Nerd Font via Homebrew..."
            brew install --cask font-fira-code-nerd-font
            log_success "FiraCode Nerd Font installed"
        elif [[ "$OS" == "ubuntu" ]]; then
            log_info "Installing FiraCode Nerd Font..."
            local font_dir="$HOME/.local/share/fonts"
            mkdir -p "$font_dir"

            # Download FiraCode Nerd Font
            local nerd_font_url="https://github.com/ryanoasis/nerd-fonts/releases/latest/download/FiraCode.zip"
            local tmp_zip="/tmp/FiraCode.zip"

            if curl -fsSL "$nerd_font_url" -o "$tmp_zip"; then
                unzip -o "$tmp_zip" -d "$font_dir" -x "*.md" -x "*.txt" -x "LICENSE" 2>/dev/null || true
                rm -f "$tmp_zip"
                # Refresh font cache
                fc-cache -fv "$font_dir" >/dev/null 2>&1
                log_success "FiraCode Nerd Font installed"
            else
                log_warning "Could not download Nerd Font. Install manually from https://www.nerdfonts.com/"
            fi
        fi
        log_info "Please configure your terminal to use 'FiraCode Nerd Font'"
    else
        log_warning "Skipped font installation - prompt may not display correctly"
    fi
}

# Install Zinit
install_zinit() {
    log_step "Installing Zinit (Zsh Plugin Manager)"

    local zinit_dir="${HOME}/.local/share/zinit/zinit.git"

    if [ -d "$zinit_dir" ]; then
        log_success "Zinit already installed"
        return 0
    fi

    if confirm "Install Zinit plugin manager?"; then
        log_info "Installing Zinit..."
        bash -c "$(curl --fail --show-error --silent --location https://raw.githubusercontent.com/zdharma-continuum/zinit/HEAD/scripts/install.sh)"
        log_success "Zinit installed"
    else
        log_warning "Skipped Zinit installation"
    fi
}

# Setup environment file
setup_environment() {
    log_step "Setting up Environment Variables"

    if [ -f "$DOTFILES_DIR/zsh/.env" ] && [ -s "$DOTFILES_DIR/zsh/.env" ]; then
        log_success "Environment file already configured"
        return 0
    fi

    if [ ! -f "$DOTFILES_DIR/zsh/.env.example" ]; then
        log_error ".env.example not found in zsh directory"
        return 1
    fi

    log_info "Creating .env file from template"
    cp "$DOTFILES_DIR/zsh/.env.example" "$DOTFILES_DIR/zsh/.env"

    log_warning "Please edit $DOTFILES_DIR/zsh/.env with your personal information:"
    log_info "  - GitHub username"
    log_info "  - GitHub Personal Access Token (if needed)"

    if confirm "Open .env file for editing now?"; then
        if command_exists code; then
            code "$DOTFILES_DIR/zsh/.env"
        elif command_exists vim; then
            vim "$DOTFILES_DIR/zsh/.env"
        else
            nano "$DOTFILES_DIR/zsh/.env"
        fi
    fi
}

# Setup Git personal configuration
setup_git_config() {
    log_step "Setting up Git Personal Configuration"

    if [ -f "$HOME/.gitconfig.local" ]; then
        log_success "Git personal config already exists"
        return 0
    fi

    if [ -f "$DOTFILES_DIR/git/.gitconfig.local.example" ]; then
        log_info "Creating personal Git configuration from template"
        cp "$DOTFILES_DIR/git/.gitconfig.local.example" "$HOME/.gitconfig.local"

        log_warning "Please edit ~/.gitconfig.local with your personal Git information:"
        log_info "  - Your full name"
        log_info "  - Your email address"
        log_info "  - GitHub/GitLab usernames"

        if confirm "Open Git config for editing now?"; then
            if command_exists code; then
                code "$HOME/.gitconfig.local"
            elif command_exists vim; then
                vim "$HOME/.gitconfig.local"
            else
                nano "$HOME/.gitconfig.local"
            fi
        fi
    else
        log_warning "Git config template not found, skipping personal Git setup"
    fi
}

# Backup existing dotfiles
backup_existing_files() {
    log_step "Backing up existing dotfiles"

    local files=(".zshrc" ".vimrc" ".aliases.sh" ".functions.sh" ".paths.sh")
    local backup_dir
    backup_dir="$HOME/.dotfiles_backup_$(date +%Y%m%d_%H%M%S)"
    local backed_up=false

    for file in "${files[@]}"; do
        if [ -f "$HOME/$file" ] && [ ! -L "$HOME/$file" ]; then
            if [ "$backed_up" = false ]; then
                mkdir -p "$backup_dir"
                backed_up=true
                log_info "Creating backup directory: $backup_dir"
            fi
            cp "$HOME/$file" "$backup_dir/"
            log_info "Backed up: $file"
        fi
    done

    if [ "$backed_up" = true ]; then
        log_success "Existing dotfiles backed up to: $backup_dir"
    else
        log_info "No existing dotfiles to backup"
    fi
}

# Setup encrypted secret management with SOPS and age
setup_secret_management() {
    log_step "Setting up Encrypted Secret Management"

    # Check if SOPS is installed
    if ! command -v sops >/dev/null 2>&1; then
        log_error "SOPS is not installed. Please install it with: brew install sops"
        log_info "SOPS should have been installed with core dependencies."
        return 1
    fi

    # Setup age encryption
    local age_dir="$HOME/.config/sops/age"
    local age_key_file="$age_dir/keys.txt"
    local sops_config="$HOME/.sops.yaml"

    # Create age directory if it doesn't exist
    if [ ! -d "$age_dir" ]; then
        log_info "Creating age directory..."
        mkdir -p "$age_dir"
    fi

    # Generate age key if it doesn't exist
    if [ ! -f "$age_key_file" ]; then
        if command -v age-keygen >/dev/null 2>&1; then
            log_info "Generating age encryption key..."
            age-keygen -o "$age_key_file"
            chmod 600 "$age_key_file"
            log_success "Age encryption key generated"
        else
            log_error "age-keygen not found. Please install age: brew install age"
            return 1
        fi
    else
        log_success "Age encryption key already exists"
    fi

    # Get the public key for SOPS config
    local public_key
    public_key=$(grep "^# public key:" "$age_key_file" | cut -d' ' -f4)
    if [ -z "$public_key" ]; then
        log_error "Could not extract public key from age key file"
        return 1
    fi

    # Create .sops.yaml configuration
    if [ ! -f "$sops_config" ]; then
        log_info "Creating sops configuration..."
        cat >"$sops_config" <<EOF
creation_rules:
  - path_regex: \.env$
    age: $public_key
  - path_regex: \.env\.sops$
    age: $public_key
  - path_regex: \.secrets\.sops\.ya?ml$
    age: $public_key
EOF
        log_success "Created .sops.yaml configuration"
    else
        log_success "sops configuration already exists"
    fi

    # Handle .env file (single file approach)
    local env_file="$HOME/.env"

    if [ -f "$env_file" ]; then
        # Check if file is already encrypted
        if head -1 "$env_file" | grep -q "^#ENC\["; then
            log_success ".env file is already encrypted"
        else
            log_info "Found plaintext .env file"

            # Check if the file uses export format
            if grep -q "^export " "$env_file"; then
                log_info "Your .env file uses shell 'export KEY=value' format - perfect for sourcing!"
            fi

            if confirm "Encrypt .env file in-place with sops?"; then
                log_info "Creating backup and encrypting .env file..."

                # Create backup for safety
                cp "$env_file" "$env_file.backup"
                log_info "Created backup: $env_file.backup"

                # Encrypt in-place
                if sops --config "$HOME/.sops.yaml" --encrypt --in-place "$env_file"; then
                    # Verify encryption worked
                    if head -1 "$env_file" | grep -q "^#ENC\["; then
                        log_success "Successfully encrypted .env file in-place"
                        log_info "Backup saved as $env_file.backup"
                    else
                        log_error "Encryption failed - restoring from backup"
                        cp "$env_file.backup" "$env_file"
                        return 1
                    fi
                else
                    log_error "Failed to encrypt .env file - restoring from backup"
                    cp "$env_file.backup" "$env_file"
                    return 1
                fi
            fi
        fi
    else
        if confirm "Create new .env file from template?"; then
            log_info "Creating .env file from template..."
            cp "$DOTFILES_DIR/zsh/.env.example" "$env_file"

            log_info "Opening .env file for editing..."
            if command -v code >/dev/null 2>&1; then
                code "$env_file"
            elif command -v vim >/dev/null 2>&1; then
                vim "$env_file"
            else
                nano "$env_file"
            fi

            if confirm "Encrypt the .env file now?"; then
                log_info "Encrypting .env file..."
                if sops --config "$HOME/.sops.yaml" --encrypt --in-place "$env_file"; then
                    if head -1 "$env_file" | grep -q "^#ENC\["; then
                        log_success "Successfully encrypted new .env file"
                    else
                        log_error "Encryption failed"
                        return 1
                    fi
                else
                    log_error "Failed to encrypt .env file"
                    return 1
                fi
            fi
        fi
    fi

    log_success "Secret management setup complete"
    log_info "Note: Your .zshrc is configured to automatically handle encrypted .env files"

    # Add .env to .gitignore if not already there
    local gitignore_file="$DOTFILES_DIR/.gitignore"
    if [ -f "$gitignore_file" ] && ! grep -q "\.env$" "$gitignore_file"; then
        echo ".env" >>"$gitignore_file"
        log_success "Added .env to .gitignore"
    fi

    log_info "Secret Management Commands:"
    log_info "  • Edit secrets: edit_secrets"
    log_info "  • View secrets: sops -d ~/.env"
    log_info "  • Direct edit: sops ~/.env"
}

# Handle stow conflicts for a specific file
handle_stow_conflict() {
    local conflict_file="$1"
    local package="$2"

    echo ""
    log_warning "Conflict detected: $conflict_file"
    log_info "This file already exists in your home directory"
    echo ""
    echo -e "${CYAN}Options:${NC}"
    echo -e "  ${YELLOW}b${NC}) Backup existing file and replace with stow symlink"
    echo -e "  ${YELLOW}k${NC}) Keep existing file (skip stowing this file)"
    echo -e "  ${YELLOW}s${NC}) Show diff between existing and dotfiles version"
    echo -e "  ${YELLOW}q${NC}) Quit installation"
    echo ""

    while true; do
        echo -en "  ${YELLOW}Choose action (b/k/s/q): ${NC}"
        read -r -n 1 choice
        echo

        case "$choice" in
            [Bb])
                local backup_dir
                backup_dir="$HOME/.dotfiles_backup_$(date +%Y%m%d_%H%M%S)"
                mkdir -p "$backup_dir"
                mv "$conflict_file" "$backup_dir/"
                log_success "Backed up to: $backup_dir/$(basename "$conflict_file")"
                return 0
                ;;
            [Kk])
                log_info "Keeping existing file: $conflict_file"
                return 1
                ;;
            [Ss])
                local dotfile_path="$DOTFILES_DIR/$package/${conflict_file#"$HOME"/}"
                if [ -f "$dotfile_path" ]; then
                    echo -e "\n${CYAN}=== Diff: Existing (left) vs Dotfiles (right) ===${NC}"
                    if command -v delta >/dev/null 2>&1; then
                        diff -u "$conflict_file" "$dotfile_path" | delta
                    else
                        diff -u "$conflict_file" "$dotfile_path" || true
                    fi
                    echo ""
                else
                    log_warning "Could not find dotfile at: $dotfile_path"
                fi
                ;;
            [Qq])
                log_info "Installation cancelled by user"
                exit 0
                ;;
            *)
                echo -e "  ${YELLOW}${WARNING} Please press 'b', 'k', 's', or 'q'${NC}"
                ;;
        esac
    done
}

# Use stow to create symlinks with conflict resolution
stow_packages() {
    log_step "Using Stow to manage dotfiles"

    local packages=("zsh" "vim" ".config" "git" "tmux" "direnv")
    local stowed_packages=()
    local skipped_files=()

    for package in "${packages[@]}"; do
        if [ -d "$DOTFILES_DIR/$package" ]; then
            log_info "Processing $package package..."

            # Use stow to create symlinks
            # Note: Exclusions are managed via .stow-local-ignore files in each package
            local stow_args=(-t "$HOME" "$package")

            # First, try a dry-run to detect conflicts
            local stow_output
            stow_output=$(stow -n "${stow_args[@]}" 2>&1)
            local stow_status=$?

            if [ $stow_status -eq 0 ]; then
                # No conflicts, proceed with stowing
                if stow "${stow_args[@]}" 2>/dev/null; then
                    log_success "Stowed $package package"
                    stowed_packages+=("$package")
                else
                    log_error "Unexpected error stowing $package package"
                fi
            else
                # Check if it's already stowed
                if echo "$stow_output" | grep -q "already stowed"; then
                    log_success "$package package already stowed"
                    stowed_packages+=("$package")
                # Check for conflicts
                elif echo "$stow_output" | grep -q "existing target"; then
                    log_warning "Conflicts detected in $package package"

                    # Extract conflicting files from stow output
                    local conflicts
                    conflicts=$(echo "$stow_output" | grep "existing target" | sed 's/.*existing target is //g' | sed 's/ .*//g')

                    # Ask user how to handle conflicts
                    echo ""
                    log_info "Found conflicts in $package package. How would you like to proceed?"
                    echo ""
                    echo -e "${CYAN}Options:${NC}"
                    echo -e "  ${YELLOW}a${NC}) Backup ALL conflicting files and replace with stow symlinks"
                    echo -e "  ${YELLOW}i${NC}) Handle each conflict individually"
                    echo -e "  ${YELLOW}k${NC}) Keep all existing files (skip this package)"
                    echo -e "  ${YELLOW}q${NC}) Quit installation"
                    echo ""

                    while true; do
                        echo -en "  ${YELLOW}Choose action (a/i/k/q): ${NC}"
                        read -r -n 1 bulk_choice
                        echo

                        case "$bulk_choice" in
                            [Aa])
                                # Backup all conflicts
                                local backup_dir
                                backup_dir="$HOME/.dotfiles_backup_$(date +%Y%m%d_%H%M%S)"
                                mkdir -p "$backup_dir"
                                log_info "Creating backup directory: $backup_dir"

                                for conflict in $conflicts; do
                                    if [ -f "$conflict" ] || [ -d "$conflict" ]; then
                                        mv "$conflict" "$backup_dir/"
                                        log_success "Backed up: $(basename "$conflict")"
                                    fi
                                done

                                # Now stow should work
                                if stow "${stow_args[@]}" 2>/dev/null; then
                                    log_success "Stowed $package package"
                                    stowed_packages+=("$package")
                                else
                                    log_error "Failed to stow $package after backup"
                                fi
                                break
                                ;;
                            [Ii])
                                # Handle individually
                                local can_stow=true
                                for conflict in $conflicts; do
                                    if ! handle_stow_conflict "$conflict" "$package"; then
                                        can_stow=false
                                        skipped_files+=("$conflict")
                                    fi
                                done

                                if [ "$can_stow" = true ]; then
                                    if stow "${stow_args[@]}" 2>/dev/null; then
                                        log_success "Stowed $package package"
                                        stowed_packages+=("$package")
                                    else
                                        log_warning "Some files in $package were skipped"
                                    fi
                                else
                                    log_warning "Skipped $package package due to conflicts"
                                fi
                                break
                                ;;
                            [Kk])
                                log_info "Skipped $package package"
                                break
                                ;;
                            [Qq])
                                log_info "Installation cancelled by user"
                                exit 0
                                ;;
                            *)
                                echo -e "  ${YELLOW}${WARNING} Please press 'a', 'i', 'k', or 'q'${NC}"
                                ;;
                        esac
                    done
                else
                    # Some other error, try restowing
                    if stow -R "${stow_args[@]}" 2>/dev/null; then
                        log_success "Re-stowed $package package"
                        stowed_packages+=("$package")
                    else
                        log_error "Could not stow $package package"
                    fi
                fi
            fi
        else
            log_warning "Package directory not found: $package"
        fi
    done

    if [ ${#stowed_packages[@]} -gt 0 ]; then
        log_success "Successfully stowed packages: ${stowed_packages[*]}"
    else
        log_error "No packages were stowed successfully"
        return 1
    fi

    if [ ${#skipped_files[@]} -gt 0 ]; then
        echo ""
        log_info "Note: Some files were skipped and kept as-is:"
        for skipped in "${skipped_files[@]}"; do
            log_info "  - $skipped"
        done
    fi
}

# Test installation
test_installation() {
    log_step "Testing Installation"

    local errors=0

    # Test zsh syntax
    if zsh -n "$HOME/.zshrc" >/dev/null 2>&1; then
        log_success "Zsh configuration syntax is valid"
    else
        log_error "Zsh configuration has syntax errors"
        ((errors++))
    fi

    # Test function files
    if bash -n "$HOME/.functions.sh" >/dev/null 2>&1; then
        log_success "Functions file syntax is valid"
    else
        log_error "Functions file has syntax errors"
        ((errors++))
    fi

    # Test aliases file
    if bash -n "$HOME/.aliases.sh" >/dev/null 2>&1; then
        log_success "Aliases file syntax is valid"
    else
        log_error "Aliases file has syntax errors"
        ((errors++))
    fi

    # Test command availability
    local commands=("starship" "fzf" "zoxide")
    for cmd in "${commands[@]}"; do
        if command_exists "$cmd"; then
            log_success "$cmd is available"
        else
            log_warning "$cmd is not available (may need to restart terminal)"
        fi
    done

    # Verify Starship configuration
    if command_exists starship; then
        if [ -L "$HOME/.config/starship.toml" ] || [ -f "$HOME/.config/starship.toml" ]; then
            log_success "Starship config found at ~/.config/starship.toml"

            # Test if starship can be initialized
            if starship init zsh >/dev/null 2>&1; then
                log_success "Starship initializes correctly"
            else
                log_warning "Starship initialization has errors - check config"
                ((errors++))
            fi
        else
            log_warning "Starship config not found at ~/.config/starship.toml"
            log_info "Run 'stow config' to create the symlink"
        fi
    fi

    if [ $errors -eq 0 ]; then
        log_success "Installation test passed!"
    else
        log_error "Installation test found $errors errors"
        return 1
    fi
}

# Print final instructions
print_final_instructions() {
    echo -e "\n${GREEN}🎉 Dotfiles installation completed on $OS_NAME!${NC}\n"

    echo -e "${CYAN}Next steps:${NC}"
    echo -e "1. ${YELLOW}Restart your terminal${NC} or run: ${BLUE}source ~/.zshrc${NC}"
    echo -e "2. ${YELLOW}Configure your terminal font${NC} to use 'FiraCode Nerd Font'"
    echo -e "3. ${YELLOW}Test the setup${NC} with: ${BLUE}take test-directory${NC}"
    echo -e "4. ${YELLOW}Explore available aliases${NC} with: ${BLUE}alias | grep git${NC}"

    echo -e "\n${CYAN}Terminal font configuration:${NC}"
    if [[ "$OS" == "macos" ]]; then
        echo -e "• ${YELLOW}Warp:${NC} Settings → Appearance → Text → Font"
        echo -e "• ${YELLOW}iTerm2:${NC} Preferences → Profiles → Text → Font"
        echo -e "• ${YELLOW}Terminal.app:${NC} Preferences → Profiles → Text → Font"
    elif [[ "$OS" == "ubuntu" ]]; then
        echo -e "• ${YELLOW}GNOME Terminal:${NC} Preferences → Profiles → Text → Custom font"
        echo -e "• ${YELLOW}Terminator:${NC} Right-click → Preferences → Profiles → Font"
        echo -e "• ${YELLOW}VS Code:${NC} Settings → terminal.integrated.fontFamily"
        echo -e "• ${YELLOW}Tilix:${NC} Preferences → Profiles → Font"
    fi

    echo -e "\n${CYAN}Useful commands to try:${NC}"
    echo -e "• ${BLUE}show_tools${NC} - Discover all modern CLI tools with examples"
    echo -e "• ${BLUE}lg${NC} - Open lazygit for interactive git operations"
    echo -e "• ${BLUE}gffs feature-name${NC} - Start a new git-flow feature branch"
    echo -e "• ${BLUE}ll${NC} - Enhanced file listing with icons and git status"
    echo -e "• ${BLUE}take my-project${NC} - Create and enter directory"
    echo -e "• ${BLUE}kill_by_port 3000${NC} - Kill processes on port 3000"
    echo -e "• ${BLUE}alias_search docker${NC} - Find all Docker-related aliases"

    echo -e "\n${CYAN}For help and troubleshooting:${NC}"
    echo -e "• Check the README.md file"
    echo -e "• Open an issue on GitHub"

    if [[ "$OS" == "ubuntu" ]]; then
        echo -e "\n${CYAN}Ubuntu-specific notes:${NC}"
        echo -e "• System packages are managed via APT"
        echo -e "• Developer tools are managed via Linuxbrew (brew command)"
        echo -e "• To update dev tools: ${BLUE}brew update && brew upgrade${NC}"
    fi

    echo ""
    echo -e "${GREEN}╔══════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║          🎉 Installation Complete! 🎉     ║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${GREEN}Enjoy your enhanced development environment! 🚀${NC}"
    echo ""
}

# Main execution
main() {
    if [ "$1" == "--dry-run" ]; then
        echo "Dry run successful"
        exit 0
    fi

    clear
    echo ""
    echo -e "${PURPLE}╔══════════════════════════════════════════╗${NC}"
    echo -e "${PURPLE}║        Thisaru's Dotfiles Installer      ║${NC}"
    echo -e "${PURPLE}║    Enhanced Development Environment      ║${NC}"
    echo -e "${PURPLE}║      Supports macOS & Ubuntu/Debian      ║${NC}"
    echo -e "${PURPLE}╚══════════════════════════════════════════╝${NC}"
    echo ""

    # Verify we're in the right directory
    if [ ! -f "$(pwd)/init.sh" ] || [ ! -f "$(pwd)/zsh/.zshrc" ]; then
        log_error "Please run this script from the dotfiles directory"
        log_info "Usage: cd ~/dotfiles && ./init.sh  # or ~/.dotfiles"
        exit 1
    fi

    log_info "Detected OS: $OS_NAME"
    log_info "Starting installation from: $DOTFILES_DIR"
    log_info "This script will set up your complete development environment"
    echo -e "${CYAN}${INFO} During installation, press 'y' for yes, 'n' for no, or 'q' to quit (no Enter needed)${NC}"

    if ! confirm "Continue with installation?"; then
        log_info "Installation cancelled"
        exit 0
    fi

    # Run installation steps (order matters!)

    # Step 1: Check OS compatibility
    check_os

    # Step 2: Install OS-specific prerequisites
    if [[ "$OS" == "macos" ]]; then
        check_xcode_tools
    elif [[ "$OS" == "ubuntu" ]]; then
        install_ubuntu_prerequisites
    fi

    # Step 3: Install Homebrew/Linuxbrew (universal package manager for dev tools)
    setup_homebrew

    # Step 4: Install essential tools
    install_stow
    install_core_dependencies

    # Step 5: Install development tools
    install_dev_tools

    # Step 6: Install optional applications
    install_terminal_apps
    install_gui_applications
    if [[ "$OS" == "ubuntu" ]]; then
        install_docker_ubuntu
    fi

    # Step 7: Install fonts
    install_fonts

    # Step 8: Install shell plugins
    install_zinit

    # Step 9: Setup configuration
    setup_environment
    setup_secret_management
    backup_existing_files
    stow_packages
    setup_git_config

    # Step 10: Test and finish
    test_installation
    print_final_instructions
}

# Run main function
main "$@"
