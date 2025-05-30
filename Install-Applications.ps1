#Requires -Version 7.0

<#
.SYNOPSIS
    Application Installation Script using Winget

.DESCRIPTION
    Installs common applications using Windows Package Manager (Winget).
    Configurable list of applications with automatic Winget installation if missing.

.PARAMETER Force
    Force reinstallation of applications even if already installed

.PARAMETER SkipBrowsers
    Skip browser installations (Firefox, Chrome, etc.)

.PARAMETER SkipDevelopment
    Skip development tools (VS Code, Git, etc.)

.PARAMETER SkipMedia
    Skip media applications (VLC, etc.)

.PARAMETER SkipUtilities
    Skip utility applications (7-Zip, etc.)

.PARAMETER SkipGaming
    Skip gaming applications (Steam, etc.)

.PARAMETER OnlyEssential
    Install only essential applications (browsers and basic utilities)

.PARAMETER Applications
    Specify custom list of application IDs to install

.EXAMPLE
    .\Install-Applications.ps1
    
.EXAMPLE
    .\Install-Applications.ps1 -Force
    
.EXAMPLE
    .\Install-Applications.ps1 -OnlyEssential
    
.EXAMPLE
    .\Install-Applications.ps1 -Applications "Mozilla.Firefox","Microsoft.VisualStudioCode"
#>

param(
    [Parameter(Mandatory = $false)]
    [switch]$Force,
    
    [Parameter(Mandatory = $false)]
    [switch]$SkipBrowsers,
    
    [Parameter(Mandatory = $false)]
    [switch]$SkipDevelopment,
    
    [Parameter(Mandatory = $false)]
    [switch]$SkipMedia,
    
    [Parameter(Mandatory = $false)]
    [switch]$SkipUtilities,
    
    [Parameter(Mandatory = $false)]
    [switch]$SkipGaming,
    
    [Parameter(Mandatory = $false)]
    [switch]$OnlyEssential,
    
    [Parameter(Mandatory = $false)]
    [string[]]$Applications
)

# Colors for output
$Colors = @{
    Success = "Green"
    Info = "Cyan"
    Warning = "Yellow"
    Error = "Red"
    Gray = "Gray"
}

function Write-StatusMessage {
    param(
        [string]$Message,
        [string]$Type = "Info"
    )
    
    $prefix = switch ($Type) {
        "Success" { "[OK]" }
        "Info" { "[INFO]" }
        "Warning" { "[WARN]" }
        "Error" { "[ERROR]" }
        default { "[*]" }
    }
    
    Write-Host "$prefix $Message" -ForegroundColor $Colors[$Type]
}

# Application configurations
$ApplicationCategories = @{
    Browsers = @(
        @{
            Name = "Mozilla Firefox"
            Id = "Mozilla.Firefox"
            Essential = $true
            Description = "Privacy-focused web browser"
        }
    )
    
    Development = @(
        @{
            Name = "Cursor AI"
            Id = "Anysphere.Cursor"
            Essential = $false
            Description = "AI-powered code editor"
        },
        @{
            Name = "Git"
            Id = "Git.Git"
            Essential = $false
            Description = "Version control system"
        },
        @{
            Name = "Windows Terminal"
            Id = "Microsoft.WindowsTerminal"
            Essential = $false
            Description = "Modern terminal application"
        }
    )
    
    Media = @(
        @{
            Name = "VLC Media Player"
            Id = "VideoLAN.VLC"
            Essential = $false
            Description = "Universal media player"
        }
    )

    Gaming = @(
        @{
            Name = "Steam"
            Id = "Valve.Steam"
            Essential = $false
            Description = "Digital game distribution platform"
        }
    )

    Utilities = @(
        @{
            Name = "7-Zip"
            Id = "7zip.7zip"
            Essential = $true
            Description = "File archiver and compression tool"
        },
        @{
            Name = "Nilesoft Shell"
            Id = "Nilesoft.Shell"
            Essential = $false
            Description = "Context Menu Replacement"
        },
        @{
            Name = "Notepad++"
            Id = "Notepad++.Notepad++"
            Essential = $false
            Description = "Advanced text editor"
        },
        @{
            Name = "PowerToys"
            Id = "Microsoft.PowerToys"
            Essential = $false
            Description = "Windows system utilities"
        }
    )
}

function Test-Winget {
    try {
        $wingetPath = Get-Command winget -ErrorAction Stop
        Write-StatusMessage "Winget found at: $($wingetPath.Source)" "Success"
        return $true
    } catch {
        Write-StatusMessage "Winget not found" "Warning"
        return $false
    }
}

function Install-Winget {
    Write-StatusMessage "Installing Windows Package Manager (Winget)..." "Info"
    
    try {
        # Try to install from Microsoft Store first
        Write-StatusMessage "Attempting to install Winget via Microsoft Store..." "Info"
        
        # Check if App Installer is available in Microsoft Store
        $appInstallerUrl = "https://www.microsoft.com/store/productId/9NBLGGH4NNS1"
        Write-StatusMessage "Please install 'App Installer' from Microsoft Store if Winget is not available" "Info"
        Write-StatusMessage "Store URL: $appInstallerUrl" "Info"
        
        # Alternative: Direct download method
        Write-StatusMessage "Attempting direct installation of Winget..." "Info"
        
        $tempDir = Join-Path $env:TEMP "winget-install"
        if (-not (Test-Path $tempDir)) {
            New-Item -Path $tempDir -ItemType Directory -Force | Out-Null
        }
        
        # Download latest release
        $releases = Invoke-RestMethod "https://api.github.com/repos/microsoft/winget-cli/releases/latest"
        $asset = $releases.assets | Where-Object { $_.name -like "*.msixbundle" } | Select-Object -First 1
        
        if ($asset) {
            $downloadPath = Join-Path $tempDir $asset.name
            Write-StatusMessage "Downloading Winget installer..." "Info"
            
            $originalProgressPreference = $ProgressPreference
            $ProgressPreference = 'SilentlyContinue'
            
            Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $downloadPath -UseBasicParsing
            
            $ProgressPreference = $originalProgressPreference
            
            Write-StatusMessage "Installing Winget package..." "Info"
            Add-AppxPackage -Path $downloadPath -Force
            
            # Clean up
            Remove-Item $tempDir -Recurse -Force -ErrorAction SilentlyContinue
            
            # Refresh PATH
            $env:PATH = [System.Environment]::GetEnvironmentVariable("PATH", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("PATH", "User")
            
            # Test again
            Start-Sleep -Seconds 2
            if (Test-Winget) {
                Write-StatusMessage "Winget installed successfully!" "Success"
                return $true
            }
        }
        
        Write-StatusMessage "Automatic Winget installation failed" "Error"
        Write-StatusMessage "Please install 'App Installer' from Microsoft Store manually" "Info"
        Write-StatusMessage "Then rerun this script" "Info"
        return $false
        
    } catch {
        Write-StatusMessage "Failed to install Winget: $($_.Exception.Message)" "Error"
        Write-StatusMessage "Please install 'App Installer' from Microsoft Store manually" "Info"
        return $false
    }
}

function Test-ApplicationInstalled {
    param([string]$AppId)
    
    try {
        $result = winget list --id $AppId --exact 2>$null
        return $LASTEXITCODE -eq 0
    } catch {
        return $false
    }
}

function Install-Application {
    param([hashtable]$App)
    
    $appName = $App.Name
    $appId = $App.Id
    
    Write-StatusMessage "Installing $appName..." "Info"
    
    # Check if already installed (unless Force is specified)
    if (-not $Force) {
        if (Test-ApplicationInstalled -AppId $appId) {
            Write-StatusMessage "$appName is already installed" "Success"
            return $true
        }
    }
    
    try {
        Write-StatusMessage "Installing $appName ($appId)..." "Info"
        
        $installArgs = @(
            "install",
            "--id", $appId,
            "--exact",
            "--silent",
            "--accept-package-agreements",
            "--accept-source-agreements"
        )
        
        if ($Force) {
            $installArgs += "--force"
        }
        
        $process = Start-Process winget -ArgumentList $installArgs -Wait -PassThru -NoNewWindow
        
        if ($process.ExitCode -eq 0) {
            Write-StatusMessage "$appName installed successfully" "Success"
            return $true
        } elseif ($process.ExitCode -eq -1978335189) {
            Write-StatusMessage "$appName is already installed (latest version)" "Success"
            return $true
        } else {
            Write-StatusMessage "Failed to install $appName (exit code: $($process.ExitCode))" "Error"
            return $false
        }
        
    } catch {
        Write-StatusMessage "Failed to install $appName`: $($_.Exception.Message)" "Error"
        return $false
    }
}

function Get-ApplicationsToInstall {
    $appsToInstall = @()
    
    # If custom application list is provided, use that
    if ($Applications -and $Applications.Count -gt 0) {
        Write-StatusMessage "Using custom application list" "Info"
        foreach ($appId in $Applications) {
            $appsToInstall += @{
                Name = $appId
                Id = $appId
                Essential = $false
                Description = "Custom application"
            }
        }
        return $appsToInstall
    }
    
    # Build application list based on categories and flags
    foreach ($category in $ApplicationCategories.GetEnumerator()) {
        $categoryName = $category.Key
        $skipCategory = $false
        
        # Check skip flags
        switch ($categoryName) {
            "Browsers" { $skipCategory = $SkipBrowsers }
            "Development" { $skipCategory = $SkipDevelopment }
            "Media" { $skipCategory = $SkipMedia }
            "Utilities" { $skipCategory = $SkipUtilities }
            "Gaming" { $skipCategory = $SkipGaming }
        }
        
        if ($skipCategory) {
            Write-StatusMessage "Skipping $categoryName applications" "Warning"
            continue
        }
        
        foreach ($app in $category.Value) {
            # If OnlyEssential is specified, only include essential apps
            if ($OnlyEssential -and -not $app.Essential) {
                continue
            }
            
            $appsToInstall += $app
        }
    }
    
    return $appsToInstall
}

# Main execution
function Main {
    Write-Host "Application Installation using Winget" -ForegroundColor Cyan
    Write-Host "=====================================" -ForegroundColor Cyan
    Write-Host "PowerShell Version: $($PSVersionTable.PSVersion)" -ForegroundColor Gray
    Write-Host ""
    
    # Check if Winget is available
    if (-not (Test-Winget)) {
        Write-StatusMessage "Winget is required but not found" "Warning"
        $installWinget = Install-Winget
        
        if (-not $installWinget) {
            Write-StatusMessage "Cannot proceed without Winget" "Error"
            Write-StatusMessage "Please install 'App Installer' from Microsoft Store and rerun this script" "Info"
            exit 1
        }
    }
    
    # Get list of applications to install
    $applicationsToInstall = Get-ApplicationsToInstall
    
    if ($applicationsToInstall.Count -eq 0) {
        Write-StatusMessage "No applications selected for installation" "Warning"
        return
    }
    
    Write-Host "`n📦 Applications to Install" -ForegroundColor Cyan
    Write-Host "=========================" -ForegroundColor Cyan
    foreach ($app in $applicationsToInstall) {
        $essentialText = if ($app.Essential) { " (Essential)" } else { "" }
        Write-Host "  • $($app.Name)$essentialText" -ForegroundColor Gray
        Write-Host "    $($app.Description)" -ForegroundColor DarkGray
    }
    Write-Host ""
    
    # Install applications
    $successful = 0
    $failed = 0
    $failedApps = @()
    
    foreach ($app in $applicationsToInstall) {
        if (Install-Application -App $app) {
            $successful++
        } else {
            $failed++
            $failedApps += $app.Name
        }
    }
    
    # Summary
    Write-Host "`n" -NoNewline
    Write-Host "📱 Application Installation Summary" -ForegroundColor Cyan
    Write-Host "===================================" -ForegroundColor Cyan
    
    if ($successful -gt 0) {
        Write-StatusMessage "Successfully installed $successful application(s)" "Success"
    }
    
    if ($failed -gt 0) {
        Write-StatusMessage "Failed to install $failed application(s)" "Error"
        Write-Host "Failed applications:" -ForegroundColor Red
        foreach ($failedApp in $failedApps) {
            Write-Host "  • $failedApp" -ForegroundColor Red
        }
        Write-Host ""
        Write-StatusMessage "You can try installing failed applications manually using:" "Info"
        Write-StatusMessage "winget install --id <ApplicationId>" "Info"
    }
    
    if ($successful -gt 0) {
        Write-Host ""
        Write-StatusMessage "🎉 Applications installed successfully!" "Success"
        Write-StatusMessage "Some applications may require a restart or logout to work properly" "Info"
        Write-StatusMessage "Check your Start Menu and desktop for new application shortcuts" "Info"
    }
}

# Run the main function
Main 