#!/bin/bash

# WSL-OneDrive Bidirectional Smart Sync - OPTIMIZED VERSION
# Performance improvements:
# 1. Incremental change tracking with persistent state
# 2. Fast file comparison using size+mtime
# 3. Optimized find operations with proper exclusions  
# 4. Batch operations to reduce system calls
# 5. Smart rsync with file lists

# Source configuration
CONFIG_FILE=""
if [ -f "/etc/SyncKit/config" ]; then
    CONFIG_FILE="/etc/SyncKit/config"
elif [ -f "$HOME/.config/SyncKit/config" ]; then
    CONFIG_FILE="$HOME/.config/SyncKit/config"
else
    echo "Error: Configuration file not found"
    exit 1
fi

source "$CONFIG_FILE"

# Enhanced configuration for optimized bidirectional sync
BIDIRECTIONAL_CONFIG="$HOME/.config/SyncKit/bidirectional.conf"
WSL_SYNC_MARKER="$HOME/.local/share/wsl-sync/.last_wsl_sync"
ONEDRIVE_SYNC_MARKER="$HOME/.local/share/wsl-sync/.last_onedrive_sync"
CONFLICT_LOG="$HOME/.local/share/wsl-sync/logs/conflicts.log"

# NEW: State tracking files for performance
WSL_STATE_DB="$HOME/.local/share/wsl-sync/state/wsl_files.db"
ONEDRIVE_STATE_DB="$HOME/.local/share/wsl-sync/state/onedrive_files.db"
CHANGE_CACHE_DIR="$HOME/.local/share/wsl-sync/cache"
PERFORMANCE_LOG="$HOME/.local/share/wsl-sync/logs/performance.log"

# Performance settings
MAX_BATCH_SIZE=1000
PARALLEL_JOBS=4
QUICK_CHECK_ONLY=false

# Default conflict resolution strategy
CONFLICT_STRATEGY="${CONFLICT_STRATEGY:-newer_wins}"

# Enhanced logging with performance timing
log_performance() {
    local operation="$1"
    local duration="$2"
    local file_count="$3"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] PERF: $operation | Duration: ${duration}s | Files: $file_count" >> "$PERFORMANCE_LOG"
}

# Enhanced logging function with log levels
log_message() {
    local level="$1"
    local message="$2"
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$level] $timestamp - $message" | tee -a "$LOG_FILE"
}

# Create file state database entry (size:mtime:path)
create_file_entry() {
    local file_path="$1"
    if [ -f "$file_path" ]; then
        local size=$(stat -c %s "$file_path" 2>/dev/null || echo "0")
        local mtime=$(stat -c %Y "$file_path" 2>/dev/null || echo "0")
        echo "$size:$mtime:$file_path"
    fi
}

# Detect if a directory is a git repository
is_git_repo() {
    local dir="$1"
    [ -d "$dir/.git" ] || git -C "$dir" rev-parse --git-dir >/dev/null 2>&1
}

# Build list of git repositories to exclude entirely
build_git_exclusions() {
    local scan_dir="$1"
    local git_repos=()
    
    # Find all directories that are git repositories
    while IFS= read -r -d '' dir; do
        if is_git_repo "$dir"; then
            git_repos+=("$dir")
            log_message "DEBUG" "Excluding git repository: $dir" >&2
        fi
    done < <(find "$scan_dir" -type d -print0 2>/dev/null)
    
    # Return array of git repo paths
    printf '%s\n' "${git_repos[@]}"
}

# Build optimized exclusion pattern for find with git repo detection
build_find_excludes() {
    local scan_dir="$1"
    local exclude_args=""
    
    # Standard pattern exclusions
    for pattern in "${EXCLUDE_PATTERNS[@]}"; do
        case "$pattern" in
            "*.tmp"|"*.log"|"~$*")
                exclude_args="$exclude_args -not -name '$pattern'"
                ;;
            ".git"|"node_modules"|"build"|"dist")
                exclude_args="$exclude_args -not -path '*/$pattern' -not -path '*/$pattern/*'"
                ;;
            ".DS_Store"|"Thumbs.db")
                exclude_args="$exclude_args -not -name '$pattern'"
                ;;
        esac
    done
    
    # Add git repository exclusions
    local git_repos_file=$(mktemp)
    build_git_exclusions "$scan_dir" > "$git_repos_file"
    
    while IFS= read -r git_repo; do
        if [ -n "$git_repo" ]; then
            exclude_args="$exclude_args -not -path '$git_repo' -not -path '$git_repo/*'"
        fi
    done < "$git_repos_file"
    
    rm -f "$git_repos_file"
    echo "$exclude_args"
}

# OPTIMIZED: Fast file system scan with state comparison
fast_scan_changes() {
    local scan_dir="$1"
    local state_db="$2"
    local output_file="$3"
    local operation_name="$4"
    
    local start_time=$(date +%s)
    log_message "DEBUG" "Starting fast scan: $operation_name" >&2
    
    # Build optimized find command with git repo detection
    local exclude_args=$(build_find_excludes "$scan_dir")
    local temp_scan=$(mktemp)
    local temp_state=$(mktemp)
    
    # OPTIMIZATION 1: Single find with all exclusions
    eval "find \"$scan_dir\" -type f $exclude_args" > "$temp_scan" 2>/dev/null
    
    local file_count=$(wc -l < "$temp_scan")
    log_message "DEBUG" "Found $file_count files to check" >&2
    
    # OPTIMIZATION 2: Batch process files to reduce system calls
    > "$output_file"  # Clear output file
    
    local batch_count=0
    local changed_count=0
    local batch_files=()
    
    while IFS= read -r file_path; do
        batch_files+=("$file_path")
        ((batch_count++))
        
        # Process in batches to reduce memory usage
        if [ ${#batch_files[@]} -ge $MAX_BATCH_SIZE ]; then
            changed_count=$((changed_count + $(process_file_batch "${batch_files[@]}" "$state_db" "$output_file")))
            batch_files=()
        fi
    done < "$temp_scan"
    
    # Process remaining files
    if [ ${#batch_files[@]} -gt 0 ]; then
        changed_count=$((changed_count + $(process_file_batch "${batch_files[@]}" "$state_db" "$output_file")))
    fi
    
    # Update state database
    > "$temp_state"
    while IFS= read -r file_path; do
        create_file_entry "$file_path" >> "$temp_state"
    done < "$temp_scan"
    mv "$temp_state" "$state_db"
    
    # Cleanup
    rm -f "$temp_scan"
    
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    log_performance "$operation_name" "$duration" "$changed_count"
    log_message "INFO" "Fast scan completed: $changed_count changed files in ${duration}s" >&2
    
    echo "$changed_count"
}

# Process a batch of files for change detection
process_file_batch() {
    local files=("${@:1:$#-2}")  # All args except last 2
    local state_db="${@: -2:1}"   # Second to last arg  
    local output_file="${@: -1}"  # Last arg
    
    local changed_in_batch=0
    
    for file_path in "${files[@]}"; do
        if [ ! -f "$file_path" ]; then
            continue
        fi
        
        local size=$(stat -c %s "$file_path" 2>/dev/null || echo "0")
        local mtime=$(stat -c %Y "$file_path" 2>/dev/null || echo "0")
        local current_entry="$size:$mtime:$file_path"
        
        # OPTIMIZATION 3: Quick comparison - check if file exists in state DB
        if [ -f "$state_db" ]; then
            if ! grep -Fq "$current_entry" "$state_db" 2>/dev/null; then
                echo "$file_path" >> "$output_file"
                ((changed_in_batch++))
            fi
        else
            # First run - all files are "changed"
            echo "$file_path" >> "$output_file" 
            ((changed_in_batch++))
        fi
    done
    
    echo "$changed_in_batch"
}

# OPTIMIZED: Fast conflict detection using pre-computed change lists
fast_check_conflicts() {
    local wsl_changes_file="$1"
    local onedrive_changes_file="$2"
    local conflicts_file="$3"
    
    local start_time=$(date +%s)
    log_message "DEBUG" "Starting fast conflict detection" >&2
    
    > "$conflicts_file"  # Clear conflicts file
    local conflict_count=0
    
    # OPTIMIZATION 4: Use hash map approach for faster lookups
    local temp_onedrive_map=$(mktemp)
    
    # Build lookup map: relative_path -> onedrive_full_path
    while IFS= read -r onedrive_file; do
        if [ -f "$onedrive_file" ]; then
            local rel_path="${onedrive_file#$ONEDRIVE_WSL_DIR/}"
            echo "$rel_path:$onedrive_file" >> "$temp_onedrive_map"
        fi
    done < "$onedrive_changes_file"
    
    # Check WSL changes against OneDrive map
    while IFS= read -r wsl_file; do
        if [ ! -f "$wsl_file" ]; then
            continue
        fi
        
        local rel_path="${wsl_file#$WSL_PROJECTS_DIR/}"
        local onedrive_file="$ONEDRIVE_WSL_DIR/$rel_path"
        
        # Check if corresponding OneDrive file exists and was also changed
        if grep -q "^$rel_path:" "$temp_onedrive_map"; then
            local wsl_mtime=$(stat -c %Y "$wsl_file" 2>/dev/null || echo "0")
            local onedrive_mtime=$(stat -c %Y "$onedrive_file" 2>/dev/null || echo "0")
            
            # OPTIMIZATION 5: Quick time difference check
            local time_diff=$((wsl_mtime - onedrive_mtime))
            time_diff=${time_diff#-}  # Absolute value
            
            local conflict_window_seconds=$((${CONFLICT_WINDOW_MINUTES:-30} * 60))
            
            if [ "$time_diff" -lt "$conflict_window_seconds" ] && [ "$wsl_mtime" != "$onedrive_mtime" ]; then
                echo "$rel_path:$wsl_mtime:$onedrive_mtime" >> "$conflicts_file"
                ((conflict_count++))
            fi
        fi
    done < "$wsl_changes_file"
    
    rm -f "$temp_onedrive_map"
    
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    log_performance "conflict_detection" "$duration" "$conflict_count"
    log_message "DEBUG" "Fast conflict detection completed: $conflict_count conflicts in ${duration}s" >&2
    
    return $conflict_count
}

# OPTIMIZED: Smart rsync using file lists
smart_rsync() {
    local source_dir="$1"
    local dest_dir="$2" 
    local files_list="$3"
    local direction="$4"
    
    if [ ! -s "$files_list" ]; then
        log_message "INFO" "No files to sync for: $direction"
        return 0
    fi
    
    local file_count=$(wc -l < "$files_list")
    local start_time=$(date +%s)
    
    log_message "INFO" "Starting smart sync: $direction ($file_count files)"
    
    # OPTIMIZATION 6: Use rsync --files-from for targeted sync
    local rsync_log=$(mktemp)
    local rsync_error=$(mktemp)
    local relative_files=$(mktemp)
    
    # Convert absolute paths to relative paths for rsync
    while IFS= read -r file_path; do
        if [[ "$file_path" == "$source_dir"* ]]; then
            echo "${file_path#$source_dir/}" >> "$relative_files"
        fi
    done < "$files_list"
    
    # Build exclude arguments
    local exclude_args=""
    for pattern in "${EXCLUDE_PATTERNS[@]}"; do
        exclude_args="$exclude_args --exclude=$pattern"
    done
    
    # Execute targeted rsync
    if rsync -av --relative --files-from="$relative_files" $exclude_args "$source_dir/" "$dest_dir/" \
        > "$rsync_log" 2> "$rsync_error"; then
        
        log_message "INFO" "✅ Smart sync completed: $direction"
        
        # Log statistics
        if grep -q "Number of files transferred" "$rsync_log"; then
            local files_transferred=$(grep "Number of files transferred" "$rsync_log" | awk -F': ' '{print $2}' | tr -d ' ')
            log_message "INFO" "Files transferred: $files_transferred"
        fi
        
        local end_time=$(date +%s)
        local duration=$((end_time - start_time))
        log_performance "smart_rsync_$direction" "$duration" "$file_count"
        
        rm -f "$rsync_log" "$rsync_error" "$relative_files"
        return 0
    else
        local exit_code=$?
        log_message "ERROR" "❌ Smart sync failed: $direction (exit code: $exit_code)"
        
        if [ -s "$rsync_error" ]; then
            log_message "ERROR" "=== RSYNC ERROR ===" 
            cat "$rsync_error" | while IFS= read -r line; do
                log_message "ERROR" "$line"
            done
        fi
        
        rm -f "$rsync_log" "$rsync_error" "$relative_files"
        return 1
    fi
}

# Initialize optimized bidirectional configuration
init_optimized_config() {
    # Create necessary directories
    mkdir -p "$(dirname "$WSL_STATE_DB")" "$(dirname "$ONEDRIVE_STATE_DB")" "$CHANGE_CACHE_DIR"
    
    if [ ! -f "$BIDIRECTIONAL_CONFIG" ]; then
        log_message "INFO" "Creating optimized bidirectional sync configuration"
        cat > "$BIDIRECTIONAL_CONFIG" << 'EOF'
# WSL-OneDrive Bidirectional Sync Configuration - OPTIMIZED

# Conflict resolution strategy
CONFLICT_STRATEGY=newer_wins

# Exclusion patterns for better performance
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
    ".dart_tool"
    ".flutter-plugins*"
    "*.lock"
    "*.swp"
    "*.swo"
    "*.bak"
)

# Performance settings
MAX_BATCH_SIZE=1000
PARALLEL_JOBS=4
CONFLICT_WINDOW_MINUTES=30
EOF
        log_message "INFO" "Created optimized configuration"
    fi
    
    source "$BIDIRECTIONAL_CONFIG"
}

# OPTIMIZED: Main bidirectional sync logic
optimized_bidirectional_sync() {
    log_message "INFO" "=== Starting OPTIMIZED Bidirectional Sync ==="
    
    local total_start_time=$(date +%s)
    
    # Prepare change detection files
    local wsl_changes="$CHANGE_CACHE_DIR/wsl_changes.list"
    local onedrive_changes="$CHANGE_CACHE_DIR/onedrive_changes.list" 
    local conflicts="$CHANGE_CACHE_DIR/conflicts.list"
    
    # STEP 1: Fast scan for changes
    log_message "INFO" "Step 1: Scanning for changes..."
    local wsl_changed_count=$(fast_scan_changes "$WSL_PROJECTS_DIR" "$WSL_STATE_DB" "$wsl_changes" "wsl_scan")
    local onedrive_changed_count=$(fast_scan_changes "$ONEDRIVE_WSL_DIR" "$ONEDRIVE_STATE_DB" "$onedrive_changes" "onedrive_scan")
    
    log_message "INFO" "Changes detected - WSL: $wsl_changed_count, OneDrive: $onedrive_changed_count"
    
    # Early exit if no changes
    if [ "$wsl_changed_count" -eq 0 ] && [ "$onedrive_changed_count" -eq 0 ]; then
        log_message "INFO" "No changes detected - sync not needed"
        local total_duration=$(($(date +%s) - total_start_time))
        log_performance "total_sync_skipped" "$total_duration" "0"
        return 0
    fi
    
    # STEP 2: Fast conflict detection (only if both sides have changes)
    local conflict_count=0
    if [ "$wsl_changed_count" -gt 0 ] && [ "$onedrive_changed_count" -gt 0 ]; then
        log_message "INFO" "Step 2: Checking for conflicts..."
        fast_check_conflicts "$wsl_changes" "$onedrive_changes" "$conflicts"
        conflict_count=$?
        
        if [ "$conflict_count" -gt 0 ]; then
            log_message "WARN" "Found $conflict_count conflicts - manual resolution required"
            log_message "WARN" "Conflicts listed in: $conflicts"
            return 1
        fi
    fi
    
    # STEP 3: Smart sync operations
    local sync_success=true
    
    if [ "$wsl_changed_count" -gt 0 ]; then
        log_message "INFO" "Step 3a: Syncing WSL changes to OneDrive..."
        if ! smart_rsync "$WSL_PROJECTS_DIR" "$ONEDRIVE_WSL_DIR" "$wsl_changes" "WSL_to_OneDrive"; then
            sync_success=false
        else
            touch "$ONEDRIVE_SYNC_MARKER"
        fi
    fi
    
    if [ "$onedrive_changed_count" -gt 0 ] && [ "$sync_success" = true ]; then
        log_message "INFO" "Step 3b: Syncing OneDrive changes to WSL..."
        if ! smart_rsync "$ONEDRIVE_WSL_DIR" "$WSL_PROJECTS_DIR" "$onedrive_changes" "OneDrive_to_WSL"; then
            sync_success=false
        else
            touch "$WSL_SYNC_MARKER"
        fi
    fi
    
    local total_duration=$(($(date +%s) - total_start_time))
    local total_files=$((wsl_changed_count + onedrive_changed_count))
    
    if [ "$sync_success" = true ]; then
        log_message "INFO" "✅ Optimized sync completed successfully"
        log_performance "total_sync_success" "$total_duration" "$total_files"
    else
        log_message "ERROR" "❌ Sync completed with errors"
        log_performance "total_sync_error" "$total_duration" "$total_files"
        return 1
    fi
}

# Environment check with performance validation
check_optimized_environment() {
    log_message "DEBUG" "=== Optimized Environment Check ===" 
    
    # Standard checks from original script
    if [ ! -d "$WSL_PROJECTS_DIR" ] || [ ! -r "$WSL_PROJECTS_DIR" ]; then
        log_message "ERROR" "❌ WSL projects directory issue: $WSL_PROJECTS_DIR"
        return 1
    fi
    
    if ! mkdir -p "$ONEDRIVE_WSL_DIR" 2>/dev/null; then
        log_message "ERROR" "❌ Cannot access OneDrive directory: $ONEDRIVE_WSL_DIR"
        return 1
    fi
    
    # OPTIMIZATION 7: Pre-create cache directories for better performance
    mkdir -p "$CHANGE_CACHE_DIR" "$(dirname "$PERFORMANCE_LOG")"
    
    # Check available disk space for state files
    local available_space=$(df "$HOME" | awk 'NR==2 {print $4}')
    log_message "DEBUG" "Available disk space: ${available_space}KB"
    
    return 0
}

# Quick mode for frequent runs
if [ "$1" = "--quick" ]; then
    QUICK_CHECK_ONLY=true
    log_message "INFO" "Quick mode enabled - change detection only"
fi

# Main execution
log_message "INFO" "=== WSL-OneDrive OPTIMIZED Bidirectional Sync Started ==="

# Initialize optimized configuration
init_optimized_config

# Run environment checks
if ! check_optimized_environment; then
    log_message "ERROR" "Environment check failed - aborting"
    exit 1
fi

# Perform optimized bidirectional sync
if [ "$QUICK_CHECK_ONLY" = true ]; then
    # Quick mode - just detect changes, don't sync
    wsl_changes="$CHANGE_CACHE_DIR/wsl_changes.list"
    wsl_changed_count=$(fast_scan_changes "$WSL_PROJECTS_DIR" "$WSL_STATE_DB" "$wsl_changes" "quick_wsl_scan")
    log_message "INFO" "Quick scan result: $wsl_changed_count changes detected"
else
    # Full optimized sync
    optimized_bidirectional_sync
fi

log_message "INFO" "=== Optimized Bidirectional Sync Completed ==="