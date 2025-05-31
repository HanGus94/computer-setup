# Windows Computer Setup - Ansible Edition

This directory contains the Ansible automation for setting up Windows computers with software, features, and configurations.

## Prerequisites

### Ansible Controller Requirements
- Ansible 2.9+ with Windows support
- Python 3.6+
- Required Ansible collections (see requirements.yml)

### Target Windows Machine Requirements
- Windows 10/11 or Windows Server 2016+
- PowerShell 5.1+ (PowerShell 7+ recommended)
- WinRM configured and enabled
- Network connectivity between Ansible controller and target

## Quick Start

### 1. Install Required Collections
```bash
ansible-galaxy collection install -r requirements.yml
```

### 2. Configure Inventory
Edit `inventory/hosts.yml` and replace the placeholder values:
- `REPLACE_WITH_YOUR_WINDOWS_IP` - Target Windows machine IP
- `REPLACE_WITH_USERNAME` - Windows username
- `vault_windows_password` - Windows password (use ansible-vault)

### 3. Create Vault for Passwords
```bash
ansible-vault create group_vars/vault.yml
```
Add your Windows password:
```yaml
vault_windows_password: "your_windows_password_here"
```

### 4. Run the Complete Setup
```bash
ansible-playbook -i inventory/hosts.yml playbooks/site.yml --ask-vault-pass
```

## Selective Installation

You can run specific parts of the setup using tags:

### Software Only
```bash
# All software (Chocolatey + Scoop)
ansible-playbook -i inventory/hosts.yml playbooks/site.yml --tags "software" --ask-vault-pass

# Chocolatey packages only
ansible-playbook -i inventory/hosts.yml playbooks/site.yml --tags "chocolatey" --ask-vault-pass

# Scoop packages only
ansible-playbook -i inventory/hosts.yml playbooks/site.yml --tags "scoop" --ask-vault-pass
```

### Windows Features Only
```bash
ansible-playbook -i inventory/hosts.yml playbooks/site.yml --tags "features" --ask-vault-pass
```

### Configuration Only
```bash
ansible-playbook -i inventory/hosts.yml playbooks/site.yml --tags "config" --ask-vault-pass
```

### Specific Configuration
```bash
# PowerShell only
ansible-playbook -i inventory/hosts.yml playbooks/site.yml --tags "powershell" --ask-vault-pass

# OBS only
ansible-playbook -i inventory/hosts.yml playbooks/site.yml --tags "obs" --ask-vault-pass

# Firefox only
ansible-playbook -i inventory/hosts.yml playbooks/site.yml --tags "firefox" --ask-vault-pass
```

## Configuration

### Software Packages
Edit `group_vars/all.yml` to customize which software packages are installed. You can:
- Enable/disable entire categories (essential, development, media, gaming, utilities)
- Add/remove individual packages
- Modify package descriptions
- Control Scoop package installation

### Windows Features
Configure which Windows features to enable in `group_vars/all.yml`:
- Hyper-V
- Windows Sandbox  
- WSL2

### Configuration Files
The playbook will copy configuration files from:
- `../../configs/powershell/` → PowerShell profile directory
- `../../configs/obs/` → `C:/Tools/`
- `../../configs/firefox/` → Firefox profile directory

## Roles

### chocolatey
Installs Chocolatey package manager and all configured software packages.

**Features:**
- Automatic Chocolatey installation
- Categorized package installation
- Error handling with warnings for failed packages
- Installation summary reporting

### scoop
Installs Scoop package manager and Scoop-only packages (fzf, psfzf, spotify-player).

**Features:**
- Automatic Scoop installation
- Essential bucket setup (extras, versions)
- Scoop-only package installation
- Error handling with warnings for failed packages
- Installation summary reporting

### windows_features
Enables Windows optional features using native Ansible modules.

**Features:**
- Hardware virtualization detection
- Hyper-V feature enablement
- Windows Sandbox enablement
- WSL2 feature enablement
- Reboot detection and management

### powershell_config
Deploys PowerShell configuration files to the correct Windows locations.

**Features:**
- Automatic PowerShell directory detection
- Profile file deployment
- Backup of existing configurations
- Support for additional configuration files

### obs_config
Deploys OBS Studio configuration files and directories.

**Features:**
- Tools directory creation
- Configuration directory copying
- Individual file deployment
- Backup support

### firefox_config
Deploys Firefox configuration files to user profiles.

**Features:**
- Firefox profile detection
- Default profile creation if needed
- Configuration file deployment
- Backup support

## Package Managers

### Chocolatey (Primary)
Used for most Windows software packages including:
- Browsers (Firefox)
- Development tools (Cursor, Git, Docker)
- Media applications (VLC)
- Gaming platforms (Steam, Epic, GOG, Battle.net)
- Utilities (PowerToys, Discord, etc.)

### Scoop (Supplementary)
Used only for packages not available in Chocolatey:
- `fzf` - Fuzzy file finder
- `psfzf` - PowerShell wrapper for fzf
- `spotify-player` - Spotify terminal player

## Error Handling

The playbook is configured to:
- Continue on software package failures (with warnings)
- Stop on Windows feature failures
- Provide detailed error reporting
- Create backups before overwriting configurations

## Security Considerations

- Use `ansible-vault` for storing passwords
- Consider using certificate-based WinRM authentication for production
- Review and customize the software package list for your security requirements
- Test in a non-production environment first

## Troubleshooting

### WinRM Connection Issues
1. Verify WinRM is enabled on target machine
2. Check firewall settings
3. Verify credentials and connectivity
4. Test with `ansible windows -m win_ping`

### Package Installation Failures
1. Check Chocolatey package names in `winget-to-chocolatey-mapping.txt`
2. Verify packages exist in Chocolatey community repository
3. For Scoop packages, verify they exist in Scoop buckets
4. Check network connectivity for package downloads

### Configuration Deployment Issues
1. Verify source configuration directories exist
2. Check file permissions on target machine
3. Review Ansible logs for specific error messages

## Migration from PowerShell Scripts

This Ansible setup replaces the PowerShell scripts in the parent directory:
- `setup.ps1` → `ansible-playbook playbooks/site.yml`
- `deploy-files.ps1` → Configuration roles
- `installers/Install-Applications.ps1` → `chocolatey` + `scoop` roles
- `installers/Enable-WindowsFeatures.ps1` → `windows_features` role

The PowerShell scripts will be removed once the Ansible migration is complete. 