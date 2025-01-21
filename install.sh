#!/bin/bash

# Exit on error, undefined variables, and pipe failures
set -euo pipefail

# Script configuration
readonly WORKSPACE_DIR="$HOME/workspace"
readonly EXO_REPO="https://github.com/exo-explore/exo.git"
readonly PYTHON_VERSION="3.12"

# Logging functions
log() { echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*" >&2; }
error() { log "ERROR: $*"; exit 1; }

# Check for sudo privileges upfront
if [ "$(id -u)" -eq 0 ]; then
    error "Please do not run this script as root/sudo directly. Run it as a normal user, it will ask for sudo privileges."
fi

# Ask for sudo password upfront
log "Requesting sudo privileges..."
sudo -v || error "Failed to obtain sudo privileges"

# Keep sudo privileges alive in the background
(while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null) &

# Function to request Full Disk Access
request_full_disk_access() {
    log "Checking and requesting Full Disk Access..."
    
    # Test if we already have full disk access by trying to read a protected file
    if ls /Library/Application\ Support/com.apple.TCC/TCC.db >/dev/null 2>&1; then
        log "Full Disk Access is already granted"
        return 0
    fi
    
    # Request Full Disk Access using tccutil
    osascript <<EOF
tell application "System Events"
    activate
    display dialog "Exo needs Full Disk Access to function properly. A permission prompt will appear next. Please click 'OK' to continue." buttons {"OK"} default button "OK"
end tell
EOF
    
    # Trigger the permission prompt
    sudo sqlite3 /Library/Application\ Support/com.apple.TCC/TCC.db .tables >/dev/null 2>&1 || true
    
    # Check if access was granted
    if ! ls /Library/Application\ Support/com.apple.TCC/TCC.db >/dev/null 2>&1; then
        error "Full Disk Access was not granted. Please run the script again and approve the permission request."
    fi
    
    log "Full Disk Access granted successfully"
}

# Request Full Disk Access first
request_full_disk_access

# Handle arguments whether script is run directly or via curl
# When script is run via curl, the arguments come after --
REMOTE_MODELS_LOCATION=""
for arg in "$@"; do
    if [ "$arg" = "--" ]; then
        continue
    elif [ -z "$REMOTE_MODELS_LOCATION" ]; then
        REMOTE_MODELS_LOCATION="$arg"
    fi
done

# Model sync is optional
SYNC_MODELS=false
if [ -n "$REMOTE_MODELS_LOCATION" ]; then
    SYNC_MODELS=true
fi
TEMP_DIR=$(mktemp -d)
trap 'rm -rf "$TEMP_DIR"' EXIT

# Function to enable SSH
enable_ssh() {
    log "Enabling SSH..."
    # Check if SSH is already enabled
    if sudo systemsetup -getremotelogin | grep -q "On"; then
        log "SSH is already enabled"
        return 0
    fi
    
    # Enable SSH
    sudo systemsetup -setremotelogin on || error "Failed to enable SSH"
    
    # Verify SSH is running
    if ! sudo systemsetup -getremotelogin | grep -q "On"; then
        error "Failed to verify SSH is enabled"
    fi
    
    log "SSH enabled successfully"
}

# Function to check command existence
check_command() {
    command -v "$1" >/dev/null 2>&1 || error "Required command '$1' not found"
}

# Enable SSH
enable_ssh

# Check for required commands
check_command curl
check_command git
check_command rsync

# Install Homebrew if not present
if ! command -v brew >/dev/null 2>&1; then
    log "Installing Homebrew..."
    NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" || error "Failed to install Homebrew"
    
    # Add Homebrew to PATH for the current session
    eval "$(/opt/homebrew/bin/brew shellenv)"
fi

# Install required packages
log "Installing packages via Homebrew..."
brew install --cask brave-browser iterm2 || error "Failed to install cask packages"
brew install mactop tmux uv || error "Failed to install brew packages"

# Configure power management and screen settings
configure_power_settings() {
    log "Configuring power management and screen settings..."

    # Disable screen saver
    defaults -currentHost write com.apple.screensaver idleTime 0

    # Prevent display from sleeping
    sudo pmset -a displaysleep 0

    # Disable screen lock
    defaults write com.apple.screensaver askForPassword -int 0

    # Disable automatic screen lock after sleep/screensaver
    defaults write com.apple.screensaver askForPasswordDelay -int 0

    log "Power management and screen settings configured"
}

# Configure automatic login
configure_autologin() {
    local current_user=$(whoami)
    log "Configuring automatic login for user: $current_user"

    # Enable automatic login in system preferences
    sudo defaults write /Library/Preferences/com.apple.loginwindow autoLoginUser "$current_user"

    # Disable FileVault if enabled (required for autologin)
    if fdesetup isactive >/dev/null 2>&1; then
        log "FileVault is enabled. Disabling for automatic login..."
        sudo fdesetup disable || error "Failed to disable FileVault"
    fi

    # Disable login password requiremen
    sudo defaults write /Library/Preferences/com.apple.loginwindow SHOWFULLNAME -bool false

    log "Automatic login configured successfully"
}

configure_power_settings || error "Failed to configure power settings"
configure_autologin || error "Failed to configure automatic login"

# Create and enter workspace directory
log "Setting up workspace..."
mkdir -p "$WORKSPACE_DIR" || error "Failed to create workspace directory"
cd "$WORKSPACE_DIR" || error "Failed to change to workspace directory"

# Clone and setup Exo
log "Cloning Exo repository..."
if [ ! -d "exo" ]; then
    git clone "$EXO_REPO" || error "Failed to clone Exo repository"
fi

cd exo || error "Failed to enter Exo directory"
echo "$PYTHON_VERSION" > .python-version || error "Failed to set Python version"

log "Installing Exo..."
uv venv
uv pip install -e . || error "Failed to install Exo"

# Set up Exo service
setup_service() {
    log "Setting up Exo as a LaunchDaemon..."
    
    # Create the plist file
    sudo tee /Library/LaunchDaemons/io.focused.exo.plist > /dev/null << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>io.focused.exo</string>
    <key>ProgramArguments</key>
    <array>
        <string>/opt/homebrew/bin/uv</string>
        <string>run</string>
        <string>exo</string>
        <string>--disable-tui</string>
    </array>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>UserName</key>
    <string>$(whoami)</string>
    <key>WorkingDirectory</key>
    <string>$WORKSPACE_DIR/exo</string>
    <key>StandardOutPath</key>
    <string>$HOME/.local/var/log/exo/exo.log</string>
    <key>StandardErrorPath</key>
    <string>$HOME/.local/var/log/exo/error.log</string>
</dict>
</plist>
EOF

    # Create necessary directories
    mkdir -p "$HOME/.local/var/log/exo"
}

# First set up the service
setup_service || error "Failed to set up service"

# Function to perform rsync with retries
perform_rsync_with_retry() {
    local source="$1"
    local dest="$2"
    local max_attempts=3
    local attempt=1
    local wait_time=10

    while [ $attempt -le $max_attempts ]; do
        log "Rsync attempt $attempt of $max_attempts..."
        if rsync -a --partial --progress --timeout=60 "$source" "$dest"; then
            return 0
        fi
        log "Rsync attempt $attempt failed. Waiting $wait_time seconds before retry..."
        sleep $wait_time
        wait_time=$((wait_time * 2))
        attempt=$((attempt + 1))
    done
    return 1
}

if [ "$SYNC_MODELS" = true ]; then
    # Sync models
    log "Syncing models from remote location..."
    if ! perform_rsync_with_retry "$REMOTE_MODELS_LOCATION" "$TEMP_DIR"; then
        error "Failed to sync models after multiple attempts"
    fi

    # Start Exo in background with models
    log "Starting Exo with models sync..."
    uv run exo --models-seed-dir "$TEMP_DIR" --disable-tui --prompt "Say 'Models Moved' Nothing else."
else
    log "No model location provided, skipping model sync"
fi

echo "Installation complete!"
echo "To manage the Exo service:"
echo "  Start:  sudo launchctl load /Library/LaunchDaemons/io.focused.exo.plist"
echo "  Stop:   sudo launchctl unload /Library/LaunchDaemons/io.focused.exo.plist"
echo "  Status: sudo launchctl list | grep exo"
echo "  Logs:   tail -f $HOME/.local/var/log/exo/exo.log"
exit 0
