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

# Check for required argument
if [ "$#" -ne 1 ]; then
    error "Usage: $0 <remote_models_location>"
fi

REMOTE_MODELS_LOCATION="$1"
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
brew install mactop tux uv || error "Failed to install brew packages"

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
uv pip install -e . || error "Failed to install Exo"

# Sync models
log "Syncing models from remote location..."
rsync -avz --progress "$REMOTE_MODELS_LOCATION" "$TEMP_DIR" || error "Failed to sync models"

# Start Exo in background
log "Starting Exo..."
uv run exo --models-seed-dir "$TEMP_DIR" &
EXOPID=$!

# Function to check if models have been moved
check_models_moved() {
    # Check if the temp directory is empty (ignoring hidden files)
    local file_count=$(find "$TEMP_DIR" -type f -not -path '*/\.*' | wc -l)
    [ "$file_count" -eq 0 ]
}

# Wait for models to load with timeout
log "Waiting for models to load..."
TIMEOUT=3600  # 1 hour timeout
ELAPSED=0
INTERVAL=10   # Check every 10 seconds

while [ $ELAPSED -lt $TIMEOUT ]; do
    if check_models_moved; then
        log "Models moved successfully"
        kill $EXOPID
        exit 0
    fi
    sleep $INTERVAL
    ELAPSED=$((ELAPSED + INTERVAL))
done

# If we get here, timeout was reached
error "Timeout waiting for models to load"