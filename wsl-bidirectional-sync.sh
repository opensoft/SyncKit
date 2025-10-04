#!/bin/bash

# WSL-OneDrive Bidirectional Smart Sync
# Syncs changes in both directions: WSL ↔ OneDrive

# Source configuration
CONFIG_FILE=""
if [ -f "/etc/wsl-sync/config" ]; then
    CONFIG_FILE="/etc/wsl-sync/config"
elif [ -f "$HOME/.config/wsl-sync/config" ]; then
    CONFIG_FILE="$HOME/.config/wsl-sync/config"
else
    echo "Error: Configuration file not found"
    exit 1
fi

source "$CONFIG_FILE"

# Enhanced configuration for bidirectional sync
BIDIRECTIONAL_CONFIG="$HOME/.config/wsl-sync/bidirectional.conf"
WSL_SYNC_MARKER="$HOME/.local/share/wsl-sync/.last_wsl_sync"
ONEDRIVE_SYNC_MARKER="$HOME/.local/share/wsl-sync/.last_onedrive_sync"
CONFLICT_LOG="$HOME/.local/share/wsl-sync/logs/conflicts.log"

# Default conflict resolution strategy
CONFLICT_STRATEGY="${CONFLICT_STRATEGY:-newer_wins}"  # Options: newer_wins, wsl_wins, onedrive_wins, manual

# Enhanced logging function with log levels
log_message() {
    local level="$1"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$level] $timestamp - $message" | tee -a "$LOG_FILE"
}

# Log conflict information
log_conflict() {
    local file="$1"
    local wsl_time="$2"
    local onedrive_time="$3"
    local resolution="$4"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] CONFLICT: $file | WSL: $wsl_time | OneDrive: $onedrive_time | Resolution: $resolution" >> "$CONFLICT_LOG"
}

# Initialize bidirectional configuration
init_bidirectional_config() {
    if [ ! -f "$BIDIRECTIONAL_CONFIG" ]; then
        log_message "INFO" "Creating bidirectional sync configuration"
        mkdir -p "$(dirname "$BIDIRECTIONAL_CONFIG")"
        cat > "$BIDIRECTIONAL_CONFIG" << EOF
# WSL-OneDrive Bidirectional Sync Configuration

# Conflict resolution strategy
# Options: newer_wins, wsl_wins, onedrive_wins, manual
CONFLICT_STRATEGY=newer_wins

# Exclusion patterns (one per line)
# These patterns will be excluded from bidirectional sync
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
)

# Maximum age for conflict detection (in minutes)
# Files changed within this window on both sides are considered conflicts
CONFLICT_WINDOW_MINUTES=30
EOF
        log_message "INFO" "Created default bidirectional configuration at: $BIDIRECTIONAL_CONFIG"
    fi
    
    source "$BIDIRECTIONAL_CONFIG"
}

# Check for file conflicts
check_conflicts() {
    local wsl_files="$1"
    local onedrive_files="$2"
    local conflicts=()
    
    log_message "DEBUG" "Checking for file conflicts..."
    
    # Create temporary files for comparison
    local wsl_temp=$(mktemp)
    local onedrive_temp=$(mktemp)
    local common_temp=$(mktemp)
    
    # Get files changed in WSL since last OneDrive sync
    if [ -f "$ONEDRIVE_SYNC_MARKER" ]; then
        find "$WSL_PROJECTS_DIR" -newer "$ONEDRIVE_SYNC_MARKER" -type f 2>/dev/null > "$wsl_temp"
    else
        find "$WSL_PROJECTS_DIR" -type f 2>/dev/null > "$wsl_temp"
    fi
    
    # Get files changed in OneDrive since last WSL sync
    if [ -f "$WSL_SYNC_MARKER" ]; then
        find "$ONEDRIVE_WSL_DIR" -newer "$WSL_SYNC_MARKER" -type f 2>/dev/null > "$onedrive_temp"
    else
        find "$ONEDRIVE_WSL_DIR" -type f 2>/dev/null > "$onedrive_temp"
    fi
    
    # Find common files (potential conflicts)
    local conflict_count=0
    while IFS= read -r wsl_file; do
        local rel_path="${wsl_file#$WSL_PROJECTS_DIR/}"
        local onedrive_file="$ONEDRIVE_WSL_DIR/$rel_path"
        
        if [ -f "$onedrive_file" ]; then
            local wsl_time=$(stat -c %Y "$wsl_file" 2>/dev/null || echo "0")
            local onedrive_time=$(stat -c %Y "$onedrive_file" 2>/dev/null || echo "0")
            
            # Check if both files were modified recently (potential conflict)
            local time_diff=$((wsl_time - onedrive_time))
            time_diff=${time_diff#-}  # Absolute value
            
            local conflict_window_seconds=$((CONFLICT_WINDOW_MINUTES * 60))
            
            if [ "$time_diff" -lt "$conflict_window_seconds" ] && [ "$wsl_time" != "$onedrive_time" ]; then
                conflicts+=("$rel_path:$wsl_time:$onedrive_time")
                ((conflict_count++))
                log_message "WARN" "Conflict detected: $rel_path (WSL: $(date -d @$wsl_time), OneDrive: $(date -d @$onedrive_time))"
            fi
        fi
    done < "$wsl_temp"
    
    # Cleanup temp files
    rm -f "$wsl_temp" "$onedrive_temp" "$common_temp"
    
    if [ "$conflict_count" -gt 0 ]; then
        log_message "WARN" "Found $conflict_count file conflicts"
        return 1
    else
        log_message "DEBUG" "No conflicts detected"
        return 0
    fi
}

# Resolve conflicts based on strategy
resolve_conflicts() {
    local conflicts=("$@")
    
    log_message "INFO" "Resolving conflicts using strategy: $CONFLICT_STRATEGY"
    
    for conflict in "${conflicts[@]}"; do
        IFS=':' read -r rel_path wsl_time onedrive_time <<< "$conflict"
        
        local wsl_file="$WSL_PROJECTS_DIR/$rel_path"
        local onedrive_file="$ONEDRIVE_WSL_DIR/$rel_path"
        
        case "$CONFLICT_STRATEGY" in
            "newer_wins")
                if [ "$wsl_time" -gt "$onedrive_time" ]; then
                    log_message "INFO" "Resolving conflict: WSL version is newer, copying to OneDrive: $rel_path"
                    cp "$wsl_file" "$onedrive_file"
                    log_conflict "$rel_path" "$(date -d @$wsl_time)" "$(date -d @$onedrive_time)" "WSL_NEWER"
                else
                    log_message "INFO" "Resolving conflict: OneDrive version is newer, copying to WSL: $rel_path"
                    cp "$onedrive_file" "$wsl_file"
                    log_conflict "$rel_path" "$(date -d @$wsl_time)" "$(date -d @$onedrive_time)" "ONEDRIVE_NEWER"
                fi
                ;;
            "wsl_wins")
                log_message "INFO" "Resolving conflict: WSL wins strategy, copying to OneDrive: $rel_path"
                cp "$wsl_file" "$onedrive_file"
                log_conflict "$rel_path" "$(date -d @$wsl_time)" "$(date -d @$onedrive_time)" "WSL_WINS"
                ;;
            "onedrive_wins")
                log_message "INFO" "Resolving conflict: OneDrive wins strategy, copying to WSL: $rel_path"
                cp "$onedrive_file" "$wsl_file"
                log_conflict "$rel_path" "$(date -d @$wsl_time)" "$(date -d @$onedrive_time)" "ONEDRIVE_WINS"
                ;;
            "manual")
                log_message "ERROR" "Manual conflict resolution required for: $rel_path"
                log_conflict "$rel_path" "$(date -d @$wsl_time)" "$(date -d @$onedrive_time)" "MANUAL_REQUIRED"
                # Create backup copies for manual resolution
                cp "$wsl_file" "${wsl_file}.wsl-conflict-$(date +%Y%m%d-%H%M%S)"
                cp "$onedrive_file" "${onedrive_file}.onedrive-conflict-$(date +%Y%m%d-%H%M%S)"
                ;;
        esac
    done
}

# Build rsync exclude arguments
build_exclude_args() {
    local exclude_args=""
    for pattern in "${EXCLUDE_PATTERNS[@]}"; do
        exclude_args="$exclude_args --exclude=$pattern"
    done
    echo "$exclude_args"
}

# Perform one-way sync with conflict resolution
perform_sync() {
    local source="$1"
    local destination="$2"
    local direction="$3"
    local sync_marker="$4"
    
    log_message "INFO" "Starting sync: $direction"
    
    # Build exclude arguments
    local exclude_args=$(build_exclude_args)
    
    # Create temporary files for rsync output
    local rsync_log=$(mktemp)
    local rsync_error=$(mktemp)
    
    # Execute rsync with exclusions
    log_message "DEBUG" "Executing: rsync -av --delete $exclude_args \"$source/\" \"$destination/\""
    
    if eval "rsync -av --delete --stats --human-readable $exclude_args \"$source/\" \"$destination/\"" \
        > "$rsync_log" 2> "$rsync_error"; then
        
        # Success
        log_message "INFO" "✅ Sync completed successfully: $direction"
        
        # Log transfer statistics
        if grep -q "Number of files transferred" "$rsync_log"; then
            local files_transferred=$(grep "Number of files transferred" "$rsync_log" | awk -F': ' '{print $2}' | tr -d ' ')
            log_message "INFO" "Files transferred: $files_transferred"
        fi
        
        # Update sync marker
        touch "$sync_marker"
        
        # Cleanup temp files
        rm -f "$rsync_log" "$rsync_error"
        return 0
        
    else
        # Failure
        local exit_code=$?
        log_message "ERROR" "❌ Sync failed: $direction (exit code: $exit_code)"
        
        # Log error details
        if [ -s "$rsync_error" ]; then
            log_message "ERROR" "=== RSYNC ERROR OUTPUT ==="
            while IFS= read -r line; do
                log_message "ERROR" "$line"
            done < "$rsync_error"
        fi
        
        # Cleanup temp files
        rm -f "$rsync_log" "$rsync_error"
        return 1
    fi
}

# Main bidirectional sync logic
bidirectional_sync() {
    log_message "INFO" "=== Starting Bidirectional Sync ==="
    
    # Check what needs syncing
    local wsl_needs_sync=false
    local onedrive_needs_sync=false
    
    # Check if WSL has changes since last OneDrive sync
    if [ ! -f "$ONEDRIVE_SYNC_MARKER" ]; then
        log_message "INFO" "First OneDrive sync - WSL changes will be synced"
        wsl_needs_sync=true
    else
        if find "$WSL_PROJECTS_DIR" -newer "$ONEDRIVE_SYNC_MARKER" 2>/dev/null | grep -q .; then
            log_message "INFO" "WSL changes detected since last OneDrive sync"
            wsl_needs_sync=true
        fi
    fi
    
    # Check if OneDrive has changes since last WSL sync
    if [ ! -f "$WSL_SYNC_MARKER" ]; then
        log_message "INFO" "First WSL sync - OneDrive changes will be synced"
        onedrive_needs_sync=true
    else
        if find "$ONEDRIVE_WSL_DIR" -newer "$WSL_SYNC_MARKER" 2>/dev/null | grep -q .; then
            log_message "INFO" "OneDrive changes detected since last WSL sync"
            onedrive_needs_sync=true
        fi
    fi
    
    # Handle different sync scenarios
    if [ "$wsl_needs_sync" = true ] && [ "$onedrive_needs_sync" = true ]; then
        log_message "WARN" "Changes detected on both sides - checking for conflicts"
        
        if check_conflicts; then
            log_message "INFO" "No conflicts detected - proceeding with bidirectional sync"
            # Sync WSL to OneDrive first (arbitrary choice)
            if perform_sync "$WSL_PROJECTS_DIR" "$ONEDRIVE_WSL_DIR" "WSL → OneDrive" "$ONEDRIVE_SYNC_MARKER"; then
                perform_sync "$ONEDRIVE_WSL_DIR" "$WSL_PROJECTS_DIR" "OneDrive → WSL" "$WSL_SYNC_MARKER"
            fi
        else
            log_message "WARN" "Conflicts detected - resolving before sync"
            # resolve_conflicts would need the conflict list - simplified for now
            log_message "ERROR" "Conflict resolution not yet fully implemented - manual intervention required"
            return 1
        fi
        
    elif [ "$wsl_needs_sync" = true ]; then
        log_message "INFO" "Only WSL has changes - syncing WSL → OneDrive"
        perform_sync "$WSL_PROJECTS_DIR" "$ONEDRIVE_WSL_DIR" "WSL → OneDrive" "$ONEDRIVE_SYNC_MARKER"
        
    elif [ "$onedrive_needs_sync" = true ]; then
        log_message "INFO" "Only OneDrive has changes - syncing OneDrive → WSL"
        perform_sync "$ONEDRIVE_WSL_DIR" "$WSL_PROJECTS_DIR" "OneDrive → WSL" "$WSL_SYNC_MARKER"
        
    else
        log_message "INFO" "No changes detected on either side - no sync needed"
    fi
}

# Environment check function (reused from unidirectional script)
check_environment() {
    log_message "DEBUG" "=== Environment Check ==="
    log_message "DEBUG" "WSL_PROJECTS_DIR: $WSL_PROJECTS_DIR"
    log_message "DEBUG" "ONEDRIVE_WSL_DIR: $ONEDRIVE_WSL_DIR"
    log_message "DEBUG" "CONFLICT_STRATEGY: $CONFLICT_STRATEGY"
    
    # Check if source directory exists and is readable
    if [ -d "$WSL_PROJECTS_DIR" ] && [ -r "$WSL_PROJECTS_DIR" ]; then
        log_message "DEBUG" "✅ WSL projects directory exists and readable: $WSL_PROJECTS_DIR"
    else
        log_message "ERROR" "❌ WSL projects directory issue: $WSL_PROJECTS_DIR"
        return 1
    fi
    
    # Check if destination directory is accessible
    if mkdir -p "$ONEDRIVE_WSL_DIR" 2>/dev/null; then
        log_message "DEBUG" "✅ OneDrive directory accessible: $ONEDRIVE_WSL_DIR"
    else
        log_message "ERROR" "❌ Cannot access OneDrive directory: $ONEDRIVE_WSL_DIR"
        return 1
    fi
    
    # Create necessary directories
    mkdir -p "$(dirname "$WSL_SYNC_MARKER")" "$(dirname "$ONEDRIVE_SYNC_MARKER")" "$(dirname "$CONFLICT_LOG")"
    
    return 0
}

# Main execution
log_message "INFO" "=== WSL-OneDrive Bidirectional Sync Started ==="

# Initialize configuration
init_bidirectional_config

# Run environment checks
if ! check_environment; then
    log_message "ERROR" "Environment check failed - aborting"
    exit 1
fi

# Perform bidirectional sync
bidirectional_sync

log_message "INFO" "=== Bidirectional Sync Completed ==="