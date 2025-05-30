#Requires -Version 7.0

<#
.SYNOPSIS
    Computer Setup Shared Utilities Module

.DESCRIPTION
    Provides common functions and variables used across all computer setup scripts.
    Eliminates code duplication and ensures consistency.

.NOTES
    This module should be imported by all setup scripts to access shared functionality.
#>

# Colors for consistent output formatting
$Colors = @{
    Success = "Green"
    Info = "Cyan"
    Warning = "Yellow"
    Error = "Red"
    Gray = "Gray"
}

# Export the Colors variable so scripts can access it
Export-ModuleMember -Variable Colors

function Write-StatusMessage {
    <#
    .SYNOPSIS
        Writes a formatted status message with consistent styling
    
    .PARAMETER Message
        The message to display
    
    .PARAMETER Type
        The type of message (Success, Info, Warning, Error)
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,
        
        [Parameter(Mandatory = $false)]
        [ValidateSet("Success", "Info", "Warning", "Error")]
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

function Invoke-FileDownload {
    <#
    .SYNOPSIS
        Downloads a file from a URL with consistent error handling
    
    .PARAMETER Url
        The URL to download from
    
    .PARAMETER OutputPath
        The local path to save the file
    
    .PARAMETER Description
        Description of what's being downloaded (for logging)
    
    .RETURNS
        Boolean indicating success or failure
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$Url,
        
        [Parameter(Mandatory = $true)]
        [string]$OutputPath,
        
        [Parameter(Mandatory = $false)]
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

function Get-GitHubLatestRelease {
    <#
    .SYNOPSIS
        Gets the latest release information from a GitHub repository
    
    .PARAMETER Repository
        The GitHub repository in format "owner/repo"
    
    .PARAMETER FilePattern
        Pattern to match against release assets
    
    .PARAMETER GitHubToken
        Optional GitHub token for authenticated requests
    
    .RETURNS
        Hashtable with DownloadUrl, FileName, Size, and Version
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$Repository,
        
        [Parameter(Mandatory = $true)]
        [string]$FilePattern,
        
        [Parameter(Mandatory = $false)]
        [string]$GitHubToken
    )
    
    try {
        Write-StatusMessage "Getting latest release info for $Repository..." "Info"
        
        $headers = @{}
        if ($GitHubToken) {
            $headers["Authorization"] = "token $GitHubToken"
        }
        
        $releases = if ($headers.Count -gt 0) {
            Invoke-RestMethod "https://api.github.com/repos/$Repository/releases/latest" -Headers $headers
        } else {
            Invoke-RestMethod "https://api.github.com/repos/$Repository/releases/latest"
        }
        
        $asset = $releases.assets | Where-Object { $_.name -like $FilePattern } | Select-Object -First 1
        
        if ($asset) {
            return @{
                DownloadUrl = $asset.browser_download_url
                FileName = $asset.name
                Size = $asset.size
                Version = $releases.tag_name
                PublishDate = $releases.published_at
            }
        } else {
            throw "No asset matching pattern '$FilePattern' found"
        }
    }
    catch {
        Write-StatusMessage "Failed to get release info: $($_.Exception.Message)" "Error"
        return $null
    }
}

function Test-IsElevated {
    <#
    .SYNOPSIS
        Tests if the current PowerShell session is running with elevated (administrator) privileges
    
    .RETURNS
        Boolean indicating if running as administrator
    #>
    try {
        $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
        $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
        return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    }
    catch {
        return $false
    }
}

function Get-SemanticVersionComparison {
    <#
    .SYNOPSIS
        Compares two semantic version strings
    
    .PARAMETER Version1
        First version to compare
    
    .PARAMETER Version2
        Second version to compare
    
    .RETURNS
        -1 if Version1 < Version2, 0 if equal, 1 if Version1 > Version2
    #>
    param(
        [Parameter(Mandatory = $false)]
        [string]$Version1,
        
        [Parameter(Mandatory = $false)]
        [string]$Version2
    )
    
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

function Get-FileVersion {
    <#
    .SYNOPSIS
        Extracts version information from file content using comment patterns
    
    .PARAMETER FilePath
        Path to the file to extract version from
    
    .RETURNS
        Version string if found, null otherwise
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$FilePath
    )
    
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

function Copy-FileBackup {
    <#
    .SYNOPSIS
        Creates a timestamped backup of an existing file
    
    .PARAMETER FilePath
        Path to the file to backup
    
    .RETURNS
        Path to the backup file if created, null if original file doesn't exist
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$FilePath
    )
    
    if (Test-Path $FilePath) {
        $backupPath = "$FilePath.backup.$(Get-Date -Format 'yyyyMMdd-HHmmss')"
        Copy-Item $FilePath $backupPath -Force
        Write-StatusMessage "Backed up existing file to: $(Split-Path $backupPath -Leaf)" "Warning"
        return $backupPath
    }
    return $null
}

function Test-Winget {
    <#
    .SYNOPSIS
        Tests if Windows Package Manager (Winget) is available
    
    .RETURNS
        Boolean indicating if Winget is installed and accessible
    #>
    try {
        $wingetPath = Get-Command winget -ErrorAction Stop
        Write-StatusMessage "Winget found at: $($wingetPath.Source)" "Success"
        return $true
    } catch {
        Write-StatusMessage "Winget not found" "Warning"
        return $false
    }
}

function Test-Scoop {
    <#
    .SYNOPSIS
        Tests if Scoop package manager is available
    
    .RETURNS
        Boolean indicating if Scoop is installed and accessible
    #>
    try {
        $scoopPath = Get-Command scoop -ErrorAction Stop
        Write-StatusMessage "Scoop found at: $($scoopPath.Source)" "Success"
        return $true
    } catch {
        Write-StatusMessage "Scoop not found" "Warning"
        return $false
    }
}

function Write-SectionHeader {
    <#
    .SYNOPSIS
        Writes a formatted section header for better script organization
    
    .PARAMETER Title
        The title of the section
    
    .PARAMETER Color
        The color to use for the header
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$Title,
        
        [Parameter(Mandatory = $false)]
        [string]$Color = "Cyan"
    )
    
    Write-Host ""
    Write-Host "============================================" -ForegroundColor $Color
    Write-Host $Title -ForegroundColor $Color
    Write-Host "============================================" -ForegroundColor $Color
}

function Get-ScriptDirectory {
    <#
    .SYNOPSIS
        Gets the directory containing the calling script
    
    .RETURNS
        Path to the script directory
    #>
    return Split-Path -Parent $MyInvocation.PSCommandPath
}

# Export all functions
Export-ModuleMember -Function Write-StatusMessage, Invoke-FileDownload, Get-GitHubLatestRelease, Test-IsElevated, Get-SemanticVersionComparison, Get-FileVersion, Copy-FileBackup, Test-Winget, Test-Scoop, Write-SectionHeader, Get-ScriptDirectory 