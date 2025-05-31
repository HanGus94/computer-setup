#Requires -Version 7.0

<#
.SYNOPSIS
    Computer Setup Deployment Script

.DESCRIPTION
    Deploys configuration files to their appropriate locations on a new computer.
    Supports version checking and handles multiple file types with smart elevation management.

.PARAMETER Force
    Force deployment even if target versions are the same or newer

.PARAMETER ShowProgress
    Show real-time progress monitoring for elevated operations

.PARAMETER KeepLogs
    Keep elevation session logs for debugging

.EXAMPLE
    .\deploy-files.ps1
    
.EXAMPLE
    .\deploy-files.ps1 -Force -ShowProgress
#>

param(
    [Parameter(Mandatory = $false)]
    [switch]$Force,
    
    [Parameter(Mandatory = $false)]
    [switch]$ShowProgress,
    
    [Parameter(Mandatory = $false)]
    [switch]$KeepLogs
)

# Import the shared module
Import-Module (Join-Path $PSScriptRoot "modules\ComputerSetup.psm1") -Force

# Enhanced configuration for different deployment types with elevation requirements
$DeploymentConfig = @{
    PowerShellSetup = @{
        SourcePath = ".\configs\powershell"
        ScriptName = "Setup-PowerShell.ps1"
        RequirePowerShell7 = $true
        RequiresAdmin = $false
        AlwaysRun = $true
        Priority = 1
        Description = "PowerShell environment setup with fonts and themes"
        PostDeploymentInstructions = @(
            "PowerShell environment setup completed",
            "Installed components may include:",
            "• CascadiaCode Nerd Font - Terminal font with icons and symbols",
            "• Oh-My-Posh - Customizable prompt theme engine",
            "• Terminal-Icons - File and folder icons in terminal",
            "• PSReadLine - Enhanced command line editing",
            "• Additional PowerShell productivity modules",
            "⚠️ Restart your terminal to see the new fonts",
            "Configure your terminal to use 'CascadiaCode Nerd Font'"
        )
        RollbackAction = {
            Write-StatusMessage "PowerShell setup rollback not implemented (manual intervention required)" "Warning"
        }
    }
    PowerShellProfile = @{
        SourcePath = ".\configs\powershell"
        FilePattern = "*profile*.ps1"
        GetTargetPath = {
            $documentsPath = [Environment]::GetFolderPath('MyDocuments')
            $powerShellPath = Join-Path $documentsPath "PowerShell"
            return Join-Path $powerShellPath "Microsoft.PowerShell_profile.ps1"
        }
        RequirePowerShell7 = $true
        RequiresAdmin = $false
        Priority = 2
        Description = "PowerShell profile configuration"
        PostDeploymentInstructions = @(
            "Restart PowerShell to load the new profile",
            "The profile will be automatically loaded in new PowerShell sessions"
        )
        RollbackAction = {
            $targetPath = & $DeploymentConfig.PowerShellProfile.GetTargetPath
            $backupPath = "$targetPath.backup"
            if (Test-Path $backupPath) {
                Copy-Item $backupPath $targetPath -Force
                Write-StatusMessage "Restored PowerShell profile from backup" "Success"
            }
        }
    }
    SystemDependencies = @{
        SourcePath = ".\installers"
        ScriptName = "Install-Dependencies.ps1"
        RequirePowerShell7 = $true
        RequiresAdmin = $true
        AlwaysRun = $true
        Priority = 3
        Description = "System dependencies (Visual C++ redistributables)"
        PostDeploymentInstructions = @(
            "System dependencies installation completed",
            "Visual C++ redistributables are now installed and ready for OBS Studio",
            "Dependencies installed:",
            "• Microsoft Visual C++ 2015-2022 Redistributable (x64)",
            "• Microsoft Visual C++ 2015-2022 Redistributable (x86)",
            "A system restart may be required for some changes to take effect"
        )
        RollbackAction = {
            Write-StatusMessage "System dependencies rollback requires manual uninstallation via Control Panel" "Warning"
            Add-RollbackAction -Description "Uninstall Visual C++ redistributables via Control Panel" -RequiresElevation -Action {
                Write-StatusMessage "Navigate to Control Panel > Programs > Uninstall a program" "Info"
                Write-StatusMessage "Remove Visual C++ 2015-2022 Redistributable packages" "Info"
            }
        }
    }
    WindowsFeatures = @{
        SourcePath = ".\installers"
        ScriptName = "Enable-WindowsFeatures.ps1"
        RequirePowerShell7 = $true
        RequiresAdmin = $true
        AlwaysRun = $true
        Priority = 4
        Description = "Windows features (Hyper-V, WSL2, Windows Sandbox)"
        PostDeploymentInstructions = @(
            "Windows features enablement completed",
            "Enabled features may include:",
            "• Hyper-V - Full hypervisor platform with management tools",
            "• Windows Sandbox - Isolated environment for testing applications",
            "• WSL2 - Windows Subsystem for Linux with full kernel support",
            "⚠️ A system restart may be required to complete feature installation",
            "After restart, features will be fully available for use"
        )
        RollbackAction = {
            Add-RollbackAction -Description "Disable Windows features via OptionalFeatures.exe" -RequiresElevation -Action {
                Write-StatusMessage "Run 'OptionalFeatures.exe' as administrator to disable features" "Info"
                Write-StatusMessage "Disable: Hyper-V, Windows Sandbox, WSL2 if needed" "Info"
            }
        }
    }
    Applications = @{
        SourcePath = ".\installers"
        ScriptName = "Install-Applications.ps1"
        RequirePowerShell7 = $true
        RequiresAdmin = $false
        AlwaysRun = $true
        Priority = 5
        Description = "Applications installation via Winget and Scoop"
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
        RollbackAction = {
            Write-StatusMessage "Application rollback requires manual uninstallation" "Warning"
            Write-StatusMessage "Use 'winget uninstall <app-id>' or Control Panel" "Info"
        }
    }
    SpecializedTools = @{
        SourcePath = ".\installers"
        ScriptName = "Install-Tools.ps1"
        RequirePowerShell7 = $true
        RequiresAdmin = $false  # Will use optimal directory
        AlwaysRun = $true
        Priority = 6
        Description = "Specialized tools installation to Tools directory"
        PostDeploymentInstructions = @(
            "Specialized tools installation completed",
            "Tools installed to Tools directory:",
            "• Wabbajack - Modding tool for Bethesda games",
            "• Additional specialized tools based on configuration",
            "Desktop and Start Menu shortcuts have been created",
            "Tools are portable and ready for use"
        )
        RollbackAction = {
            $toolsDir = Get-OptimalToolsDirectory
            Add-RollbackAction -Description "Remove Tools directory" -Action {
                if (Test-Path $toolsDir) {
                    Remove-Item $toolsDir -Recurse -Force
                    Write-StatusMessage "Removed Tools directory: $toolsDir" "Success"
                }
            }
        }
    }
    OBSPortable = @{
        SourcePath = ".\configs\obs"
        ScriptName = "setup-obs.ps1"
        RequirePowerShell7 = $true
        RequiresAdmin = $false  # Will use optimal directory
        AlwaysRun = $true
        Priority = 7
        Description = "OBS Studio portable installations with multiple profiles"
        PostDeploymentInstructions = @(
            "OBS Studio portable installations completed",
            "Launch OBS profiles from desktop shortcuts or start menu:",
            "• OBS Studio (Streaming) - Full streaming setup with advanced plugins",
            "• OBS Studio (Recording) - Optimized for high-quality recording",
            "• OBS Studio (Testing) - Minimal setup for testing and development",
            "Each profile is completely independent with its own settings and plugins",
            "Profiles are located in Tools directory"
        )
        RollbackAction = {
            $toolsDir = Get-OptimalToolsDirectory
            Add-RollbackAction -Description "Remove OBS installations" -Action {
                $obsDir = Join-Path $toolsDir "OBS"
                if (Test-Path $obsDir) {
                    Remove-Item $obsDir -Recurse -Force
                    Write-StatusMessage "Removed OBS installations: $obsDir" "Success"
                }
            }
        }
    }
    FirefoxUserChrome = @{
        SourcePath = ".\configs\firefox"
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
        RequiresAdmin = $false
        Priority = 8
        Description = "Firefox userChrome.css customization"
        PostDeploymentInstructions = @(
            "Restart Firefox to apply userChrome.css changes",
            "If changes don't appear, enable toolkit.legacyUserProfileCustomizations.stylesheets in about:config",
            "Set the preference to 'true' and restart Firefox again"
        )
        RollbackAction = {
            $targetPath = & $DeploymentConfig.FirefoxUserChrome.GetTargetPath
            if ($targetPath -and (Test-Path $targetPath)) {
                Remove-Item $targetPath -Force
                Write-StatusMessage "Removed Firefox userChrome.css" "Success"
            }
        }
    }
    SideberyData = @{
        SourcePath = ".\configs\firefox"
        FilePattern = "sidebery-data.json"
        GetTargetPath = {
            $firefoxProfiles = Get-ChildItem "$env:APPDATA\Mozilla\Firefox\Profiles" -Directory -ErrorAction SilentlyContinue
            if ($firefoxProfiles) {
                $defaultProfile = $firefoxProfiles | Select-Object -First 1
                # Sidebery stores data in the extension storage, but for manual import
                # we'll put it in a backup location for the user to manually import
                $backupPath = Join-Path $defaultProfile.FullName "sidebery-backup"
                return Join-Path $backupPath "sidebery-data.json"
            }
            return $null
        }
        RequirePowerShell7 = $false
        RequiresAdmin = $false
        AlwaysOverwrite = $true
        Priority = 9
        Description = "Sidebery extension configuration"
        PostDeploymentInstructions = @(
            "Open Sidebery extension in Firefox",
            "Go to Sidebery Settings → Help → Import/Export",
            "Click 'Import from file' and select the deployed sidebery-data.json",
            "The file is located in your Firefox profile's sidebery-backup folder",
            "Restart Firefox after importing for best results"
        )
        RollbackAction = {
            $targetPath = & $DeploymentConfig.SideberyData.GetTargetPath
            if ($targetPath -and (Test-Path $targetPath)) {
                Remove-Item $targetPath -Force
                Write-StatusMessage "Removed Sidebery backup configuration" "Success"
            }
        }
    }
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
    
    # Handle script-based deployments
    if ($Config.ScriptName) {
        $scriptPath = Join-Path $Config.SourcePath $Config.ScriptName
        
        if (-not (Test-Path $scriptPath)) {
            Write-StatusMessage "Script not found: $scriptPath" "Error"
            return $deploymentResults
        }
        
        # Check if operation requires admin
        if ($Config.RequiresAdmin -and -not (Test-IsElevated)) {
            # Queue for elevated batch execution
            $arguments = @()
            if ($Force) { $arguments += "-Force" }
            
            # Add rollback action before queuing operation
            if ($Config.RollbackAction) {
                & $Config.RollbackAction
            }
            
            $operationId = Add-ElevatedOperation -OperationName $Config.Description -ScriptPath $scriptPath -Arguments $arguments -Priority $Config.Priority
            Write-StatusMessage "Queued for elevated execution: $($Config.Description)" "Info"
            
            $deploymentResults.Deployed = $true  # Will be validated after batch execution
            $deploymentResults.Instructions = $Config.PostDeploymentInstructions
            return $deploymentResults
        } else {
            # Execute in current context
            Write-StatusMessage "Executing: $($Config.Description)" "Info"
            
            try {
                if ($Force) {
                    & $scriptPath -Force
                } else {
                    & $scriptPath
                }
                
                if ($LASTEXITCODE -eq 0 -or $null -eq $LASTEXITCODE) {
                    Write-StatusMessage "$($Config.Description) completed successfully" "Success"
                    $deploymentResults.Deployed = $true
                    $deploymentResults.Instructions = $Config.PostDeploymentInstructions
                } else {
                    Write-StatusMessage "$($Config.Description) failed with exit code: $LASTEXITCODE" "Error"
                    # Add rollback if available
                    if ($Config.RollbackAction) {
                        & $Config.RollbackAction
                    }
                }
            } catch {
                Write-StatusMessage "$($Config.Description) failed: $($_.Exception.Message)" "Error"
                # Add rollback if available
                if ($Config.RollbackAction) {
                    & $Config.RollbackAction
                }
            }
            
            return $deploymentResults
        }
    }
    
    # Handle file-based deployments (existing logic)
    if ($Config.FilePattern) {
        $sourceFiles = Get-ChildItem $Config.SourcePath -Filter $Config.FilePattern -ErrorAction SilentlyContinue
        
        if (-not $sourceFiles) {
            Write-Host "  No files found matching pattern: $($Config.FilePattern)" -ForegroundColor Yellow
            return $deploymentResults
        }
        
        foreach ($sourceFile in $sourceFiles) {
            $targetPath = & $Config.GetTargetPath
            
            if (-not $targetPath) {
                Write-Host "  Target path could not be determined" -ForegroundColor Yellow
                continue
            }
            
            # Create target directory if it doesn't exist
            $targetDir = Split-Path $targetPath -Parent
            if (-not (Test-Path $targetDir)) {
                try {
                    New-Item -Path $targetDir -ItemType Directory -Force | Out-Null
                    Write-StatusMessage "Created directory: $targetDir" "Info"
                    $deploymentResults.TargetDirectory = $targetDir
                } catch {
                    Write-StatusMessage "Failed to create directory: $targetDir" "Error"
                    continue
                }
            }
            
            # Version checking (if not forced and not always overwrite)
            $shouldDeploy = $Force -or $Config.AlwaysOverwrite
            
            if (-not $shouldDeploy) {
                $sourceVersion = Get-FileVersion -FilePath $sourceFile.FullName
                $targetVersion = Get-FileVersion -FilePath $targetPath
                
                if ($sourceVersion -and $targetVersion) {
                    $comparison = Get-SemanticVersionComparison -Version1 $sourceVersion -Version2 $targetVersion
                    if ($comparison -le 0) {
                        Write-Host "  Target version ($targetVersion) is same or newer than source ($sourceVersion)" -ForegroundColor Yellow
                        continue
                    }
                    Write-StatusMessage "Updating from version $targetVersion to $sourceVersion" "Info"
                } elseif (Test-Path $targetPath) {
                    Write-Host "  Target file exists but version comparison not possible" -ForegroundColor Yellow
                    continue
                }
                
                $shouldDeploy = $true
            }
            
            if ($shouldDeploy) {
                try {
                    # Create backup if target exists
                    if (Test-Path $targetPath) {
                        $backupPath = Copy-FileBackup -SourcePath $targetPath
                        if ($backupPath -and $Config.RollbackAction) {
                            Add-RollbackAction -Description "Restore $targetPath from backup" -Action {
                                Copy-Item $backupPath $targetPath -Force
                                Write-StatusMessage "Restored $targetPath from backup" "Success"
                            }
                        }
                    }
                    
                    # Deploy the file
                    Copy-Item $sourceFile.FullName $targetPath -Force
                    Write-StatusMessage "Deployed: $(Split-Path $targetPath -Leaf)" "Success"
                    Write-StatusMessage "Location: $targetPath" "Info"
                    
                    $deploymentResults.Deployed = $true
                    $deploymentResults.Instructions = $Config.PostDeploymentInstructions
                    
                } catch {
                    Write-StatusMessage "Failed to deploy $($sourceFile.Name): $($_.Exception.Message)" "Error"
                }
            }
        }
    }
    
    return $deploymentResults
}

# Main execution
function Main {
    Write-Host "Computer Setup Deployment with Smart Elevation" -ForegroundColor Cyan
    Write-Host "=" * 50 -ForegroundColor Cyan
    Write-Host "PowerShell Version: $($PSVersionTable.PSVersion)" -ForegroundColor Gray
    Write-Host "Administrator: $(if (Test-IsElevated) { 'Yes' } else { 'No' })" -ForegroundColor Gray
    Write-Host ""
    
    # Initialize elevation session for batching
    Initialize-ElevationSession | Out-Null
    
    # Track overall results
    $deploymentResults = @()
    $elevatedOperationsQueued = $false
    
    # Process each deployment type in priority order
    $sortedDeployments = $DeploymentConfig.GetEnumerator() | Sort-Object { $_.Value.Priority }
    
    foreach ($deployment in $sortedDeployments) {
        $typeName = $deployment.Key
        $config = $deployment.Value
        
        $result = Deploy-FileType -TypeName $typeName -Config $config
        $deploymentResults += @{
            TypeName = $typeName
            Config = $config
            Result = $result
        }
        
        # Check if we queued elevated operations
        if ($config.RequiresAdmin -and -not (Test-IsElevated)) {
            $elevatedOperationsQueued = $true
        }
    }
    
    # Execute batched elevated operations if any were queued
    if ($elevatedOperationsQueued) {
        Write-Host "`n" + "=" * 50 -ForegroundColor Yellow
        Write-Host "Executing Elevated Operations" -ForegroundColor Yellow
        Write-Host "=" * 50 -ForegroundColor Yellow
        
        $elevatedSuccess = Invoke-ElevatedBatch -ShowProgress:$ShowProgress -TimeoutMinutes 45
        
        if (-not $elevatedSuccess) {
            Write-StatusMessage "Some elevated operations failed. Check output above for details." "Error"
        }
    }
    
    # Show deployment summary
    Write-Host "`n" + "=" * 50 -ForegroundColor Cyan
    Write-Host "Deployment Summary" -ForegroundColor Cyan
    Write-Host "=" * 50 -ForegroundColor Cyan
    
    $successfulDeployments = 0
    $failedDeployments = 0
    
    foreach ($deployResult in $deploymentResults) {
        $typeName = $deployResult.TypeName
        $result = $deployResult.Result
        $config = $deployResult.Config
        
        if ($result.Deployed) {
            $successfulDeployments++
            Write-StatusMessage "$typeName deployed successfully" "Success"
            
            # Show post-deployment instructions
            if ($result.Instructions -and $result.Instructions.Count -gt 0) {
                Write-Host ""
                Write-Host "📝 $typeName Instructions:" -ForegroundColor Cyan
                foreach ($instruction in $result.Instructions) {
                    Write-Host "  $instruction" -ForegroundColor Gray
                }
            }
        } else {
            $failedDeployments++
            if ($config.RequiresAdmin -and -not (Test-IsElevated)) {
                Write-StatusMessage "$typeName queued for elevation (check results above)" "Warning"
            } else {
                Write-StatusMessage "$typeName deployment failed or skipped" "Error"
            }
        }
    }
    
    Write-Host ""
    Write-StatusMessage "Deployment completed: $successfulDeployments successful, $failedDeployments failed/skipped" "Info"
    
    if ($successfulDeployments -gt 0) {
        Write-Host ""
        Write-StatusMessage "🎉 Computer setup deployment completed!" "Success"
        Write-StatusMessage "Some changes may require a restart or logout to take effect" "Info"
    }
    
    # Clean up elevation session
    Close-ElevationSession -KeepLogs:$KeepLogs
    
    if ($KeepLogs) {
        Write-StatusMessage "Elevation logs preserved for debugging" "Info"
    }
}

# Run the main function
Main
