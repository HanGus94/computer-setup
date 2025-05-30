#Requires -Version 7.0
#Requires -RunAsAdministrator

<#
.SYNOPSIS
    Windows Features Enablement Script

.DESCRIPTION
    Enables advanced Windows features including:
    - Hyper-V (with management tools and PowerShell module)
    - Windows Sandbox
    - WSL2 (Windows Subsystem for Linux 2)
    - Required supporting features and dependencies

.PARAMETER Force
    Force enabling features even if they appear to be already enabled

.PARAMETER SkipHyperV
    Skip Hyper-V feature enablement

.PARAMETER SkipWindowsSandbox
    Skip Windows Sandbox feature enablement

.PARAMETER SkipWSL2
    Skip WSL2 feature enablement

.PARAMETER NoReboot
    Don't prompt for reboot even if features require it

.EXAMPLE
    .\Enable-WindowsFeatures.ps1
    
.EXAMPLE
    .\Enable-WindowsFeatures.ps1 -Force
    
.EXAMPLE
    .\Enable-WindowsFeatures.ps1 -SkipHyperV
    
.EXAMPLE
    .\Enable-WindowsFeatures.ps1 -NoReboot
#>

param(
    [Parameter(Mandatory = $false)]
    [switch]$Force,
    
    [Parameter(Mandatory = $false)]
    [switch]$SkipHyperV,
    
    [Parameter(Mandatory = $false)]
    [switch]$SkipWindowsSandbox,
    
    [Parameter(Mandatory = $false)]
    [switch]$SkipWSL2,
    
    [Parameter(Mandatory = $false)]
    [switch]$NoReboot
)

# Import the shared module
Import-Module (Join-Path (Split-Path -Parent $PSScriptRoot) "modules\ComputerSetup.psm1") -Force

# Feature configurations
$FeatureConfigurations = @{
    HyperV = @{
        Name = "Hyper-V"
        Description = "Windows Hyper-V hypervisor platform with management tools"
        Features = @(
            "Microsoft-Hyper-V-All",
            "Microsoft-Hyper-V",
            "Microsoft-Hyper-V-Tools-All",
            "Microsoft-Hyper-V-Management-PowerShell",
            "Microsoft-Hyper-V-Hypervisor",
            "Microsoft-Hyper-V-Services",
            "Microsoft-Hyper-V-Management-Clients"
        )
        Dependencies = @("VirtualMachinePlatform")
        RequiresReboot = $true
        Essential = $true
    }
    WindowsSandbox = @{
        Name = "Windows Sandbox"
        Description = "Lightweight desktop environment for safely running applications in isolation"
        Features = @("Containers-DisposableClientVM")
        Dependencies = @("VirtualMachinePlatform")
        RequiresReboot = $true
        Essential = $false
    }
    WSL2 = @{
        Name = "Windows Subsystem for Linux 2"
        Description = "Full Linux kernel compatibility layer for Windows"
        Features = @(
            "Microsoft-Windows-Subsystem-Linux",
            "VirtualMachinePlatform"
        )
        Dependencies = @()
        RequiresReboot = $true
        Essential = $true
    }
}

function Test-FeatureEnabled {
    param([string]$FeatureName)
    
    try {
        $feature = Get-WindowsOptionalFeature -Online -FeatureName $FeatureName -ErrorAction SilentlyContinue
        return $feature -and $feature.State -eq "Enabled"
    }
    catch {
        return $false
    }
}

function Test-VirtualizationSupported {
    try {
        # Check if virtualization is supported in hardware
        $cpu = Get-WmiObject -Class Win32_Processor
        $virtualizationSupported = $cpu.VirtualizationFirmwareEnabled -or $cpu.VMMonitorModeExtensions
        
        if (-not $virtualizationSupported) {
            Write-StatusMessage "Hardware virtualization support not detected" "Warning"
            Write-StatusMessage "Please enable virtualization in your BIOS/UEFI settings" "Warning"
            return $false
        }
        
        return $true
    }
    catch {
        Write-StatusMessage "Could not determine virtualization support" "Warning"
        return $true  # Assume it's supported and let Windows handle the error
    }
}

function Enable-WindowsFeature {
    param(
        [string]$FeatureName,
        [string]$Description = $FeatureName
    )
    
    try {
        Write-StatusMessage "Enabling feature: $FeatureName" "Info"
        
        # Check if already enabled (unless Force is specified)
        if (-not $Force) {
            if (Test-FeatureEnabled -FeatureName $FeatureName) {
                Write-StatusMessage "Feature $FeatureName is already enabled" "Success"
                return $true
            }
        }
        
        # Enable the feature
        $result = Enable-WindowsOptionalFeature -Online -FeatureName $FeatureName -All -NoRestart
        
        if ($result.RestartNeeded) {
            Write-StatusMessage "Feature $FeatureName enabled (restart required)" "Success"
            return "RestartRequired"
        } else {
            Write-StatusMessage "Feature $FeatureName enabled successfully" "Success"
            return $true
        }
        
    }
    catch {
        Write-StatusMessage "Failed to enable feature $FeatureName`: $($_.Exception.Message)" "Error"
        return $false
    }
}

function Enable-FeatureSet {
    param(
        [string]$SetName,
        [hashtable]$FeatureConfig
    )
    
    Write-SectionHeader $FeatureConfig.Name
    Write-Host $FeatureConfig.Description -ForegroundColor Gray
    Write-Host ""
    
    $requiresReboot = $false
    $allSuccessful = $true
    $featuresEnabled = 0
    
    # Enable dependencies first
    if ($FeatureConfig.Dependencies -and $FeatureConfig.Dependencies.Count -gt 0) {
        Write-StatusMessage "Enabling dependencies..." "Info"
        foreach ($dependency in $FeatureConfig.Dependencies) {
            $result = Enable-WindowsFeature -FeatureName $dependency -Description "Dependency: $dependency"
            if ($result -eq "RestartRequired") {
                $requiresReboot = $true
                $featuresEnabled++
            } elseif ($result -eq $true) {
                $featuresEnabled++
            } else {
                $allSuccessful = $false
            }
        }
    }
    
    # Enable main features
    foreach ($feature in $FeatureConfig.Features) {
        $result = Enable-WindowsFeature -FeatureName $feature -Description $feature
        if ($result -eq "RestartRequired") {
            $requiresReboot = $true
            $featuresEnabled++
        } elseif ($result -eq $true) {
            $featuresEnabled++
        } else {
            $allSuccessful = $false
        }
    }
    
    Write-Host ""
    if ($featuresEnabled -gt 0) {
        Write-StatusMessage "Enabled $featuresEnabled feature(s) for $($FeatureConfig.Name)" "Success"
    }
    
    return @{
        Success = $allSuccessful
        RequiresReboot = $requiresReboot
        FeaturesEnabled = $featuresEnabled
    }
}

function Test-WindowsEditionSupport {
    try {
        $edition = (Get-WindowsEdition -Online).Edition
        
        # Windows Sandbox requires Pro, Enterprise, or Education
        $sandboxSupportedEditions = @("Professional", "Enterprise", "Education", "ServerStandard", "ServerDatacenter")
        $supportsSandbox = $edition -in $sandboxSupportedEditions
        
        if (-not $supportsSandbox -and -not $SkipWindowsSandbox) {
            Write-StatusMessage "Windows Sandbox requires Windows 10/11 Pro, Enterprise, or Education" "Warning"
            Write-StatusMessage "Current edition: $edition" "Info"
            Write-StatusMessage "Windows Sandbox will be skipped" "Warning"
            return @{ SupportsSandbox = $false; Edition = $edition }
        }
        
        return @{ SupportsSandbox = $supportsSandbox; Edition = $edition }
    }
    catch {
        Write-StatusMessage "Could not determine Windows edition" "Warning"
        return @{ SupportsSandbox = $true; Edition = "Unknown" }
    }
}

# Main execution
function Main {
    Write-Host "Windows Features Enablement" -ForegroundColor Cyan
    Write-Host "===========================" -ForegroundColor Cyan
    Write-Host "PowerShell Version: $($PSVersionTable.PSVersion)" -ForegroundColor Gray
    Write-Host ""
    
    # Verify we're running as administrator
    if (-not (Test-IsElevated)) {
        Write-StatusMessage "This script requires administrator privileges" "Error"
        Write-StatusMessage "Please run PowerShell as Administrator and try again" "Error"
        exit 1
    }
    
    # Check hardware virtualization support
    if (-not (Test-VirtualizationSupported)) {
        Write-StatusMessage "Virtualization features may not work without hardware support" "Warning"
        Write-Host ""
    }
    
    # Check Windows edition support
    $editionInfo = Test-WindowsEditionSupport
    Write-StatusMessage "Windows Edition: $($editionInfo.Edition)" "Info"
    Write-Host ""
    
    # Determine which features to enable
    $featuresToEnable = @()
    
    if (-not $SkipHyperV) {
        $featuresToEnable += @{ Name = "HyperV"; Config = $FeatureConfigurations.HyperV }
    }
    
    if (-not $SkipWindowsSandbox -and $editionInfo.SupportsSandbox) {
        $featuresToEnable += @{ Name = "WindowsSandbox"; Config = $FeatureConfigurations.WindowsSandbox }
    }
    
    if (-not $SkipWSL2) {
        $featuresToEnable += @{ Name = "WSL2"; Config = $FeatureConfigurations.WSL2 }
    }
    
    if ($featuresToEnable.Count -eq 0) {
        Write-StatusMessage "No features selected for enablement" "Warning"
        return
    }
    
    # Show what will be enabled
    Write-Host "🔧 Features to Enable" -ForegroundColor Cyan
    Write-Host "====================" -ForegroundColor Cyan
    foreach ($feature in $featuresToEnable) {
        $essentialText = if ($feature.Config.Essential) { " (Essential)" } else { "" }
        Write-Host "  • $($feature.Config.Name)$essentialText" -ForegroundColor Gray
        Write-Host "    $($feature.Config.Description)" -ForegroundColor DarkGray
        Write-Host "    Features: $($feature.Config.Features -join ', ')" -ForegroundColor Magenta
        if ($feature.Config.Dependencies -and $feature.Config.Dependencies.Count -gt 0) {
            Write-Host "    Dependencies: $($feature.Config.Dependencies -join ', ')" -ForegroundColor Yellow
        }
    }
    Write-Host ""
    
    # Enable features
    $totalFeaturesEnabled = 0
    $anyRequiresReboot = $false
    $allSuccessful = $true
    $failedFeatures = @()
    
    foreach ($feature in $featuresToEnable) {
        $result = Enable-FeatureSet -SetName $feature.Name -FeatureConfig $feature.Config
        
        $totalFeaturesEnabled += $result.FeaturesEnabled
        
        if ($result.RequiresReboot) {
            $anyRequiresReboot = $true
        }
        
        if (-not $result.Success) {
            $allSuccessful = $false
            $failedFeatures += $feature.Config.Name
        }
    }
    
    # Summary
    Write-Host "`n" -NoNewline
    Write-Host "🪟 Windows Features Summary" -ForegroundColor Cyan
    Write-Host "===========================" -ForegroundColor Cyan
    
    if ($totalFeaturesEnabled -gt 0) {
        Write-StatusMessage "Successfully enabled $totalFeaturesEnabled Windows feature(s)" "Success"
    }
    
    if ($failedFeatures.Count -gt 0) {
        Write-StatusMessage "Failed to enable some features:" "Error"
        foreach ($failedFeature in $failedFeatures) {
            Write-Host "  • $failedFeature" -ForegroundColor Red
        }
        Write-Host ""
    }
    
    # Handle reboot requirement
    if ($anyRequiresReboot) {
        Write-Host ""
        Write-StatusMessage "⚠️ REBOOT REQUIRED" "Warning"
        Write-StatusMessage "Some features require a system restart to complete installation" "Warning"
        
        if (-not $NoReboot) {
            Write-Host ""
            $response = Read-Host "Would you like to restart now? (y/N)"
            if ($response -match '^[Yy]') {
                Write-StatusMessage "Restarting system..." "Info"
                Restart-Computer -Force
            } else {
                Write-StatusMessage "Please restart your computer manually to complete feature installation" "Warning"
            }
        } else {
            Write-StatusMessage "NoReboot flag specified - please restart manually to complete installation" "Info"
        }
    }
    
    if ($allSuccessful -and $totalFeaturesEnabled -gt 0) {
        Write-Host ""
        Write-StatusMessage "🎉 Windows features enabled successfully!" "Success"
        
        if (-not $anyRequiresReboot) {
            Write-StatusMessage "All features are ready to use" "Info"
        }
        
        # Additional post-installation notes
        Write-Host ""
        Write-StatusMessage "📋 Post-Installation Notes:" "Info"
        
        if (-not $SkipHyperV) {
            Write-Host "  • Hyper-V Manager is available in Administrative Tools" -ForegroundColor Gray
            Write-Host "  • Use 'Get-VM' PowerShell cmdlet to manage virtual machines" -ForegroundColor Gray
        }
        
        if (-not $SkipWindowsSandbox -and $editionInfo.SupportsSandbox) {
            Write-Host "  • Windows Sandbox is available in Start Menu" -ForegroundColor Gray
            Write-Host "  • Each sandbox session starts clean and isolated" -ForegroundColor Gray
        }
        
        if (-not $SkipWSL2) {
            Write-Host "  • Install Linux distributions from Microsoft Store" -ForegroundColor Gray
            Write-Host "  • Use 'wsl --install -d <distribution>' to install specific distros" -ForegroundColor Gray
            Write-Host "  • Configure WSL2 as default: 'wsl --set-default-version 2'" -ForegroundColor Gray
        }
    }
}

# Run the main function
Main 