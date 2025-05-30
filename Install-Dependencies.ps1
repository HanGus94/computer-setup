#Requires -Version 7.0

<#
.SYNOPSIS
    System Dependencies Installation Script

.DESCRIPTION
    Installs required system dependencies for OBS Studio and plugins including:
    - Microsoft Visual C++ Redistributables (2015-2022)
    - Other common runtime libraries

.PARAMETER Force
    Force reinstallation even if dependencies are already installed

.PARAMETER SkipVCRedist
    Skip Visual C++ Redistributable installation

.EXAMPLE
    .\Install-Dependencies.ps1
    
.EXAMPLE
    .\Install-Dependencies.ps1 -Force
    
.EXAMPLE
    .\Install-Dependencies.ps1 -SkipVCRedist
#>

param(
    [Parameter(Mandatory = $false)]
    [switch]$Force,
    
    [Parameter(Mandatory = $false)]
    [switch]$SkipVCRedist
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

function Test-VCRedistInstalled {
    param([string]$Version)
    
    try {
        # Check both 32-bit and 64-bit installations
        $registryPaths = @(
            "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
            "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*"
        )
        
        foreach ($path in $registryPaths) {
            $installed = Get-ItemProperty $path -ErrorAction SilentlyContinue | 
                Where-Object { $_.DisplayName -like "*Visual C++*$Version*" }
            
            if ($installed) {
                return $true
            }
        }
        
        return $false
    }
    catch {
        return $false
    }
}

function Download-File {
    param(
        [string]$Url,
        [string]$OutputPath,
        [string]$Description = "file"
    )
    
    try {
        $originalProgressPreference = $ProgressPreference
        $ProgressPreference = 'SilentlyContinue'
        
        Write-StatusMessage "Downloading $Description..." "Info"
        Invoke-WebRequest -Uri $Url -OutFile $OutputPath -UseBasicParsing
        
        return $true
    }
    catch {
        Write-StatusMessage "Failed to download $Description`: $($_.Exception.Message)" "Error"
        return $false
    }
    finally {
        $ProgressPreference = $originalProgressPreference
    }
}

function Install-VCRedist {
    param([hashtable]$VCPackage)
    
    $packageName = $VCPackage.Name
    $architecture = $VCPackage.Architecture
    $downloadUrl = $VCPackage.Url
    
    Write-StatusMessage "Installing $packageName ($architecture)..." "Info"
    
    # Check if already installed (unless Force is specified)
    if (-not $Force) {
        $isInstalled = Test-VCRedistInstalled -Version $VCPackage.Version
        if ($isInstalled) {
            Write-StatusMessage "$packageName ($architecture) is already installed" "Success"
            return $true
        }
    }
    
    # Create temp directory
    $tempDir = Join-Path $env:TEMP "vcredist-install"
    if (-not (Test-Path $tempDir)) {
        New-Item -Path $tempDir -ItemType Directory -Force | Out-Null
    }
    
    try {
        # Download
        $fileName = "vcredist_$($architecture)_$($VCPackage.Version).exe"
        $installerPath = Join-Path $tempDir $fileName
        
        if (-not (Download-File -Url $downloadUrl -OutputPath $installerPath -Description $packageName)) {
            throw "Failed to download $packageName"
        }
        
        # Install silently
        Write-StatusMessage "Installing $packageName ($architecture) silently..." "Info"
        $installArgs = @("/install", "/quiet", "/norestart")
        
        $process = Start-Process -FilePath $installerPath -ArgumentList $installArgs -Wait -PassThru
        
        if ($process.ExitCode -eq 0) {
            Write-StatusMessage "$packageName ($architecture) installed successfully" "Success"
            return $true
        } elseif ($process.ExitCode -eq 1638) {
            Write-StatusMessage "$packageName ($architecture) is already installed (newer version)" "Success"
            return $true
        } else {
            throw "Installation failed with exit code: $($process.ExitCode)"
        }
        
    }
    catch {
        Write-StatusMessage "Failed to install $packageName ($architecture): $($_.Exception.Message)" "Error"
        return $false
    }
    finally {
        # Cleanup
        if (Test-Path $installerPath) {
            Remove-Item $installerPath -Force -ErrorAction SilentlyContinue
        }
    }
}

function Install-AllVCRedist {
    Write-Host "`n============================================" -ForegroundColor Cyan
    Write-Host "Microsoft Visual C++ Redistributables" -ForegroundColor Cyan
    Write-Host "============================================" -ForegroundColor Cyan
    Write-Host "Required for OBS Studio and most plugins" -ForegroundColor Gray
    Write-Host ""
    
    # Define Visual C++ packages to install
    # Using the latest unified redistributables that are backward compatible
    $vcPackages = @(
        @{
            Name = "Visual C++ 2015-2022 Redistributable"
            Version = "2015-2022"
            Architecture = "x64"
            Url = "https://aka.ms/vs/17/release/vc_redist.x64.exe"
        },
        @{
            Name = "Visual C++ 2015-2022 Redistributable"
            Version = "2015-2022"  
            Architecture = "x86"
            Url = "https://aka.ms/vs/17/release/vc_redist.x86.exe"
        }
    )
    
    $successful = 0
    $failed = 0
    
    foreach ($package in $vcPackages) {
        if (Install-VCRedist -VCPackage $package) {
            $successful++
        } else {
            $failed++
        }
    }
    
    Write-Host ""
    if ($successful -gt 0) {
        Write-StatusMessage "Successfully processed $successful Visual C++ package(s)" "Success"
    }
    if ($failed -gt 0) {
        Write-StatusMessage "Failed to install $failed Visual C++ package(s)" "Error"
        return $false
    }
    
    return $true
}

function Test-IsElevated {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

# Main execution
function Main {
    Write-Host "System Dependencies Installation" -ForegroundColor Cyan
    Write-Host "================================" -ForegroundColor Cyan
    Write-Host "PowerShell Version: $($PSVersionTable.PSVersion)" -ForegroundColor Gray
    Write-Host ""
    
    # Check if running as administrator
    if (-not (Test-IsElevated)) {
        Write-StatusMessage "Warning: Not running as administrator" "Warning"
        Write-StatusMessage "Some installations may fail without elevated privileges" "Warning"
        Write-Host ""
    }
    
    $allSuccessful = $true
    
    # Install Visual C++ Redistributables
    if (-not $SkipVCRedist) {
        $vcResult = Install-AllVCRedist
        if (-not $vcResult) {
            $allSuccessful = $false
        }
    } else {
        Write-StatusMessage "Skipping Visual C++ Redistributables (SkipVCRedist flag)" "Warning"
    }
    
    # Future: Add other dependencies here
    # - .NET Framework/Core if needed
    # - DirectX redistributables
    # - Other common runtime libraries
    
    # Summary
    Write-Host "`n" -NoNewline
    Write-Host "🔧 Dependencies Installation Summary" -ForegroundColor Cyan
    Write-Host "====================================" -ForegroundColor Cyan
    
    if ($allSuccessful) {
        Write-StatusMessage "All dependencies installed successfully!" "Success"
        Write-StatusMessage "Your system is ready for OBS Studio and plugins." "Info"
    } else {
        Write-StatusMessage "Some dependencies failed to install." "Error"
        Write-StatusMessage "OBS Studio may not work correctly without all required dependencies." "Warning"
        Write-StatusMessage "Try running this script as administrator or check the errors above." "Info"
    }
    
    Write-Host ""
    Write-StatusMessage "Note: A system restart may be required for some changes to take effect." "Info"
}

# Run the main function
Main 