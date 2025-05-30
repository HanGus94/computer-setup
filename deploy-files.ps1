#Requires -Version 7.0

<#
.SYNOPSIS
    Computer Setup Deployment Script

.DESCRIPTION
    Deploys configuration files to their appropriate locations on a new computer.
    Supports version checking and handles multiple file types.

.PARAMETER Force
    Force deployment even if target versions are the same or newer

.EXAMPLE
    .\setup.ps1
    
.EXAMPLE
    .\setup.ps1 -Force
#>

param(
    [Parameter(Mandatory = $false)]
    [switch]$Force
)

# Configuration for different deployment types
$DeploymentConfig = @{
    PowerShellProfile = @{
        SourcePath = ".\powershell"
        FilePattern = "*profile*.ps1"
        GetTargetPath = {
            $documentsPath = [Environment]::GetFolderPath('MyDocuments')
            $powerShellPath = Join-Path $documentsPath "PowerShell"
            return Join-Path $powerShellPath "Microsoft.PowerShell_profile.ps1"
        }
        RequirePowerShell7 = $true
        PostDeploymentInstructions = @(
            "Restart PowerShell to load the new profile",
            "The profile will be automatically loaded in new PowerShell sessions"
        )
    }
    FirefoxUserChrome = @{
        SourcePath = ".\firefox"
        FilePattern = "userChrome.css"
        GetTargetPath = {
            $firefoxProfiles = Get-ChildItem "$env:APPDATA\Mozilla\Firefox\Profiles" -Directory -ErrorAction SilentlyContinue
            if ($firefoxProfiles) {
                $defaultProfile = $firefoxProfiles | Select-Object -First 1
                $chromePath = Join-Path $defaultProfile.FullName "chrome"
                return Join-Path $chromePath "userChrome.css"
            }
            return $null
        }
        RequirePowerShell7 = $false
        PostDeploymentInstructions = @(
            "Restart Firefox to apply userChrome.css changes",
            "If changes don't appear, enable toolkit.legacyUserProfileCustomizations.stylesheets in about:config",
            "Set the preference to 'true' and restart Firefox again"
        )
    }
    SideberyData = @{
        SourcePath = ".\firefox"
        FilePattern = "sidebery-data.json"
        GetTargetPath = {
            $firefoxProfiles = Get-ChildItem "$env:APPDATA\Mozilla\Firefox\Profiles" -Directory -ErrorAction SilentlyContinue
            if ($firefoxProfiles) {
                $defaultProfile = $firefoxProfiles | Select-Object -First 1
                # Sidebery stores data in the extension storage
                $sideberyPath = Join-Path $defaultProfile.FullName "storage\default\moz-extension+++*\idb"
                # For manual import, we'll put it in a backup location for the user to manually import
                $backupPath = Join-Path $defaultProfile.FullName "sidebery-backup"
                return Join-Path $backupPath "sidebery-data.json"
            }
            return $null
        }
        RequirePowerShell7 = $false
        AlwaysOverwrite = $true
        PostDeploymentInstructions = @(
            "Open Sidebery extension in Firefox",
            "Go to Sidebery Settings → Help → Import/Export",
            "Click 'Import from file' and select the deployed sidebery-data.json",
            "The file is located in your Firefox profile's sidebery-backup folder",
            "Restart Firefox after importing for best results"
        )
    }
    OBSPortable = @{
        SourcePath = ".\obs"
        ScriptName = "setup-obs.ps1"
        RequirePowerShell7 = $true
        AlwaysRun = $true
        PostDeploymentInstructions = @(
            "OBS Studio portable installations completed",
            "Launch OBS profiles from desktop shortcuts or start menu:",
            "• OBS Studio (Streaming) - Full streaming setup with advanced plugins",
            "• OBS Studio (Recording) - Optimized for high-quality recording",
            "• OBS Studio (Testing) - Minimal setup for testing and development",
            "Each profile is completely independent with its own settings and plugins",
            "Profiles are located in C:\Tools\ directory"
        )
    }
    SystemDependencies = @{
        SourcePath = "."
        ScriptName = "Install-Dependencies.ps1"
        RequirePowerShell7 = $true
        AlwaysRun = $true
        PostDeploymentInstructions = @(
            "System dependencies installation completed",
            "Visual C++ redistributables are now installed and ready for OBS Studio",
            "Dependencies installed:",
            "• Microsoft Visual C++ 2015-2022 Redistributable (x64)",
            "• Microsoft Visual C++ 2015-2022 Redistributable (x86)",
            "A system restart may be required for some changes to take effect"
        )
    }
    Applications = @{
        SourcePath = "."
        ScriptName = "Install-Applications.ps1"
        RequirePowerShell7 = $true
        AlwaysRun = $true
        PostDeploymentInstructions = @(
            "Application installation completed using Windows Package Manager (Winget)",
            "Applications installed include browsers, development tools, and utilities",
            "Installed applications:",
            "• Mozilla Firefox - Privacy-focused web browser",
            "• 7-Zip - File archiver and compression tool",
            "• Additional tools based on your selection",
            "Check your Start Menu and desktop for new application shortcuts",
            "Some applications may require a restart to work properly"
        )
    }
}

# Simple semantic version comparison
function Compare-Version {
    param([string]$Version1, [string]$Version2)
    
    if (-not $Version1 -and -not $Version2) { return 0 }
    if (-not $Version1) { return -1 }
    if (-not $Version2) { return 1 }
    
    $v1 = $Version1 -replace '^v?', '' -split '\.' | ForEach-Object { [int]$_ }
    $v2 = $Version2 -replace '^v?', '' -split '\.' | ForEach-Object { [int]$_ }
    
    for ($i = 0; $i -lt [Math]::Max($v1.Length, $v2.Length); $i++) {
        $val1 = if ($i -lt $v1.Length) { $v1[$i] } else { 0 }
        $val2 = if ($i -lt $v2.Length) { $v2[$i] } else { 0 }
        
        if ($val1 -lt $val2) { return -1 }
        if ($val1 -gt $val2) { return 1 }
    }
    return 0
}

# Extract version from file content
function Get-FileVersion {
    param([string]$FilePath)
    
    if (-not (Test-Path $FilePath)) { return $null }
    
    $content = Get-Content $FilePath -Raw -ErrorAction SilentlyContinue
    if (-not $content) { return $null }
    
    # Get file extension to determine comment format
    $extension = [System.IO.Path]::GetExtension($FilePath).ToLower()
    
    # Define version patterns for different file types
    $versionPatterns = switch ($extension) {
        '.css' {
            @(
                '/\*[^*]*Version[:\s]*([v]?\d+(?:\.\d+)*(?:-[a-zA-Z0-9\-\.]+)?)[^*]*\*/',
                '/\*[^*]*@version\s+([v]?\d+(?:\.\d+)*(?:-[a-zA-Z0-9\-\.]+)?)[^*]*\*/'
            )
        }
        '.ps1' {
            @(
                '#.*[Vv]ersion[:\s]*([v]?\d+(?:\.\d+)*(?:-[a-zA-Z0-9\-\.]+)?)',
                '<#[^#]*[Vv]ersion[:\s]*([v]?\d+(?:\.\d+)*(?:-[a-zA-Z0-9\-\.]+)?)[^#]*#>'
            )
        }
        default {
            @(
                '#.*[Vv]ersion[:\s]*([v]?\d+(?:\.\d+)*(?:-[a-zA-Z0-9\-\.]+)?)',
                '/\*[^*]*[Vv]ersion[:\s]*([v]?\d+(?:\.\d+)*(?:-[a-zA-Z0-9\-\.]+)?)[^*]*\*/',
                '//.*[Vv]ersion[:\s]*([v]?\d+(?:\.\d+)*(?:-[a-zA-Z0-9\-\.]+)?)'
            )
        }
    }
    
    # Try each pattern
    foreach ($pattern in $versionPatterns) {
        if ($content -match $pattern) {
            return $Matches[1]
        }
    }
    
    return $null
}

# Create backup of existing file
function Backup-File {
    param([string]$FilePath)
    
    if (Test-Path $FilePath) {
        $backupPath = "$FilePath.backup.$(Get-Date -Format 'yyyyMMdd-HHmmss')"
        Copy-Item $FilePath $backupPath -Force
        Write-Host "  Backed up existing file to: $(Split-Path $backupPath -Leaf)" -ForegroundColor Yellow
        return $backupPath
    }
    return $null
}

# Deploy a single file type
function Deploy-FileType {
    param(
        [string]$TypeName,
        [hashtable]$Config
    )
    
    Write-Host "`n[$TypeName]" -ForegroundColor Cyan
    
    $deploymentResults = @{
        Deployed = $false
        Instructions = @()
        TargetDirectory = $null
    }
    
    # Check PowerShell version requirement
    if ($Config.RequirePowerShell7 -and $PSVersionTable.PSVersion.Major -lt 7) {
        Write-Host "  Skipped: Requires PowerShell 7+" -ForegroundColor Yellow
        return $deploymentResults
    }
    
    # Check source directory
    if (-not (Test-Path $Config.SourcePath)) {
        Write-Host "  Skipped: Source path '$($Config.SourcePath)' not found" -ForegroundColor Yellow
        return $deploymentResults
    }
    
    # Handle script-based deployment
    if ($Config.ScriptName) {
        $scriptPath = Join-Path $Config.SourcePath $Config.ScriptName
        if (-not (Test-Path $scriptPath)) {
            Write-Host "  Skipped: Script '$($Config.ScriptName)' not found" -ForegroundColor Yellow
            return $deploymentResults
        }
        
        Write-Host "  Executing: $($Config.ScriptName)" -ForegroundColor Green
        
        try {
            # Execute the script
            $scriptArgs = @()
            if ($Force) {
                $scriptArgs += "-Force"
            }
            
            & $scriptPath @scriptArgs
            
            Write-Host "  Script executed successfully" -ForegroundColor Green
            
            $deploymentResults.Deployed = $true
            $deploymentResults.Instructions += $Config.PostDeploymentInstructions
            $deploymentResults.TargetDirectory = Split-Path $scriptPath -Parent
            
        } catch {
            Write-Host "  Error executing script: $($_.Exception.Message)" -ForegroundColor Red
        }
        
        return $deploymentResults
    }
    
    # Find source files (original file-based logic)
    $sourceFiles = Get-ChildItem -Path $Config.SourcePath -Filter $Config.FilePattern -ErrorAction SilentlyContinue
    if (-not $sourceFiles) {
        Write-Host "  Skipped: No files matching '$($Config.FilePattern)' found" -ForegroundColor Yellow
        return $deploymentResults
    }
    
    foreach ($sourceFile in $sourceFiles) {
        # Get target path
        $targetPath = & $Config.GetTargetPath
        if (-not $targetPath) {
            Write-Host "  Skipped: Could not determine target path" -ForegroundColor Yellow
            continue
        }
        
        Write-Host "  Processing: $($sourceFile.Name)" -ForegroundColor Green
        
        # Get versions
        $sourceVersion = Get-FileVersion $sourceFile.FullName
        $targetVersion = Get-FileVersion $targetPath
        
        if (-not $Config.AlwaysOverwrite) {
            Write-Host "    Source version: $(if ($sourceVersion) { $sourceVersion } else { 'None' })" -ForegroundColor Gray
            Write-Host "    Target version: $(if ($targetVersion) { $targetVersion } else { 'None' })" -ForegroundColor Gray
        } else {
            Write-Host "    Mode: Always overwrite (version checking disabled)" -ForegroundColor Gray
        }
        
        # Decide whether to deploy
        $shouldDeploy = $true
        $reason = "No existing file"
        
        if (Test-Path $targetPath) {
            if ($Config.AlwaysOverwrite) {
                $reason = "Always overwrite enabled"
            } else {
                $comparison = Compare-Version $sourceVersion $targetVersion
                if ($comparison -gt 0) {
                    $reason = "Source is newer"
                } elseif ($comparison -eq 0) {
                    if ($Force) {
                        $reason = "Force deployment"
                    } else {
                        $shouldDeploy = $false
                        $reason = "Same version (use -Force to override)"
                    }
                } else {
                    $shouldDeploy = $false
                    $reason = "Target is newer or equal"
                }
            }
        }
        
        Write-Host "    Decision: $reason" -ForegroundColor $(if ($shouldDeploy) { "Green" } else { "Yellow" })
        
        if ($shouldDeploy) {
            try {
                # Create target directory if needed
                $targetDir = Split-Path $targetPath -Parent
                if (-not (Test-Path $targetDir)) {
                    New-Item -Path $targetDir -ItemType Directory -Force | Out-Null
                    Write-Host "    Created directory: $targetDir" -ForegroundColor Gray
                }
                
                # Backup existing file
                Backup-File $targetPath
                
                # Deploy new file
                Copy-Item $sourceFile.FullName $targetPath -Force
                Write-Host "    Deployed to: $targetPath" -ForegroundColor Green
                
                $deploymentResults.Deployed = $true
                $deploymentResults.Instructions += $Config.PostDeploymentInstructions
                $deploymentResults.TargetDirectory = $targetDir
                
            } catch {
                Write-Host "    Error: $($_.Exception.Message)" -ForegroundColor Red
            }
        }
    }
    
    return $deploymentResults
}

# Main deployment function
function Start-Deployment {
    Write-Host "Computer Setup Deployment" -ForegroundColor Cyan
    Write-Host "=========================" -ForegroundColor Cyan
    Write-Host "PowerShell Version: $($PSVersionTable.PSVersion)" -ForegroundColor Gray
    
    $allInstructions = @()
    $deployedItems = @()
    
    # Define deployment order to ensure dependencies are installed first
    $deploymentOrder = @(
        "SystemDependencies",
        "Applications",
        "PowerShellProfile", 
        "FirefoxUserChrome",
        "SideberyData",
        "OBSPortable"
    )
    
    foreach ($deploymentTypeName in $deploymentOrder) {
        if ($DeploymentConfig.ContainsKey($deploymentTypeName)) {
            $results = Deploy-FileType -TypeName $deploymentTypeName -Config $DeploymentConfig[$deploymentTypeName]
            if ($results.Deployed) {
                $deployedItems += $deploymentTypeName
                $allInstructions += @{
                    Type = $deploymentTypeName
                    Instructions = $results.Instructions
                    TargetDirectory = $results.TargetDirectory
                }
            }
        }
    }
    
    # Deploy any additional types not in the ordered list
    foreach ($deploymentType in $DeploymentConfig.GetEnumerator()) {
        if ($deploymentType.Key -notin $deploymentOrder) {
            $results = Deploy-FileType -TypeName $deploymentType.Key -Config $deploymentType.Value
            if ($results.Deployed) {
                $deployedItems += $deploymentType.Key
                $allInstructions += @{
                    Type = $deploymentType.Key
                    Instructions = $results.Instructions
                    TargetDirectory = $results.TargetDirectory
                }
            }
        }
    }
    
    Write-Host "`n" -NoNewline
    Write-Host "🎉 Deployment Summary" -ForegroundColor Cyan
    Write-Host "===================" -ForegroundColor Cyan
    
    if ($deployedItems.Count -gt 0) {
        Write-Host "Successfully deployed:" -ForegroundColor Green
        foreach ($item in $deployedItems) {
            Write-Host "  ✅ $item" -ForegroundColor Green
        }
        
        if ($allInstructions.Count -gt 0) {
            Write-Host "`n📋 Post-Deployment Instructions" -ForegroundColor Yellow
            Write-Host "===============================" -ForegroundColor Yellow
            
            foreach ($instructionSet in $allInstructions) {
                Write-Host "`n[$($instructionSet.Type)]" -ForegroundColor Cyan
                if ($instructionSet.TargetDirectory) {
                    Write-Host "  📁 Target folder: $($instructionSet.TargetDirectory)" -ForegroundColor Yellow
                    Write-Host "     (Copy this path to File Explorer for easy navigation)" -ForegroundColor DarkGray
                }
                foreach ($instruction in $instructionSet.Instructions) {
                    Write-Host "  • $instruction" -ForegroundColor Gray
                }
            }
        }
        
        Write-Host "`n🔔 Important: Follow the instructions above to complete the setup!" -ForegroundColor Yellow
    } else {
        Write-Host "No items were deployed. Check the output above for details." -ForegroundColor Yellow
    }
}

# Run the deployment
Start-Deployment
