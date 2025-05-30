# Computer Setup Automation

This repository contains PowerShell scripts to automate the setup of a new Windows computer with development tools, configurations, and Windows features.

## Features

### 🔧 System Setup
- **Windows Features**: Enable Hyper-V, Windows Sandbox, and WSL2 with all management tools
- **System Dependencies**: Install Visual C++ redistributables and runtime libraries
- **Applications**: Install essential applications via Windows Package Manager (Winget)
- **Specialized Tools**: Install tools from GitHub releases (Wabbajack, etc.)

### ⚙️ Configuration Deployment
- **PowerShell Profile**: Enhanced profile with useful aliases and functions
- **Firefox userChrome.css**: Custom Firefox interface modifications  
- **Sidebery**: Firefox sidebar tab management configuration
- **OBS Studio**: Multi-profile portable OBS installations with plugins

## Quick Start

1. **Run the main deployment script** (requires PowerShell 7+):
   ```powershell
   .\deploy-files.ps1
   ```

2. **Or run individual components**:
   ```powershell
   # Enable Windows features (requires admin)
   .\installers\Enable-WindowsFeatures.ps1
   
   # Install system dependencies
   .\installers\Install-Dependencies.ps1
   
   # Install applications
   .\installers\Install-Applications.ps1
   
   # Install specialized tools
   .\installers\Install-Tools.ps1
   ```

## Scripts Overview

### Core Deployment
- **`setup.ps1`**: Bootstrap script that installs PowerShell 7+ if needed
- **`deploy-files.ps1`**: Main orchestrator that runs all deployment stages

### Windows Features (`installers/Enable-WindowsFeatures.ps1`)
Enables advanced Windows features with all sub-components:
- **Hyper-V**: Full hypervisor platform with management tools and PowerShell module
- **Windows Sandbox**: Isolated environment for testing applications
- **WSL2**: Windows Subsystem for Linux with full kernel support

**Requirements**: Administrator privileges, compatible Windows edition
**Features**: Hardware virtualization detection, edition compatibility checking, reboot handling

### System Dependencies (`installers/Install-Dependencies.ps1`)
Installs required runtime libraries:
- Microsoft Visual C++ 2015-2022 Redistributables (x64 & x86)
- Future: Additional runtime libraries as needed

### Applications (`installers/Install-Applications.ps1`)
Installs applications via package managers:
- Primary: Windows Package Manager (Winget)
- Fallback: Scoop package manager
- Configurable application list

### Specialized Tools (`installers/Install-Tools.ps1`)
Downloads and installs tools from GitHub releases:
- Wabbajack modding tool
- Creates desktop and Start Menu shortcuts
- Portable installations to C:\Tools

### Configuration Files
- **`configs/powershell/`**: PowerShell profile with enhanced features
- **`configs/firefox/`**: userChrome.css and Sidebery configuration
- **`configs/obs/`**: OBS Studio portable setup with multiple profiles

## Architecture

### Shared Module (`modules/ComputerSetup.psm1`)
Provides common functionality across all scripts:
- Consistent status messaging and logging
- File download and GitHub API interactions
- Version comparison and file backup utilities
- Package manager detection and testing
- Admin privilege detection

### Design Principles
- **Modular**: Each script handles a specific concern
- **Consistent**: Shared module ensures uniform behavior
- **Robust**: Comprehensive error handling and validation
- **Flexible**: Skip flags and configuration options
- **Informative**: Detailed status messages and summaries

## Usage Examples

### Basic Setup
```powershell
# Run complete setup
.\deploy-files.ps1

# Run with force flag to reinstall everything
.\deploy-files.ps1 -Force
```

### Individual Components
```powershell
# Enable Windows features only
.\installers\Enable-WindowsFeatures.ps1

# Skip specific features
.\installers\Enable-WindowsFeatures.ps1 -SkipHyperV -SkipWindowsSandbox

# Install tools to custom directory
.\installers\Install-Tools.ps1 -ToolsDirectory "D:\MyTools"

# Skip specific OBS profiles
.\configs\obs\setup-obs.ps1 -SkipTesting -SkipRecording
```

## Requirements

- **PowerShell 7.0+** (setup.ps1 can install this automatically)
- **Windows 10/11** (some features require specific editions)
- **Administrator privileges** (for Windows features and some installations)
- **Internet connection** (for downloading components)

## Post-Installation

### Windows Features
After enabling Windows features, a reboot may be required. Once complete:
- **Hyper-V Manager**: Available in Administrative Tools
- **Windows Sandbox**: Available in Start Menu  
- **WSL2**: Install distributions from Microsoft Store or via `wsl --install`

### Development Environment
- PowerShell profile loads automatically in new sessions
- Firefox with custom interface and Sidebery tab management
- OBS Studio with optimized profiles for different use cases
- Specialized tools available via desktop shortcuts

## Troubleshooting

### Common Issues
- **PowerShell version**: Use setup.ps1 to install PowerShell 7+
- **Execution policy**: Run `Set-ExecutionPolicy RemoteSigned` as administrator
- **Windows features fail**: Check hardware virtualization support in BIOS
- **Downloads fail**: Check internet connection and firewall settings

### Logs and Status
All scripts provide detailed status messages during execution:
- 🟢 **[OK]**: Successful operations
- 🔵 **[INFO]**: Informational messages  
- 🟡 **[WARN]**: Warnings (non-critical)
- 🔴 **[ERROR]**: Critical errors

## Contributing

This automation system is designed for personal use but can be adapted:
1. Modify configuration files in `configs/` directories
2. Update application lists in installer scripts
3. Add new tools to `Install-Tools.ps1` configuration
4. Extend shared module functionality as needed
