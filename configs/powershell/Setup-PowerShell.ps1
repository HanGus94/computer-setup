#Requires -Version 7.0

<#
.SYNOPSIS
    PowerShell Environment Setup Script

.DESCRIPTION
    Sets up a complete PowerShell environment with:
    - Nerd Fonts (CascadiaCove) for terminal icons and symbols
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
    Specify which Nerd Font to install (default: CascadiaCove)

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
    [string]$FontName = "CascadiaCove"
)

# Import the shared module
Import-Module (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) "modules\ComputerSetup.psm1") -Force

# PowerShell components configuration
$PowerShellComponents = @{
    NerdFonts = @{
        Name = "Nerd Fonts"
        Description = "Fonts with icons and symbols for terminal applications"
        Repository = "ryanoasis/nerd-fonts"
        DefaultFont = "CascadiaCove"
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
        "PSReadLine" = @{
            Name = "PSReadLine"
            Description = "Enhanced command line editing"
            MinimumVersion = "2.2.6"
            Essential = $true
        }
        "PowerShellGet" = @{
            Name = "PowerShellGet"
            Description = "PowerShell module management"
            MinimumVersion = "3.0.0"
            Essential = $true
        }
        "Microsoft.PowerShell.ConsoleGuiTools" = @{
            Name = "ConsoleGuiTools"
            Description = "Out-ConsoleGridView and Show-ObjectTree cmdlets"
            Essential = $false
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
        # Check if font is installed by looking in Windows Fonts directory
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

function Install-NerdFont {
    param([string]$FontName)
    
    Write-StatusMessage "Installing Nerd Font: $FontName" "Info"
    
    try {
        # Check if already installed
        if (-not $Force -and (Test-NerdFontInstalled -FontName $FontName)) {
            Write-StatusMessage "Nerd Font '$FontName' is already installed" "Success"
            return $true
        }
        
        # Get latest release from Nerd Fonts repository
        $releaseInfo = Get-GitHubLatestRelease -Repository "ryanoasis/nerd-fonts" -FilePattern "$FontName.zip"
        
        if (-not $releaseInfo) {
            Write-StatusMessage "Could not find font '$FontName' in Nerd Fonts releases" "Error"
            return $false
        }
        
        Write-StatusMessage "Found $FontName font version $($releaseInfo.Version)" "Info"
        
        # Download font
        $tempDir = Join-Path $env:TEMP "nerd-fonts-$FontName"
        if (Test-Path $tempDir) {
            Remove-Item $tempDir -Recurse -Force
        }
        New-Item -Path $tempDir -ItemType Directory -Force | Out-Null
        
        $fontArchive = Join-Path $tempDir "$FontName.zip"
        
        if (-not (Invoke-FileDownload -Url $releaseInfo.DownloadUrl -OutputPath $fontArchive -Description "Nerd Font $FontName")) {
            throw "Failed to download font"
        }
        
        # Extract font files
        $extractPath = Join-Path $tempDir "extracted"
        Expand-Archive -Path $fontArchive -DestinationPath $extractPath -Force
        
        # Install fonts
        $fontFiles = Get-ChildItem -Path $extractPath -Filter "*.ttf" -Recurse
        if ($fontFiles.Count -eq 0) {
            $fontFiles = Get-ChildItem -Path $extractPath -Filter "*.otf" -Recurse
        }
        
        if ($fontFiles.Count -eq 0) {
            throw "No font files found in downloaded archive"
        }
        
        Write-StatusMessage "Installing $($fontFiles.Count) font files..." "Info"
        
        # Install fonts to user directory (doesn't require admin)
        $userFontsPath = "$env:LOCALAPPDATA\Microsoft\Windows\Fonts"
        if (-not (Test-Path $userFontsPath)) {
            New-Item -Path $userFontsPath -ItemType Directory -Force | Out-Null
        }
        
        $installedCount = 0
        foreach ($fontFile in $fontFiles) {
            try {
                $targetPath = Join-Path $userFontsPath $fontFile.Name
                Copy-Item $fontFile.FullName $targetPath -Force
                $installedCount++
            }
            catch {
                Write-StatusMessage "Warning: Failed to install $($fontFile.Name)" "Warning"
            }
        }
        
        # Register fonts with Windows (requires registry modification)
        try {
            foreach ($fontFile in $fontFiles) {
                $fontName = [System.IO.Path]::GetFileNameWithoutExtension($fontFile.Name)
                $registryPath = "HKCU:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts"
                $registryName = "$fontName (TrueType)"
                $fontPath = Join-Path $userFontsPath $fontFile.Name
                
                Set-ItemProperty -Path $registryPath -Name $registryName -Value $fontPath -ErrorAction SilentlyContinue
            }
        }
        catch {
            Write-StatusMessage "Warning: Could not register all fonts with Windows" "Warning"
        }
        
        # Cleanup
        Remove-Item $tempDir -Recurse -Force -ErrorAction SilentlyContinue
        
        Write-StatusMessage "Successfully installed $installedCount font files for $FontName" "Success"
        Write-StatusMessage "Note: Restart terminal applications to see the new fonts" "Info"
        
        return $true
        
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