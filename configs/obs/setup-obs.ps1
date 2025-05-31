#Requires -Version 7.0

<#
.SYNOPSIS
    OBS Studio Portable Setup Script

.DESCRIPTION
    Downloads and configures multiple portable OBS Studio installations with different profiles:
    - Streaming Profile: Full setup with advanced plugins for live streaming
    - Recording Profile: Optimized for high-quality local recording
    - Testing Profile: Minimal setup for testing and development
    
    Automatically selects optimal Tools directory based on admin privileges.

.PARAMETER Force
    Force reinstallation even if OBS is already installed

.PARAMETER SkipStreaming
    Skip the streaming profile installation

.PARAMETER SkipRecording
    Skip the recording profile installation

.PARAMETER SkipTesting
    Skip the testing profile installation

.PARAMETER ToolsDirectory
    Custom tools directory path (overrides automatic selection)

.PARAMETER GitHubToken
    GitHub personal access token for authenticated API requests (optional)

.EXAMPLE
    .\setup-obs.ps1
    
.EXAMPLE
    .\setup-obs.ps1 -Force
    
.EXAMPLE
    .\setup-obs.ps1 -SkipTesting
#>

param(
    [Parameter(Mandatory = $false)]
    [switch]$Force,
    
    [Parameter(Mandatory = $false)]
    [switch]$SkipStreaming,
    
    [Parameter(Mandatory = $false)]
    [switch]$SkipRecording,
    
    [Parameter(Mandatory = $false)]
    [switch]$SkipTesting,
    
    [Parameter(Mandatory = $false)]
    [string]$ToolsDirectory,
    
    [Parameter(Mandatory = $false)]
    [string]$GitHubToken
)

# Import the shared module
Import-Module (Join-Path (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)) "modules\ComputerSetup.psm1") -Force

# Determine optimal tools directory
if ([string]::IsNullOrEmpty($ToolsDirectory)) {
    $ToolsDirectory = Get-OptimalToolsDirectory
}

# Load configuration from JSON file
$configPath = Join-Path $PSScriptRoot "obs-profiles.json"

if (-not (Test-Path $configPath)) {
    Write-StatusMessage "Configuration file not found: $configPath" "Error"
    exit 1
}

try {
    $config = Get-Content $configPath -Raw | ConvertFrom-Json
}
catch {
    Write-StatusMessage "Failed to parse configuration file: $($_.Exception.Message)" "Error"
    exit 1
}

function Get-LatestRelease {
    param(
        [string]$Repository,
        [string]$FilePattern
    )
    
    $releaseInfo = Get-GitHubLatestRelease -Repository $Repository -FilePattern $FilePattern -GitHubToken $GitHubToken
    
    if ($releaseInfo) {
        return @{
            Name = $releaseInfo.FileName
            DownloadUrl = $releaseInfo.DownloadUrl
            Size = $releaseInfo.Size
            Version = $releaseInfo.Version
        }
    }
    
    return $null
}

function Expand-ArchiveFile {
    param(
        [string]$ArchivePath,
        [string]$DestinationPath,
        [string]$Description = "archive"
    )
    
    try {
        Write-StatusMessage "Extracting $Description..." "Info"
        
        if (-not (Test-Path $DestinationPath)) {
            New-Item -Path $DestinationPath -ItemType Directory -Force | Out-Null
        }
        
        # Use .NET for ZIP extraction (PowerShell 7+ has better compression support)
        if ($ArchivePath.EndsWith('.zip')) {
            Expand-Archive -Path $ArchivePath -DestinationPath $DestinationPath -Force
        } else {
            throw "Unsupported archive format: $ArchivePath"
        }
        
        return $true
    }
    catch {
        Write-StatusMessage "Failed to extract $Description`: $($_.Exception.Message)" "Error"
        return $false
    }
}

function Get-PluginDownload {
    param(
        [PSCustomObject]$Plugin
    )
    
    try {
        $originalProgressPreference = $ProgressPreference
        $ProgressPreference = 'SilentlyContinue'
        
        # Determine download method
        $downloadMethod = if ($Plugin.downloadMethod) { $Plugin.downloadMethod } else { "github" }
        
        switch ($downloadMethod.ToLower()) {
            "github" {
                if (-not $Plugin.repo) {
                    throw "GitHub download method requires 'repo' field"
                }
                if (-not $Plugin.filePattern) {
                    throw "GitHub download method requires 'filePattern' field"
                }
                
                Write-StatusMessage "Getting latest release from $($Plugin.repo)..." "Info"
                
                # Prepare headers for authentication if token is provided
                $headers = @{}
                if ($GitHubToken) {
                    $headers['Authorization'] = "token $GitHubToken"
                }
                
                $releases = if ($headers.Count -gt 0) {
                    Invoke-RestMethod "https://api.github.com/repos/$($Plugin.repo)/releases/latest" -Headers $headers
                } else {
                    Invoke-RestMethod "https://api.github.com/repos/$($Plugin.repo)/releases/latest"
                }
                
                $asset = $releases.assets | Where-Object { $_.name -like $Plugin.filePattern } | Select-Object -First 1
                
                if (-not $asset) {
                    throw "No asset matching pattern '$($Plugin.filePattern)' found in $($Plugin.repo)"
                }
                
                return @{
                    Name = $asset.name
                    DownloadUrl = $asset.browser_download_url
                    Size = $asset.size
                    Version = $releases.tag_name
                    Method = "github"
                }
            }
            
            "direct" {
                if (-not $Plugin.url) {
                    throw "Direct download method requires 'url' field"
                }
                
                $filename = if ($Plugin.filename) { $Plugin.filename } else { Split-Path $Plugin.url -Leaf }
                
                # Try to get file size from headers
                $size = 0
                try {
                    $response = Invoke-WebRequest -Uri $Plugin.url -Method Head -UseBasicParsing
                    $size = [int64]$response.Headers.'Content-Length'[0]
                } catch {
                    # Size unknown
                }
                
                return @{
                    Name = $filename
                    DownloadUrl = $Plugin.url
                    Size = $size
                    Version = "direct"
                    Method = "direct"
                }
            }
            
            "obsproject" {
                # For OBS Project forum downloads with resource ID
                if (-not $Plugin.resourceId) {
                    throw "OBS Project download method requires 'resourceId' field"
                }
                
                # Construct download URL using the pattern: 
                # https://obsproject.com/forum/resources/{resourceId}/version/{version}/download?file={fileId}
                $downloadUrl = "https://obsproject.com/forum/resources/$($Plugin.resourceId)/download"
                
                # Add version if specified
                if ($Plugin.version) {
                    $downloadUrl = "https://obsproject.com/forum/resources/$($Plugin.resourceId)/version/$($Plugin.version)/download"
                }
                
                # Add file ID if specified
                if ($Plugin.fileId) {
                    $downloadUrl += "?file=$($Plugin.fileId)"
                }
                
                $filename = if ($Plugin.filename) { $Plugin.filename } else { "plugin_$($Plugin.resourceId).zip" }
                
                Write-StatusMessage "Using OBS Project download URL: $downloadUrl" "Info"
                
                return @{
                    Name = $filename
                    DownloadUrl = $downloadUrl
                    Size = 0  # Will be determined during download
                    Version = if ($Plugin.version) { $Plugin.version } else { "latest" }
                    Method = "obsproject"
                }
            }
            
            default {
                throw "Unknown download method: $downloadMethod"
            }
        }
    }
    catch {
        Write-StatusMessage "Failed to get plugin download info: $($_.Exception.Message)" "Error"
        return $null
    }
    finally {
        $ProgressPreference = $originalProgressPreference
    }
}

function Install-OBSProfile {
    param(
        [string]$ProfileName,
        [PSCustomObject]$ProfileConfig,
        [string]$BaseInstallPath,
        [hashtable]$ObsRelease,
        [string]$SharedObsFiles
    )
    
    Write-Host "`n============================================" -ForegroundColor Cyan
    Write-Host "Installing Profile: $($ProfileConfig.name)" -ForegroundColor Cyan
    Write-Host "============================================" -ForegroundColor Cyan
    Write-Host "Description: $($ProfileConfig.description)" -ForegroundColor Gray
    
    $profilePath = Join-Path $BaseInstallPath "OBS-$ProfileName"
    $profileExists = Test-Path $profilePath
    
    # Check if profile exists and handle accordingly
    if ($profileExists -and -not $Force) {
        Write-StatusMessage "Profile exists at $profilePath, checking for updates..." "Info"
        
        # Verify OBS executable exists
        $obsExe = Join-Path $profilePath "bin\64bit\obs64.exe"
        if (-not (Test-Path $obsExe)) {
            Write-StatusMessage "OBS executable missing, reinstalling profile..." "Warning"
            Remove-Item $profilePath -Recurse -Force -ErrorAction SilentlyContinue
            $profileExists = $false
        }
    } elseif ($profileExists -and $Force) {
        Write-StatusMessage "Force flag specified, reinstalling profile..." "Warning"
        Remove-Item $profilePath -Recurse -Force -ErrorAction SilentlyContinue
        $profileExists = $false
    }
    
    # Create temp directory for plugin downloads
    $tempDir = Join-Path $env:TEMP "obs-setup-$ProfileName"
    
    if (Test-Path $tempDir) {
        Remove-Item $tempDir -Recurse -Force
    }
    New-Item -Path $tempDir -ItemType Directory -Force | Out-Null
    
    try {
        # Install OBS files if profile doesn't exist or SharedObsFiles are provided
        if (-not $profileExists -and $SharedObsFiles) {
            Write-StatusMessage "Installing OBS Studio files from shared download..." "Info"
            
            # Create target directory
            if (-not (Test-Path $profilePath)) {
                New-Item -Path $profilePath -ItemType Directory -Force | Out-Null
            }
            
            # Copy all contents from the shared OBS directory to the profile path
            Write-StatusMessage "Copying OBS files to profile directory..." "Info"
            Get-ChildItem $SharedObsFiles | ForEach-Object {
                $targetItem = Join-Path $profilePath $_.Name
                if ($_.PSIsContainer) {
                    Copy-Item $_.FullName $targetItem -Recurse -Force
                } else {
                    Copy-Item $_.FullName $targetItem -Force
                }
            }
            
            Write-StatusMessage "OBS installed to: $profilePath" "Success"
            
            # Verify directory structure
            Write-StatusMessage "Verifying OBS installation structure..." "Info"
            $obsExe = Join-Path $profilePath "bin\64bit\obs64.exe"
            if (Test-Path $obsExe) {
                Write-StatusMessage "Found obs64.exe at expected location" "Success"
            } else {
                Write-StatusMessage "obs64.exe not found at expected location" "Warning"
                # Try to find it elsewhere
                $obs64Files = Get-ChildItem $profilePath -Recurse -Filter "obs64.exe"
                if ($obs64Files) {
                    Write-Host "  Found obs64.exe at: $($obs64Files[0].FullName.Substring($profilePath.Length + 1))" -ForegroundColor Yellow
                }
            }
            
            # Create portable_mode.txt for portable mode
            $portableFile = Join-Path $profilePath "portable_mode.txt"
            "# This file makes OBS run in portable mode" | Out-File -FilePath $portableFile -Encoding utf8
            Write-StatusMessage "Portable mode enabled" "Success"
        } elseif (-not $profileExists) {
            Write-StatusMessage "No shared OBS files available and profile doesn't exist" "Warning"
        } else {
            Write-StatusMessage "OBS installation already exists, skipping OBS setup" "Info"
        }
        
        # Always check and update plugins (whether OBS was just installed or already existed)
        Write-StatusMessage "Checking plugins for profile..." "Info"
        
        # Install plugins
        if ($ProfileConfig.plugins -and $ProfileConfig.plugins.Count -gt 0) {
            Write-StatusMessage "Checking $($ProfileConfig.plugins.Count) plugins..." "Info"
            
            $installedPlugins = Get-InstalledPlugins -ProfilePath $profilePath
            $pluginsUpdated = 0
            $pluginsSkipped = 0
            
            foreach ($plugin in $ProfileConfig.plugins) {
                Write-StatusMessage "Checking plugin: $($plugin.name)" "Info"
                Write-Host "  Description: $($plugin.description)" -ForegroundColor Gray
                
                if (Test-PluginNeedsUpdate -Plugin $plugin -InstalledPlugins $installedPlugins) {
                    Write-StatusMessage "Installing/updating plugin: $($plugin.name)" "Info"
                    $pluginRelease = Get-PluginDownload -Plugin $plugin
                    if (-not $pluginRelease) {
                        Write-StatusMessage "Skipping $($plugin.name) - could not get release info" "Warning"
                        continue
                    }
                    
                    $pluginArchive = Join-Path $tempDir "$($plugin.name).zip"
                    
                    if (Invoke-FileDownload -Url $pluginRelease.DownloadUrl -OutputPath $pluginArchive -Description $plugin.name) {
                        $pluginExtractDir = Join-Path $tempDir "$($plugin.name)-extract"
                        if (Expand-ArchiveFile -ArchivePath $pluginArchive -DestinationPath $pluginExtractDir -Description $plugin.name) {
                            # Copy plugin files to OBS directory
                            # Look for common plugin directories
                            $pluginDirs = @("obs-plugins", "data")
                            $copied = $false
                            
                            foreach ($dir in $pluginDirs) {
                                $sourcePath = Join-Path $pluginExtractDir $dir
                                $targetPath = Join-Path $profilePath $dir
                                
                                if (Test-Path $sourcePath) {
                                    if (-not (Test-Path $targetPath)) {
                                        New-Item -Path $targetPath -ItemType Directory -Force | Out-Null
                                    }
                                    Copy-Item "$sourcePath\*" $targetPath -Recurse -Force
                                    $copied = $true
                                }
                            }
                            
                            # If no standard directories found, copy everything
                            if (-not $copied) {
                                $allItems = Get-ChildItem $pluginExtractDir -Recurse
                                $dllFiles = $allItems | Where-Object { $_.Extension -eq '.dll' }
                                $dataFiles = $allItems | Where-Object { $_.Extension -in @('.json', '.effect', '.png', '.jpg') }
                                
                                # Copy DLL files to obs-plugins/64bit
                                if ($dllFiles) {
                                    $pluginBinDir = Join-Path $profilePath "obs-plugins\64bit"
                                    if (-not (Test-Path $pluginBinDir)) {
                                        New-Item -Path $pluginBinDir -ItemType Directory -Force | Out-Null
                                    }
                                    $dllFiles | ForEach-Object { Copy-Item $_.FullName $pluginBinDir -Force }
                                }
                                
                                # Copy data files to data/obs-plugins
                                if ($dataFiles) {
                                    $pluginDataDir = Join-Path $profilePath "data\obs-plugins"
                                    if (-not (Test-Path $pluginDataDir)) {
                                        New-Item -Path $pluginDataDir -ItemType Directory -Force | Out-Null
                                    }
                                    $dataFiles | ForEach-Object { 
                                        $relativePath = $_.FullName.Substring($pluginExtractDir.Length + 1)
                                        $targetFile = Join-Path $pluginDataDir $relativePath
                                        $targetFileDir = Split-Path $targetFile -Parent
                                        if (-not (Test-Path $targetFileDir)) {
                                            New-Item -Path $targetFileDir -ItemType Directory -Force | Out-Null
                                        }
                                        Copy-Item $_.FullName $targetFile -Force
                                    }
                                }
                            }
                            
                            $installedPlugins[$plugin.name] = @{
                                version = $pluginRelease.Version
                            }
                            
                            $pluginsUpdated++
                            Write-StatusMessage "Plugin $($plugin.name) installed/updated successfully (version: $($pluginRelease.Version))" "Success"
                        }
                    }
                } else {
                    $pluginsSkipped++
                    Write-StatusMessage "Plugin $($plugin.name) is up to date" "Info"
                }
            }
            
            # Save updated metadata
            Save-PluginMetadata -ProfilePath $profilePath -InstalledPlugins $installedPlugins
            
            if ($pluginsUpdated -gt 0) {
                Write-StatusMessage "Updated $pluginsUpdated plugins" "Success"
            }
            if ($pluginsSkipped -gt 0) {
                Write-StatusMessage "Skipped $pluginsSkipped up-to-date plugins" "Info"
            }
        }
        
        return $true
    }
    catch {
        Write-StatusMessage "Failed to install profile $ProfileName`: $($_.Exception.Message)" "Error"
        return $false
    }
    finally {
        # Cleanup temp directory (only for plugins now, not OBS)
        if (Test-Path $tempDir) {
            Remove-Item $tempDir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

function New-OBSShortcuts {
    param(
        [string]$ProfileName,
        [string]$ProfilePath,
        [string]$DisplayName
    )
    
    try {
        $obsExe = Join-Path $ProfilePath "bin\64bit\obs64.exe"
        if (-not (Test-Path $obsExe)) {
            Write-StatusMessage "OBS executable not found at $obsExe" "Warning"
            return
        }
        
        # Create desktop shortcut
        $desktopPath = [Environment]::GetFolderPath('Desktop')
        $shortcutPath = Join-Path $desktopPath "$DisplayName.lnk"
        
        $shell = New-Object -ComObject WScript.Shell
        $shortcut = $shell.CreateShortcut($shortcutPath)
        $shortcut.TargetPath = $obsExe
        $shortcut.WorkingDirectory = Split-Path $obsExe
        $shortcut.Description = $DisplayName
        $shortcut.Save()
        
        Write-StatusMessage "Created desktop shortcut: $DisplayName" "Success"
        
        # Create start menu shortcut
        $startMenuPath = Join-Path ([Environment]::GetFolderPath('StartMenu')) "Programs"
        $startShortcutPath = Join-Path $startMenuPath "$DisplayName.lnk"
        
        try {
            $startShortcut = $shell.CreateShortcut($startShortcutPath)
            $startShortcut.TargetPath = $obsExe
            $startShortcut.WorkingDirectory = Split-Path $obsExe
            $startShortcut.Description = $DisplayName
            $startShortcut.Save()
            
            Write-StatusMessage "Created start menu shortcut: $DisplayName" "Success"
        }
        catch {
            # Try alternative start menu location
            Write-StatusMessage "Failed to create start menu shortcut in user location, trying common location..." "Warning"
            try {
                $commonStartMenu = Join-Path ([Environment]::GetFolderPath('CommonStartMenu')) "Programs"
                $commonShortcutPath = Join-Path $commonStartMenu "$DisplayName.lnk"
                
                $commonShortcut = $shell.CreateShortcut($commonShortcutPath)
                $commonShortcut.TargetPath = $obsExe
                $commonShortcut.WorkingDirectory = Split-Path $obsExe
                $commonShortcut.Description = $DisplayName
                $commonShortcut.Save()
                
                Write-StatusMessage "Created start menu shortcut in common location: $DisplayName" "Success"
            }
            catch {
                Write-StatusMessage "Failed to create start menu shortcut: $($_.Exception.Message)" "Warning"
            }
        }
        
    }
    catch {
        Write-StatusMessage "Failed to create shortcuts for $DisplayName`: $($_.Exception.Message)" "Warning"
    }
}

function Get-InstalledPlugins {
    param([string]$ProfilePath)
    
    $metadataFile = Join-Path $ProfilePath ".obs-plugins-metadata.json"
    if (Test-Path $metadataFile) {
        try {
            $metadata = Get-Content $metadataFile -Raw | ConvertFrom-Json
            
            # Convert PSCustomObject to Hashtable for easier manipulation
            $pluginsHashtable = @{}
            if ($metadata.plugins) {
                $metadata.plugins.PSObject.Properties | ForEach-Object {
                    $pluginsHashtable[$_.Name] = @{
                        version = $_.Value.version
                    }
                }
            }
            
            return $pluginsHashtable
        } catch {
            Write-StatusMessage "Could not read plugin metadata, treating as fresh install" "Warning"
            return @{}
        }
    }
    return @{}
}

function Save-PluginMetadata {
    param(
        [string]$ProfilePath,
        [hashtable]$InstalledPlugins
    )
    
    $metadataFile = Join-Path $ProfilePath ".obs-plugins-metadata.json"
    $metadata = @{
        lastUpdated = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ssZ")
        plugins = $InstalledPlugins
    }
    
    $metadata | ConvertTo-Json -Depth 10 | Out-File -FilePath $metadataFile -Encoding utf8
}

function Compare-PluginVersions {
    param(
        [string]$InstalledVersion,
        [string]$RequiredVersion
    )
    
    # If no installed version, needs update
    if (-not $InstalledVersion) { return $true }
    
    # If required version is "latest", check if we have a version at all
    if ($RequiredVersion -eq "latest") { return $false }
    
    # Simple string comparison for now (works for most cases)
    # Could be enhanced with semantic version parsing if needed
    return $InstalledVersion -ne $RequiredVersion
}

function Test-PluginNeedsUpdate {
    param(
        [PSCustomObject]$Plugin,
        [hashtable]$InstalledPlugins
    )
    
    $pluginKey = $Plugin.name
    if (-not $InstalledPlugins.ContainsKey($pluginKey)) {
        return $true  # Plugin not installed
    }
    
    $installedPlugin = $InstalledPlugins[$pluginKey]
    
    # Get the version that would be downloaded
    $pluginRelease = Get-PluginDownload -Plugin $Plugin
    if (-not $pluginRelease) {
        return $false  # Can't determine if update needed
    }
    
    $requiredVersion = $pluginRelease.Version
    $installedVersion = $installedPlugin.version
    
    return Compare-PluginVersions -InstalledVersion $installedVersion -RequiredVersion $requiredVersion
}

# Main execution
function Main {
    Write-Host "OBS Studio Multi-Profile Setup" -ForegroundColor Cyan
    Write-Host "==============================" -ForegroundColor Cyan
    Write-Host "PowerShell Version: $($PSVersionTable.PSVersion)" -ForegroundColor Gray
    Write-Host ""
    
    Write-StatusMessage "Loaded configuration from $configPath" "Info"
    Write-StatusMessage "Base install path: $($config.baseInstallPath)" "Info"
    Write-StatusMessage "Tools Directory: $ToolsDirectory" "Info"
    
    # Determine which profiles to install based on skip flags
    $profilesToInstall = @()
    if (-not $SkipStreaming) { $profilesToInstall += "streaming" }
    if (-not $SkipRecording) { $profilesToInstall += "recording" }
    if (-not $SkipTesting) { $profilesToInstall += "testing" }
    
    Write-StatusMessage "Profiles to install: $($profilesToInstall -join ', ')" "Info"
    Write-Host ""
    
    # Use ToolsDirectory instead of config.baseInstallPath
    $baseInstallPath = $ToolsDirectory
    
    # Get OBS release info once
    Write-StatusMessage "Getting latest OBS Studio release..." "Info"
    $obsRelease = Get-LatestRelease -Repository "obsproject/obs-studio" -FilePattern "OBS-Studio-*-Windows.zip"
    if (-not $obsRelease) {
        Write-StatusMessage "Failed to get OBS Studio release information" "Error"
        exit 1
    }
    Write-StatusMessage "Found OBS Studio $($obsRelease.Version)" "Success"
    
    # Ensure base install path exists
    if (-not (Test-Path $baseInstallPath)) {
        Write-StatusMessage "Creating base install directory: $baseInstallPath" "Info"
        try {
            New-Item -Path $baseInstallPath -ItemType Directory -Force | Out-Null
            Write-StatusMessage "Base install directory created successfully" "Success"
        }
        catch {
            Write-StatusMessage "Failed to create base install directory: $($_.Exception.Message)" "Error"
            exit 1
        }
    }
    
    # Download and extract OBS once if any profiles need installation
    $sharedObsFiles = $null
    $needsObsDownload = $false
    
    foreach ($profileName in $profilesToInstall) {
        if (-not $config.profiles.$profileName) {
            continue
        }
        
        $profilePath = Join-Path $baseInstallPath "OBS-$profileName"
        $profileExists = Test-Path $profilePath
        
        if (-not $profileExists -or $Force) {
            $needsObsDownload = $true
            break
        }
    }
    
    if ($needsObsDownload) {
        Write-Host "`n============================================" -ForegroundColor Yellow
        Write-Host "Downloading OBS Studio (shared for all profiles)" -ForegroundColor Yellow
        Write-Host "============================================" -ForegroundColor Yellow
        
        # Create shared temp directory for OBS download
        $sharedTempDir = Join-Path $env:TEMP "obs-shared-download"
        
        if (Test-Path $sharedTempDir) {
            Remove-Item $sharedTempDir -Recurse -Force
        }
        New-Item -Path $sharedTempDir -ItemType Directory -Force | Out-Null
        
        try {
            # Download OBS once
            $obsArchive = Join-Path $sharedTempDir "obs-studio.zip"
            
            if (-not (Invoke-FileDownload -Url $obsRelease.DownloadUrl -OutputPath $obsArchive -Description "OBS Studio $($obsRelease.Version)")) {
                throw "Failed to download OBS Studio"
            }
            
            if (-not (Expand-ArchiveFile -ArchivePath $obsArchive -DestinationPath $sharedTempDir -Description "OBS Studio")) {
                throw "Failed to extract OBS Studio"
            }
            
            # Find the extracted OBS directory
            $obsExtractedDir = Get-ChildItem $sharedTempDir -Directory | Where-Object { 
                $_.Name -like "*OBS*" -or $_.Name -like "*obs*" -or $_.Name -like "*Studio*"
            } | Select-Object -First 1
            
            # Check if extraction happened directly to temp directory
            $directExtraction = $false
            $binInTemp = Test-Path (Join-Path $sharedTempDir "bin")
            $obs64InTemp = $false
            if ($binInTemp) {
                $obs64InTemp = Test-Path (Join-Path $sharedTempDir "bin\64bit\obs64.exe")
            }
            
            if ($binInTemp -and $obs64InTemp) {
                Write-StatusMessage "Detected direct extraction to temp directory" "Info"
                $obsExtractedDir = Get-Item $sharedTempDir
                $directExtraction = $true
            }
            
            if (-not $directExtraction -and $obsExtractedDir) {
                # Verify the found directory contains OBS
                $hasBin = Test-Path (Join-Path $obsExtractedDir.FullName "bin")
                $hasObs64 = (Get-ChildItem $obsExtractedDir.FullName -Recurse -Filter "obs64.exe" -ErrorAction SilentlyContinue).Count -gt 0
                
                if (-not $hasBin -and -not $hasObs64) {
                    $obsExtractedDir = $null
                }
            }
            
            if (-not $obsExtractedDir) {
                # Look for directory containing obs64.exe
                $obs64Files = Get-ChildItem $sharedTempDir -Recurse -Filter "obs64.exe" -ErrorAction SilentlyContinue
                
                if ($obs64Files) {
                    $obsExeFile = $obs64Files[0]
                    $current = $obsExeFile.Directory
                    
                    # Go up directories until we find the root OBS directory
                    while ($current.Parent -and $current.Parent.FullName -ne $sharedTempDir) {
                        $current = $current.Parent
                        if ((Get-ChildItem $current.FullName -Directory -Name -ErrorAction SilentlyContinue) -contains "bin") {
                            break
                        }
                    }
                    
                    $obsExtractedDir = $current
                }
            }
            
            if (-not $obsExtractedDir) {
                throw "Could not find extracted OBS directory in $sharedTempDir"
            }
            
            Write-StatusMessage "OBS extracted and ready for deployment" "Success"
            $sharedObsFiles = $obsExtractedDir.FullName
            
        }
        catch {
            Write-StatusMessage "Failed to download/extract OBS: $($_.Exception.Message)" "Error"
            exit 1
        }
    }
    
    # Install each requested profile
    $installedProfiles = @()
    $failedProfiles = @()
    
    foreach ($profileName in $profilesToInstall) {
        if (-not $config.profiles.$profileName) {
            Write-StatusMessage "Profile '$profileName' not found in configuration" "Warning"
            $failedProfiles += $profileName
            continue
        }
        
        $success = Install-OBSProfile -ProfileName $profileName -ProfileConfig $config.profiles.$profileName -BaseInstallPath $baseInstallPath -ObsRelease $obsRelease -SharedObsFiles $sharedObsFiles
        
        if ($success) {
            $installedProfiles += $profileName
            $profilePath = Join-Path $baseInstallPath "OBS-$profileName"
            New-OBSShortcuts -ProfileName $profileName -ProfilePath $profilePath -DisplayName $config.profiles.$profileName.name
        } else {
            $failedProfiles += $profileName
        }
    }
    
    # Cleanup shared temp directory
    if ($sharedObsFiles -and (Test-Path $sharedTempDir)) {
        Remove-Item $sharedTempDir -Recurse -Force -ErrorAction SilentlyContinue
    }
    
    # Summary
    Write-Host "`n" -NoNewline
    Write-Host "🎉 Installation Summary" -ForegroundColor Cyan
    Write-Host "======================" -ForegroundColor Cyan
    
    if ($installedProfiles.Count -gt 0) {
        Write-StatusMessage "Successfully installed profiles:" "Success"
        foreach ($profile in $installedProfiles) {
            $profilePath = Join-Path $baseInstallPath "OBS-$profile"
            Write-Host "  ✅ $($config.profiles.$profile.name)" -ForegroundColor Green
            Write-Host "     Location: $profilePath" -ForegroundColor Gray
            Write-Host "     Plugins: $($config.profiles.$profile.plugins.Count)" -ForegroundColor Gray
        }
    }
    
    if ($failedProfiles.Count -gt 0) {
        Write-StatusMessage "Failed to install profiles:" "Error"
        foreach ($profile in $failedProfiles) {
            Write-Host "  ❌ $profile" -ForegroundColor Red
        }
    }
    
    if ($installedProfiles.Count -gt 0) {
        Write-Host ""
        Write-StatusMessage "Setup completed! Launch OBS from desktop shortcuts or start menu." "Success"
        Write-StatusMessage "Each profile is completely independent with its own settings and plugins." "Info"
    }
}

# Run the main function
Main 