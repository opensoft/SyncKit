#!/bin/bash

# WSL-OneDrive Sync Installer
# This installer sets up the sync system in proper system locations

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
APP_NAME="wsl-sync"
INSTALL_TYPE="user"  # Default to user installation
INSTALL_DIR=""
CONFIG_DIR=""
LOG_DIR=""
BIN_DIR=""

print_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

show_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --system      Install system-wide (requires sudo)"
    echo "  --user        Install for current user only (default)"
    echo "  --help        Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0                # Install for current user"
    echo "  sudo $0 --system  # Install system-wide"
}

setup_directories() {
    if [ "$INSTALL_TYPE" = "system" ]; then
        # System-wide installation
        BIN_DIR="/usr/local/bin"
        CONFIG_DIR="/etc/$APP_NAME"
        LOG_DIR="/var/log/$APP_NAME"
        DATA_DIR="/usr/local/share/$APP_NAME"
    else
        # User installation
        BIN_DIR="$HOME/.local/bin"
        CONFIG_DIR="$HOME/.config/$APP_NAME"
        LOG_DIR="$HOME/.local/share/$APP_NAME/logs"
        DATA_DIR="$HOME/.local/share/$APP_NAME"
    fi
}

create_directories() {
    print_info "Creating directories..."
    
    mkdir -p "$BIN_DIR"
    mkdir -p "$CONFIG_DIR"
    mkdir -p "$LOG_DIR"
    mkdir -p "$DATA_DIR"
    
    # Ensure directories have correct permissions
    if [ "$INSTALL_TYPE" = "system" ]; then
        chmod 755 "$CONFIG_DIR" "$LOG_DIR" "$DATA_DIR"
        chmod 755 "$BIN_DIR"
    else
        chmod 700 "$CONFIG_DIR" "$LOG_DIR" "$DATA_DIR"
        chmod 755 "$BIN_DIR"
    fi
    
    print_success "Directories created"
}

install_scripts() {
    print_info "Installing sync scripts..."
    
    # Create smart-sync script
    cat > "$BIN_DIR/wsl-smart-sync" << 'EOF'
#!/bin/bash

# WSL-OneDrive Smart Sync
# Only syncs when files have changed

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

# Function to log messages with timestamp
log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

# Check if files changed since last sync
if [ ! -f "$LAST_SYNC_FILE" ]; then
    log_message "First run - will sync all files"
    SYNC_NEEDED=true
else
    # Check if any files are newer than the last sync
    if find "$WSL_PROJECTS_DIR" -newer "$LAST_SYNC_FILE" 2>/dev/null | grep -q .; then
        log_message "Files changed since last sync - syncing now"
        SYNC_NEEDED=true
    else
        log_message "No changes detected since last sync"
        SYNC_NEEDED=false
    fi
fi

# Perform sync if needed
if [ "$SYNC_NEEDED" = true ]; then
    log_message "Starting sync: WSL → OneDrive"
    
    # Create OneDrive directory if it doesn't exist
    mkdir -p "$ONEDRIVE_WSL_DIR"
    
    # Use rsync to sync efficiently
    if rsync -av --delete "$WSL_PROJECTS_DIR/" "$ONEDRIVE_WSL_DIR/"; then
        # Update the sync timestamp
        touch "$LAST_SYNC_FILE"
        log_message "✅ Sync completed successfully"
    else
        log_message "❌ Sync failed - check permissions and paths"
        exit 1
    fi
else
    log_message "ℹ️  No sync needed"
fi
EOF

    # Create sync-from-onedrive script
    cat > "$BIN_DIR/wsl-sync-from-onedrive" << 'EOF'
#!/bin/bash

# Sync FROM OneDrive TO WSL
# Use this when you get home or switch machines

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

# Function to log messages with timestamp
log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" | tee -a "$LOG_FILE"
}

log_message "Starting sync: OneDrive → WSL"

# Create WSL projects directory if it doesn't exist
mkdir -p "$WSL_PROJECTS_DIR"

# Use rsync to sync efficiently
if rsync -av --delete "$ONEDRIVE_WSL_DIR/" "$WSL_PROJECTS_DIR/"; then
    log_message "✅ Sync from OneDrive completed successfully"
    
    # Update the sync timestamp so smart-sync doesn't immediately sync back
    touch "$LAST_SYNC_FILE"
    
    log_message "📁 Projects available in $WSL_PROJECTS_DIR"
    ls -la "$WSL_PROJECTS_DIR/"
else
    log_message "❌ Sync from OneDrive failed - check permissions and paths"
    exit 1
fi
EOF

    # Make scripts executable
    chmod +x "$BIN_DIR/wsl-smart-sync"
    chmod +x "$BIN_DIR/wsl-sync-from-onedrive"
    
    print_success "Scripts installed to $BIN_DIR"
}

create_config() {
    print_info "Creating configuration file..."
    
    # Default configuration
    cat > "$CONFIG_DIR/config" << EOF
# WSL-OneDrive Sync Configuration

# WSL Projects Directory (where you work)
WSL_PROJECTS_DIR="$HOME/projects"

# OneDrive WSL Directory (backup location)
ONEDRIVE_WSL_DIR="/mnt/c/Users/\$USER/OneDrive - Opensoft Inc/projects/wsl"

# Tracking files
LAST_SYNC_FILE="$DATA_DIR/.last_sync_time"
LOG_FILE="$LOG_DIR/sync.log"
EOF

    if [ "$INSTALL_TYPE" = "system" ]; then
        chmod 644 "$CONFIG_DIR/config"
    else
        chmod 600 "$CONFIG_DIR/config"
    fi
    
    print_success "Configuration created at $CONFIG_DIR/config"
}

setup_cron() {
    print_info "Setting up automatic sync..."
    
    # Add cron job for current user
    CRON_COMMAND="*/10 * * * * $BIN_DIR/wsl-smart-sync"
    
    # Check if cron job already exists
    if crontab -l 2>/dev/null | grep -q "wsl-smart-sync"; then
        print_warning "Cron job already exists, skipping..."
    else
        # Add to existing crontab or create new one
        (crontab -l 2>/dev/null; echo "$CRON_COMMAND") | crontab -
        print_success "Cron job added - will run every 10 minutes"
    fi
}

add_to_path() {
    if [ "$INSTALL_TYPE" = "user" ] && [ "$BIN_DIR" = "$HOME/.local/bin" ]; then
        # Add ~/.local/bin to PATH if not already there
        if ! echo "$PATH" | grep -q "$HOME/.local/bin"; then
            if [ -f "$HOME/.bashrc" ]; then
                echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.bashrc"
            fi
            if [ -f "$HOME/.zshrc" ]; then
                echo 'export PATH="$HOME/.local/bin:$PATH"' >> "$HOME/.zshrc"
            fi
            print_info "Added $BIN_DIR to PATH (restart shell or source ~/.bashrc/.zshrc)"
        fi
    fi
}

main() {
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --system)
                if [ "$EUID" -ne 0 ]; then
                    print_error "System installation requires sudo privileges"
                    exit 1
                fi
                INSTALL_TYPE="system"
                shift
                ;;
            --user)
                INSTALL_TYPE="user"
                shift
                ;;
            --help)
                show_usage
                exit 0
                ;;
            *)
                print_error "Unknown option: $1"
                show_usage
                exit 1
                ;;
        esac
    done
    
    print_info "Installing WSL-OneDrive Sync ($INSTALL_TYPE installation)..."
    
    setup_directories
    create_directories
    install_scripts
    create_config
    setup_cron
    add_to_path
    
    print_success "Installation completed!"
    echo ""
    print_info "Available commands:"
    echo "  wsl-smart-sync              - Manual sync to OneDrive"
    echo "  wsl-sync-from-onedrive      - Manual sync from OneDrive"
    echo ""
    print_info "Configuration: $CONFIG_DIR/config"
    print_info "Logs: $LOG_DIR/sync.log"
    echo ""
    print_info "Automatic sync runs every 10 minutes via cron"
}

main "$@"
EOF