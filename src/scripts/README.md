# SyncKit - WSL OneDrive Sync

![Version](https://img.shields.io/badge/version-1.0.0-blue.svg)
![License](https://img.shields.io/badge/license-MIT-green.svg)
![Platform](https://img.shields.io/badge/platform-WSL2-orange.svg)

Intelligent synchronization between WSL filesystem and OneDrive for optimal development performance.

## 🚀 Quick Start

```bash
# Clone the repository
git clone <your-repo-url> SyncKit
cd SyncKit

# Install for current user
./src/scripts/install-wsl-sync.sh

# Or install system-wide
sudo ./src/scripts/install-wsl-sync.sh --system
```

## 🎯 Features

- **🚀 Fast Development**: Work on native WSL filesystem for maximum performance
- **💾 Automatic Backup**: Smart sync only when files actually change  
- **🔄 Bi-directional Sync**: Full sync capabilities between WSL and OneDrive
- **📱 Multi-device Access**: Access your projects from anywhere via OneDrive
- **⚡ Efficient**: Only syncs when changes are detected
- **🛡️ Safe**: Non-destructive sync with proper error handling
- **🔧 Configurable**: Easy customization for different OneDrive setups

## 📁 Project Structure

```
SyncKit/
├── README.md                           # This file
├── LICENSE                            # MIT License
├── CHANGELOG.md                       # Version history
└── src/
    └── scripts/
        ├── README.md                  # Installation & usage guide
        ├── install-wsl-sync.sh        # Main installer script
        ├── uninstall-wsl-sync.sh      # Uninstaller script
        ├── wsl-smart-sync             # Core sync script (WSL → OneDrive)
        ├── wsl-sync-from-onedrive     # Reverse sync script (OneDrive → WSL)
        └── config.template            # Configuration template
```

## 🔧 Development Setup

This project contains the source scripts for the WSL-OneDrive sync system.

### Script Overview

| Script | Purpose | Location After Install |
|--------|---------|----------------------|
| `wsl-smart-sync` | Smart sync WSL → OneDrive | `~/.local/bin/` or `/usr/local/bin/` |
| `wsl-sync-from-onedrive` | OneDrive → WSL sync | `~/.local/bin/` or `/usr/local/bin/` |
| `install-wsl-sync.sh` | Professional installer | - |
| `uninstall-wsl-sync.sh` | Clean uninstaller | - |

### Configuration Files

After installation:
- **User config**: `~/.config/wsl-sync/config`
- **System config**: `/etc/wsl-sync/config`

### Log Files

After installation:
- **User logs**: `~/.local/share/wsl-sync/logs/sync.log`
- **System logs**: `/var/log/wsl-sync/sync.log`

## 🚦 Usage

### Automatic Sync
The system automatically syncs your WSL projects to OneDrive every 10 minutes when changes are detected.

### Manual Commands
```bash
# Sync WSL projects TO OneDrive
wsl-smart-sync

# Sync FROM OneDrive TO WSL (when switching machines)
wsl-sync-from-onedrive
```

## 🔄 Workflow

1. **Develop** in `~/projects/` (fast WSL filesystem)
2. **Auto-sync** runs every 10 minutes when changes are detected
3. **OneDrive** automatically syncs to cloud
4. **Access** from other machines using `wsl-sync-from-onedrive`

## ⚙️ Configuration

Edit the configuration file to customize paths:

```bash
# User installation
nano ~/.config/wsl-sync/config

# System installation  
sudo nano /etc/wsl-sync/config
```

### Default Configuration
```bash
# WSL Projects Directory (where you work)
WSL_PROJECTS_DIR="$HOME/projects"

# OneDrive WSL Directory (backup location)
ONEDRIVE_WSL_DIR="/mnt/c/Users/$USER/OneDrive - [Company]/projects/wsl"

# Sync frequency: Every 10 minutes via cron
```

## 📊 Monitoring

### View Sync Logs
```bash
# Live monitoring
tail -f ~/.local/share/wsl-sync/logs/sync.log

# Recent activity
tail -20 ~/.local/share/wsl-sync/logs/sync.log
```

### Check Status
```bash
# List cron jobs
crontab -l

# Check cron service
systemctl status cron

# Manual sync test
wsl-smart-sync
```

## 🔧 Development

### Making Changes

1. Edit scripts in `src/scripts/`
2. Test changes locally
3. Update version in installer
4. Commit to Git
5. Create release package

### Building Release Package

```bash
# Copy scripts to release directory
mkdir -p release/
cp src/scripts/{install-wsl-sync.sh,uninstall-wsl-sync.sh,README.md} release/
chmod +x release/*.sh
```

## 🐛 Troubleshooting

### Common Issues

**Sync not working?**
```bash
# Check cron job exists
crontab -l | grep wsl-smart-sync

# Manual test
wsl-smart-sync

# Check logs
tail ~/.local/share/wsl-sync/logs/sync.log
```

**Permission Issues?**
```bash
# Check OneDrive path accessibility
ls -la "/mnt/c/Users/$USER/OneDrive"*

# Verify script permissions
ls -la ~/.local/bin/wsl-*
```

**Path Issues?**
```bash
# Check PATH includes ~/.local/bin
echo $PATH | grep -o ~/.local/bin

# Source shell config if needed  
source ~/.bashrc  # or ~/.zshrc
```

## 📝 License

MIT License - See [LICENSE](LICENSE) file for details.

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch
3. Make changes to scripts in `src/scripts/`
4. Test thoroughly
5. Submit a pull request

## 📈 Version History

See [CHANGELOG.md](CHANGELOG.md) for version history.

## 🆘 Support

- **Issues**: Create an issue on GitHub
- **Documentation**: See `src/scripts/README.md`
- **Logs**: Check `~/.local/share/wsl-sync/logs/sync.log`