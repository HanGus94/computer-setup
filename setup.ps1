#Requires -Version 5.1

<#
.SYNOPSIS
    Computer Setup Bootstrap Script

.DESCRIPTION
    This script checks for PowerShell 7+ and installs it if not present.
    After ensuring PowerShell 7+ is available, it launches the main deployment script.
    
    This bootstrap script is designed to work with Windows PowerShell 5.1+ and will
    automatically upgrade to PowerShell 7+ for the actual deployment.

.PARAMETER Force
    Force reinstallation of PowerShell 7+ even if already present

.EXAMPLE
    .\setup.ps1
    
.EXAMPLE
    .\setup.ps1 -Force
#>

param(
    [Parameter(Mandatory = $false)]
    [switch]$Force
)

# Colors for better output
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

function Test-PowerShell7 {
    try {
        # Try to find PowerShell 7+ in common locations
        $pwshPaths = @(
            "pwsh",  # If in PATH
            "$env:ProgramFiles\PowerShell\7\pwsh.exe",
            "${env:ProgramFiles(x86)}\PowerShell\7\pwsh.exe"
        )
        
        foreach ($path in $pwshPaths) {
            try {
                $result = & $path --version 2>$null
                if ($result -and $result -match "PowerShell (\d+)\.(\d+)\.(\d+)") {
                    $majorVersion = [int]$Matches[1]
                    if ($majorVersion -ge 7) {
                        return @{
                            Found = $true
                            Path = $path
                            Version = $result
                        }
                    }
                }
            } catch {
                # Continue to next path
            }
        }
        
        return @{ Found = $false }
    } catch {
        return @{ Found = $false }
    }
}

function Test-Winget {
    try {
        $null = Get-Command winget -ErrorAction Stop
        return $true
    } catch {
        return $false
    }
}

function Install-PowerShell7 {
    Write-StatusMessage "Installing PowerShell 7..." "Info"
    
    # Try winget first (fastest and most reliable)
    if (Test-Winget) {
        Write-StatusMessage "Using winget to install PowerShell..." "Info"
        try {
            $null = winget install --id Microsoft.Powershell --source winget --accept-package-agreements --accept-source-agreements 2>&1
            if ($LASTEXITCODE -eq 0) {
                Write-StatusMessage "PowerShell 7 installed successfully via winget!" "Success"
                return $true
            } else {
                Write-StatusMessage "Winget installation failed, trying alternative method..." "Warning"
            }
        } catch {
            Write-StatusMessage "Winget installation failed, trying alternative method..." "Warning"
        }
    }
    
    # Fallback to direct download
    Write-StatusMessage "Downloading PowerShell 7 directly from GitHub..." "Info"
    try {
        # Disable progress bar for faster downloads
        $originalProgressPreference = $ProgressPreference
        $ProgressPreference = 'SilentlyContinue'
        
        # Get latest release info
        $releases = Invoke-RestMethod "https://api.github.com/repos/PowerShell/PowerShell/releases/latest"
        $asset = $releases.assets | Where-Object { $_.name -like "*win-x64.msi" } | Select-Object -First 1
        
        if (-not $asset) {
            throw "Could not find Windows x64 installer"
        }
        
        $downloadPath = Join-Path $env:TEMP $asset.name
        Write-StatusMessage "Downloading $($asset.name) ($('{0:N1}' -f ($asset.size / 1MB)) MB)..." "Info"
        
        Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $downloadPath -UseBasicParsing
        
        # Restore progress preference
        $ProgressPreference = $originalProgressPreference
        
        Write-StatusMessage "Installing PowerShell 7..." "Info"
        $installArgs = @(
            "/i", $downloadPath,
            "/quiet",
            "ADD_EXPLORER_CONTEXT_MENU_OPENPOWERSHELL=1",
            "ADD_FILE_CONTEXT_MENU_RUNPOWERSHELL=1",
            "ENABLE_PSREMOTING=1",
            "REGISTER_MANIFEST=1"
        )
        
        $process = Start-Process msiexec.exe -ArgumentList $installArgs -Wait -PassThru
        
        if ($process.ExitCode -eq 0) {
            Write-StatusMessage "PowerShell 7 installed successfully!" "Success"
            # Clean up
            Remove-Item $downloadPath -Force -ErrorAction SilentlyContinue
            return $true
        } else {
            throw "Installation failed with exit code: $($process.ExitCode)"
        }
        
    } catch {
        # Restore progress preference in case of error
        if ($originalProgressPreference) {
            $ProgressPreference = $originalProgressPreference
        }
        Write-StatusMessage "Failed to install PowerShell 7: $($_.Exception.Message)" "Error"
        return $false
    }
}

function Start-MainDeployment {
    param([string]$PowerShellPath)
    
    $deployScript = Join-Path $PSScriptRoot "deploy-files.ps1"
    
    if (-not (Test-Path $deployScript)) {
        Write-StatusMessage "Main deployment script not found: $deployScript" "Error"
        return $false
    }
    
    Write-StatusMessage "Opening deployment script in new window..." "Info"
    Write-Host ""
    
    try {
        $arguments = @("-NoExit", "-File", $deployScript)
        if ($Force) {
            $arguments = @("-NoExit", "-Command", "& '$deployScript' -Force; Write-Host ''; Write-Host 'Press any key to close this window...' -ForegroundColor Yellow; Read-Host")
        } else {
            $arguments = @("-NoExit", "-Command", "& '$deployScript'; Write-Host ''; Write-Host 'Press any key to close this window...' -ForegroundColor Yellow; Read-Host")
        }
        
        $process = Start-Process -FilePath $PowerShellPath -ArgumentList $arguments -PassThru
        
        Write-StatusMessage "Deployment script launched in new window (PID: $($process.Id))" "Success"
        Write-StatusMessage "Check the new PowerShell window for deployment progress and results." "Info"
        
        return $true
    } catch {
        Write-StatusMessage "Failed to launch deployment script: $($_.Exception.Message)" "Error"
        return $false
    }
}

# Main execution
function Main {
    Write-Host "Computer Setup Bootstrap" -ForegroundColor Cyan
    Write-Host "========================" -ForegroundColor Cyan
    Write-Host "Current PowerShell: $($PSVersionTable.PSVersion)" -ForegroundColor Gray
    Write-Host ""
    
    # Check for PowerShell 7+
    $pwsh7 = Test-PowerShell7
    
    if ($pwsh7.Found) {
        Write-StatusMessage "PowerShell 7+ found: $($pwsh7.Version)" "Success"
        Write-StatusMessage "Using: $($pwsh7.Path)" "Info"
        Write-Host ""
        
        # Launch main deployment
        $success = Start-MainDeployment -PowerShellPath $pwsh7.Path
        
        if ($success) {
            Write-Host ""
            Write-StatusMessage "Setup completed successfully!" "Success"
        } else {
            Write-StatusMessage "Setup encountered errors. Please check the output above." "Error"
            exit 1
        }
    } else {
        Write-StatusMessage "PowerShell 7+ not found. Installation required." "Warning"
        
        # Install PowerShell 7
        $installSuccess = Install-PowerShell7
        
        if ($installSuccess) {
            Write-Host ""
            Write-StatusMessage "Checking for PowerShell 7+ after installation..." "Info"
            
            # Refresh PATH and check again
            $env:PATH = [System.Environment]::GetEnvironmentVariable("PATH", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("PATH", "User")
            
            $pwsh7 = Test-PowerShell7
            if ($pwsh7.Found) {
                Write-StatusMessage "PowerShell 7+ is now available!" "Success"
                Write-Host ""
                
                # Launch main deployment
                $success = Start-MainDeployment -PowerShellPath $pwsh7.Path
                
                if ($success) {
                    Write-Host ""
                    Write-StatusMessage "Setup completed successfully!" "Success"
                } else {
                    Write-StatusMessage "Setup encountered errors. Please check the output above." "Error"
                    exit 1
                }
            } else {
                Write-StatusMessage "PowerShell 7+ installation completed, but couldn't be detected." "Warning"
                Write-StatusMessage "Please restart your terminal and run: pwsh -File deploy-files.ps1" "Info"
            }
        } else {
            Write-StatusMessage "Failed to install PowerShell 7+. Please install manually and rerun this script." "Error"
            Write-StatusMessage "Download from: https://github.com/PowerShell/PowerShell/releases" "Info"
            exit 1
        }
    }
}

# Run the main function
Main 