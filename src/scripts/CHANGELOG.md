# Changelog

All notable changes to SyncKit will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2025-10-02

### Added
- Initial release of SyncKit - WSL OneDrive Sync
- Smart sync script (`wsl-smart-sync`) that only syncs when files change
- Reverse sync script (`wsl-sync-from-onedrive`) for pulling changes from OneDrive
- Professional installer script with user/system installation options
- Clean uninstaller script
- Configuration management system
- Automatic cron job setup for periodic syncing
- Comprehensive logging system
- Linux Filesystem Hierarchy Standard (FHS) compliance
- User and system installation modes
- Proper error handling and permission management

### Features
- **Fast Development**: Native WSL filesystem performance
- **Automatic Backup**: Smart sync every 10 minutes when changes detected
- **Bi-directional Sync**: Full sync capabilities between WSL and OneDrive
- **Multi-device Access**: Access projects from anywhere via OneDrive
- **Efficient**: Only syncs when changes are detected (no wasted bandwidth)
- **Safe**: Non-destructive sync with proper error handling
- **Configurable**: Easy customization for different OneDrive setups
- **Professional**: Proper installation locations and system integration

### Technical Details
- Uses `rsync` for efficient file synchronization
- Uses `find` with timestamp comparison for change detection  
- Cron-based scheduling for automatic syncing
- Configurable via simple config files
- Comprehensive logging with timestamps
- PATH integration for easy command access
- Follows Linux standards for file placement

### Installation Locations

#### User Installation (Default)
- Scripts: `~/.local/bin/`
- Config: `~/.config/wsl-sync/`
- Logs: `~/.local/share/wsl-sync/logs/`

#### System Installation
- Scripts: `/usr/local/bin/`
- Config: `/etc/wsl-sync/`
- Logs: `/var/log/wsl-sync/`

### Commands Added
- `wsl-smart-sync` - Manual sync WSL → OneDrive
- `wsl-sync-from-onedrive` - Manual sync OneDrive → WSL
- `./install-wsl-sync.sh` - Install the sync system
- `./uninstall-wsl-sync.sh` - Clean uninstall

### Configuration
- Default WSL projects directory: `~/projects/`
- Default OneDrive path: `/mnt/c/Users/$USER/OneDrive - [Company]/projects/wsl/`
- Default sync frequency: Every 10 minutes
- All paths configurable via config file

## [Unreleased]

### Planned
- GUI configuration tool
- Multiple OneDrive account support
- Sync conflict resolution
- Exclude patterns support
- Sync statistics and reporting
- Windows installer
- Real-time sync option (inotify-based)
- Bandwidth throttling options