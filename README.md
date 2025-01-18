# Exo Server Setup Script

An automated setup script for configuring a new Mac as an Exo server. This script handles installation of required dependencies, enables SSH access, and configures the Exo environment with model synchronization.

## Prerequisites

- macOS (tested on macOS Ventura and later)
- Administrator access (sudo privileges)
- Source machine with Exo models for synchronization
- Internet connection for downloading dependencies

## Features

- Automated Homebrew installation
- Installation of required packages:
  - brave-browser
  - iterm2
  - mactop
  - tux
  - uv
- SSH enablement
- Exo installation and configuration
- Model synchronization from a source machine
- Automatic cleanup after model transfer

## Quick Install

If you'd like to inspect the script before running it, you can view it here:
[install.sh](https://github.com/focused/exo-server-setup/blob/main/install.sh)

You can download and run the script directly using:

```bash
# Basic installation without model sync
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/focused/exo-server-setup/refs/heads/main/install.sh)"

# Installation with model sync
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/focused/exo-server-setup/refs/heads/main/install.sh)" -- <remote_models_location>
```

For better security, you can download and verify the script first:
```bash
# Download the script
curl -fsSL https://raw.githubusercontent.com/focused/exo-server-setup/refs/heads/main/install.sh -o install.sh

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

### Verification

You can verify the script's integrity by:
1. Checking the GitHub repository directly
2. Inspecting the script before execution
3. Verifying that all downloaded packages are from official sources (Homebrew)

## Manual Installation
   ```bash
   git clone <repository-url>
   cd <repository-name>
   ```

2. Make the script executable:
   ```bash
   chmod +x setup.sh
   ```

3. Run the script with the source models location:
   ```bash
   ./setup.sh <remote_models_location>
   ```
   
   Example:
   ```bash
   ./setup.sh user@source-machine:/path/to/models/
   ```

## What the Script Does

1. Enables SSH access for remote management
2. Installs Homebrew and required packages
3. Creates a workspace directory
4. Clones and installs Exo
5. Synchronizes models from the source location
6. Starts Exo and monitors model transfer
7. Cleans up temporary files after successful transfer

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

## Contributing

Feel free to submit issues and enhancement requests!