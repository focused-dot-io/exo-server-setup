# Exo Server Setup Script

An automated setup script for configuring a new Mac as an Exo server. This script handles installation of required dependencies, enables SSH access, and configures the Exo environment with model synchronization.

## Prerequisites

- macOS (tested on macOS Ventura and later)
- Administrator access (sudo privileges)
- Full Disk Access (you'll be prompted to grant this during installation)
- Source machine with Exo models for synchronization (optional)
- Internet connection for downloading dependencies

## Quick Install

If you'd like to inspect the script before running it, you can view it here:
[install.sh](https://github.com/focused-dot-io/exo-server-setup/blob/main/install.sh)

You can download and run the script directly using:

```bash
# Basic installation without model sync
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/focused-dot-io/exo-server-setup/refs/heads/main/install.sh)"

# Installation with model sync
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/focused-dot-io/exo-server-setup/refs/heads/main/install.sh)" -- <remote_models_location>
```

Note: The script will automatically request Full Disk Access permission via a system prompt. Simply approve the request when it appears.

For better security, you can download and verify the script first:
```bash
# Download the script
curl -fsSL https://raw.githubusercontent.com/focused-dot-io/exo-server-setup/refs/heads/main/install.sh -o install.sh

# Inspect the script
less install.sh

# Make it executable and run it
chmod +x install.sh
./install.sh [remote_models_location]  # remote_models_location is optional
```

Example with model sync:
```bash
./install.sh user@source-machine:/path/to/models/
```

### Security Notes

- Always inspect scripts before running them with elevated privileges
- The script requires sudo access to enable SSH and install system packages
- All network requests are made via HTTPS
- The script has built-in error handling and cleanup procedures
- No sensitive data is collected or transmitted

## Features

- Automated Full Disk Access request and verification
- Automated Homebrew installation
- Installation of required packages:
  - brave-browser
  - iterm2
  - mactop
  - tmux
  - uv
- SSH enablement
- Exo installation and configuration
- LaunchDaemon setup for automatic startup
- Model synchronization from a source machine (optional)
- Automatic cleanup after model transfer

## What the Script Does

1. Checks and requests Full Disk Access if needed
2. Enables SSH access for remote management
3. Installs Homebrew and required packages
4. Creates a workspace directory
5. Clones and installs Exo
6. Sets up Exo as a LaunchDaemon for automatic startup
7. Synchronizes models from the source location (if provided)
8. Cleans up temporary files after successful transfer

## Service Management

The script sets up Exo as a LaunchDaemon. You can manage it using:

```bash
# Start the service
sudo launchctl load /Library/LaunchDaemons/io.focused.exo.plist

# Stop the service
sudo launchctl unload /Library/LaunchDaemons/io.focused.exo.plist

# Check status
sudo launchctl list | grep exo

# View logs
tail -f ~/.local/var/log/exo/exo.log
```

## Error Handling

The script includes comprehensive error handling and will:
- Exit on any critical error
- Clean up temporary files even if the script fails
- Provide detailed error messages
- Log all operations with timestamps

## Troubleshooting

If you encounter issues:

1. **SSH Access Denied**:
   - Ensure you have administrator privileges
   - Check if SSH is blocked by firewall settings

2. **Homebrew Installation Fails**:
   - Check internet connection
   - Ensure XCode Command Line Tools are installed

3. **Model Sync Issues**:
   - Verify source location is accessible
   - Check network connectivity
   - Ensure sufficient disk space

4. **Service Issues**:
   - Check the log files at ~/.local/var/log/exo/
   - Verify the service status using launchctl
   - Ensure proper permissions on the workspace directory

## Contributing

Feel free to submit issues and enhancement requests!