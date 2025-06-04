# Windows Computer Setup with Ansible

Automated Windows computer setup using Ansible for software installation, configuration deployment, and system feature management. This project provides a comprehensive solution for setting up Windows workstations with Chocolatey packages, Scoop packages, Windows features, and custom configurations.

## 🚀 Features

- **Package Management**: Chocolatey for primary software installation + Scoop for CLI tools
- **Windows Features**: Automated enabling of Hyper-V, WSL2, Windows Sandbox
- **Power Management**: Automatic configuration of Windows power plans including Ultimate Performance
- **Configuration Deployment**: PowerShell profiles, OBS settings, Firefox configurations
- **Smart Rebooting**: Automatic reboots when needed with intelligent polling
- **SSH-based**: Secure SSH connection with proper privilege separation
- **Error Handling**: Continues on package failures with detailed reporting

## 📋 Prerequisites

### Ansible Controller (Linux)
```bash
# Install required Python packages
pip install -r ansible-controller-requirements.txt

# Verify Ansible collections
ansible-galaxy collection list | grep -E "(chocolatey|ansible.windows|community.windows)"
```

### Windows Target Machine
1. **Run the SSH setup script as Administrator**:
   ```powershell
   # On Windows target machine
   .\setup-remoting.ps1
   ```
   This script configures OpenSSH Server for Ansible connectivity.

2. **Supported Windows Versions**:
   - Windows 10 version 1809 (build 17763) or later
   - Windows 11 (all versions)
   - Windows Server 2019 or later

## 🏗️ Architecture

### SSH Connection Model
- **Default**: Run as regular user (better security)
- **Selective elevation**: Use `become: yes` only for tasks requiring admin rights
- **Natural privilege separation**: Scoop installs as user, system features as admin

### Role Structure
```
ansible/
├── playbooks/
│   └── site.yml                 # Main orchestration playbook
├── roles/
│   ├── chocolatey/             # System-wide package installation
│   ├── scoop/                  # User-level CLI packages  
│   ├── windows_features/       # Windows optional features
│   ├── power_management/       # Windows power plan management
│   ├── powershell_config/      # PowerShell profile deployment
│   │   └── files/              # PowerShell configuration files
│   ├── obs_config/            # OBS Studio configuration
│   └── firefox_config/        # Firefox settings deployment
│       └── files/              # Firefox configuration files
├── inventory/
│   └── hosts.yml              # SSH connection configuration
└── group_vars/
    └── all.yml               # Global variables and package lists
setup-remoting.ps1              # Windows SSH setup script
```

## ⚙️ Configuration

### 1. Update Inventory
Edit `ansible/inventory/hosts.yml`:
```yaml
target-windows:
  ansible_host: YOUR_WINDOWS_IP
  ansible_user: YOUR_USERNAME
  ansible_password: YOUR_PASSWORD
  ansible_connection: ssh
  ansible_shell_type: powershell
```

### 2. Customize Package Lists
Edit `ansible/group_vars/all.yml` to modify:
- Chocolatey packages (essential, development, media, gaming, utilities)
- Scoop packages (CLI tools)
- Windows features to enable
- Power management settings (Ultimate Performance, High Performance, etc.)
- Configuration paths

### 3. Role-specific Variables
Each role has its own `defaults/main.yml` with package definitions and settings.

## 🎯 Usage

### Quick Start
```bash
cd ansible

# Test connection
ansible target-windows -i inventory/hosts.yml -m ping

# Run complete setup
ansible-playbook -i inventory/hosts.yml playbooks/site.yml
```

### Selective Installation
```bash
# Only software packages
ansible-playbook -i inventory/hosts.yml playbooks/site.yml --tags software

# Only Chocolatey packages
ansible-playbook -i inventory/hosts.yml playbooks/site.yml --tags chocolatey

# Only Windows features
ansible-playbook -i inventory/hosts.yml playbooks/site.yml --tags features

# Only power management
ansible-playbook -i inventory/hosts.yml playbooks/site.yml --tags power

# Skip reboots
ansible-playbook -i inventory/hosts.yml playbooks/site.yml --skip-tags reboot
```

### OBS Plugin Management
```bash
# Check plugin status for all profiles
ansible-playbook -i inventory/hosts.yml playbooks/obs-plugins.yml --tags status

# Repair/reinstall missing plugins
ansible-playbook -i inventory/hosts.yml playbooks/obs-plugins.yml --tags repair

# Install plugins for specific profile
ansible-playbook -i inventory/hosts.yml playbooks/obs-plugins.yml --tags install_profile -e target_profile=Streaming

# Run OBS plugin repair from main playbook
ansible-playbook -i inventory/hosts.yml playbooks/site.yml --tags obs_repair

# Install only OBS software (without plugins)
ansible-playbook -i inventory/hosts.yml playbooks/site.yml --tags obs
```

## 📦 Package Categories

### Chocolatey Packages
- **Essential**: Firefox, 7zip
- **Development**: Cursor, Git, Windows Terminal, Docker Desktop
- **Media**: VLC, Spotify
- **Gaming**: Steam, Epic Games, GOG Galaxy, Battle.net
- **Utilities**: PowerToys, Discord, Google Drive, Flameshot, MobaXterm

### Scoop Packages
- **CLI Tools**: fzf, psfzf, spotify-player

### Windows Features
- **Hyper-V**: Complete virtualization platform
- **WSL2**: Windows Subsystem for Linux
- **Windows Sandbox**: Isolated desktop environment

### Power Management
- **Ultimate Performance**: Maximum performance with disabled CPU frequency scaling and core parking
- **High Performance**: High performance mode with reduced power saving features  
- **Balanced**: Automatic balance between performance and power consumption (default)
- **Power Saver**: Maximum power savings with reduced performance for mobile devices

## 🔧 Advanced Configuration

### SSH Key Authentication
```powershell
# Generate SSH keys during setup
.\setup-remoting.ps1 -EnableKeyAuth

# Use key-based auth in inventory
ansible_ssh_private_key_file: ~/.ssh/id_rsa
```

### Custom Package Lists
Add packages to role defaults:
```yaml
# roles/chocolatey/defaults/main.yml
chocolatey:
  packages:
    utilities:
      - name: "your-package"
        description: "Your custom package"
```

### Environment-specific Variables
```yaml
# group_vars/production.yml
reboot:
  auto_reboot: false  # Manual reboots in production

error_handling:
  continue_on_package_failure: false  # Strict mode

# Power management for workstations
power_management:
  power_plan: "ultimate_performance"  # Maximum performance
  enable_ultimate_performance: true
  force_set: true
```

## 🚨 Troubleshooting

### SSH Connection Issues
```bash
# Test SSH directly
ssh username@windows-ip

# Check SSH service on Windows
Get-Service sshd
```

### Package Installation Failures
```bash
# Run with maximum verbosity
ansible-playbook -i inventory/hosts.yml playbooks/site.yml -vvv

# Check specific package availability
ansible target-windows -m win_shell -a "choco search package-name"
```

### Privilege Issues
```bash
# Verify user can elevate
ansible target-windows -m win_shell -a "whoami" --become
```

## 🔄 Migration from PowerShell

This project replaces a PowerShell-based setup with Ansible for:
- **Better remote management**: SSH vs local execution
- **Idempotency**: Only changes what needs changing
- **Error handling**: Robust failure management
- **Scalability**: Manage multiple machines
- **Version control**: Infrastructure as code

## 📝 Contributing

1. Test changes with `--check` mode first
2. Update role documentation for new packages
3. Verify SSH functionality with test connections
4. Follow Ansible best practices for variable naming

## 📄 License

MIT License - see LICENSE file for details.

---

**Note**: This setup uses SSH instead of WinRM for better security and privilege separation. Scoop packages install naturally as regular user, while system changes use selective privilege escalation.
