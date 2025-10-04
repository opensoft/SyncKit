# SyncKit Architecture Documentation

## Overview

SyncKit is a WSL-to-OneDrive synchronization system designed to automatically sync project files from Windows Subsystem for Linux (WSL) to OneDrive for backup and cross-platform access. The system provides intelligent, change-based synchronization with comprehensive logging and error handling.

## System Architecture

### High-Level Components

```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────────┐
│   WSL Projects  │    │    SyncKit       │    │   OneDrive WSL      │
│   /home/brett/  │───▶│   Smart Sync     │───▶│   C:\Users\Brett\   │
│   projects/     │    │   Script         │    │   OneDrive\...      │
└─────────────────┘    └──────────────────┘    └─────────────────────┘
                              │
                              ▼
                       ┌──────────────────┐
                       │   Cron Scheduler │
                       │   (Every 5 min)  │
                       └──────────────────┘
                              │
                              ▼
                       ┌──────────────────┐
                       │  Enhanced Logging│
                       │  & Diagnostics   │
                       └──────────────────┘
```

## Implementation Details

### 1. Core Sync Script (`wsl-smart-sync`)

**Location**: `~/.local/bin/wsl-smart-sync`  
**Language**: Bash  
**Purpose**: Main synchronization logic with intelligent change detection

#### Key Features:
- **Change Detection**: Only syncs when files have been modified since last successful sync
- **Atomic Operations**: Uses rsync for reliable, resumable transfers
- **Delete Synchronization**: Maintains exact mirror with `--delete` flag
- **Comprehensive Logging**: Multi-level logging (DEBUG, INFO, WARN, ERROR)

#### Configuration Sources:
1. System: `/etc/wsl-sync/config`
2. User: `~/.config/wsl-sync/config` (current)

### 2. Configuration System

**Location**: `~/.config/wsl-sync/config`

```bash
# WSL Projects Directory (source)
WSL_PROJECTS_DIR="/home/brett/projects"

# OneDrive WSL Directory (destination) 
ONEDRIVE_WSL_DIR="/mnt/c/Users/$USER/OneDrive - Opensoft Inc/projects/wsl"

# Tracking Files
LAST_SYNC_FILE="/home/brett/.local/share/wsl-sync/.last_sync_time"
LOG_FILE="/home/brett/.local/share/wsl-sync/logs/sync.log"
```

### 3. Scheduling System

**Implementation**: Cron-based scheduling  
**Frequency**: Every 5 minutes  
**Configuration**: 
```cron
*/5 * * * * HOME=/home/brett USER=brett PATH=/usr/local/bin:/usr/bin:/bin /home/brett/.local/bin/wsl-smart-sync
```

**Environment Variables Set**:
- `HOME=/home/brett` - Ensures proper home directory access
- `USER=brett` - Sets user context
- `PATH=/usr/local/bin:/usr/bin:/bin` - Minimal but sufficient PATH

### 4. Enhanced Logging & Diagnostics

#### Log Levels:
- **[DEBUG]**: Environment checks, file detection, configuration validation
- **[INFO]**: Sync start/completion, file counts, transfer statistics  
- **[WARN]**: Non-critical issues (temp files, open files)
- **[ERROR]**: Sync failures, permission issues, path problems

#### Diagnostic Features:
- **Environment Validation**: Directory accessibility, permissions, disk space
- **OneDrive Conflict Detection**: Identifies active OneDrive sync operations
- **Open File Detection**: Uses `lsof` to identify files in use
- **Detailed Error Capture**: Separate stdout/stderr from rsync
- **Performance Metrics**: Transfer rates, file counts, data volumes

### 5. Data Flow

```
1. Cron Trigger (Every 5 minutes)
   ↓
2. Environment Check
   ├── Validate source directory (/home/brett/projects)
   ├── Check destination accessibility (OneDrive path)  
   ├── Verify disk space availability
   └── Detect OneDrive sync conflicts
   ↓
3. Change Detection
   ├── Compare file timestamps to last sync marker
   ├── Log detected changes
   └── Decide if sync needed
   ↓
4. Sync Execution (if changes detected)
   ├── Execute: rsync -av --delete --stats --human-readable
   ├── Capture detailed output and errors
   └── Update sync timestamp on success
   ↓
5. Result Logging
   ├── Success: Log transfer statistics
   └── Failure: Execute diagnostic checks
```

### 6. Directory Structure

```
/home/brett/
├── .config/wsl-sync/
│   └── config                          # Configuration file
├── .local/
│   ├── bin/
│   │   └── wsl-smart-sync              # Main sync script
│   └── share/wsl-sync/
│       ├── .last_sync_time             # Sync timestamp marker
│       └── logs/
│           └── sync.log                # Detailed sync logs
└── projects/
    ├── SyncKit/                        # This project
    ├── DevBench/
    ├── adminbench/
    ├── dartwingers/
    ├── keycloak/
    ├── nopSetup/
    ├── spec-kit/
    └── test/
```

### 7. Error Handling & Recovery

#### Common Failure Scenarios:
1. **Permission Issues**: Read-only files, insufficient write access
2. **OneDrive Conflicts**: Active sync operations creating temporary files
3. **Network/Mount Issues**: SMB mount problems, network interruption
4. **Disk Space**: Insufficient space on destination
5. **File Locks**: Applications holding files open during sync

#### Recovery Mechanisms:
- **Automatic Retry**: Cron reschedules every 5 minutes
- **Partial Sync Recovery**: rsync resumes interrupted transfers
- **Conflict Detection**: Identifies and logs sync conflicts
- **Manual Override**: Can be run manually for immediate sync

## Current Status

### ✅ Implemented Features:
- [x] **Bidirectional synchronization** (WSL ↔ OneDrive)
- [x] **Intelligent change detection** (separate timestamps for each direction)
- [x] **Conflict resolution** (4 strategies: newer_wins, wsl_wins, onedrive_wins, manual)
- [x] **Smart exclusion patterns** (build artifacts, temp files, version control)
- [x] **Cron-based scheduling** (5-minute intervals)
- [x] **Enhanced multi-level logging** (DEBUG/INFO/WARN/ERROR)
- [x] **Comprehensive error diagnostics**
- [x] **Environment validation**
- [x] **Configuration management**
- [x] **Manual sync capability**
- [x] **Conflict logging and tracking**

### ✅ Resolved Issues:
- **Cron vs Manual Execution**: ✅ Resolved with enhanced environment validation
- **Environment Differences**: ✅ Fixed with comprehensive diagnostic checks
- **Unidirectional limitations**: ✅ Replaced with full bidirectional sync

### 📈 Major Updates (v2.0.0 - 2025-10-04):
- **🔄 Bidirectional Sync**: Complete rewrite for WSL ↔ OneDrive synchronization
- **⚔️ Conflict Resolution**: Multiple strategies with automatic and manual options
- **🛡️ Smart Exclusions**: Comprehensive exclusion patterns for development workflows
- **📊 Enhanced Logging**: Separate conflict log and improved diagnostics
- **⚡ Performance Optimization**: Efficient conflict detection and sync operations

## Technical Specifications

### Dependencies:
- **rsync**: File synchronization utility
- **find**: File discovery and timestamp comparison
- **lsof**: Open file detection (optional)
- **df**: Disk space monitoring
- **cron**: Task scheduling

### Performance Characteristics:
- **Source Size**: ~7.7GB project directory
- **Sync Frequency**: Every 5 minutes
- **Change Detection**: Timestamp-based (efficient for large directories)
- **Transfer Method**: Delta sync via rsync (only changed files)

### Platform Requirements:
- **WSL**: Windows Subsystem for Linux (Ubuntu 24.04)
- **OneDrive**: Business account with sufficient storage
- **File System**: WSL ext4 → NTFS (via SMB mount)

## Future Enhancements

### Planned Features:
- [x] ~~Bidirectional sync capability~~ ✅ **COMPLETED**
- [x] ~~Exclusion patterns (.gitignore style)~~ ✅ **COMPLETED**
- [x] ~~Sync conflict resolution~~ ✅ **COMPLETED**
- [ ] Real-time change detection (inotify)
- [ ] Multiple destination support
- [ ] Encryption at rest
- [ ] Web-based monitoring dashboard
- [ ] Project-specific `.syncignore` files
- [ ] Sync performance analytics
- [ ] Mobile notifications for conflicts

### Monitoring & Alerting:
- [ ] Email notifications on sync failures
- [ ] Prometheus metrics export
- [ ] Health check endpoint
- [ ] Sync performance trending

---

*Generated: 2025-10-04*  
*Last Updated: 2025-10-04*