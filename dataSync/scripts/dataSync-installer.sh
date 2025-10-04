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
    
    # Get the directory where this installer is located
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    
    # Install the simple unidirectional WSL → OneDrive script
    if [ -f "$SCRIPT_DIR/wsl-sync-to-onedrive" ]; then
        print_info "Installing WSL → OneDrive sync script..."
        cp "$SCRIPT_DIR/wsl-sync-to-onedrive" "$BIN_DIR/wsl-sync-to-onedrive"
    else
        print_error "wsl-sync-to-onedrive not found in $SCRIPT_DIR"
        exit 1
    fi
    
    # Install the simple unidirectional OneDrive → WSL script
    if [ -f "$SCRIPT_DIR/wsl-sync-from-onedrive" ]; then
        print_info "Installing OneDrive → WSL sync script..."
        cp "$SCRIPT_DIR/wsl-sync-from-onedrive" "$BIN_DIR/wsl-sync-from-onedrive"
    else
        print_error "wsl-sync-from-onedrive not found in $SCRIPT_DIR"
        exit 1
    fi
    
    # Install the bidirectional coordinator script
    if [ -f "$SCRIPT_DIR/wsl-bidirectional-sync.sh" ]; then
        print_info "Installing bidirectional coordinator script..."
        cp "$SCRIPT_DIR/wsl-bidirectional-sync.sh" "$BIN_DIR/wsl-bidirectional-sync"
        
        # Update the log file paths to use consistent naming
        sed -i "s|WSL_SYNC_MARKER=.*|WSL_SYNC_MARKER=\"$DATA_DIR/.last_wsl_sync\"|g" "$BIN_DIR/wsl-bidirectional-sync"
        sed -i "s|ONEDRIVE_SYNC_MARKER=.*|ONEDRIVE_SYNC_MARKER=\"$DATA_DIR/.last_onedrive_sync\"|g" "$BIN_DIR/wsl-bidirectional-sync"
        sed -i "s|CONFLICT_LOG=.*|CONFLICT_LOG=\"$LOG_DIR/conflicts.log\"|g" "$BIN_DIR/wsl-bidirectional-sync"
    else
        print_error "wsl-bidirectional-sync.sh not found in $SCRIPT_DIR"
        exit 1
    fi
    
    # Make scripts executable
    chmod +x "$BIN_DIR/wsl-sync-to-onedrive"
    chmod +x "$BIN_DIR/wsl-sync-from-onedrive"
    chmod +x "$BIN_DIR/wsl-bidirectional-sync"
    
    print_success "Scripts installed to $BIN_DIR"
    print_info "wsl-sync-to-onedrive: Manual WSL → OneDrive sync"
    print_info "wsl-sync-from-onedrive: Manual OneDrive → WSL sync"
    print_info "wsl-bidirectional-sync: Automated bidirectional sync with conflict resolution"
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
    
    # Add cron job for current user with proper PATH environment
    # This fixes the issue where cron jobs fail due to missing PATH variables
    CRON_COMMAND="*/5 * * * * PATH=/usr/local/bin:/usr/bin:/bin $BIN_DIR/wsl-bidirectional-sync"
    
    # Check if cron job already exists
    if crontab -l 2>/dev/null | grep -q "wsl-bidirectional-sync"; then
        print_warning "Cron job already exists, updating with proper PATH..."
        # Remove old cron job and add new one with PATH
        crontab -l 2>/dev/null | grep -v "wsl-bidirectional-sync" | crontab -
        (crontab -l 2>/dev/null; echo "$CRON_COMMAND") | crontab -
        print_success "Cron job updated with proper PATH environment"
    else
        # Add to existing crontab or create new one
        (crontab -l 2>/dev/null; echo "$CRON_COMMAND") | crontab -
        print_success "Cron job added - will run every 5 minutes with proper PATH"
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
    echo "  wsl-sync-to-onedrive        - Manual WSL → OneDrive sync"
    echo "  wsl-sync-from-onedrive      - Manual OneDrive → WSL sync"
    echo "  wsl-bidirectional-sync      - Manual bidirectional sync (same as automatic)"
    echo ""
    print_info "Configuration: $CONFIG_DIR/config"
    print_info "Logs: $LOG_DIR/sync.log"
    echo ""
    print_info "Automatic sync runs every 5 minutes via cron"
}

main "$@"
