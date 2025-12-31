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
APP_NAME="SyncKit"
INSTALL_TYPE="user"  # Default to user installation
INSTALL_DIR=""
CONFIG_DIR=""
LOG_DIR=""
BIN_DIR=""
INTERACTIVE_MODE=true
WSL_PROJECTS_PATH=""
ONEDRIVE_WSL_PATH=""

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
    echo "  --system                    Install system-wide (requires sudo)"
    echo "  --user                      Install for current user only (default)"
    echo "  --wsl-dir PATH              Set WSL projects directory (skips prompt)"
    echo "  --onedrive-dir PATH         Set OneDrive sync directory (skips prompt)"
    echo "  --non-interactive           Skip all prompts (use with --wsl-dir and --onedrive-dir)"
    echo "  --help                      Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0                                    # Interactive installation (auto-detects paths)"
    echo "  sudo $0 --system                     # System-wide interactive installation"
    echo "  $0 --wsl-dir ~/dev --onedrive-dir '/mnt/c/Users/User/OneDrive/projects/wsl'"
    echo "  $0 --non-interactive --wsl-dir ~/code --onedrive-dir '/mnt/c/Users/User/OneDrive - Company/projects/wsl'"
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
    if [ -f "$SCRIPT_DIR/oneDriveDataSync.sh" ]; then
        print_info "Installing bidirectional coordinator script..."
        cp "$SCRIPT_DIR/oneDriveDataSync.sh" "$BIN_DIR/wsl-bidirectional-sync"
        
        # Update the log file paths to use consistent naming
        sed -i "s|WSL_SYNC_MARKER=.*|WSL_SYNC_MARKER=\"$DATA_DIR/.last_wsl_sync\"|g" "$BIN_DIR/wsl-bidirectional-sync"
        sed -i "s|ONEDRIVE_SYNC_MARKER=.*|ONEDRIVE_SYNC_MARKER=\"$DATA_DIR/.last_onedrive_sync\"|g" "$BIN_DIR/wsl-bidirectional-sync"
        sed -i "s|CONFLICT_LOG=.*|CONFLICT_LOG=\"$LOG_DIR/conflicts.log\"|g" "$BIN_DIR/wsl-bidirectional-sync"
    else
        print_error "oneDriveDataSync.sh not found in $SCRIPT_DIR"
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

prompt_for_paths() {
    # Handle non-interactive mode
    if [ "$INTERACTIVE_MODE" = false ]; then
        if [ -z "$WSL_PROJECTS_PATH" ] || [ -z "$ONEDRIVE_WSL_PATH" ]; then
            print_error "Non-interactive mode requires both --wsl-dir and --onedrive-dir to be specified"
            exit 1
        fi
        
        # Expand tilde if present
        WSL_PROJECTS_PATH="${WSL_PROJECTS_PATH/#\~/$HOME}"
        ONEDRIVE_WSL_PATH="${ONEDRIVE_WSL_PATH/#\~/$HOME}"
        
        # Create directories if they don't exist
        mkdir -p "$WSL_PROJECTS_PATH" || {
            print_error "Failed to create WSL projects directory: $WSL_PROJECTS_PATH"
            exit 1
        }
        mkdir -p "$ONEDRIVE_WSL_PATH" || {
            print_error "Failed to create OneDrive sync directory: $ONEDRIVE_WSL_PATH"
            exit 1
        }
        
        print_info "Non-interactive configuration:"
        print_info "  WSL Projects Directory: $WSL_PROJECTS_PATH"
        print_info "  OneDrive Sync Directory: $ONEDRIVE_WSL_PATH"
        return 0
    fi
    
    # Interactive mode
    echo ""
    print_info "=== SyncKit Configuration Setup ==="
    echo ""
    
    # Detect common WSL project directories
    local common_wsl_paths=(
        "$HOME/projects"
        "$HOME/dev"
        "$HOME/code"
        "$HOME/workspace"
        "$HOME/src"
        "$HOME/development"
    )
    
    local detected_wsl=""
    local detected_projects_count=0
    local detected_git_count=0
    for path in "${common_wsl_paths[@]}"; do
        if [ -d "$path" ]; then
            local project_count=$(find "$path" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | wc -l)
            local git_count=$(find "$path" -mindepth 1 -maxdepth 2 -name ".git" -type d 2>/dev/null | wc -l)
            
            # Prioritize directories with git repositories, then by project count
            if [ "$git_count" -gt "$detected_git_count" ] || 
               ([ "$git_count" -eq "$detected_git_count" ] && [ "$project_count" -gt "$detected_projects_count" ]); then
                detected_wsl="$path"
                detected_projects_count="$project_count"
                detected_git_count="$git_count"
            fi
        fi
    done
    
    local default_wsl="${detected_wsl:-$HOME/projects}"
    echo ""
    print_info "WSL Projects Directory Detection:"
    if [ -n "$detected_wsl" ] && [ "$detected_projects_count" -gt 0 ]; then
        if [ "$detected_git_count" -gt 0 ]; then
            print_success "Found existing projects directory: $detected_wsl ($detected_projects_count projects, $detected_git_count git repos)"
        else
            print_success "Found existing projects directory: $detected_wsl ($detected_projects_count projects)"
        fi
    else
        print_info "No existing projects directory detected, will use default"
        echo "Common locations:"
        echo "  - $HOME/projects"
        echo "  - $HOME/dev"
        echo "  - $HOME/code"
        echo "  - $HOME/workspace"
    fi
    
    echo -n "Enter your WSL projects directory [$default_wsl]: "
    read wsl_projects_input
    WSL_PROJECTS_PATH="${wsl_projects_input:-$default_wsl}"
    
    # Expand tilde if present
    WSL_PROJECTS_PATH="${WSL_PROJECTS_PATH/#\~/$HOME}"
    
    # Validate WSL projects directory
    if [ ! -d "$WSL_PROJECTS_PATH" ]; then
        print_warning "Directory $WSL_PROJECTS_PATH does not exist."
        echo -n "Create it now? [Y/n]: "
        read create_wsl
        if [[ "$create_wsl" =~ ^[Nn]$ ]]; then
            print_error "WSL projects directory is required. Exiting."
            exit 1
        else
            mkdir -p "$WSL_PROJECTS_PATH"
            print_success "Created WSL projects directory: $WSL_PROJECTS_PATH"
        fi
    fi
    
    # Detect common OneDrive paths
    local common_onedrive_paths=(
        "/mnt/c/Users/$USER/OneDrive"
        "/mnt/c/Users/$USER/OneDrive - *"
        "/mnt/c/OneDrive"
    )
    
    local detected_onedrive=""
    for pattern in "${common_onedrive_paths[@]}"; do
        local found_path=$(ls -d $pattern 2>/dev/null | head -1)
        if [ -n "$found_path" ] && [ -d "$found_path" ]; then
            detected_onedrive="$found_path"
            break
        fi
    done
    
    echo ""
    print_info "OneDrive Directory Detection:"
    if [ -n "$detected_onedrive" ]; then
        print_success "Found OneDrive at: $detected_onedrive"
        local suggested_path="$detected_onedrive/projects/wsl"
        echo -n "Enter your OneDrive sync directory [$suggested_path]: "
        read onedrive_input
        ONEDRIVE_WSL_PATH="${onedrive_input:-$suggested_path}"
    else
        print_warning "Could not auto-detect OneDrive directory"
        echo "Common paths:"
        echo "  - /mnt/c/Users/YourUsername/OneDrive/projects/wsl"
        echo "  - /mnt/c/Users/YourUsername/OneDrive - CompanyName/projects/wsl"
        echo ""
        echo -n "Enter your full OneDrive sync directory path: "
        read onedrive_input
        ONEDRIVE_WSL_PATH="$onedrive_input"
    fi
    
    # Expand tilde if present
    ONEDRIVE_WSL_PATH="${ONEDRIVE_WSL_PATH/#\~/$HOME}"
    
    # Validate/create OneDrive directory
    if [ ! -d "$ONEDRIVE_WSL_PATH" ]; then
        print_warning "OneDrive directory $ONEDRIVE_WSL_PATH does not exist."
        echo -n "Create it now? [Y/n]: "
        read create_onedrive
        if [[ "$create_onedrive" =~ ^[Nn]$ ]]; then
            print_error "OneDrive sync directory is required. Exiting."
            exit 1
        else
            mkdir -p "$ONEDRIVE_WSL_PATH"
            if [ $? -eq 0 ]; then
                print_success "Created OneDrive sync directory: $ONEDRIVE_WSL_PATH"
            else
                print_error "Failed to create OneDrive directory. Check permissions and path."
                exit 1
            fi
        fi
    fi
    
    echo ""
    print_info "Configuration Summary:"
    echo "  WSL Projects Directory: $WSL_PROJECTS_PATH"
    echo "  OneDrive Sync Directory: $ONEDRIVE_WSL_PATH"
    echo ""
    echo -n "Proceed with this configuration? [Y/n]: "
    read confirm
    if [[ "$confirm" =~ ^[Nn]$ ]]; then
        print_error "Configuration cancelled by user."
        exit 1
    fi
}

create_config() {
    print_info "Creating configuration file..."
    
    # Create configuration with user-provided paths
    cat > "$CONFIG_DIR/config" << EOF
# WSL-OneDrive Sync Configuration
# Generated by SyncKit installer on $(date)

# WSL Projects Directory (where you work)
WSL_PROJECTS_DIR="$WSL_PROJECTS_PATH"

# OneDrive WSL Directory (backup location)
ONEDRIVE_WSL_DIR="$ONEDRIVE_WSL_PATH"

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
            --wsl-dir)
                WSL_PROJECTS_PATH="$2"
                if [ -z "$WSL_PROJECTS_PATH" ]; then
                    print_error "--wsl-dir requires a path argument"
                    exit 1
                fi
                shift 2
                ;;
            --onedrive-dir)
                ONEDRIVE_WSL_PATH="$2"
                if [ -z "$ONEDRIVE_WSL_PATH" ]; then
                    print_error "--onedrive-dir requires a path argument"
                    exit 1
                fi
                shift 2
                ;;
            --non-interactive)
                INTERACTIVE_MODE=false
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
    prompt_for_paths
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
