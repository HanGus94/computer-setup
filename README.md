# Computer Setup Scripts

Automated deployment scripts for setting up a new computer with customized configurations.

## 🚀 Quick Start

**One-Command Setup** - Run this for complete automation:
```powershell
.\setup.ps1
```

This single command will automatically:
1. Install PowerShell 7+ if missing
2. Install system dependencies (Visual C++ redistributables)
3. Install common applications via Winget (Firefox, Cursor AI, Steam, etc.)
4. Deploy PowerShell profiles
5. Set up Firefox customizations (after Firefox is installed)
6. Install OBS Studio with multiple profiles

**That's it!** No manual intervention required - just run `setup.ps1` and everything else happens automatically.

## 📁 Script Overview

### **`setup.ps1`** - Bootstrap Script
- Checks for PowerShell 7+ and installs if missing
- Launches the main deployment script
- Works with Windows PowerShell 5.1+

### **`deploy-files.ps1`** - Main Deployment Engine
- Handles version checking and smart deployment
- Supports multiple file types and script execution
- Creates backups and provides detailed instructions

### **`Install-Dependencies.ps1`** - System Dependencies
- Installs Microsoft Visual C++ 2015-2022 redistributables (x64 + x86)
- Required for OBS Studio and most plugins
- Idempotent - safe to run multiple times
- Checks admin privileges and existing installations

```powershell
# Run dependencies separately if needed
.\Install-Dependencies.ps1

# Force reinstall dependencies
.\Install-Dependencies.ps1 -Force

# Skip Visual C++ installation
.\Install-Dependencies.ps1 -SkipVCRedist
```

### **`Install-Applications.ps1`** - Application Installer
- Installs common applications using Windows Package Manager (Winget)
- Automatically installs Winget if missing
- Configurable application categories (browsers, development, media, utilities)
- Idempotent - detects existing installations

```powershell
# Install all default applications
.\Install-Applications.ps1

# Install only essential applications (Firefox + 7-Zip)
.\Install-Applications.ps1 -OnlyEssential

# Skip specific categories
.\Install-Applications.ps1 -SkipDevelopment -SkipMedia

# Install custom application list
.\Install-Applications.ps1 -Applications "Mozilla.Firefox","Microsoft.VisualStudioCode"

# Force reinstall all applications
.\Install-Applications.ps1 -Force
```

**Supported Application Categories:**
- **Browsers**: Firefox
- **Development**: Cursor AI, Git, Windows Terminal  
- **Media**: VLC Media Player
- **Gaming**: Steam
- **Utilities**: 7-Zip, Notepad++, PowerToys

### **`obs/setup-obs.ps1`** - OBS Multi-Profile Setup
- Downloads OBS Studio once, installs to multiple profiles
- Manages plugins with version tracking
- Creates desktop shortcuts and start menu entries
- Supports GitHub, direct URL, and OBS Project forum downloads

```powershell
# Install specific profiles
.\obs\setup-obs.ps1 -Profiles streaming,recording

# Use GitHub token to avoid rate limits
.\obs\setup-obs.ps1 -GitHubToken "your_token_here"

# Keep downloaded files for debugging
.\obs\setup-obs.ps1 -KeepFiles
```

## 📂 Directory Structure

```
computer-setup/
├── setup.ps1                    # Bootstrap script
├── deploy-files.ps1             # Main deployment engine
├── Install-Dependencies.ps1     # System dependencies installer
├── Install-Applications.ps1     # Application installer via Winget
├── README.md                    # This file
├── powershell/                  # PowerShell profiles
├── firefox/                     # Firefox customizations
│   ├── userChrome.css
│   └── sidebery-data.json
└── obs/                         # OBS Studio setup
    ├── setup-obs.ps1
    ├── obs-profiles.json
    └── obs-profiles-EXAMPLE.json
```

## 🔧 Configuration Files

### **PowerShell Profiles** (`powershell/`)
- Custom PowerShell configurations with version tracking
- Deployed to `Documents\PowerShell\Microsoft.PowerShell_profile.ps1`

### **Firefox Customizations** (`firefox/`)
- **userChrome.css**: Custom Firefox UI styling
- **sidebery-data.json**: Tree-style tabs configuration

### **OBS Profiles** (`obs/obs-profiles.json`)
- Multi-profile OBS Studio configurations
- Plugin management with version tracking
- See `obs-profiles-EXAMPLE.json` for all download methods

## 🎯 Plugin Download Methods

The OBS setup supports three plugin download methods:

### 1. **GitHub Releases** (Recommended)
```json
{
  "downloadMethod": "github",
  "repo": "exeldro/obs-source-dock",
  "filePattern": "*.zip"
}
```

### 2. **Direct URL**
```json
{
  "downloadMethod": "direct",
  "url": "https://example.com/plugin.zip",
  "filename": "plugin.zip"
}
```

### 3. **OBS Project Forum**
```json
{
  "downloadMethod": "obsproject",
  "resourceId": "913",
  "version": "6257",
  "fileId": "113467",
  "filename": "move.zip"
}
```

## ⚡ Performance Features

- **Smart Version Checking**: Only deploys newer versions
- **Shared Downloads**: OBS downloaded once for all profiles
- **Idempotent Operations**: Safe to run multiple times
- **Backup Creation**: Existing files are backed up automatically
- **Plugin Caching**: Downloaded plugins cached per profile

## 🔐 Security Considerations

- Scripts check for PowerShell 7+ requirements
- Dependencies installer warns if not running as administrator
- All downloads use HTTPS with verification
- GitHub token support for authenticated API access

## 📋 Common Usage Patterns

### Fresh Computer Setup
```powershell
# Complete setup (recommended)
.\setup.ps1
```

### Updating Existing Setup
```powershell
# Update everything
.\deploy-files.ps1

# Force update everything
.\deploy-files.ps1 -Force

# Update only OBS profiles
.\obs\setup-obs.ps1

# Install new dependencies
.\Install-Dependencies.ps1

# Install applications only
.\Install-Applications.ps1
```

### Development/Testing
```powershell
# Test with debug mode
.\obs\setup-obs.ps1 -KeepFiles

# Install single profile
.\obs\setup-obs.ps1 -Profiles testing

# Skip dependencies
.\Install-Dependencies.ps1 -SkipVCRedist

# Install only essential applications
.\Install-Applications.ps1 -OnlyEssential

# Skip certain application categories
.\Install-Applications.ps1 -SkipDevelopment -SkipMedia
```

## 🛠️ Requirements

- **Windows 10/11**
- **PowerShell 5.1+** (script auto-upgrades to PowerShell 7+)
- **Internet connection** for downloads
- **Administrator privileges** recommended for dependencies

## 🤝 Contributing

Feel free to customize the configuration files and scripts for your specific needs. The system is designed to be modular and extensible.
