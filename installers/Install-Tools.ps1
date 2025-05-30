#Requires -Version 7.0

<#
.SYNOPSIS
    Specialized Tools Installation Script

.DESCRIPTION
    Downloads and installs specialized tools from GitHub releases to C:\Tools directory.
    Creates desktop shortcuts and Start Menu entries for easy access.

.PARAMETER Force
    Force reinstallation even if tools are already installed

.PARAMETER SkipWabbajack
    Skip Wabbajack modding tool installation

.PARAMETER ToolsDirectory
    Custom directory for tool installation (default: C:\Tools)

.PARAMETER GitHubToken
    GitHub personal access token for authenticated API requests (optional)

.EXAMPLE
    .\Install-Tools.ps1
    
.EXAMPLE
    .\Install-Tools.ps1 -Force
    
.EXAMPLE
    .\Install-Tools.ps1 -SkipWabbajack
    
.EXAMPLE
    .\Install-Tools.ps1 -ToolsDirectory "D:\MyTools"
#>

param(
    [Parameter(Mandatory = $false)]
    [switch]$Force,
    
    [Parameter(Mandatory = $false)]
    [switch]$SkipWabbajack,
    
    [Parameter(Mandatory = $false)]
    [string]$ToolsDirectory = "C:\Tools",
    
    [Parameter(Mandatory = $false)]
    [string]$GitHubToken
)

# Import the shared module
Import-Module (Join-Path (Split-Path -Parent $PSScriptRoot) "modules\ComputerSetup.psm1") -Force

# Tool configurations
$ToolConfigurations = @{
    Wabbajack = @{
        Name = "Wabbajack"
        Repository = "wabbajack-tools/wabbajack"
        FilePattern = "Wabbajack.exe"
        Description = "Modding tool for Bethesda games"
        ExecutableName = "Wabbajack.exe"
        ShortcutName = "Wabbajack"
        CreateShortcuts = $true
        Essential = $true
    }
}

function Test-ToolInstalled {
    param(
        [string]$ToolName,
        [string]$ToolPath
    )
    
    $executablePath = Join-Path $ToolPath $ToolConfigurations[$ToolName].ExecutableName
    return Test-Path $executablePath
}

function Install-Tool {
    param(
        [string]$ToolName,
        [hashtable]$ToolConfig
    )
    
    Write-StatusMessage "Installing $($ToolConfig.Name)..." "Info"
    
    $toolPath = Join-Path $ToolsDirectory $ToolName
    
    # Check if already installed (unless Force is specified)
    if (-not $Force) {
        if (Test-ToolInstalled -ToolName $ToolName -ToolPath $toolPath) {
            Write-StatusMessage "$($ToolConfig.Name) is already installed" "Success"
            return $true
        }
    }
    
    try {
        # Get latest release information
        $releaseInfo = Get-GitHubLatestRelease -Repository $ToolConfig.Repository -FilePattern $ToolConfig.FilePattern -GitHubToken $GitHubToken
        
        if (-not $releaseInfo) {
            Write-StatusMessage "Failed to get release information for $($ToolConfig.Name)" "Error"
            return $false
        }
        
        Write-StatusMessage "Found $($ToolConfig.Name) version $($releaseInfo.Version)" "Info"
        Write-StatusMessage "File: $($releaseInfo.FileName) ($('{0:N2}' -f ($releaseInfo.Size / 1MB)) MB)" "Info"
        
        # Create tool directory
        if (-not (Test-Path $toolPath)) {
            New-Item -Path $toolPath -ItemType Directory -Force | Out-Null
            Write-StatusMessage "Created directory: $toolPath" "Info"
        }
        
        # Download the tool
        $downloadPath = Join-Path $env:TEMP $releaseInfo.FileName
        
        if (-not (Invoke-FileDownload -Url $releaseInfo.DownloadUrl -OutputPath $downloadPath -Description $ToolConfig.Name)) {
            throw "Failed to download $($ToolConfig.Name)"
        }
        
        # Install the tool (copy executable)
        $targetPath = Join-Path $toolPath $ToolConfig.ExecutableName
        Copy-Item $downloadPath $targetPath -Force
        
        Write-StatusMessage "$($ToolConfig.Name) installed to: $targetPath" "Success"
        
        # Create shortcuts if requested
        if ($ToolConfig.CreateShortcuts) {
            Create-Shortcuts -ToolName $ToolName -ToolConfig $ToolConfig -ExecutablePath $targetPath
        }
        
        # Cleanup
        if (Test-Path $downloadPath) {
            Remove-Item $downloadPath -Force -ErrorAction SilentlyContinue
        }
        
        return $true
        
    } catch {
        Write-StatusMessage "Failed to install $($ToolConfig.Name): $($_.Exception.Message)" "Error"
        return $false
    }
}

function Create-Shortcuts {
    param(
        [string]$ToolName,
        [hashtable]$ToolConfig,
        [string]$ExecutablePath
    )
    
    try {
        $shell = New-Object -ComObject WScript.Shell
        
        # Desktop shortcut
        $desktopPath = [Environment]::GetFolderPath('Desktop')
        $desktopShortcut = Join-Path $desktopPath "$($ToolConfig.ShortcutName).lnk"
        
        $shortcut = $shell.CreateShortcut($desktopShortcut)
        $shortcut.TargetPath = $ExecutablePath
        $shortcut.WorkingDirectory = Split-Path $ExecutablePath -Parent
        $shortcut.Description = $ToolConfig.Description
        $shortcut.Save()
        
        Write-StatusMessage "Created desktop shortcut: $($ToolConfig.ShortcutName)" "Success"
        
        # Start Menu shortcut
        $startMenuPath = Join-Path $env:APPDATA "Microsoft\Windows\Start Menu\Programs"
        $startMenuShortcut = Join-Path $startMenuPath "$($ToolConfig.ShortcutName).lnk"
        
        $shortcut = $shell.CreateShortcut($startMenuShortcut)
        $shortcut.TargetPath = $ExecutablePath
        $shortcut.WorkingDirectory = Split-Path $ExecutablePath -Parent
        $shortcut.Description = $ToolConfig.Description
        $shortcut.Save()
        
        Write-StatusMessage "Created Start Menu shortcut: $($ToolConfig.ShortcutName)" "Success"
        
    } catch {
        Write-StatusMessage "Warning: Failed to create shortcuts for $($ToolConfig.Name): $($_.Exception.Message)" "Warning"
    }
}

function Get-ToolsToInstall {
    $toolsToInstall = @()
    
    foreach ($tool in $ToolConfigurations.GetEnumerator()) {
        $toolName = $tool.Key
        $toolConfig = $tool.Value
        
        # Check skip flags
        $skipTool = $false
        switch ($toolName) {
            "Wabbajack" { $skipTool = $SkipWabbajack }
        }
        
        if ($skipTool) {
            Write-StatusMessage "Skipping $($toolConfig.Name)" "Warning"
            continue
        }
        
        $toolsToInstall += @{
            Name = $toolName
            Config = $toolConfig
        }
    }
    
    return $toolsToInstall
}

# Main execution
function Main {
    Write-Host "Specialized Tools Installation" -ForegroundColor Cyan
    Write-Host "=============================" -ForegroundColor Cyan
    Write-Host "PowerShell Version: $($PSVersionTable.PSVersion)" -ForegroundColor Gray
    Write-Host "Tools Directory: $ToolsDirectory" -ForegroundColor Gray
    Write-Host ""
    
    # Create tools directory if it doesn't exist
    if (-not (Test-Path $ToolsDirectory)) {
        try {
            New-Item -Path $ToolsDirectory -ItemType Directory -Force | Out-Null
            Write-StatusMessage "Created tools directory: $ToolsDirectory" "Success"
        } catch {
            Write-StatusMessage "Failed to create tools directory: $($_.Exception.Message)" "Error"
            exit 1
        }
    }
    
    # Get list of tools to install
    $toolsToInstall = Get-ToolsToInstall
    
    if ($toolsToInstall.Count -eq 0) {
        Write-StatusMessage "No tools selected for installation" "Warning"
        return
    }
    
    Write-Host "`n🔧 Tools to Install" -ForegroundColor Cyan
    Write-Host "==================" -ForegroundColor Cyan
    foreach ($tool in $toolsToInstall) {
        $essentialText = if ($tool.Config.Essential) { " (Essential)" } else { "" }
        Write-Host "  • $($tool.Config.Name)$essentialText" -ForegroundColor Gray
        Write-Host "    $($tool.Config.Description)" -ForegroundColor DarkGray
        Write-Host "    Repository: $($tool.Config.Repository)" -ForegroundColor Magenta
    }
    Write-Host ""
    
    # Install tools
    $successful = 0
    $failed = 0
    $failedTools = @()
    
    foreach ($tool in $toolsToInstall) {
        if (Install-Tool -ToolName $tool.Name -ToolConfig $tool.Config) {
            $successful++
        } else {
            $failed++
            $failedTools += $tool.Config.Name
        }
    }
    
    # Summary
    Write-Host "`n" -NoNewline
    Write-Host "🛠️ Tools Installation Summary" -ForegroundColor Cyan
    Write-Host "=============================" -ForegroundColor Cyan
    
    if ($successful -gt 0) {
        Write-StatusMessage "Successfully installed $successful tool(s)" "Success"
    }
    
    if ($failed -gt 0) {
        Write-StatusMessage "Failed to install $failed tool(s)" "Error"
        Write-Host "Failed tools:" -ForegroundColor Red
        foreach ($failedTool in $failedTools) {
            Write-Host "  • $failedTool" -ForegroundColor Red
        }
        Write-Host ""
        Write-StatusMessage "Check the errors above for troubleshooting information" "Info"
    }
    
    if ($successful -gt 0) {
        Write-Host ""
        Write-StatusMessage "🎉 Tools installed successfully!" "Success"
        Write-StatusMessage "Tools are located in: $ToolsDirectory" "Info"
        Write-StatusMessage "Desktop and Start Menu shortcuts have been created" "Info"
        Write-StatusMessage "Tools are portable and ready for use" "Info"
    }
}

# Run the main function
Main 