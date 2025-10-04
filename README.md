# SyncKit - WSL ↔ OneDrive Bidirectional Sync

**Intelligent bidirectional synchronization between WSL projects and OneDrive with conflict resolution and comprehensive logging.**

![SyncKit Architecture](https://img.shields.io/badge/WSL-↔-OneDrive?style=for-the-badge&logo=microsoft&logoColor=white)

## 🚀 Features

- **🔄 Bidirectional Sync**: Automatically syncs changes in both directions (WSL ↔ OneDrive)
- **🧠 Smart Change Detection**: Only syncs when files have actually changed
- **⚡ Conflict Resolution**: Multiple strategies to handle file conflicts
- **🛡️ Exclusion Patterns**: Intelligently excludes build artifacts, temp files, and version control
- **📊 Comprehensive Logging**: Multi-level logging with detailed diagnostics
- **⏰ Automated Scheduling**: Runs every 5 minutes via cron
- **🔧 Configurable**: Flexible configuration system

## 📁 Directory Structure

```
/home/brett/
├── .config/wsl-sync/
│   ├── config                          # Main sync configuration
│   └── bidirectional.conf             # Bidirectional sync settings
├── .local/
│   ├── bin/
│   │   └── wsl-smart-sync              # Main sync script
│   └── share/SyncKit/
│       ├── .last_wsl_sync              # OneDrive → WSL sync marker
│       ├── .last_onedrive_sync         # WSL → OneDrive sync marker
│       └── logs/
│           ├── sync.log                # Main sync log
│           └── conflicts.log           # Conflict resolution log
└── projects/                           # Your synced projects
    ├── SyncKit/                        # This project
    ├── DevBench/
    └── [other projects...]
```

## 🛠️ Installation & Setup

### Prerequisites
- Windows Subsystem for Linux (WSL) with Ubuntu
- OneDrive Business account with sync enabled
- `rsync` installed (usually pre-installed)

### Current Installation
SyncKit is already installed and configured on your system:

**✅ Installed Components:**
- Main sync script: `~/.local/bin/wsl-smart-sync`
- Configuration: `~/.config/wsl-sync/config`
- Bidirectional config: `~/.config/wsl-sync/bidirectional.conf`
- Cron job: Every 5 minutes

**✅ Sync Paths:**
- **WSL Source**: `/home/brett/projects`
- **OneDrive Destination**: `/mnt/c/Users/brett/OneDrive - Opensoft Inc/projects/wsl`

## ⚙️ Configuration

### Main Configuration (`~/.config/wsl-sync/config`)
```bash
# WSL Projects Directory (source)
WSL_PROJECTS_DIR="/home/brett/projects"

# OneDrive WSL Directory (destination) 
ONEDRIVE_WSL_DIR="/mnt/c/Users/brett/OneDrive - Opensoft Inc/projects/wsl"

# Tracking Files
LAST_SYNC_FILE="/home/brett/.local/share/SyncKit/.last_sync_time"
LOG_FILE="/home/brett/.local/share/SyncKit/logs/sync.log"
```

### Bidirectional Configuration (`~/.config/wsl-sync/bidirectional.conf`)
```bash
# Conflict resolution strategy
CONFLICT_STRATEGY=newer_wins

# Exclusion patterns
EXCLUDE_PATTERNS=(
    "*.tmp"
    "*.log"
    ".git"
    "node_modules"
    "build"
    "dist"
    ".DS_Store"
    "Thumbs.db"
    "~$*"
    "*:Zone.Identifier"      # Windows security metadata
    "*.Zone.Identifier"      # Alternative format
)

# Conflict detection window (minutes)
CONFLICT_WINDOW_MINUTES=30
```

## 🔄 How Bidirectional Sync Works

### Sync Logic
1. **Change Detection**: Checks for changes on both WSL and OneDrive sides
2. **Conflict Analysis**: Identifies files modified on both sides within the conflict window
3. **Conflict Resolution**: Applies resolution strategy (newer wins by default)
4. **Sync Execution**: Performs sync operations using rsync with exclusions
5. **Marker Updates**: Updates sync timestamps for next iteration

### Sync Scenarios

| WSL Changes | OneDrive Changes | Action |
|-------------|------------------|---------|
| ✅ Yes | ❌ No | WSL → OneDrive |
| ❌ No | ✅ Yes | OneDrive → WSL |
| ✅ Yes | ✅ Yes | Conflict Resolution + Bidirectional |
| ❌ No | ❌ No | No sync needed |

## ⚔️ Conflict Resolution Strategies

### 1. `newer_wins` (Default)
The file with the most recent modification time wins.
```bash
CONFLICT_STRATEGY=newer_wins
```

### 2. `wsl_wins`
WSL version always takes precedence.
```bash
CONFLICT_STRATEGY=wsl_wins
```

### 3. `onedrive_wins`
OneDrive version always takes precedence.
```bash
CONFLICT_STRATEGY=onedrive_wins
```

### 4. `manual`
Creates backup copies and requires manual intervention.
```bash
CONFLICT_STRATEGY=manual
```
Creates files like:
- `file.txt.wsl-conflict-20251004-063032`
- `file.txt.onedrive-conflict-20251004-063032`

## 🎯 Usage

### Automatic Operation
SyncKit runs automatically every 5 minutes via cron:
```bash
*/5 * * * * HOME=/home/brett USER=brett PATH=/usr/local/bin:/usr/bin:/bin /home/brett/.local/bin/wsl-smart-sync
```

### Manual Operation
Run sync manually:
```bash
~/.local/bin/wsl-smart-sync
```

### Check Sync Status
View recent sync activity:
```bash
tail -20 ~/.local/share/SyncKit/logs/sync.log
```

View conflicts:
```bash
tail -10 ~/.local/share/SyncKit/logs/conflicts.log
```

## 📊 Monitoring & Logs

### Log Levels
- **[DEBUG]**: Environment checks, file detection, detailed operations
- **[INFO]**: Sync operations, completion status, file counts
- **[WARN]**: Conflicts, non-critical issues
- **[ERROR]**: Sync failures, permission problems

### Sample Log Output
```
[INFO] 2025-10-04 06:33:16 - === WSL-OneDrive Bidirectional Sync Started ===
[DEBUG] 2025-10-04 06:33:16 - ✅ WSL projects directory exists and readable
[INFO] 2025-10-04 06:33:16 - WSL changes detected since last OneDrive sync
[INFO] 2025-10-04 06:33:16 - Starting sync: WSL → OneDrive
[INFO] 2025-10-04 06:33:16 - ✅ Sync completed successfully: WSL → OneDrive
[INFO] 2025-10-04 06:33:16 - Files transferred: 42
```

### Performance Metrics
- **Source Size**: ~7.7GB
- **Sync Frequency**: Every 5 minutes
- **Conflict Detection**: ~16 minutes for full scan
- **Typical Sync**: 30 seconds - 3 minutes depending on changes

## 🚨 Troubleshooting

### Common Issues

#### Sync Failures
```bash
# Check recent errors
grep "ERROR" ~/.local/share/SyncKit/logs/sync.log | tail -10
```

#### Permission Issues
```bash
# Verify directory permissions
ls -la ~/projects
ls -la "/mnt/c/Users/brett/OneDrive - Opensoft Inc/projects/wsl"
```

#### OneDrive Sync Conflicts
```bash
# Check for OneDrive temp files
find "/mnt/c/Users/brett/OneDrive - Opensoft Inc/projects/wsl" -name "*.tmp" -o -name "~*"
```

### Manual Recovery
If sync gets stuck or conflicts arise:

1. **Stop automatic sync** (temporarily):
   ```bash
   crontab -e
   # Comment out the sync line with #
   ```

2. **Check for open files**:
   ```bash
   lsof +D ~/projects
   ```

3. **Manual conflict resolution**:
   ```bash
   # Find conflict files
   find ~/projects -name "*.wsl-conflict-*" -o -name "*.onedrive-conflict-*"
   ```

4. **Force sync** (use with caution):
   ```bash
   # Remove sync markers to force full sync
   rm ~/.local/share/SyncKit/.last_*_sync
   ~/.local/bin/wsl-smart-sync
   ```

## 📈 Customization

### Adding Exclusion Patterns
Edit `~/.config/wsl-sync/bidirectional.conf`:
```bash
EXCLUDE_PATTERNS=(
    "*.tmp"
    "*.log"
    ".git"
    "node_modules"
    "build"
    "dist"
    ".DS_Store"
    "Thumbs.db"
    "~$*"
    # Add your patterns here
    "*.cache"
    "venv"
    ".vscode/settings.json"
)
```

### Changing Sync Frequency
Edit crontab:
```bash
crontab -e
# Change */5 to different interval (e.g., */10 for 10 minutes)
*/10 * * * * HOME=/home/brett USER=brett PATH=/usr/local/bin:/usr/bin:/bin /home/brett/.local/bin/wsl-smart-sync
```

### Conflict Window Adjustment
Edit `~/.config/wsl-sync/bidirectional.conf`:
```bash
# Increase window for slower workflows
CONFLICT_WINDOW_MINUTES=60

# Decrease for faster conflict detection
CONFLICT_WINDOW_MINUTES=15
```

## 🔮 Advanced Features

### Conflict Resolution Scenarios

#### Scenario 1: Developer working on both Windows and WSL
```bash
# Set strategy to prefer WSL for development work
CONFLICT_STRATEGY=wsl_wins
```

#### Scenario 2: Collaboration with team via OneDrive
```bash
# Set strategy to prefer newer files
CONFLICT_STRATEGY=newer_wins
```

#### Scenario 3: Critical files need manual review
```bash
# Set manual resolution for careful review
CONFLICT_STRATEGY=manual
```

### Custom Exclusions by Project
You can create project-specific `.syncignore` files (future enhancement).

## 🔧 Technical Details

### Sync Markers
- **WSL → OneDrive**: `~/.local/share/SyncKit/.last_onedrive_sync`
- **OneDrive → WSL**: `~/.local/share/SyncKit/.last_wsl_sync`

### Rsync Options
```bash
rsync -av --delete --stats --human-readable [exclusions] source/ destination/
```
- `-a`: Archive mode (preserves permissions, timestamps, etc.)
- `-v`: Verbose output
- `--delete`: Remove files that don't exist in source
- `--stats`: Show transfer statistics
- `--human-readable`: Human-readable file sizes

### Dependencies
- `rsync`: File synchronization
- `find`: File discovery and change detection
- `stat`: File timestamp queries
- `lsof`: Open file detection (optional)
- `cron`: Task scheduling

## 📋 Status & Health Check

### Quick Health Check
```bash
# Check if sync is running
ps aux | grep wsl-smart-sync

# Check last sync time
ls -la ~/.local/share/SyncKit/.last_*_sync

# Check recent activity
tail -5 ~/.local/share/SyncKit/logs/sync.log

# Verify cron job
crontab -l | grep wsl-smart-sync
```

### System Information
- **Platform**: WSL Ubuntu 24.04
- **Shell**: zsh 5.9
- **Sync Method**: rsync bidirectional
- **Scheduling**: cron (every 5 minutes)
- **Logging**: Multi-level with rotation

## 🎯 Best Practices

1. **🔄 Regular Monitoring**: Check logs weekly for any issues
2. **⚡ Exclude Build Artifacts**: Keep exclusion patterns updated
3. **🛡️ Backup Critical Files**: OneDrive provides versioning, but consider additional backups
4. **🕐 Respect Conflict Windows**: Avoid rapid changes on both sides simultaneously
5. **📊 Monitor Performance**: Large projects may need longer sync intervals

## 🆘 Support & Troubleshooting

### Get Help
1. **Check Logs**: Start with `~/.local/share/SyncKit/logs/sync.log`
2. **Review Configuration**: Verify paths and settings
3. **Test Manual Sync**: Run `~/.local/bin/wsl-smart-sync` manually
4. **Check System Resources**: Monitor disk space and memory

### Emergency Procedures
- **Stop All Syncing**: `crontab -e` and comment out sync line
- **Restore from OneDrive**: Use OneDrive version history
- **Reset Sync State**: Remove all `.last_*_sync` files

---

## 📝 Changelog

### v2.0.0 (2025-10-04) - Bidirectional Sync
- ✨ **NEW**: Full bidirectional synchronization
- ✨ **NEW**: Conflict detection and resolution
- ✨ **NEW**: Multiple conflict resolution strategies
- ✨ **NEW**: Comprehensive exclusion patterns
- ✨ **NEW**: Separate sync markers for each direction
- ✨ **NEW**: Conflict logging
- 🔧 **IMPROVED**: Enhanced logging with DEBUG/INFO/WARN/ERROR levels
- 🔧 **IMPROVED**: Better error handling and diagnostics

### v1.0.0 (2025-10-04) - Unidirectional Sync
- ✨ Initial implementation with WSL → OneDrive sync
- ✨ Smart change detection
- ✨ Cron-based scheduling
- ✨ Basic logging and error handling

---

*SyncKit v2.0.0 - Bidirectional Smart Sync for WSL ↔ OneDrive*  
*Last Updated: October 4, 2025*