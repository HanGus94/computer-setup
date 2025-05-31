#Requires -Version 7.0

<#
.SYNOPSIS
    PowerShell Environment Setup Script

.DESCRIPTION
    Sets up a complete PowerShell environment with:
    - Nerd Fonts (CascadiaCode) for terminal icons and symbols
    - Oh-My-Posh for customizable prompt themes
    - Terminal-Icons for file and folder icons
    - PSReadLine for enhanced command line editing
    - Additional PowerShell modules for productivity

.PARAMETER Force
    Force reinstallation of all components

.PARAMETER SkipFonts
    Skip Nerd Fonts installation

.PARAMETER SkipOhMyPosh
    Skip Oh-My-Posh installation

.PARAMETER SkipModules
    Skip PowerShell module installation

.PARAMETER FontName
    Specify which Nerd Font to install (default: CascadiaCode)

.EXAMPLE
    .\Setup-PowerShell.ps1
    
.EXAMPLE
    .\Setup-PowerShell.ps1 -Force
    
.EXAMPLE
    .\Setup-PowerShell.ps1 -SkipFonts
    
.EXAMPLE
    .\Setup-PowerShell.ps1 -FontName "FiraCode"
#>

param(
    [Parameter(Mandatory = $false)]
    [switch]$Force,
    
    [Parameter(Mandatory = $false)]
    [switch]$SkipFonts,
    
    [Parameter(Mandatory = $false)]
    [switch]$SkipOhMyPosh,
    
    [Parameter(Mandatory = $false)]
    [switch]$SkipModules,
    
    [Parameter(Mandatory = $false)]
    [string]$FontName = "CascadiaCode"
)

# Import the shared module
Import-Module (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) "modules\ComputerSetup.psm1") -Force

# PowerShell components configuration
$PowerShellComponents = @{
    NerdFonts = @{
        Name = "Nerd Fonts"
        Description = "Fonts with icons and symbols for terminal applications"
        Repository = "ryanoasis/nerd-fonts"
        DefaultFont = "CascadiaCode"
        Essential = $true
    }
    
    OhMyPosh = @{
        Name = "Oh-My-Posh"
        Description = "Cross-platform prompt theme engine"
        InstallMethod = "winget"
        PackageId = "JanDeDobbeleer.OhMyPosh"
        Essential = $true
    }
    
    PowerShellModules = @{
        "Terminal-Icons" = @{
            Name = "Terminal-Icons"
            Description = "File and folder icons in terminal"
            Repository = "PowerShell/PSResourceGet"
            Essential = $true
        }
        "PSFzf" = @{
            Name = "PSFzf"
            Description = "Fuzzy finder integration for PowerShell"
            Essential = $false
        }
    }
}

function Test-NerdFontInstalled {
    param([string]$FontName)
    
    try {
        # Check if font is installed via Scoop
        if (Get-Command scoop -ErrorAction SilentlyContinue) {
            $scoopFontName = $FontName.ToLower() -replace "code", "-code"
            $installedApps = & scoop list 2>&1 | Select-String $scoopFontName
            if ($installedApps) {
                return $true
            }
        }
        
        # Fallback: Check if font files exist in Windows Fonts directory
        $fontPaths = @(
            "$env:WINDIR\Fonts",
            "$env:LOCALAPPDATA\Microsoft\Windows\Fonts"
        )
        
        foreach ($fontPath in $fontPaths) {
            $fontFiles = Get-ChildItem -Path $fontPath -Filter "*$FontName*" -ErrorAction SilentlyContinue
            if ($fontFiles.Count -gt 0) {
                return $true
            }
        }
        
        return $false
    }
    catch {
        return $false
    }
}

function Test-ScoopInstalled {
    try {
        $scoopPath = Get-Command scoop -ErrorAction SilentlyContinue
        return $null -ne $scoopPath
    }
    catch {
        return $false
    }
}

function Install-Scoop {
    Write-StatusMessage "Installing Scoop package manager..." "Info"
    
    try {
        # Check if Scoop is already in PATH but not detected
        $env:PATH = [System.Environment]::GetEnvironmentVariable("PATH", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("PATH", "User")
        
        if (Test-ScoopInstalled) {
            Write-StatusMessage "Scoop is already installed" "Success"
            return $true
        }
        
        # Install Scoop using the standard method
        Write-StatusMessage "Downloading and installing Scoop..." "Info"
        
        # Set execution policy for current process
        Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
        
        # Install Scoop
        Invoke-RestMethod -Uri https://get.scoop.sh | Invoke-Expression
        
        # Refresh PATH
        $env:PATH = [System.Environment]::GetEnvironmentVariable("PATH", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("PATH", "User")
        
        # Verify installation
        Start-Sleep -Seconds 3
        if (Test-ScoopInstalled) {
            Write-StatusMessage "Scoop installed successfully" "Success"
            return $true
        } else {
            Write-StatusMessage "Scoop installation completed but command not found in PATH" "Warning"
            Write-StatusMessage "You may need to restart your terminal" "Info"
            return $false
        }
    }
    catch {
        Write-StatusMessage "Failed to install Scoop: $($_.Exception.Message)" "Error"
        return $false
    }
}

function Add-ScoopBucket {
    param([string]$BucketName, [string]$BucketUrl = $null)
    
    try {
        # Check if bucket already exists
        $bucketCheckResult = & scoop bucket list 2>&1
        if ($bucketCheckResult -match $BucketName) {
            Write-StatusMessage "Scoop bucket '$BucketName' already added" "Success"
            return $true
        }
        
        # Add bucket
        Write-StatusMessage "Adding Scoop bucket: $BucketName" "Info"
        if ($BucketUrl) {
            & scoop bucket add $BucketName $BucketUrl
        } else {
            & scoop bucket add $BucketName
        }
        
        if ($LASTEXITCODE -eq 0) {
            Write-StatusMessage "Successfully added Scoop bucket: $BucketName" "Success"
            return $true
        } else {
            throw "Scoop bucket add command failed with exit code: $LASTEXITCODE"
        }
    }
    catch {
        Write-StatusMessage "Failed to add Scoop bucket '$BucketName': $($_.Exception.Message)" "Error"
        return $false
    }
}

function Install-NerdFont {
    param([string]$FontName)
    
    Write-StatusMessage "Installing Nerd Font: $FontName" "Info"
    
    try {
        # Check if already installed
        if (-not $Force -and (Test-NerdFontInstalled -FontName $FontName)) {
            Write-StatusMessage "Nerd Font '$FontName' is already installed" "Success"
            return $true
        }
        
        # Ensure Scoop is available
        if (-not (Get-Command scoop -ErrorAction SilentlyContinue)) {
            throw "Scoop package manager is not installed or not in PATH. Please install Scoop first."
        }
        
        # Add nerd-fonts bucket
        if (-not (Add-ScoopBucket -BucketName "nerd-fonts")) {
            throw "Failed to add nerd-fonts bucket"
        }
        
        # Convert font name to Scoop package name (lowercase with hyphens)
        $scoopFontName = switch ($FontName) {
            "CascadiaCode" { "cascadia-code" }
            "FiraCode" { "fira-code" }
            "JetBrainsMono" { "jetbrains-mono" }
            "Hack" { "hack" }
            "SourceCodePro" { "source-code-pro" }
            "UbuntuMono" { "ubuntu-mono" }
            "DejaVuSansMono" { "dejavusansmono" }
            default { 
                # Generic conversion: CamelCase to kebab-case
                $FontName -creplace '([A-Z])', '-$1' -replace '^-', '' | ForEach-Object { $_.ToLower() }
            }
        }
        
        Write-StatusMessage "Installing font package: $scoopFontName" "Info"
        
        # Install the font using Scoop
        if ($Force) {
            & scoop install $scoopFontName --force
        } else {
            & scoop install $scoopFontName
        }
        
        if ($LASTEXITCODE -eq 0) {
            Write-StatusMessage "✅ Successfully installed $FontName Nerd Font via Scoop" "Success"
            Write-StatusMessage "Both Regular and Mono variants are included" "Success"
            Write-StatusMessage "Note: Restart terminal applications to see the new fonts" "Info"
            return $true
        } else {
            throw "Scoop install command failed with exit code: $LASTEXITCODE"
        }
        
    }
    catch {
        Write-StatusMessage "Failed to install Nerd Font '$FontName': $($_.Exception.Message)" "Error"
        return $false
    }
}

function Test-OhMyPoshInstalled {
    try {
        $ohMyPoshPath = Get-Command oh-my-posh -ErrorAction SilentlyContinue
        return $null -ne $ohMyPoshPath
    }
    catch {
        return $false
    }
}

function Install-OhMyPosh {
    Write-StatusMessage "Installing Oh-My-Posh..." "Info"
    
    try {
        # Check if already installed
        if (-not $Force -and (Test-OhMyPoshInstalled)) {
            Write-StatusMessage "Oh-My-Posh is already installed" "Success"
            return $true
        }
        
        # Install via winget
        Write-StatusMessage "Installing Oh-My-Posh via Windows Package Manager..." "Info"
        
        $installArgs = @(
            "install",
            "--id", "JanDeDobbeleer.OhMyPosh",
            "--exact",
            "--silent",
            "--disable-interactivity",
            "--accept-package-agreements",
            "--accept-source-agreements"
        )
        
        if ($Force) {
            $installArgs += "--force"
        }
        
        $process = Start-Process winget -ArgumentList $installArgs -Wait -PassThru -NoNewWindow
        
        if ($process.ExitCode -eq 0 -or $process.ExitCode -eq -1978335189) {
            # Refresh PATH
            $env:PATH = [System.Environment]::GetEnvironmentVariable("PATH", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("PATH", "User")
            
            # Verify installation
            Start-Sleep -Seconds 2
            if (Test-OhMyPoshInstalled) {
                Write-StatusMessage "Oh-My-Posh installed successfully" "Success"
                return $true
            } else {
                Write-StatusMessage "Oh-My-Posh installation completed but command not found in PATH" "Warning"
                Write-StatusMessage "You may need to restart your terminal" "Info"
                return $true
            }
        } else {
            throw "Winget installation failed with exit code: $($process.ExitCode)"
        }
        
    }
    catch {
        Write-StatusMessage "Failed to install Oh-My-Posh: $($_.Exception.Message)" "Error"
        return $false
    }
}

function Test-PowerShellModuleInstalled {
    param(
        [string]$ModuleName,
        [string]$MinimumVersion = $null
    )
    
    try {
        $module = Get-Module -Name $ModuleName -ListAvailable | Select-Object -First 1
        
        if (-not $module) {
            return $false
        }
        
        if ($MinimumVersion) {
            return $module.Version -ge [version]$MinimumVersion
        }
        
        return $true
    }
    catch {
        return $false
    }
}

function Install-PowerShellModule {
    param(
        [string]$ModuleName,
        [hashtable]$ModuleConfig
    )
    
    Write-StatusMessage "Installing PowerShell module: $($ModuleConfig.Name)" "Info"
    
    try {
        # Check if already installed
        if (-not $Force -and (Test-PowerShellModuleInstalled -ModuleName $ModuleName -MinimumVersion $ModuleConfig.MinimumVersion)) {
            Write-StatusMessage "Module '$($ModuleConfig.Name)' is already installed" "Success"
            return $true
        }
        
        # Install module
        Write-StatusMessage "Installing $($ModuleConfig.Name) from PowerShell Gallery..." "Info"
        
        $installParams = @{
            Name = $ModuleName
            Scope = "CurrentUser"
            Force = $Force
            SkipPublisherCheck = $true
            AllowClobber = $true
        }
        
        if ($ModuleConfig.MinimumVersion) {
            $installParams.MinimumVersion = $ModuleConfig.MinimumVersion
        }
        
        Install-Module @installParams
        
        Write-StatusMessage "Module '$($ModuleConfig.Name)' installed successfully" "Success"
        return $true
        
    }
    catch {
        Write-StatusMessage "Failed to install module '$($ModuleConfig.Name)': $($_.Exception.Message)" "Error"
        return $false
    }
}

function Initialize-PowerShellRepository {
    try {
        # Ensure PSGallery is trusted
        $psGallery = Get-PSRepository -Name PSGallery -ErrorAction SilentlyContinue
        if ($psGallery -and $psGallery.InstallationPolicy -ne "Trusted") {
            Write-StatusMessage "Setting PSGallery as trusted repository..." "Info"
            Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
        }
        
        return $true
    }
    catch {
        Write-StatusMessage "Warning: Could not configure PowerShell repository: $($_.Exception.Message)" "Warning"
        return $false
    }
}

# Main execution
function Main {
    Write-Host "PowerShell Environment Setup" -ForegroundColor Cyan
    Write-Host "============================" -ForegroundColor Cyan
    Write-Host "PowerShell Version: $($PSVersionTable.PSVersion)" -ForegroundColor Gray
    Write-Host ""
    
    $successful = 0
    $failed = 0
    $components = @()
    
    # Initialize PowerShell repository
    Initialize-PowerShellRepository
    
    # Install Nerd Fonts
    if (-not $SkipFonts) {
        Write-SectionHeader "Nerd Fonts Installation"
        if (Install-NerdFont -FontName $FontName) {
            $successful++
            $components += "Nerd Font ($FontName)"
        } else {
            $failed++
        }
    } else {
        Write-StatusMessage "Skipping Nerd Fonts installation" "Warning"
    }
    
    # Install Oh-My-Posh
    if (-not $SkipOhMyPosh) {
        Write-SectionHeader "Oh-My-Posh Installation"
        if (Install-OhMyPosh) {
            $successful++
            $components += "Oh-My-Posh"
        } else {
            $failed++
        }
    } else {
        Write-StatusMessage "Skipping Oh-My-Posh installation" "Warning"
    }
    
    # Install PowerShell Modules
    if (-not $SkipModules) {
        Write-SectionHeader "PowerShell Modules Installation"
        
        $moduleResults = @()
        foreach ($module in $PowerShellComponents.PowerShellModules.GetEnumerator()) {
            $moduleName = $module.Key
            $moduleConfig = $module.Value
            
            if (Install-PowerShellModule -ModuleName $moduleName -ModuleConfig $moduleConfig) {
                $successful++
                $components += $moduleConfig.Name
                $moduleResults += "✅ $($moduleConfig.Name)"
            } else {
                $failed++
                $moduleResults += "❌ $($moduleConfig.Name)"
            }
        }
        
        Write-Host "`nModule Installation Results:" -ForegroundColor Cyan
        foreach ($result in $moduleResults) {
            Write-Host "  $result" -ForegroundColor Gray
        }
    } else {
        Write-StatusMessage "Skipping PowerShell modules installation" "Warning"
    }
    
    # Summary
    Write-Host "`n" -NoNewline
    Write-Host "🎉 PowerShell Setup Summary" -ForegroundColor Cyan
    Write-Host "===========================" -ForegroundColor Cyan
    
    if ($successful -gt 0) {
        Write-StatusMessage "Successfully installed $successful component(s)" "Success"
        Write-Host "Installed components:" -ForegroundColor Green
        foreach ($component in $components) {
            Write-Host "  ✅ $component" -ForegroundColor Green
        }
    }
    
    if ($failed -gt 0) {
        Write-StatusMessage "Failed to install $failed component(s)" "Error"
    }
    
    if ($successful -gt 0) {
        Write-Host ""
        Write-StatusMessage "🔔 Next Steps:" "Info"
        Write-Host "  • Restart your terminal to see the new fonts" -ForegroundColor Gray
        Write-Host "  • Configure your terminal to use '$FontName Nerd Font'" -ForegroundColor Gray
        Write-Host "  • Oh-My-Posh themes are available at: https://ohmyposh.dev/docs/themes" -ForegroundColor Gray
        Write-Host "  • Update your PowerShell profile to load Oh-My-Posh and Terminal-Icons" -ForegroundColor Gray
        Write-Host "  • Example profile configuration:" -ForegroundColor Gray
        Write-Host "    oh-my-posh init pwsh | Invoke-Expression" -ForegroundColor Yellow
        Write-Host "    Import-Module Terminal-Icons" -ForegroundColor Yellow
    }
}

# Run the main function
Main 