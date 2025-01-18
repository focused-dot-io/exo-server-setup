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

# Set up Exo service
setup_service() {
    log "Setting up Exo as a Homebrew service..."
    
    # Create the formula directory
    mkdir -p /opt/homebrew/Library/Taps/focused-dot-io/homebrew-exo
    
    # Create and install the formula
    cat > /opt/homebrew/Library/Taps/focused-dot-io/homebrew-exo/exo.rb << 'EOF'
class Exo < Formula
  desc "Exo server application"
  homepage "https://github.com/exo-explore/exo"
  version "0.1.0"
  
  # This is a dummy URL since we're installing from local
  url "file:///dev/null"
  sha256 "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855"

  def install
    # Create necessary directories
    (var/"log/exo").mkpath
    (var/"exo").mkpath
  end

  service do
    run [opt_bin/"uv", "run", "exo", "--disable-tui"]
    keep_alive true
    log_path var/"log/exo/exo.log"
    error_log_path var/"log/exo/error.log"
    working_dir var/"exo"
  end
end
EOF

    # Install and start the service
    brew tap focused-dot-io/exo
    brew install exo
    
    log "Exo service setup complete. You can manage it with 'brew services'"
}

# First set up the service
setup_service || error "Failed to set up service"

if [ "$SYNC_MODELS" = true ]; then
    # Sync models
    log "Syncing models from remote location..."
    rsync -avz --progress "$REMOTE_MODELS_LOCATION" "$TEMP_DIR" || error "Failed to sync models"

    # Start Exo in background with models
    log "Starting Exo with models sync..."
    uv run exo --models-seed-dir "$TEMP_DIR" --disable-tui > /tmp/exo.log 2>&1 &
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
            break
        fi
        sleep $INTERVAL
        ELAPSED=$((ELAPSED + INTERVAL))
    done

    # If we get here and elapsed >= timeout, timeout was reached
    if [ $ELAPSED -ge $TIMEOUT ]; then
        error "Timeout waiting for models to load"
    fi
else
    log "No model location provided, skipping model sync"
fi

log "Installation complete!"
exit 0