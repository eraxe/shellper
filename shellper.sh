#!/bin/bash
#
# ZSH Setup Script
# This script helps quickly set up zsh with oh-my-zsh and custom configurations
# on various Linux distributions (Alma/RHEL, Debian/Ubuntu, Arch).
#
# Author: Claude
# Created: May 2, 2025
#

# Set up colors for better visualization
C_RESET="\033[0m"
C_GREEN="\033[0;32m"
C_YELLOW="\033[0;33m"
C_BLUE="\033[0;34m"
C_RED="\033[0;31m"
C_CYAN="\033[0;36m"

log_success() { echo -e "${C_GREEN}[SUCCESS]${C_RESET} $1"; }
log_info() { echo -e "${C_BLUE}[INFO]${C_RESET} $1"; }
log_warning() { echo -e "${C_YELLOW}[WARNING]${C_RESET} $1"; }
log_error() { echo -e "${C_RED}[ERROR]${C_RESET} $1"; }
log_step() { echo -e "\n${C_CYAN}==== $1 ====${C_RESET}"; }

# Function to detect the Linux distribution
detect_distro() {
    log_step "Detecting Distribution"
    
    # Check for common distribution identification files
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        DISTRO=$ID
        VERSION=$VERSION_ID
    elif [ -f /etc/lsb-release ]; then
        . /etc/lsb-release
        DISTRO=$DISTRIB_ID
        VERSION=$DISTRIB_RELEASE
    elif [ -f /etc/redhat-release ]; then
        DISTRO="rhel"
    elif [ -f /etc/arch-release ]; then
        DISTRO="arch"
    else
        DISTRO="unknown"
    fi
    
    # Normalize distro names
    case "${DISTRO,,}" in
        "ubuntu"|"debian"|"linuxmint"|"pop"|"elementary"|"zorin")
            DISTRO_TYPE="debian"
            ;;
        "rhel"|"centos"|"fedora"|"almalinux"|"rocky"|"ol"|"scientific")
            DISTRO_TYPE="rhel"
            ;;
        "arch"|"manjaro"|"endeavouros"|"garuda"|"artix"|"cachyos")
            DISTRO_TYPE="arch"
            ;;
        *)
            DISTRO_TYPE="unknown"
            ;;
    esac
    
    log_info "Detected Linux distribution: $DISTRO ($DISTRO_TYPE)"
}

# Function to install dependencies based on distribution
install_dependencies() {
    log_step "Installing ZSH and Dependencies"
    
    case "$DISTRO_TYPE" in
        "debian")
            log_info "Using apt package manager..."
            sudo apt update
            sudo apt install -y zsh curl git wget 
            
            # Try to install optional tools
            sudo apt install -y fonts-powerline fzf 2>/dev/null || log_warning "Couldn't install fonts-powerline or fzf"
            
            # Handle bat and fd which have different package names on some Debian-based systems
            if ! command -v bat &> /dev/null; then
                sudo apt install -y bat 2>/dev/null || sudo apt install -y batcat 2>/dev/null || install_bat
            fi
            
            if ! command -v fd &> /dev/null; then
                sudo apt install -y fd-find 2>/dev/null || install_fd
            fi
            
            # Create symbolic links for Debian-based systems if needed
            if command -v batcat &> /dev/null && ! command -v bat &> /dev/null; then
                sudo ln -sf $(which batcat) /usr/local/bin/bat
                log_info "Created symlink for batcat → bat"
            fi
            if command -v fdfind &> /dev/null && ! command -v fd &> /dev/null; then
                sudo ln -sf $(which fdfind) /usr/local/bin/fd
                log_info "Created symlink for fdfind → fd"
            fi
            ;;
            
        "rhel")
            if command -v dnf &> /dev/null; then
                # For RHEL 8+, Fedora, AlmaLinux, etc.
                log_info "Using dnf package manager..."
                sudo dnf install -y epel-release
                sudo dnf install -y zsh curl git wget
                
                # Try to install optional tools
                sudo dnf install -y fzf 2>/dev/null || install_fzf
                sudo dnf install -y bat 2>/dev/null || install_bat
                sudo dnf install -y fd-find 2>/dev/null || install_fd
            else
                # For older RHEL systems
                log_info "Using yum package manager..."
                sudo yum install -y epel-release
                sudo yum install -y zsh curl git wget
                
                # Install additional tools
                install_fzf
                install_bat
                install_fd
            fi
            ;;
            
        "arch")
            log_info "Using pacman package manager..."
            sudo pacman -Syu --noconfirm
            sudo pacman -S --noconfirm zsh curl git wget fzf bat fd
            ;;
            
        *)
            log_error "Unknown distribution. Please install zsh and dependencies manually."
            exit 1
            ;;
    esac
    
    # Check if installation was successful
    if ! command -v zsh &> /dev/null; then
        log_error "Failed to install zsh. Please install it manually."
        exit 1
    fi
    
    log_success "Dependencies installed successfully!"
}

# Function to install bat from source if not available in repos
install_bat() {
    log_info "Installing bat from GitHub releases..."
    BAT_VERSION=$(curl -s https://api.github.com/repos/sharkdp/bat/releases/latest | grep -oP '"tag_name": "\K(.*)(?=")')
    
    # Determine architecture
    ARCH=$(uname -m)
    case "$ARCH" in
        x86_64)
            ARCH="x86_64"
            ;;
        aarch64|arm64)
            ARCH="aarch64"
            ;;
        *)
            log_warning "Unsupported architecture for bat: $ARCH"
            return 1
            ;;
    esac
    
    # Create temporary directory
    TMP_DIR=$(mktemp -d)
    cd "$TMP_DIR"
    
    # Download and install bat
    if [[ "$DISTRO_TYPE" == "rhel" ]]; then
        wget "https://github.com/sharkdp/bat/releases/download/${BAT_VERSION}/bat-${BAT_VERSION}-${ARCH}-unknown-linux-gnu.tar.gz"
        tar xzf "bat-${BAT_VERSION}-${ARCH}-unknown-linux-gnu.tar.gz"
        sudo cp "bat-${BAT_VERSION}-${ARCH}-unknown-linux-gnu/bat" /usr/local/bin/
    else
        wget "https://github.com/sharkdp/bat/releases/download/${BAT_VERSION}/bat_${BAT_VERSION}_${ARCH}.deb"
        sudo dpkg -i "bat_${BAT_VERSION}_${ARCH}.deb" || log_warning "Failed to install bat package"
    fi
    
    cd - > /dev/null
    rm -rf "$TMP_DIR"
    
    if command -v bat &> /dev/null; then
        log_success "bat installed successfully!"
    else
        log_warning "bat installation failed. Some preview features may not work."
    fi
}

# Function to install fd from source if not available in repos
install_fd() {
    log_info "Installing fd from GitHub releases..."
    FD_VERSION=$(curl -s https://api.github.com/repos/sharkdp/fd/releases/latest | grep -oP '"tag_name": "\K(.*)(?=")')
    
    # Determine architecture
    ARCH=$(uname -m)
    case "$ARCH" in
        x86_64)
            ARCH="x86_64"
            ;;
        aarch64|arm64)
            ARCH="aarch64"
            ;;
        *)
            log_warning "Unsupported architecture for fd: $ARCH"
            return 1
            ;;
    esac
    
    # Create temporary directory
    TMP_DIR=$(mktemp -d)
    cd "$TMP_DIR"
    
    # Download and install fd
    if [[ "$DISTRO_TYPE" == "rhel" ]]; then
        wget "https://github.com/sharkdp/fd/releases/download/${FD_VERSION}/fd-${FD_VERSION}-${ARCH}-unknown-linux-gnu.tar.gz"
        tar xzf "fd-${FD_VERSION}-${ARCH}-unknown-linux-gnu.tar.gz"
        sudo cp "fd-${FD_VERSION}-${ARCH}-unknown-linux-gnu/fd" /usr/local/bin/
    else
        wget "https://github.com/sharkdp/fd/releases/download/${FD_VERSION}/fd_${FD_VERSION}_${ARCH}.deb"
        sudo dpkg -i "fd_${FD_VERSION}_${ARCH}.deb" || log_warning "Failed to install fd package"
    fi
    
    cd - > /dev/null
    rm -rf "$TMP_DIR"
    
    if command -v fd &> /dev/null; then
        log_success "fd installed successfully!"
    else
        log_warning "fd installation failed. Fallback to find will be used."
    fi
}

# Function to install fzf from source if not available in repos
install_fzf() {
    log_info "Installing fzf from GitHub..."
    if [ -d ~/.fzf ]; then
        log_info "fzf directory already exists, updating..."
        cd ~/.fzf && git pull && cd - > /dev/null
    else
        git clone --depth 1 https://github.com/junegunn/fzf.git ~/.fzf
    fi
    
    ~/.fzf/install --all --no-update-rc
    
    if [ -f ~/.fzf.zsh ]; then
        log_success "fzf installed successfully!"
    else
        log_warning "fzf installation may have issues. Some fuzzy finding features might not work."
    fi
}

# Function to install Oh My Zsh
install_oh_my_zsh() {
    log_step "Installing Oh My Zsh"
    
    # Backup existing .zshrc if it exists
    if [ -f ~/.zshrc ]; then
        BACKUP_FILE=~/.zshrc.backup.$(date +%Y%m%d-%H%M%S)
        cp ~/.zshrc $BACKUP_FILE
        log_info "Existing .zshrc backed up to $BACKUP_FILE"
    fi
    
    # Install Oh My Zsh
    if [ -d ~/.oh-my-zsh ]; then
        log_info "Oh My Zsh is already installed. Updating..."
        cd ~/.oh-my-zsh && git pull && cd - > /dev/null
    else
        # Install Oh My Zsh
        log_info "Downloading and installing Oh My Zsh..."
        sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
    fi
    
    # Install Powerlevel10k theme
    if [ -d "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k" ]; then
        log_info "Powerlevel10k theme is already installed. Updating..."
        git -C "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k" pull
    else
        log_info "Installing Powerlevel10k theme..."
        git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k"
    fi
    
    # Install plugins
    log_info "Installing Oh My Zsh plugins..."
    
    # zsh-autosuggestions
    if [ -d "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-autosuggestions" ]; then
        log_info "zsh-autosuggestions is already installed. Updating..."
        git -C "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-autosuggestions" pull
    else
        log_info "Installing zsh-autosuggestions..."
        git clone --depth=1 https://github.com/zsh-users/zsh-autosuggestions "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-autosuggestions"
    fi
    
    # zsh-syntax-highlighting
    if [ -d "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting" ]; then
        log_info "zsh-syntax-highlighting is already installed. Updating..."
        git -C "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting" pull
    else
        log_info "Installing zsh-syntax-highlighting..."
        git clone --depth=1 https://github.com/zsh-users/zsh-syntax-highlighting "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting"
    fi
    
    # zsh-history-substring-search
    if [ -d "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-history-substring-search" ]; then
        log_info "zsh-history-substring-search is already installed. Updating..."
        git -C "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-history-substring-search" pull
    else
        log_info "Installing zsh-history-substring-search..."
        git clone --depth=1 https://github.com/zsh-users/zsh-history-substring-search "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-history-substring-search"
    fi
    
    # history-search-multi-word
    if [ -d "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/history-search-multi-word" ]; then
        log_info "history-search-multi-word is already installed. Updating..."
        git -C "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/history-search-multi-word" pull
    else
        log_info "Installing history-search-multi-word..."
        git clone --depth=1 https://github.com/z-shell/history-search-multi-word "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/history-search-multi-word"
    fi
    
    log_success "Oh My Zsh installation completed!"
}

# Function to configure zsh with the custom settings
configure_zsh() {
    log_step "Configuring ZSH with Custom Settings"
    
    # Create the zshrc file with custom configurations
    cat > ~/.zshrc << 'EOL'
# Enable Powerlevel10k instant prompt. Should stay close to the top of ~/.zshrc.
# Initialization code that may require console input (password prompts, [y/n]
# confirmations, etc.) must go above this block; everything else may go below.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# Path to your oh-my-zsh installation
export ZSH="$HOME/.oh-my-zsh"
export PATH="$PATH:$HOME/.local/bin"

# Set theme (Powerlevel10k)
ZSH_THEME="powerlevel10k/powerlevel10k"

# Plugins
plugins=(
  git
  ssh
  sudo
  ssh-agent
  z
  history
  pip
  docker
  python
  alias-finder
  per-directory-history
  copyfile
  copypath
  zsh-autosuggestions
  zsh-syntax-highlighting
  zsh-history-substring-search
  history-search-multi-word
)

# Load Oh My Zsh
source $ZSH/oh-my-zsh.sh

# Source plugin configs manually if not autoloaded
[[ -f /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh ]] && source /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh
[[ -f /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ]] && source /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

# Source Powerlevel10k config if exists
[[ -f ~/.p10k.zsh ]] && source ~/.p10k.zsh

# Starship prompt (optional)
if command -v starship &> /dev/null; then
  eval "$(starship init zsh)"
fi

# FZF: enable keybindings and completions
[ -f /usr/share/fzf/key-bindings.zsh ] && source /usr/share/fzf/key-bindings.zsh
[ -f /usr/share/fzf/completion.zsh ] && source /usr/share/fzf/completion.zsh
[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh

# Use bat as the preview tool if available
if command -v bat &>/dev/null; then
  export FZF_PREVIEW_CMD="bat --style=plain --color=always {}"
else
  export FZF_PREVIEW_CMD="cat {}"
fi

# Use fd as the file finder if available
if command -v fd &>/dev/null; then
  export FZF_DEFAULT_COMMAND='fd --type f --hidden --follow --exclude .git'
  export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
  export FZF_ALT_C_COMMAND='fd --type d --hidden --follow --exclude .git'
else
  export FZF_DEFAULT_COMMAND='find . -type f'
fi

# Global FZF options
export FZF_DEFAULT_OPTS='
  --height=40%
  --layout=reverse
  --border
  --preview-window=right:50%
  --bind=ctrl-/:toggle-preview
  --preview="$FZF_PREVIEW_CMD"
'

# Ctrl+R: enhanced fuzzy command history
fzf-history-widget() {
  BUFFER=$(fc -l 1 | awk '{$1=""; print substr($0,2)}' | eval fzf --query="$LBUFFER" $FZF_DEFAULT_OPTS)
  CURSOR=$#BUFFER
  zle accept-line
}
zle -N fzf-history-widget
bindkey '^R' fzf-history-widget

# Standard ls with colors and better formatting
alias ls='ls --color=auto --group-directories-first'
alias ll='ls -l --color=auto --group-directories-first'
alias la='ls -la --color=auto --group-directories-first'
alias lll='ls -lah --color=auto --group-directories-first'
alias lt='find . -type d | sort | sed -e "s/[^-][^\/]*\//  │   /g" -e "s/│\([^ ]\)/├── \1/"'

# Color-enhanced commands
alias grep='grep --color=auto'
alias egrep='egrep --color=auto'
alias fgrep='fgrep --color=auto'

# Directory navigation and file sorting
alias recent='find . -type f -printf "%T@ %T+ %p\n" | sort -n | tail -20 | cut -f2- -d" "'
alias biggest='find . -type f -printf "%s %p\n" | sort -nr | head -10 | numfmt --field=1 --to=iec'
alias folders='find . -maxdepth 1 -type d | sort'
alias l='f() { if [ $# -eq 0 ]; then /bin/ls -latr; else /bin/ls -latr | grep "$@"; fi; }; f'

# Environment safety
export EDITOR=nano
export SHELL=/bin/zsh

# History settings
HISTFILE=~/.zsh_history
HISTSIZE=10000

# ===== 🌈 Enhanced Directory Color Highlighting =====
# Set LS_COLORS for different file types
export LS_COLORS="di=1;34:ln=35:so=32:pi=33:ex=31:bd=34;46:cd=34;43:su=30;41:sg=30;46:tw=30;42:ow=30;43"

# Special highlight for common development files
export LS_COLORS="${LS_COLORS}:*.cpp=36:*.h=32:*.py=33:*.js=35:*.html=31:*.css=36:*.json=37:*.md=33:*.txt=37"

# Special highlight for media types
export LS_COLORS="${LS_COLORS}:*.jpg=35:*.png=35:*.mp4=31:*.mp3=36"

# Special highlight for archive files
export LS_COLORS="${LS_COLORS}:*.zip=33:*.tar=33:*.gz=33"

# ===== 📊 Improved Directory Statistics Function =====
# Add detailed stats about current directory
dirstat() {
  echo "📁 Directory Statistics"
  echo "------------------------"
  echo "📌 Total files: $(find . -type f 2>/dev/null | wc -l)"
  echo "📁 Total directories: $(find . -type d 2>/dev/null | wc -l)"
  echo "💾 Total size: $(du -sh . 2>/dev/null | cut -f1)"
  echo "⏰ Latest modified files:"
  find . -type f -printf '%T+ %p\n' 2>/dev/null | sort -r | head -n 5
  echo "------------------------"
  echo "📊 File types:"
  find . -type f 2>/dev/null | grep -E ".*\.[a-zA-Z0-9]+$" | sed -e 's/.*\(\.[a-zA-Z0-9]\+\)$/\1/' | sort | uniq -c | sort -rn | head -10
}

# Project-specific directory stats
projstat() {
  local dir="${1:-.}"
  echo "📁 Project Statistics for: $dir"
  echo "------------------------"
  echo "📌 Total files: $(find "$dir" -type f 2>/dev/null | wc -l)"
  echo "📁 Total directories: $(find "$dir" -type d 2>/dev/null | wc -l)"
  echo "💾 Total size: $(du -sh "$dir" 2>/dev/null | cut -f1)"
  echo "⏰ Latest modified files:"
  find "$dir" -type f -printf '%T+ %p\n' 2>/dev/null | sort -r | head -n 5
  echo "------------------------"
  echo "📊 File types:"
  find "$dir" -type f 2>/dev/null | grep -E ".*\.[a-zA-Z0-9]+$" | sed -e 's/.*\(\.[a-zA-Z0-9]\+\)$/\1/' | sort | uniq -c | sort -rn | head -10
  
  # Show git info if available
  if [ -d "$dir/.git" ]; then
    echo "------------------------"
    echo "📊 Git Info:"
    echo "Branch: $(git -C "$dir" branch --show-current)"
    echo "Recent commits:"
    git -C "$dir" log --oneline -n 3
  fi
}

# ===== 🔍 Enhanced Search Functions =====
# Find files by content with colored output
findtext() {
  grep --color=always -r "$1" . | less -R
}

# Find files by name with cool formatting
findfile() {
  find . -name "*$1*" -type f | xargs ls -la --color=always 2>/dev/null
}

# ===== 🛠 Project Management Functions =====
# Project finder with instant navigation (requires fzf)
goto() {
  local dest=$(find ~/projects -type d -name "*$1*" 2>/dev/null | fzf)
  if [[ -n "$dest" ]]; then
    cd "$dest"
    ls -la --group-directories-first
  fi
}

# ===== 💡 Additional Utilities =====
# Quick directory bookmarks
alias mark='pwd > ~/.lastdir'
alias jump='cd "$(cat ~/.lastdir)"'

# Quick file backup
bak() {
  cp "$1" "$1.bak.$(date +%Y%m%d-%H%M%S)"
  echo "✅ Backup created: $1.bak.$(date +%Y%m%d-%H%M%S)"
}

# Make dir and cd into it
mkcd() {
  mkdir -p "$1" && cd "$1"
}

# Go back multiple directories at once
back() {
  cd $(printf "%0.0s../" $(seq 1 ${1:-1}))
}

# Ensure completions work properly
fpath=(~/.zsh/completions $fpath)
autoload -Uz compinit && compinit
EOL
    
    # Create basic p10k configuration
    log_info "Creating Powerlevel10k configuration..."
    cat > ~/.p10k.zsh << 'EOL'
# Generated by Powerlevel10k configuration wizard.
# Based on romkatv/powerlevel10k/config/p10k-lean.zsh.
# Wizard options: nerdfont-complete + powerline, small icons, unicode, lean, 24h time,
# 1 line, compact, few icons, concise, instant_prompt=verbose.

typeset -g POWERLEVEL9K_INSTANT_PROMPT=verbose

# Temporarily change options.
'builtin' 'local' '-a' 'p10k_config_opts'
[[ ! -o 'aliases'         ]] || p10k_config_opts+=('aliases')
[[ ! -o 'sh_glob'         ]] || p10k_config_opts+=('sh_glob')
[[ ! -o 'no_brace_expand' ]] || p10k_config_opts+=('no_brace_expand')
'builtin' 'setopt' 'no_aliases' 'no_sh_glob' 'brace_expand'

() {
  emulate -L zsh -o extended_glob

  # Basic style configuration
  typeset -g POWERLEVEL9K_MODE=nerdfont-complete
  typeset -g POWERLEVEL9K_PROMPT_ADD_NEWLINE=false
  typeset -g POWERLEVEL9K_PROMPT_ON_NEWLINE=false
  typeset -g POWERLEVEL9K_RPROMPT_ON_NEWLINE=false
  typeset -g POWERLEVEL9K_MULTILINE_FIRST_PROMPT_PREFIX='%242F╭─'
  typeset -g POWERLEVEL9K_MULTILINE_NEWLINE_PROMPT_PREFIX='%242F├─'
  typeset -g POWERLEVEL9K_MULTILINE_LAST_PROMPT_PREFIX='%242F╰─'

  # Left prompt segments
  typeset -g POWERLEVEL9K_LEFT_PROMPT_ELEMENTS=(
    os_icon                 # operating system icon
    dir                     # current directory
    vcs                     # git status
    command_execution_time  # duration of the last command
    status                  # exit code of the last command
  )

  # Right prompt segments
  typeset -g POWERLEVEL9K_RIGHT_PROMPT_ELEMENTS=(
    time                    # current time
  )

  # Basic colors
  typeset -g POWERLEVEL9K_BACKGROUND=
  typeset -g POWERLEVEL9K_DIR_BACKGROUND=004
  typeset -g POWERLEVEL9K_STATUS_OK_BACKGROUND=2
  typeset -g POWERLEVEL9K_STATUS_ERROR_BACKGROUND=1

  # Time
  typeset -g POWERLEVEL9K_TIME_FORMAT='%D{%H:%M:%S}'
}

# Restore options.
(( ${#p10k_config_opts} )) && setopt ${p10k_config_opts[@]}
'builtin' 'unset' 'p10k_config_opts'
EOL

    log_success "ZSH custom configuration completed!"
}

# Function to change default shell to zsh
change_default_shell() {
    log_step "Changing Default Shell to ZSH"
    
    # Get the path to zsh
    ZSH_PATH=$(which zsh)
    
    if [ -z "$ZSH_PATH" ]; then
        log_error "ZSH not found. Please make sure it's installed."
        return 1
    fi
    
    # Check if zsh is already the default shell
    if [ "$SHELL" = "$ZSH_PATH" ]; then
        log_info "ZSH is already the default shell."
        return 0
    fi
    
    # Check if zsh is in /etc/shells
    if ! grep -q "$ZSH_PATH" /etc/shells; then
        log_info "Adding $ZSH_PATH to /etc/shells..."
        echo "$ZSH_PATH" | sudo tee -a /etc/shells > /dev/null
    fi
    
    # Change the default shell
    log_info "Changing default shell to ZSH..."
    chsh -s "$ZSH_PATH"
    
    # Verify the change
    if [ $? -eq 0 ]; then
        log_success "Default shell changed to ZSH. You may need to log out and log back in for changes to take effect."
    else
        log_error "Failed to change default shell. Please change it manually using: chsh -s $ZSH_PATH"
    fi
}

# Function to install system-level zsh plugins (for distros that use package managers)
install_system_plugins() {
    log_step "Checking for System-Level ZSH Plugins"
    
    case "$DISTRO_TYPE" in
        "debian")
            log_info "Checking for system zsh plugins in Debian/Ubuntu..."
            sudo apt install -y zsh-autosuggestions zsh-syntax-highlighting 2>/dev/null || true
            ;;
        "rhel")
            if command -v dnf &> /dev/null; then
                log_info "Checking for system zsh plugins in RHEL/Fedora..."
                sudo dnf install -y zsh-autosuggestions zsh-syntax-highlighting 2>/dev/null || true
            else
                log_info "System plugins may not be available for this RHEL version."
            fi
            ;;
        "arch")
            log_info "Checking for system zsh plugins in Arch..."
            sudo pacman -S --noconfirm zsh-autosuggestions zsh-syntax-highlighting 2>/dev/null || true
            ;;
    esac
    
    # Create directory for completions
    mkdir -p ~/.zsh/completions
}

# Function to handle system-specific adjustments
system_specific_adjustments() {
    log_step "Making System-Specific Adjustments"
    
    case "$DISTRO_TYPE" in
        "debian")
            log_info "Applying Debian/Ubuntu specific adjustments..."
            # Add system-level plugins paths to zshrc if they exist
            if [ -f /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh ]; then
                echo "# Debian system plugins" >> ~/.zshrc
                echo "source /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh" >> ~/.zshrc
                echo "source /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" >> ~/.zshrc
            fi
            ;;
        "rhel")
            log_info "Applying RHEL/Fedora specific adjustments..."
            # Add system-level plugins paths to zshrc if they exist
            if [ -f /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh ]; then
                echo "# RHEL system plugins" >> ~/.zshrc
                echo "source /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh" >> ~/.zshrc
                echo "source /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" >> ~/.zshrc
            fi
            ;;
        "arch")
            log_info "Applying Arch specific adjustments..."
            # Add system-level plugins paths to zshrc if they exist
            if [ -f /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh ]; then
                # Already handled in main zshrc template
                true
            fi
            ;;
    esac
    
    log_success "System-specific adjustments completed!"
}

# Function to install additional tools
install_additional_tools() {
    log_step "Installing Additional Tools"
    
    # Install Starship prompt if user wants it
    if [[ "$INSTALL_STARSHIP" == "y" ]]; then
        log_info "Installing Starship prompt..."
        if command -v starship &> /dev/null; then
            log_info "Starship is already installed."
        else
            curl -sS https://starship.rs/install.sh | sh -s -- --yes
        fi
    fi
    
    log_success "Additional tools installation completed!"
}

# Function to setup system warning prompt
setup_warning_prompt() {
    log_step "Setting Up System Warning Prompt"
    
    # Ask for system identifier
    if [ -z "$SYSTEM_IDENTIFIER" ]; then
        read -p "Enter a system identifier (e.g., PRODUCTION, DEV, GERMANY): " SYSTEM_IDENTIFIER
    fi
    
    # Default to hostname if no identifier provided
    if [ -z "$SYSTEM_IDENTIFIER" ]; then
        SYSTEM_IDENTIFIER=$(hostname | tr '[:lower:]' '[:upper:]')
        log_info "Using hostname as system identifier: $SYSTEM_IDENTIFIER"
    fi
    
    # Ask for warning color
    if [ -z "$WARNING_COLOR" ]; then
        echo "Select a color for the warning prompt:"
        echo "1) Red (danger/production)"
        echo "2) Yellow (caution/staging)"
        echo "3) Blue (development)"
        echo "4) Green (safe/local)"
        echo "5) Magenta (special purpose)"
        echo "6) Cyan (testing)"
        read -p "Enter your choice [1-6]: " color_choice
        
        case $color_choice in
            1) WARNING_COLOR="red" ;;
            2) WARNING_COLOR="yellow" ;;
            3) WARNING_COLOR="blue" ;;
            4) WARNING_COLOR="green" ;;
            5) WARNING_COLOR="magenta" ;;
            6) WARNING_COLOR="cyan" ;;
            *) WARNING_COLOR="red"; log_info "Invalid choice. Using red as default." ;;
        esac
    fi
    
    # Ask for warning style
    if [ -z "$WARNING_STYLE" ]; then
        echo "Select a warning style:"
        echo "1) [SYSTEM] - Simple brackets"
        echo "2) ⚠️ SYSTEM ⚠️ - With warning symbols"
        echo "3) 【SYSTEM】 - Double brackets"
        echo "4) <<SYSTEM>> - Angle brackets"
        echo "5) ✪ SYSTEM ✪ - Star symbols"
        read -p "Enter your choice [1-5]: " style_choice
        
        case $style_choice in
            1) WARNING_STYLE="[%s]" ;;
            2) WARNING_STYLE="⚠️ %s ⚠️" ;;
            3) WARNING_STYLE="【%s】" ;;
            4) WARNING_STYLE="<<%s>>" ;;
            5) WARNING_STYLE="✪ %s ✪" ;;
            *) WARNING_STYLE="[%s]"; log_info "Invalid choice. Using simple brackets as default." ;;
        esac
    fi
    
    # Create the warning configurations
    log_info "Creating warning prompt configuration..."
    
    # Create warning prompt config file
    mkdir -p ~/.zsh_custom
    cat > ~/.zsh_custom/warning_prompt.zsh << EOF
# ZSH Warning Prompt Configuration
# Generated by zsh-setup script

# System identifier: ${SYSTEM_IDENTIFIER}
# Warning color: ${WARNING_COLOR}
# Warning style: ${WARNING_STYLE}

# Define color codes
case "${WARNING_COLOR}" in
    "red") COLOR_CODE="%F{196}" ;;
    "yellow") COLOR_CODE="%F{226}" ;;
    "blue") COLOR_CODE="%F{33}" ;;
    "green") COLOR_CODE="%F{46}" ;;
    "magenta") COLOR_CODE="%F{201}" ;;
    "cyan") COLOR_CODE="%F{51}" ;;
    *) COLOR_CODE="%F{196}" ;;
esac

# Format the warning prompt
FORMATTED_STYLE="\$(printf "${WARNING_STYLE}" "${SYSTEM_IDENTIFIER}")"
export SYSTEM_WARNING_PROMPT="\${COLOR_CODE}\${FORMATTED_STYLE}%f"

# Function to integrate with various prompt systems
warning_prompt_integration() {
    # For regular ZSH prompt
    if [[ -z \$POWERLEVEL9K_INSTANT_PROMPT ]]; then
        # If not using Powerlevel10k, add to PS1
        export PS1="\$SYSTEM_WARNING_PROMPT \$PS1"
    else
        # For Powerlevel10k we need special handling - add a custom function
        # to be executed before the prompt
        function warn_prompt_precmd() {
            # Check if we're in a Powerlevel10k instant prompt
            if [[ -n \$POWERLEVEL9K_INSTANT_PROMPT ]]; then
                # Print the warning before the prompt
                print -P "\$SYSTEM_WARNING_PROMPT"
            fi
        }
        
        # Add our function to precmd functions array
        autoload -Uz add-zsh-hook
        add-zsh-hook precmd warn_prompt_precmd
    fi
    
    # Handle Starship prompt if active
    if command -v starship &> /dev/null && [[ -n \$STARSHIP_SHELL ]]; then
        # Add to starship pre-rendering hooks if supported
        export STARSHIP_CONFIG=~/.config/starship.toml
        
        # Check if we have a starship config, create one if not
        if [[ ! -f \$STARSHIP_CONFIG ]]; then
            mkdir -p ~/.config
            echo '# Starship config generated by zsh-setup' > \$STARSHIP_CONFIG
            echo 'format = "\$all"' >> \$STARSHIP_CONFIG
        fi
        
        # Modify the format to include our warning
        if ! grep -q "custom.warning" \$STARSHIP_CONFIG; then
            sed -i 's/format = "\\(.*\\)"/format = "\$custom.warning \\1"/' \$STARSHIP_CONFIG
            
            # Add custom warning module
            cat >> \$STARSHIP_CONFIG << STARSHIP_CONF

[custom.warning]
command = "echo -e '${COLOR_CODE}$(printf "${WARNING_STYLE}" "${SYSTEM_IDENTIFIER}")%f'"
when = "true"
shell = ["bash", "--noprofile", "--norc"]
STARSHIP_CONF
        fi
    fi
}

# Run the integration on startup
warning_prompt_integration
EOF
    
    # Add source command to .zshrc if not already there
    if ! grep -q "source ~/.zsh_custom/warning_prompt.zsh" ~/.zshrc; then
        echo -e "\n# Load system warning prompt\nsource ~/.zsh_custom/warning_prompt.zsh" >> ~/.zshrc
    fi
    
    log_success "Warning prompt setup completed! The system warning ${WARNING_STYLE//%s/$SYSTEM_IDENTIFIER} in ${WARNING_COLOR} will be displayed in your prompt."
    log_info "Log out and log back in, or restart your shell to see the changes."
}

# Function to add self-update capability
setup_self_update() {
    log_step "Setting Up Self-Update Capability"
    
    # Get the script's path
    SCRIPT_PATH=$(readlink -f "$0")
    SCRIPT_NAME=$(basename "$SCRIPT_PATH")
    SCRIPT_DIR=$(dirname "$SCRIPT_PATH")
    
    # Ask for update URL if not provided
    if [ -z "$UPDATE_URL" ]; then
        read -p "Enter URL for script updates (leave empty to skip): " UPDATE_URL
    fi
    
    if [ -n "$UPDATE_URL" ]; then
        # Create update script
        cat > "${SCRIPT_DIR}/update-${SCRIPT_NAME}" << EOF
#!/bin/bash
# Auto-update script for ${SCRIPT_NAME}
# Generated by zsh-setup script

# Set up colors
C_RESET="\033[0m"
C_GREEN="\033[0;32m"
C_YELLOW="\033[0;33m"
C_BLUE="\033[0;34m"
C_RED="\033[0;31m"

# Script information
SCRIPT_PATH="${SCRIPT_PATH}"
UPDATE_URL="${UPDATE_URL}"
TEMP_FILE=\$(mktemp)

echo -e "\${C_BLUE}[INFO]\${C_RESET} Checking for updates to ${SCRIPT_NAME}..."

# Download the latest version
if command -v curl &> /dev/null; then
    curl -s -o \$TEMP_FILE "\$UPDATE_URL"
    DOWNLOAD_STATUS=\$?
elif command -v wget &> /dev/null; then
    wget -q -O \$TEMP_FILE "\$UPDATE_URL"
    DOWNLOAD_STATUS=\$?
else
    echo -e "\${C_RED}[ERROR]\${C_RESET} Neither curl nor wget is installed. Cannot check for updates."
    exit 1
fi

# Check if download was successful
if [ \$DOWNLOAD_STATUS -ne 0 ]; then
    echo -e "\${C_RED}[ERROR]\${C_RESET} Failed to download update. Please check your connection or the update URL."
    rm -f \$TEMP_FILE
    exit 1
fi

# Check if there are differences
if diff -q "\$SCRIPT_PATH" "\$TEMP_FILE" > /dev/null; then
    echo -e "\${C_GREEN}[SUCCESS]\${C_RESET} ${SCRIPT_NAME} is already up to date!"
    rm -f \$TEMP_FILE
    exit 0
fi

# Calculate version differences using script size as a basic metric
OLD_SIZE=\$(wc -l < "\$SCRIPT_PATH")
NEW_SIZE=\$(wc -l < "\$TEMP_FILE")
SIZE_DIFF=\$((\$NEW_SIZE - \$OLD_SIZE))

if [ \$SIZE_DIFF -gt 0 ]; then
    CHANGE_DESC="added \$SIZE_DIFF lines"
elif [ \$SIZE_DIFF -lt 0 ]; then
    CHANGE_DESC="removed \$((-\$SIZE_DIFF)) lines"
else
    CHANGE_DESC="modified but same size"
fi

echo -e "\${C_YELLOW}[WARNING]\${C_RESET} New version available (\$CHANGE_DESC)"
read -p "Do you want to update to the new version? (y/n): " choice

if [[ "\$choice" != "y" ]]; then
    echo -e "\${C_BLUE}[INFO]\${C_RESET} Update cancelled."
    rm -f \$TEMP_FILE
    exit 0
fi

# Create backup of current script
BACKUP_FILE="\${SCRIPT_PATH}.backup.\$(date +%Y%m%d-%H%M%S)"
cp "\$SCRIPT_PATH" "\$BACKUP_FILE"
echo -e "\${C_BLUE}[INFO]\${C_RESET} Backup created at \$BACKUP_FILE"

# Replace script with new version
mv "\$TEMP_FILE" "\$SCRIPT_PATH"
chmod +x "\$SCRIPT_PATH"

echo -e "\${C_GREEN}[SUCCESS]\${C_RESET} ${SCRIPT_NAME} has been updated successfully!"
echo -e "\${C_BLUE}[INFO]\${C_RESET} Please run the script again to use the new version."
exit 0
EOF
        
        # Make update script executable
        chmod +x "${SCRIPT_DIR}/update-${SCRIPT_NAME}"
        
        # Add alias to .zshrc
        ALIAS_NAME="update-$(basename "$SCRIPT_NAME" .sh)"
        if ! grep -q "alias $ALIAS_NAME=" ~/.zshrc; then
            echo -e "\n# Auto-update for ${SCRIPT_NAME}\nalias ${ALIAS_NAME}='${SCRIPT_DIR}/update-${SCRIPT_NAME}'" >> ~/.zshrc
        fi
        
        log_success "Self-update capability has been set up!"
        log_info "You can update the script by running '${ALIAS_NAME}' after restarting your shell."
        log_info "Update URL: ${UPDATE_URL}"
    else
        log_info "Self-update setup skipped. No update URL provided."
    fi
}

# Function to verify installation
verify_installation() {
    log_step "Verifying Installation"
    
    # Check if key components are installed
    log_info "Checking for ZSH..."
    if command -v zsh &> /dev/null; then
        log_success "✓ ZSH is installed: $(zsh --version)"
    else
        log_error "✗ ZSH is not installed or not in PATH"
    fi
    
    log_info "Checking for Oh My Zsh..."
    if [ -d ~/.oh-my-zsh ]; then
        log_success "✓ Oh My Zsh is installed"
    else
        log_error "✗ Oh My Zsh is not installed"
    fi
    
    log_info "Checking for Powerlevel10k theme..."
    if [ -d ~/.oh-my-zsh/custom/themes/powerlevel10k ]; then
        log_success "✓ Powerlevel10k theme is installed"
    else
        log_error "✗ Powerlevel10k theme is not installed"
    fi
    
    log_info "Checking for custom .zshrc..."
    if [ -f ~/.zshrc ] && grep -q "Improved Directory Statistics Function" ~/.zshrc; then
        log_success "✓ Custom .zshrc is configured"
    else
        log_error "✗ Custom .zshrc may not be properly configured"
    fi
    
    # Check if warning prompt is configured
    if [ -f ~/.zsh_custom/warning_prompt.zsh ]; then
        log_success "✓ System warning prompt is configured"
    fi
    
    log_success "Installation verification completed!"
}

# Function to display help
show_help() {
    echo -e "${C_CYAN}ZSH Setup Script${C_RESET}"
    echo "This script helps you quickly set up ZSH with Oh My Zsh and a custom configuration."
    echo
    echo "Usage: $0 [options]"
    echo
    echo "Options:"
    echo "  -h, --help             Show this help message"
    echo "  -a, --auto             Automatic installation with defaults"
    echo "  -s, --shell-only       Only change the default shell to ZSH"
    echo "  -c, --config-only      Only configure ZSH (assumes ZSH is already installed)"
    echo "  -d, --deps-only        Only install dependencies"
    echo "  -w, --warning-prompt   Setup system warning prompt"
    echo "  -u, --setup-update     Configure self-update capability"
    echo "  --skip-shell-change    Don't change the default shell"
    echo "  --system=NAME          Set system identifier for warning prompt"
    echo "  --color=COLOR          Set warning color (red,yellow,blue,green,magenta,cyan)"
    echo "  --style=NUM            Set warning style (1-5)"
    echo "  --update-url=URL       Set URL for script updates"
    echo
    echo "Examples:"
    echo "  $0                     # Interactive mode"
    echo "  $0 --auto              # Fully automatic installation"
    echo "  $0 --shell-only        # Only change the default shell"
    echo "  $0 --warning-prompt --system=PRODUCTION --color=red"
    echo "  $0 --setup-update --update-url=https://example.com/zsh-setup.sh"
}

# Main function
main() {
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            -a|--auto)
                AUTO_MODE=true
                INSTALL_DEPS=true
                INSTALL_OMZ=true
                CONFIGURE_ZSH=true
                CHANGE_SHELL=true
                INSTALL_STARSHIP="n"
                ;;
            -s|--shell-only)
                CHANGE_SHELL=true
                ;;
            -c|--config-only)
                CONFIGURE_ZSH=true
                INSTALL_OMZ=true
                ;;
            -d|--deps-only)
                INSTALL_DEPS=true
                ;;
            -w|--warning-prompt)
                SETUP_WARNING=true
                ;;
            -u|--setup-update)
                SETUP_UPDATE=true
                ;;
            --skip-shell-change)
                SKIP_SHELL_CHANGE=true
                ;;
            --system=*)
                SYSTEM_IDENTIFIER="${1#*=}"
                ;;
            --color=*)
                WARNING_COLOR="${1#*=}"
                ;;
            --style=*)
                STYLE_NUM="${1#*=}"
                # Convert style number to actual style
                case "$STYLE_NUM" in
                    1) WARNING_STYLE="[%s]" ;;
                    2) WARNING_STYLE="⚠️ %s ⚠️" ;;
                    3) WARNING_STYLE="【%s】" ;;
                    4) WARNING_STYLE="<<%s>>" ;;
                    5) WARNING_STYLE="✪ %s ✪" ;;
                    *) WARNING_STYLE="" ;; # Will use default if invalid
                esac
                ;;
            --update-url=*)
                UPDATE_URL="${1#*=}"
                ;;
            *)
                echo "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
        shift
    done
    
    # Display banner
    echo -e "${C_CYAN}"
    echo "███████╗███████╗██╗  ██╗    ███████╗███████╗████████╗██╗   ██╗██████╗ "
    echo "╚══███╔╝██╔════╝██║  ██║    ██╔════╝██╔════╝╚══██╔══╝██║   ██║██╔══██╗"
    echo "  ███╔╝ ███████╗███████║    ███████╗█████╗     ██║   ██║   ██║██████╔╝"
    echo " ███╔╝  ╚════██║██╔══██║    ╚════██║██╔══╝     ██║   ██║   ██║██╔═══╝ "
    echo "███████╗███████║██║  ██║    ███████║███████╗   ██║   ╚██████╔╝██║     "
    echo "╚══════╝╚══════╝╚═╝  ╚═╝    ╚══════╝╚══════╝   ╚═╝    ╚═════╝ ╚═╝     "
    echo -e "${C_RESET}"
    echo -e "${C_YELLOW}A script to quickly set up ZSH with Oh My Zsh and custom configuration${C_RESET}"
    echo
    
    # Check if running as root
    if [ "$(id -u)" -eq 0 ]; then
        log_warning "This script is not meant to be run as root directly."
        log_warning "It will use sudo when necessary for system-level operations."
        read -p "Continue anyway? (y/n): " choice
        if [[ "$choice" != "y" ]]; then
            log_info "Exiting."
            exit 0
        fi
    fi
    
    # Always detect the distribution
    detect_distro
    
    # Interactive mode if no arguments were provided
    if [ -z "$AUTO_MODE" ] && [ -z "$INSTALL_DEPS" ] && [ -z "$INSTALL_OMZ" ] && [ -z "$CONFIGURE_ZSH" ] && 
       [ -z "$CHANGE_SHELL" ] && [ -z "$SETUP_WARNING" ] && [ -z "$SETUP_UPDATE" ]; then
        echo -e "${C_CYAN}What would you like to do?${C_RESET}"
        echo "1) Full setup (install dependencies, Oh My Zsh, and configure)"
        echo "2) Install dependencies only"
        echo "3) Install Oh My Zsh only"
        echo "4) Configure ZSH only (requires Oh My Zsh)"
        echo "5) Change default shell to ZSH"
        echo "6) Setup system warning prompt"
        echo "7) Setup self-update capability"
        echo "8) Exit"
        echo
        read -p "Enter your choice [1-8]: " choice
        
        case $choice in
            1)
                INSTALL_DEPS=true
                INSTALL_OMZ=true
                CONFIGURE_ZSH=true
                CHANGE_SHELL=true
                ;;
            2)
                INSTALL_DEPS=true
                ;;
            3)
                INSTALL_OMZ=true
                ;;
            4)
                CONFIGURE_ZSH=true
                ;;
            5)
                CHANGE_SHELL=true
                ;;
            6)
                SETUP_WARNING=true
                ;;
            7)
                SETUP_UPDATE=true
                ;;
            8|*)
                log_info "Exiting."
                exit 0
                ;;
        esac
        
        if [ -n "$INSTALL_DEPS" ] || [ -n "$INSTALL_OMZ" ] || [ -n "$CONFIGURE_ZSH" ]; then
            read -p "Install Starship prompt as well? (y/n): " INSTALL_STARSHIP
        fi
        
        if [ -n "$CONFIGURE_ZSH" ] || [ -n "$INSTALL_OMZ" ]; then
            if [ -z "$SKIP_SHELL_CHANGE" ]; then
                read -p "Change default shell to ZSH? (y/n): " change_shell_choice
                if [[ "$change_shell_choice" == "y" ]]; then
                    CHANGE_SHELL=true
                fi
            fi
        fi
        
        # If doing full setup, ask about warning prompt and self-update
        if [ -n "$INSTALL_DEPS" ] && [ -n "$CONFIGURE_ZSH" ]; then
            read -p "Setup system warning prompt? (y/n): " warning_choice
            if [[ "$warning_choice" == "y" ]]; then
                SETUP_WARNING=true
            fi
            
            read -p "Setup self-update capability? (y/n): " update_choice
            if [[ "$update_choice" == "y" ]]; then
                SETUP_UPDATE=true
            fi
        fi
    fi
    
    # Run the requested operations
    if [ -n "$INSTALL_DEPS" ]; then
        install_dependencies
        install_system_plugins
    fi
    
    if [ -n "$INSTALL_OMZ" ]; then
        install_oh_my_zsh
    fi
    
    if [ -n "$CONFIGURE_ZSH" ]; then
        configure_zsh
        system_specific_adjustments
    fi
    
    if [ -n "$INSTALL_STARSHIP" ] && [[ "$INSTALL_STARSHIP" == "y" ]]; then
        install_additional_tools
    fi
    
    if [ -n "$CHANGE_SHELL" ] && [ -z "$SKIP_SHELL_CHANGE" ]; then
        change_default_shell
    fi
    
    # Setup system warning prompt if requested
    if [ -n "$SETUP_WARNING" ]; then
        setup_warning_prompt
    fi
    
    # Setup self-update capability if requested
    if [ -n "$SETUP_UPDATE" ]; then
        setup_self_update
    fi
    
    # Verify installation if any components were installed
    if [ -n "$INSTALL_DEPS" ] || [ -n "$INSTALL_OMZ" ] || [ -n "$CONFIGURE_ZSH" ] || 
       [ -n "$SETUP_WARNING" ] || [ -n "$SETUP_UPDATE" ]; then
        verify_installation
    fi
    
    # Final message
    log_step "Setup Complete!"
    echo -e "${C_GREEN}ZSH setup completed! Here's what to do next:${C_RESET}"
    echo
    
    if [ -n "$CHANGE_SHELL" ]; then
        echo "1) Log out and log back in, or run 'zsh' to start using your new shell"
    else
        echo "1) Run 'zsh' to start using ZSH with your new configuration"
    fi
    
    echo "2) When first running ZSH with Powerlevel10k, you'll be prompted to configure it"
    echo "   (Choose the options you prefer for your prompt)"
    echo
    echo -e "${C_YELLOW}Enjoy your enhanced shell experience!${C_RESET}"
}

# Run the main function
main "$@"
