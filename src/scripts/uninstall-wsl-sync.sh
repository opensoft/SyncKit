#!/bin/bash

# WSL-OneDrive Sync Uninstaller

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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

remove_cron_job() {
    print_info "Removing cron job..."
    
    # Remove cron job
    if crontab -l 2>/dev/null | grep -q "wsl-smart-sync"; then
        crontab -l 2>/dev/null | grep -v "wsl-smart-sync" | crontab -
        print_success "Cron job removed"
    else
        print_info "No cron job found"
    fi
}

remove_files() {
    print_info "Removing installed files..."
    
    # Try system locations first
    if [ -d "/etc/wsl-sync" ]; then
        if [ "$EUID" -ne 0 ]; then
            print_error "System installation detected, but not running as root"
            print_info "Please run: sudo $0"
            exit 1
        fi
        
        # System installation cleanup
        rm -f "/usr/local/bin/wsl-smart-sync"
        rm -f "/usr/local/bin/wsl-sync-from-onedrive"
        rm -rf "/etc/wsl-sync"
        rm -rf "/var/log/wsl-sync"
        rm -rf "/usr/local/share/wsl-sync"
        
        print_success "System files removed"
    fi
    
    # User installation cleanup
    if [ -d "$HOME/.config/wsl-sync" ]; then
        rm -f "$HOME/.local/bin/wsl-smart-sync"
        rm -f "$HOME/.local/bin/wsl-sync-from-onedrive"
        rm -rf "$HOME/.config/wsl-sync"
        rm -rf "$HOME/.local/share/wsl-sync"
        
        print_success "User files removed"
    fi
    
    # Remove old scripts from home directory (if they exist)
    if [ -f "$HOME/smart-sync.sh" ]; then
        print_warning "Found old script at $HOME/smart-sync.sh"
        read -p "Remove it? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            rm -f "$HOME/smart-sync.sh"
            rm -f "$HOME/sync-from-onedrive.sh"
            rm -f "$HOME/sync.log"
            print_success "Old scripts removed"
        fi
    fi
}

main() {
    print_info "Uninstalling WSL-OneDrive Sync..."
    
    remove_cron_job
    remove_files
    
    print_success "Uninstallation completed!"
    print_info "Your project files in ~/projects/ were not touched"
}

main "$@"