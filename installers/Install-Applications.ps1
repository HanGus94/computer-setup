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

.PARAMETER SkipScoop
    Skip Scoop package manager installation

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
    .\Install-Applications.ps1 -SkipScoop -SkipGaming
    
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
    [switch]$SkipScoop,
    
    [Parameter(Mandatory = $false)]
    [switch]$OnlyEssential,
    
    [Parameter(Mandatory = $false)]
    [string[]]$Applications
)

# Import the shared module
Import-Module (Join-Path (Split-Path -Parent $PSScriptRoot) "modules\ComputerSetup.psm1") -Force

# Application configurations
$ApplicationCategories = @{
    Browsers = @(
        @{
            Name = "Mozilla Firefox"
            Id = "Mozilla.Firefox"
            Essential = $true
            Description = "Privacy-focused web browser"
            PackageManager = "winget"
        }
    )
    
    Development = @(
        @{
            Name = "Cursor AI"
            Id = "Anysphere.Cursor"
            Essential = $false
            Description = "AI-powered code editor"
            PackageManager = "winget"
        },
        @{
            Name = "Git"
            Id = "Git.Git"
            Essential = $false
            Description = "Version control system"
            PackageManager = "winget"
        },
        @{
            Name = "Windows Terminal"
            Id = "Microsoft.WindowsTerminal"
            Essential = $false
            Description = "Modern terminal application"
            PackageManager = "winget"
        },
        @{
            Name = "Docker Desktop"
            Id = "Docker.DockerDesktop"
            Essential = $false
            Description = "Docker containerization platform"
            PackageManager = "winget"
        }
    )
    
    Media = @(
        @{
            Name = "VLC Media Player"
            Id = "VideoLAN.VLC"
            Essential = $false
            Description = "Universal media player"
            PackageManager = "winget"
        },
        @{
            Name = "Spotify Terminal Player"
            Id = "spotify-player"
            Essential = $false
            Description = "Spotify terminal player"
            PackageManager = "scoop"
        }
    )

    Gaming = @(
        @{
            Name = "Steam"
            Id = "Valve.Steam"
            Essential = $false
            Description = "Digital game distribution platform"
            PackageManager = "winget"
        },
        @{
            Name = "Epic Games Launcher"
            Id = "EpicGames.EpicGamesLauncher"
            Essential = $false
            Description = "Digital game distribution platform"
            PackageManager = "winget"
        },
        @{
            Name = "GOG Galaxy"
            Id = "GOG.Galaxy"
            Essential = $false
            Description = "Digital game distribution platform"
            PackageManager = "winget"
        },
        @{
            Name = "Battle.net"
            Id = "Blizzard.BattleNet"
            Essential = $false
            Description = "Digital game distribution platform"
            PackageManager = "winget"
            SilentArgs = @("--lang=enUS", "--installpath=`"C:\Program Files (x86)\Battle.net`"")
            CustomDetection = {
                # Check for Battle.net installation using multiple methods
                $installPaths = @(
                    "${env:ProgramFiles(x86)}\Battle.net\Battle.net.exe",
                    "${env:ProgramFiles}\Battle.net\Battle.net.exe"
                )
                
                foreach ($path in $installPaths) {
                    if (Test-Path $path) {
                        return $true
                    }
                }
                
                # Check registry
                $regPaths = @(
                    "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\Battle.net",
                    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\Battle.net"
                )
                
                foreach ($regPath in $regPaths) {
                    if (Test-Path $regPath) {
                        return $true
                    }
                }
                
                return $false
            }
        }
    )

    Utilities = @(
        @{
            Name = "7-Zip"
            Id = "7zip.7zip"
            Essential = $true
            Description = "File archiver and compression tool"
            PackageManager = "winget"
        },
        @{
            Name = "PowerToys"
            Id = "Microsoft.PowerToys"
            Essential = $false
            Description = "Windows system utilities"
            PackageManager = "winget"
        },
        @{
            Name = "Discord"
            Id = "Discord.Discord"
            Essential = $false
            Description = "Voice and text chat for gamers"
            PackageManager = "winget"
        },
        @{
            Name = "Nilesoft Shell"
            Id = "Nilesoft.Shell"
            Essential = $false
            Description = "Windows shell replacement"
            PackageManager = "winget"
        },
        @{
            Name = "Elgato Wavelink"
            Id = "Elgato.Wavelink"
            Essential = $false
            Description = "Elgato Wavelink"
            PackageManager = "winget"
        },
        @{
            Name = "Elgato Stream Deck"
            Id = "Elgato.StreamDeck"
            Essential = $false
            Description = "Elgato Stream Deck"
            PackageManager = "winget"
        },
        @{
            Name = "Elgato Camera Hub"
            Id = "Elgato.CameraHub"
            Essential = $false
            Description = "Elgato Camera Hub"
            PackageManager = "winget"
        },
        @{
            Name = "Google Drive"
            Id = "Google.GoogleDrive"
            Essential = $false
            Description = "Google Drive"
            PackageManager = "winget"
        },
        @{
            Name = "Flameshot"
            Id = "Flameshot.Flameshot"
            Essential = $false
            Description = "Flameshot"
            PackageManager = "winget"
        },
        @{
            Name = "Teracopy"
            Id = "CodeSector.TeraCopy"
            Essential = $false
            Description = "Teracopy"
            PackageManager = "winget"
        },
        @{
            Name = "MobaXterm"
            Id = "Mobatek.MobaXterm"
            Essential = $false
            Description = "MobaXterm"
            PackageManager = "winget"
        },
        @{
            Name = "Zoxide"
            Id = "ajeetdsouza.zoxide"
            Essential = $false
            Description = "Zoxide"
            PackageManager = "winget"
        },
        @{
            Name = "Fzf"
            Id = "fzf"
            Essential = $false
            Description = "Fzf"
            PackageManager = "scoop"
        },
        @{
            Name = "PSFzf"
            Id = "psfzf"
            Essential = $false
            Description = "PSFzf"
            PackageManager = "scoop"
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

function Add-ScoopBucket {
    param(
        [Parameter(Mandatory = $true)]
        [string]$BucketName,
        
        [Parameter(Mandatory = $false)]
        [string]$BucketUrl = $null
    )
    
    try {
        # Check if bucket is already added
        $existingBuckets = & scoop bucket list 2>$null | Out-String
        if ($existingBuckets -match $BucketName) {
            Write-StatusMessage "Scoop bucket '$BucketName' is already added" "Success"
            return $true
        }
        
        # Add the bucket
        Write-StatusMessage "Adding Scoop bucket: $BucketName" "Info"
        
        if ($BucketUrl) {
            $result = & scoop bucket add $BucketName $BucketUrl 2>&1
        } else {
            $result = & scoop bucket add $BucketName 2>&1
        }
        
        if ($LASTEXITCODE -eq 0) {
            Write-StatusMessage "Successfully added Scoop bucket: $BucketName" "Success"
            return $true
        } else {
            Write-StatusMessage "Failed to add Scoop bucket '$BucketName': $result" "Warning"
            return $false
        }
        
    } catch {
        Write-StatusMessage "Error adding Scoop bucket '$BucketName': $($_.Exception.Message)" "Warning"
        return $false
    }
}

function Test-Scoop {
    try {
        $scoopPath = Get-Command scoop -ErrorAction Stop
        Write-StatusMessage "Scoop found at: $($scoopPath.Source)" "Success"
        return $true
    } catch {
        Write-StatusMessage "Scoop not found" "Warning"
        return $false
    }
}

function Install-Scoop {
    Write-StatusMessage "Installing Scoop package manager..." "Info"
    
    try {
        # Check execution policy
        $currentPolicy = Get-ExecutionPolicy -Scope CurrentUser
        $needsPolicyChange = $currentPolicy -eq "Restricted"
        
        if ($needsPolicyChange) {
            Write-StatusMessage "Setting execution policy to RemoteSigned for current user..." "Info"
            Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
        }
        
        # Download and install Scoop
        Write-StatusMessage "Downloading Scoop installer..." "Info"
        
        $originalProgressPreference = $ProgressPreference
        $ProgressPreference = 'SilentlyContinue'
        
        Invoke-RestMethod -Uri https://get.scoop.sh | Invoke-Expression
        
        $ProgressPreference = $originalProgressPreference
        
        # Refresh PATH
        $env:PATH = [System.Environment]::GetEnvironmentVariable("PATH", "User") + ";" + $env:PATH
        
        # Test installation
        Start-Sleep -Seconds 2
        if (Test-Scoop) {
            Write-StatusMessage "Scoop installed successfully!" "Success"
            
            # Install essential buckets using idempotent function
            Write-StatusMessage "Installing essential Scoop buckets..." "Info"
            Add-ScoopBucket -BucketName "extras"
            Add-ScoopBucket -BucketName "versions"
            
            return $true
        } else {
            throw "Scoop installation verification failed"
        }
        
    } catch {
        Write-StatusMessage "Failed to install Scoop: $($_.Exception.Message)" "Error"
        Write-StatusMessage "You can install Scoop manually from: https://scoop.sh" "Info"
        return $false
    }
}

function Test-ApplicationInstalled {
    param(
        [string]$AppId,
        [scriptblock]$CustomDetection = $null
    )
    
    # Use custom detection if provided
    if ($CustomDetection) {
        try {
            return & $CustomDetection
        } catch {
            Write-StatusMessage "Custom detection failed for $AppId`: $($_.Exception.Message)" "Warning"
            # Fall back to winget detection
        }
    }
    
    # Default winget detection
    try {
        winget list --id $AppId --exact --disable-interactivity 2>$null | Out-Null
        return $LASTEXITCODE -eq 0
    } catch {
        return $false
    }
}

function Install-Application {
    param([hashtable]$App)
    
    $appName = $App.Name
    $appId = $App.Id
    $packageManager = if ($App.PackageManager) { $App.PackageManager } else { "winget" }
    $customDetection = $App.CustomDetection
    $silentArgs = $App.SilentArgs
    
    Write-StatusMessage "Installing $appName using $packageManager..." "Info"
    
    # Check if already installed (unless Force is specified)
    if (-not $Force) {
        $isInstalled = $false
        
        if ($packageManager -eq "scoop") {
            try {
                $scoopList = & scoop list 2>$null | Out-String
                $isInstalled = $scoopList -match $appId
            } catch {
                $isInstalled = $false
            }
        } else {
            $isInstalled = Test-ApplicationInstalled -AppId $appId -CustomDetection $customDetection
        }
        
        if ($isInstalled) {
            Write-StatusMessage "$appName is already installed" "Success"
            return $true
        }
    }
    
    try {
        if ($packageManager -eq "scoop") {
            # Install via Scoop
            if (-not (Test-Scoop)) {
                Write-StatusMessage "Scoop is not available, cannot install $appName" "Error"
                return $false
            }
            
            Write-StatusMessage "Installing $appName ($appId) via Scoop..." "Info"
            $process = Start-Process scoop -ArgumentList @("install", $appId) -Wait -PassThru -NoNewWindow
            
            if ($process.ExitCode -eq 0) {
                Write-StatusMessage "$appName installed successfully via Scoop" "Success"
                return $true
            } else {
                Write-StatusMessage "Failed to install $appName via Scoop (exit code: $($process.ExitCode))" "Error"
                return $false
            }
        } else {
            # Install via Winget (default)
            Write-StatusMessage "Installing $appName ($appId) via Winget..." "Info"
            
            $installArgs = @(
                "install",
                "--id", $appId,
                "--exact",
                "--silent",
                "--disable-interactivity",
                "--accept-package-agreements",
                "--accept-source-agreements"
            )
            
            # Add custom silent arguments if provided
            if ($silentArgs) {
                $installArgs += "--override"
                $installArgs += ($silentArgs -join " ")
            }
            
            if ($Force) {
                $installArgs += "--force"
            }
            
            $process = Start-Process winget -ArgumentList $installArgs -Wait -PassThru -NoNewWindow
            
            if ($process.ExitCode -eq 0) {
                Write-StatusMessage "$appName installed successfully via Winget" "Success"
                return $true
            } elseif ($process.ExitCode -eq -1978335189) {
                Write-StatusMessage "$appName is already installed (latest version)" "Success"
                return $true
            } else {
                Write-StatusMessage "Failed to install $appName via Winget (exit code: $($process.ExitCode))" "Error"
                
                # For Battle.net, provide additional troubleshooting info
                if ($appId -eq "Blizzard.BattleNet") {
                    Write-StatusMessage "Battle.net installation troubleshooting:" "Info"
                    Write-StatusMessage "• Make sure you have enough disk space" "Info"
                    Write-StatusMessage "• Check if another installer is running" "Info"
                    Write-StatusMessage "• Try running as administrator" "Info"
                }
                
                return $false
            }
        }
        
    } catch {
        Write-StatusMessage "Failed to install $appName`: $($_.Exception.Message)" "Error"
        return $false
    }
}

function Initialize-ScoopBuckets {
    <#
    .SYNOPSIS
        Initializes essential Scoop buckets (idempotent)
    #>
    
    if (-not (Test-Scoop)) {
        Write-StatusMessage "Scoop is not available, cannot initialize buckets" "Warning"
        return $false
    }
    
    Write-StatusMessage "Initializing essential Scoop buckets..." "Info"
    
    $bucketsAdded = 0
    
    # Essential buckets for our applications
    $essentialBuckets = @(
        "extras",
        "versions"
    )
    
    foreach ($bucket in $essentialBuckets) {
        if (Add-ScoopBucket -BucketName $bucket) {
            $bucketsAdded++
        }
    }
    
    Write-StatusMessage "Scoop bucket initialization completed ($bucketsAdded buckets processed)" "Info"
    return $true
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
    
    # Check if Scoop should be installed
    if (-not $SkipScoop) {
        if (-not (Test-Scoop)) {
            Write-StatusMessage "Installing Scoop package manager..." "Info"
            $installScoop = Install-Scoop
            
            if ($installScoop) {
                Write-StatusMessage "Scoop is now available for additional package management" "Success"
            } else {
                Write-StatusMessage "Scoop installation failed, but continuing with Winget..." "Warning"
            }
        } else {
            Write-StatusMessage "Scoop is already installed" "Success"
        }
    } else {
        Write-StatusMessage "Skipping Scoop installation (SkipScoop flag)" "Warning"
    }
    
    # Get list of applications to install
    $applicationsToInstall = Get-ApplicationsToInstall
    
    if ($applicationsToInstall.Count -eq 0) {
        Write-StatusMessage "No applications selected for installation" "Warning"
        return
    }
    
    # Check if any Scoop applications are in the list and ensure buckets
    $scoopApps = $applicationsToInstall | Where-Object { $_.PackageManager -eq "scoop" }
    if ($scoopApps.Count -gt 0 -and (Test-Scoop)) {
        Initialize-ScoopBuckets
    }
    
    Write-Host "`n📦 Applications to Install" -ForegroundColor Cyan
    Write-Host "=========================" -ForegroundColor Cyan
    foreach ($app in $applicationsToInstall) {
        $essentialText = if ($app.Essential) { " (Essential)" } else { "" }
        $packageManager = if ($app.PackageManager) { $app.PackageManager } else { "winget" }
        Write-Host "  • $($app.Name)$essentialText" -ForegroundColor Gray
        Write-Host "    $($app.Description)" -ForegroundColor DarkGray
        Write-Host "    Package Manager: $packageManager" -ForegroundColor Magenta
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