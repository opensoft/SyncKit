# DataSync - WSL to OneDrive File Synchronization

DataSync provides automated bidirectional file synchronization between WSL (Windows Subsystem for Linux) and OneDrive, enabling seamless data management across Windows and Linux environments.

## Features

- **Automated Sync**: Periodic synchronization every 10 minutes (configurable)
- **Smart Detection**: Only syncs when changes are detected to minimize resource usage
- **Bidirectional**: Support for both WSL→OneDrive and OneDrive→WSL synchronization
- **Zone Identifier Handling**: Automatically removes Windows zone identifiers from synced files
- **Professional Installation**: System-wide installation with proper Linux filesystem locations

## Components

### Scripts
- `install-wsl-sync.sh` - Installer script for setting up DataSync
- `uninstall-wsl-sync.sh` - Uninstaller script for removing DataSync
- `wsl-smart-sync` - Main synchronization script (WSL→OneDrive)
- `wsl-sync-from-onedrive` - Reverse synchronization script (OneDrive→WSL)
- `wsl-bidirectional-sync.sh` - Enhanced bidirectional sync with conflict resolution

### Documentation
- `CHANGELOG.md` - Version history and changes
- `README.md` - Detailed documentation (this file)

### Configuration
- `config.template` - Configuration template for setting up sync paths

## Installation

```bash
# Install DataSync system-wide
./scripts/install-wsl-sync.sh

# Uninstall DataSync
./scripts/uninstall-wsl-sync.sh
```

## Configuration

After installation, configure your sync paths in `~/.config/wsl-sync/config`:

```bash
# WSL source directory
WSL_SOURCE="/home/username/projects"

# OneDrive target directory
ONEDRIVE_TARGET="/mnt/c/Users/username/OneDrive - Company/projects/wsl"
```

## Usage

### Automatic Sync
DataSync runs automatically via cron every 10 minutes after installation.

### Manual Sync
```bash
# Sync WSL to OneDrive
wsl-smart-sync

# Sync OneDrive to WSL
wsl-sync-from-onedrive

# Bidirectional sync with conflict resolution
wsl-bidirectional-sync.sh
```

## Architecture

DataSync uses rsync for efficient file synchronization with the following key features:

- **Smart Change Detection**: Uses timestamp comparison to detect changes
- **Incremental Sync**: Only transfers changed files
- **Preserve Permissions**: Maintains file permissions and timestamps
- **Zone Identifier Cleanup**: Removes Windows security zone identifiers

## Troubleshooting

### Common Issues

1. **Cron PATH Issues**: DataSync installer sets proper PATH in cron
2. **Permission Errors**: Ensure proper permissions on source and target directories
3. **OneDrive Sync Conflicts**: Monitor OneDrive sync status to avoid conflicts

### Logs
Check sync logs in `~/.local/share/wsl-sync/logs/`

## Requirements

- WSL (Windows Subsystem for Linux)
- OneDrive with accessible mount point
- rsync installed
- Proper permissions on sync directories