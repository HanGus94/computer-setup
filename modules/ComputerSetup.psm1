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

# Elevation management system globals
$script:ElevationSession = @{
    IsActive = $false
    SessionId = $null
    TempDirectory = $null
    OperationResults = @()
    RollbackActions = @()
    ProgressFile = $null
    ResultsFile = $null
    BatchedOperations = @()
}

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
    
    # Also write to progress file if elevation session is active
    if ($script:ElevationSession.IsActive -and $script:ElevationSession.ProgressFile) {
        try {
            $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
            "$timestamp [$Type] $Message" | Add-Content $script:ElevationSession.ProgressFile -ErrorAction SilentlyContinue
        } catch {
            # Silent failure for progress logging
        }
    }
}

function Initialize-ElevationSession {
    <#
    .SYNOPSIS
        Initializes a new elevation session for batched operations
    #>
    
    if ($script:ElevationSession.IsActive) {
        Write-StatusMessage "Elevation session already active" "Warning"
        return $script:ElevationSession.SessionId
    }
    
    # Generate unique session ID
    $sessionId = [System.Guid]::NewGuid().ToString("N").Substring(0, 8)
    
    # Create temporary directory for session
    $tempDir = Join-Path $env:TEMP "ComputerSetup_$sessionId"
    New-Item -Path $tempDir -ItemType Directory -Force | Out-Null
    
    # Initialize session
    $script:ElevationSession.IsActive = $true
    $script:ElevationSession.SessionId = $sessionId
    $script:ElevationSession.TempDirectory = $tempDir
    $script:ElevationSession.ProgressFile = Join-Path $tempDir "progress.log"
    $script:ElevationSession.ResultsFile = Join-Path $tempDir "results.json"
    $script:ElevationSession.OperationResults = @()
    $script:ElevationSession.RollbackActions = @()
    $script:ElevationSession.BatchedOperations = @()
    
    # Create initial files
    @() | ConvertTo-Json | Set-Content $script:ElevationSession.ResultsFile
    "Session initialized: $sessionId" | Set-Content $script:ElevationSession.ProgressFile
    
    Write-StatusMessage "Elevation session initialized: $sessionId" "Info"
    return $sessionId
}

function Add-ElevatedOperation {
    <#
    .SYNOPSIS
        Adds an operation to the elevated batch queue
    
    .PARAMETER OperationName
        Name of the operation for tracking
    
    .PARAMETER ScriptPath
        Path to the script to execute
    
    .PARAMETER Arguments
        Arguments to pass to the script
    
    .PARAMETER RollbackAction
        Scriptblock to execute if rollback is needed
    
    .PARAMETER Priority
        Priority level (1-10, lower numbers execute first)
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$OperationName,
        
        [Parameter(Mandatory = $true)]
        [string]$ScriptPath,
        
        [Parameter(Mandatory = $false)]
        [string[]]$Arguments = @(),
        
        [Parameter(Mandatory = $false)]
        [scriptblock]$RollbackAction = $null,
        
        [Parameter(Mandatory = $false)]
        [int]$Priority = 5
    )
    
    if (-not $script:ElevationSession.IsActive) {
        Initialize-ElevationSession | Out-Null
    }
    
    $operation = @{
        Name = $OperationName
        ScriptPath = $ScriptPath
        Arguments = $Arguments
        RollbackAction = $RollbackAction
        Priority = $Priority
        Id = [System.Guid]::NewGuid().ToString("N").Substring(0, 8)
        Status = "Queued"
        StartTime = $null
        EndTime = $null
        ExitCode = $null
        Output = $null
        Error = $null
    }
    
    $script:ElevationSession.BatchedOperations += $operation
    
    Write-StatusMessage "Queued elevated operation: $OperationName" "Info"
    return $operation.Id
}

function Invoke-ElevatedBatch {
    <#
    .SYNOPSIS
        Executes all queued elevated operations in a single elevated session
    
    .PARAMETER ShowProgress
        Whether to show real-time progress monitoring
    
    .PARAMETER TimeoutMinutes
        Maximum time to wait for operations to complete
    #>
    param(
        [Parameter(Mandatory = $false)]
        [switch]$ShowProgress,
        
        [Parameter(Mandatory = $false)]
        [int]$TimeoutMinutes = 30
    )
    
    if (-not $script:ElevationSession.IsActive) {
        Write-StatusMessage "No elevation session active" "Warning"
        return $false
    }
    
    if ($script:ElevationSession.BatchedOperations.Count -eq 0) {
        Write-StatusMessage "No operations queued for elevation" "Warning"
        return $true
    }
    
    # Sort operations by priority
    $sortedOps = $script:ElevationSession.BatchedOperations | Sort-Object Priority, Name
    
    Write-StatusMessage "Executing $($sortedOps.Count) elevated operations..." "Info"
    
    # Create batch execution script
    $batchScript = New-ElevatedBatchScript -Operations $sortedOps
    $batchScriptPath = Join-Path $script:ElevationSession.TempDirectory "batch_operations.ps1"
    $batchScript | Set-Content $batchScriptPath -Encoding UTF8
    
    # Ask for user confirmation
    Write-Host ""
    Write-Host "Operations requiring elevation:" -ForegroundColor Yellow
    foreach ($op in $sortedOps) {
        Write-Host "  • $($op.Name)" -ForegroundColor Gray
    }
    Write-Host ""
    
    $confirmation = Read-Host "Continue with elevation? (Y/N)"
    if ($confirmation -notmatch '^[Yy]') {
        Write-StatusMessage "User declined elevation. Operations cancelled." "Warning"
        return $false
    }
    
    try {
        # Start elevated process
        Write-StatusMessage "Starting elevated batch process..." "Info"
        
        $processArgs = @(
            "-NoProfile",
            "-ExecutionPolicy", "Bypass",
            "-File", $batchScriptPath
        )
        
        $process = Start-Process pwsh -Verb RunAs -ArgumentList $processArgs -PassThru
        
        # Monitor progress if requested
        if ($ShowProgress) {
            Start-ProgressMonitoring -Process $process -TimeoutMinutes $TimeoutMinutes
        } else {
            # Simple wait
            Write-StatusMessage "Waiting for elevated operations to complete..." "Info"
            $process.WaitForExit()
        }
        
        # Read results
        $results = Read-ElevationResults
        
        # Process results
        $successful = ($results | Where-Object { $_.Success }).Count
        $failed = ($results | Where-Object { -not $_.Success }).Count
        
        Write-Host ""
        Write-StatusMessage "Elevation batch completed: $successful successful, $failed failed" "Info"
        
        # Show detailed results
        foreach ($result in $results) {
            $status = if ($result.Success) { "Success" } else { "Error" }
            Write-StatusMessage "$($result.OperationName): $($result.Message)" $status
        }
        
        # Handle failures
        if ($failed -gt 0) {
            Write-Host ""
            $rollbackChoice = Read-Host "Some operations failed. Attempt rollback? (Y/N)"
            if ($rollbackChoice -match '^[Yy]') {
                Invoke-RollbackOperations
            }
            return $false
        }
        
        return $true
        
    } catch {
        Write-StatusMessage "Failed to execute elevated batch: $($_.Exception.Message)" "Error"
        return $false
    }
}

function New-ElevatedBatchScript {
    <#
    .SYNOPSIS
        Creates a PowerShell script to execute batched operations
    #>
    param([array]$Operations)
    
    $script = @"
#Requires -Version 7.0
#Requires -RunAsAdministrator

# Batch execution script for Computer Setup
# Session: $($script:ElevationSession.SessionId)
# Generated: $(Get-Date)

`$ProgressFile = "$($script:ElevationSession.ProgressFile)"
`$ResultsFile = "$($script:ElevationSession.ResultsFile)"
`$Results = @()

function Write-Progress {
    param([string]`$Message, [string]`$Type = "Info")
    `$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "`$timestamp [`$Type] `$Message" | Add-Content `$ProgressFile
    Write-Host "[$Type] `$Message" -ForegroundColor $(if (`$Type -eq "Error") { "Red" } elseif (`$Type -eq "Success") { "Green" } else { "Cyan" })
}

Write-Progress "Starting elevated batch execution"

"@

    foreach ($op in $Operations) {
        $script += @"

# Operation: $($op.Name)
Write-Progress "Starting operation: $($op.Name)"
`$opResult = @{
    OperationId = "$($op.Id)"
    OperationName = "$($op.Name)"
    Success = `$false
    Message = ""
    StartTime = Get-Date
    EndTime = `$null
    ExitCode = `$null
    Output = ""
    Error = ""
}

try {
    `$startTime = Get-Date
    
"@

        # Add the actual operation execution
        if ($op.Arguments.Count -gt 0) {
            $argString = ($op.Arguments | ForEach-Object { "`"$_`"" }) -join ", "
            $script += "    `$result = & `"$($op.ScriptPath)`" $argString 2>&1`n"
        } else {
            $script += "    `$result = & `"$($op.ScriptPath)`" 2>&1`n"
        }
        
        $script += @"
    
    `$opResult.ExitCode = `$LASTEXITCODE
    `$opResult.Output = `$result | Out-String
    `$opResult.EndTime = Get-Date
    
    if (`$LASTEXITCODE -eq 0) {
        `$opResult.Success = `$true
        `$opResult.Message = "Operation completed successfully"
        Write-Progress "Completed: $($op.Name)" "Success"
    } else {
        `$opResult.Message = "Operation failed with exit code `$LASTEXITCODE"
        Write-Progress "Failed: $($op.Name) (Exit: `$LASTEXITCODE)" "Error"
    }
    
} catch {
    `$opResult.EndTime = Get-Date
    `$opResult.Error = `$_.Exception.Message
    `$opResult.Message = "Operation threw exception: `$(`$_.Exception.Message)"
    Write-Progress "Exception in $($op.Name): `$(`$_.Exception.Message)" "Error"
}

`$Results += `$opResult

"@
    }

    $script += @"

# Save results
Write-Progress "Saving results and cleaning up"
`$Results | ConvertTo-Json -Depth 10 | Set-Content `$ResultsFile
Write-Progress "Batch execution completed"

# Pause to let user see results before window closes
Read-Host "Press Enter to close this window"
"@

    return $script
}

function Start-ProgressMonitoring {
    <#
    .SYNOPSIS
        Monitors progress of elevated operations in real-time
    #>
    param(
        [System.Diagnostics.Process]$Process,
        [int]$TimeoutMinutes
    )
    
    $timeout = (Get-Date).AddMinutes($TimeoutMinutes)
    $lastSize = 0
    
    Write-StatusMessage "Monitoring elevated operations (timeout: ${TimeoutMinutes}m)..." "Info"
    Write-Host ""
    
    while (-not $Process.HasExited -and (Get-Date) -lt $timeout) {
        Start-Sleep -Seconds 2
        
        # Read new progress entries
        if (Test-Path $script:ElevationSession.ProgressFile) {
            try {
                $content = Get-Content $script:ElevationSession.ProgressFile -Raw
                if ($content.Length -gt $lastSize) {
                    $newContent = $content.Substring($lastSize)
                    $lines = $newContent -split "`n" | Where-Object { $_.Trim() -ne "" }
                    
                    foreach ($line in $lines) {
                        if ($line -match "^\d{4}-\d{2}-\d{2} \d{2}:\d{2}:\d{2} \[(.+?)\] (.+)$") {
                            $type = $matches[1]
                            $message = $matches[2]
                            
                            $color = switch ($type) {
                                "Success" { "Green" }
                                "Error" { "Red" }
                                "Warning" { "Yellow" }
                                default { "Gray" }
                            }
                            
                            Write-Host "  $message" -ForegroundColor $color
                        }
                    }
                    
                    $lastSize = $content.Length
                }
            } catch {
                # Continue silently if progress file is locked
            }
        }
    }
    
    if (-not $Process.HasExited) {
        Write-StatusMessage "Timeout reached. Operations may still be running..." "Warning"
    }
    
    $Process.WaitForExit()
    Write-Host ""
}

function Read-ElevationResults {
    <#
    .SYNOPSIS
        Reads the results from completed elevated operations
    #>
    
    if (-not (Test-Path $script:ElevationSession.ResultsFile)) {
        Write-StatusMessage "Results file not found" "Error"
        return @()
    }
    
    try {
        $content = Get-Content $script:ElevationSession.ResultsFile -Raw
        if ([string]::IsNullOrWhiteSpace($content)) {
            return @()
        }
        
        $results = $content | ConvertFrom-Json
        return $results
    } catch {
        Write-StatusMessage "Failed to read results: $($_.Exception.Message)" "Error"
        return @()
    }
}

function Add-RollbackAction {
    <#
    .SYNOPSIS
        Adds a rollback action for the current operation
    
    .PARAMETER Description
        Description of what this rollback action does
    
    .PARAMETER Action
        Scriptblock to execute for rollback
    
    .PARAMETER RequiresElevation
        Whether this rollback action requires elevation
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$Description,
        
        [Parameter(Mandatory = $true)]
        [scriptblock]$Action,
        
        [Parameter(Mandatory = $false)]
        [switch]$RequiresElevation
    )
    
    $rollbackAction = @{
        Description = $Description
        Action = $Action
        RequiresElevation = $RequiresElevation.IsPresent
        Timestamp = Get-Date
        Id = [System.Guid]::NewGuid().ToString("N").Substring(0, 8)
    }
    
    $script:ElevationSession.RollbackActions += $rollbackAction
    Write-StatusMessage "Added rollback action: $Description" "Info"
}

function Invoke-RollbackOperations {
    <#
    .SYNOPSIS
        Executes all registered rollback actions
    #>
    
    if ($script:ElevationSession.RollbackActions.Count -eq 0) {
        Write-StatusMessage "No rollback actions registered" "Info"
        return $true
    }
    
    Write-StatusMessage "Starting rollback of $($script:ElevationSession.RollbackActions.Count) actions..." "Warning"
    
    # Execute rollback actions in reverse order
    $reversedActions = $script:ElevationSession.RollbackActions | Sort-Object Timestamp -Descending
    
    $successful = 0
    $failed = 0
    
    foreach ($action in $reversedActions) {
        Write-StatusMessage "Rolling back: $($action.Description)" "Warning"
        
        try {
            if ($action.RequiresElevation -and -not (Test-IsElevated)) {
                Write-StatusMessage "Rollback action requires elevation, skipping: $($action.Description)" "Warning"
                continue
            }
            
            & $action.Action
            $successful++
            Write-StatusMessage "Rollback successful: $($action.Description)" "Success"
            
        } catch {
            $failed++
            Write-StatusMessage "Rollback failed: $($action.Description) - $($_.Exception.Message)" "Error"
        }
    }
    
    Write-StatusMessage "Rollback completed: $successful successful, $failed failed" "Info"
    return $failed -eq 0
}

function Close-ElevationSession {
    <#
    .SYNOPSIS
        Closes the current elevation session and cleans up
    
    .PARAMETER KeepLogs
        Whether to keep log files for debugging
    #>
    param(
        [Parameter(Mandatory = $false)]
        [switch]$KeepLogs
    )
    
    if (-not $script:ElevationSession.IsActive) {
        return
    }
    
    $sessionId = $script:ElevationSession.SessionId
    
    if (-not $KeepLogs -and $script:ElevationSession.TempDirectory -and (Test-Path $script:ElevationSession.TempDirectory)) {
        try {
            Remove-Item $script:ElevationSession.TempDirectory -Recurse -Force
            Write-StatusMessage "Cleaned up elevation session: $sessionId" "Info"
        } catch {
            Write-StatusMessage "Failed to clean up session directory: $($_.Exception.Message)" "Warning"
        }
    }
    
    # Reset session
    $script:ElevationSession.IsActive = $false
    $script:ElevationSession.SessionId = $null
    $script:ElevationSession.TempDirectory = $null
    $script:ElevationSession.OperationResults = @()
    $script:ElevationSession.RollbackActions = @()
    $script:ElevationSession.ProgressFile = $null
    $script:ElevationSession.ResultsFile = $null
    $script:ElevationSession.BatchedOperations = @()
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

function Get-OptimalToolsDirectory {
    <#
    .SYNOPSIS
        Returns the optimal tools directory based on elevation status
    
    .PARAMETER PreferredPath
        Preferred path when running as administrator
    
    .RETURNS
        Path to use for tool installations
    #>
    param(
        [Parameter(Mandatory = $false)]
        [string]$PreferredPath = "C:\Tools"
    )
    
    if (Test-IsElevated) {
        return $PreferredPath
    } else {
        $userTools = Join-Path $env:USERPROFILE "Tools"
        Write-StatusMessage "Using user directory (not admin): $userTools" "Info"
        return $userTools
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
    
    if ([string]::IsNullOrEmpty($Version1) -and [string]::IsNullOrEmpty($Version2)) {
        return 0
    }
    if ([string]::IsNullOrEmpty($Version1)) {
        return -1
    }
    if ([string]::IsNullOrEmpty($Version2)) {
        return 1
    }
    
    try {
        # Remove any 'v' prefix and normalize
        $v1 = $Version1.TrimStart('v').Split('.') | ForEach-Object { [int]$_ }
        $v2 = $Version2.TrimStart('v').Split('.') | ForEach-Object { [int]$_ }
        
        # Pad arrays to same length
        $maxLength = [Math]::Max($v1.Length, $v2.Length)
        while ($v1.Length -lt $maxLength) { $v1 += 0 }
        while ($v2.Length -lt $maxLength) { $v2 += 0 }
        
        # Compare each component
        for ($i = 0; $i -lt $maxLength; $i++) {
            if ($v1[$i] -lt $v2[$i]) { return -1 }
            if ($v1[$i] -gt $v2[$i]) { return 1 }
        }
        
        return 0
    }
    catch {
        # Fallback to string comparison
        return [string]::Compare($Version1, $Version2, $true)
    }
}

function Get-FileVersion {
    <#
    .SYNOPSIS
        Gets the version of a file
    
    .PARAMETER FilePath
        Path to the file
    
    .RETURNS
        Version string or null if not available
    #>
    param([string]$FilePath)
    
    try {
        if (-not (Test-Path $FilePath)) {
            return $null
        }
        
        $versionInfo = [System.Diagnostics.FileVersionInfo]::GetVersionInfo($FilePath)
        return $versionInfo.FileVersion
    }
    catch {
        return $null
    }
}

function Copy-FileBackup {
    <#
    .SYNOPSIS
        Creates a backup copy of a file before replacement
    
    .PARAMETER SourcePath
        Path to the file to backup
    
    .PARAMETER BackupSuffix
        Suffix to add to backup file (default: .backup)
    
    .RETURNS
        Path to backup file or null if backup failed
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$SourcePath,
        
        [Parameter(Mandatory = $false)]
        [string]$BackupSuffix = ".backup"
    )
    
    try {
        if (-not (Test-Path $SourcePath)) {
            return $null
        }
        
        $backupPath = $SourcePath + $BackupSuffix
        Copy-Item $SourcePath $backupPath -Force
        
        Write-StatusMessage "Created backup: $backupPath" "Info"
        return $backupPath
    }
    catch {
        Write-StatusMessage "Failed to create backup of $SourcePath`: $($_.Exception.Message)" "Warning"
        return $null
    }
}

function Test-Winget {
    <#
    .SYNOPSIS
        Tests if Winget is available
    
    .RETURNS
        Boolean indicating if Winget is available
    #>
    try {
        $null = Get-Command winget -ErrorAction Stop
        return $true
    }
    catch {
        return $false
    }
}

function Test-Scoop {
    <#
    .SYNOPSIS
        Tests if Scoop is available
    
    .RETURNS
        Boolean indicating if Scoop is available
    #>
    try {
        $null = Get-Command scoop -ErrorAction Stop
        return $true
    }
    catch {
        return $false
    }
}

function Write-SectionHeader {
    <#
    .SYNOPSIS
        Writes a formatted section header
    
    .PARAMETER Title
        The section title
    #>
    param([string]$Title)
    
    Write-Host ""
    Write-Host $Title -ForegroundColor Cyan
    Write-Host ("=" * $Title.Length) -ForegroundColor Cyan
}

function Get-ScriptDirectory {
    <#
    .SYNOPSIS
        Gets the directory containing the current script
    
    .RETURNS
        Directory path of the calling script
    #>
    return Split-Path -Parent $MyInvocation.ScriptName
}

# Export all functions
Export-ModuleMember -Function Write-StatusMessage, Invoke-FileDownload, Get-GitHubLatestRelease, Test-IsElevated, Get-SemanticVersionComparison, Get-FileVersion, Copy-FileBackup, Test-Winget, Test-Scoop, Write-SectionHeader, Get-ScriptDirectory, Initialize-ElevationSession, Add-ElevatedOperation, Invoke-ElevatedBatch, Add-RollbackAction, Invoke-RollbackOperations, Close-ElevationSession, Get-OptimalToolsDirectory 