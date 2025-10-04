# SyncKit - Comprehensive Synchronization Suite

**A complete synchronization solution for modern development environments**

![SyncKit](https://img.shields.io/badge/SyncKit-v2.0-blue?style=for-the-badge) ![Platform](https://img.shields.io/badge/Platform-WSL%20%7C%20Windows%20%7C%20Linux-lightgrey?style=for-the-badge)

SyncKit is a comprehensive synchronization suite that provides automated synchronization solutions for different aspects of your development and work environment. It consists of two main subprojects designed to work together for complete environment management.

## 🎯 Subprojects

### 🔄 DataSync - File & Data Synchronization
**Status**: ✅ **Production Ready**  
**Location**: [`./dataSync/`](./dataSync/)

Automated bidirectional file synchronization between WSL (Windows Subsystem for Linux) and OneDrive, enabling seamless data management across Windows and Linux environments.

**Key Features:**
- Bidirectional WSL ↔ OneDrive synchronization
- Smart change detection and conflict resolution
- Automated scheduling with cron integration
- Zone Identifier handling for Windows files
- Professional Linux filesystem installation

[📖 DataSync Documentation](./dataSync/README.md)

### 📦 AppSync - Application Synchronization
**Status**: 🚧 **Under Development**  
**Location**: [`./appSync/`](./appSync/)

Cross-platform application synchronization that maintains consistent development environments by synchronizing installed applications, configurations, and package lists across multiple workstations.

**Planned Features:**
- Multi-platform package manager support (apt, chocolatey, winget, homebrew)
- Application configuration synchronization
- Development environment setup automation
- Team environment standardization

[📖 AppSync Documentation](./appSync/README.md)

## 🏗️ Architecture

```
SyncKit/
├── dataSync/                   # File & Data Sync (Production)
│   ├── scripts/               # DataSync executable scripts
│   ├── docs/                  # DataSync documentation
│   └── config/                # DataSync configuration templates
├── appSync/                    # Application Sync (Development)
│   ├── scripts/               # AppSync executable scripts (planned)
│   ├── docs/                  # AppSync documentation
│   └── config/                # AppSync configuration templates
├── README.md                   # This file - main project overview
├── LICENSE                     # MIT License
├── PRD.md                      # Product Requirements Document
└── ARCHITECTURE.md             # Overall architecture documentation
```

## 🚀 Quick Start

### DataSync (Ready to Use)
```bash
# Navigate to DataSync
cd dataSync/

# Install DataSync system-wide
./scripts/install-wsl-sync.sh

# Configure your sync paths
# Edit ~/.config/wsl-sync/config

# Start syncing (or wait for automatic cron sync)
wsl-smart-sync
```

### AppSync (Coming Soon)
```bash
# Navigate to AppSync
cd appSync/

# Review planned features and architecture
cat README.md

# Check development status
ls -la scripts/  # Currently empty - under development
```

## 💡 Use Cases

### Individual Developer
- **DataSync**: Keep project files synchronized between WSL and OneDrive for backup and cross-device access
- **AppSync**: Maintain consistent development tools across multiple workstations

### Development Teams
- **DataSync**: Share project configurations and ensure team members have synchronized project data
- **AppSync**: Standardize development environments across the team

### IT Administration
- **DataSync**: Automate backup and synchronization of critical development data
- **AppSync**: Deploy and maintain consistent application stacks across multiple workstations

## 🔧 Current Installation Status

DataSync is currently installed and configured on this system:

**✅ Active Components:**
- DataSync scripts installed in `~/.local/bin/`
- Configuration in `~/.config/wsl-sync/`
- Automated sync via cron every 10 minutes
- WSL projects syncing to OneDrive Business

**🚧 Development Components:**
- AppSync architecture and planning complete
- Implementation in progress

## 📊 Project Status

| Component | Status | Version | Description |
|-----------|--------|---------|-------------|
| **DataSync** | ✅ Production | v2.0 | WSL-OneDrive file synchronization |
| **AppSync** | 🚧 Development | v0.1-alpha | Application synchronization |
| **Documentation** | ✅ Complete | v2.0 | Comprehensive docs for both projects |
| **Testing** | ✅ Complete | v2.0 | DataSync fully tested and deployed |

## 🤝 Contributing

SyncKit is actively developed and maintained. Contributions are welcome!

### DataSync
DataSync is production-ready but welcomes improvements and bug fixes.

### AppSync  
AppSync is in active development. Design input, feature requests, and implementation help are especially welcome.

### Development Guidelines
- Follow existing code style and patterns
- Update documentation for any changes
- Test thoroughly before submitting changes
- Use conventional commit messages

## 📄 Documentation

- **[DataSync README](./dataSync/README.md)** - Complete DataSync documentation
- **[AppSync README](./appSync/README.md)** - AppSync architecture and planning
- **[Architecture Overview](./ARCHITECTURE.md)** - Overall system architecture
- **[Product Requirements](./PRD.md)** - Detailed product requirements

## 🔗 Integration

DataSync and AppSync are designed to work together:

- **DataSync** handles your files, projects, and data
- **AppSync** handles your applications, tools, and configurations
- Together they provide complete workstation environment synchronization

## 📝 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🏷️ Version History

- **v2.0** - Subproject organization, DataSync production ready, AppSync planning
- **v1.0** - Initial DataSync implementation and deployment

---

**SyncKit** - *Synchronize Everything, Seamlessly* 🔄