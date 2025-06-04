# PowerShell 7+ Profile Configuration
# Version: 1.0.0
# Description: Enhanced PowerShell profile with useful aliases and functions

# Set console to UTF-8
[console]::InputEncoding = [console]::OutputEncoding = New-Object System.Text.UTF8Encoding

#######################
# Enhanced PSReadLine #
#######################
$PSReadLineOptions = @{
    EditMode = 'Windows'
    HistoryNoDuplicates = $true
    HistorySearchCursorMovesToEnd = $true
    Colors = @{
        Command = '#87CEEB'  # SkyBlue (pastel)
        Parameter = '#98FB98'  # PaleGreen (pastel)
        Operator = '#FFB6C1'  # LightPink (pastel)
        Variable = '#DDA0DD'  # Plum (pastel)
        String = '#FFDAB9'  # PeachPuff (pastel)
        Number = '#B0E0E6'  # PowderBlue (pastel)
        Type = '#F0E68C'  # Khaki (pastel)
        Comment = '#D3D3D3'  # LightGray (pastel)
        Keyword = '#8367c7'  # Violet (pastel)
        Error = '#FF6347'  # Tomato (keeping it close to red for visibility)
    }
    PredictionSource = 'History'
    #PredictionViewStyle = 'ListView'
    BellStyle = 'None'
}
Set-PSReadLineOption @PSReadLineOptions

########################
# Prompt Customization #
########################

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
function prompt {
    if ($isAdmin) { "[" + (Get-Location) + "] # " } else { "[" + (Get-Location) + "] $ " }
}
$adminSuffix = if ($isAdmin) { " [ADMIN]" } else { "" }
$Host.UI.RawUI.WindowTitle = "PowerShell {0}$adminSuffix" -f $PSVersionTable.PSVersion.ToString()

##########################
# Set PSReadLine options #
##########################
Set-PSReadLineOption -AddToHistoryHandler {
    param($line)
    $sensitive = @('password', 'secret', 'token', 'apikey', 'connectionstring')
    $hasSensitive = $sensitive | Where-Object { $line -match $_ }
    return ($null -eq $hasSensitive)
}
Set-PSReadLineOption -PredictionSource HistoryAndPlugin
Set-PSReadLineOption -MaximumHistoryCount 10000

#######################
# Custom key handlers #
#######################
Set-PSReadLineKeyHandler -Key UpArrow -Function HistorySearchBackward
Set-PSReadLineKeyHandler -Key DownArrow -Function HistorySearchForward
Set-PSReadLineKeyHandler -Key Tab -Function MenuComplete
Set-PSReadLineKeyHandler -Chord 'Ctrl+d' -Function DeleteChar
Set-PSReadLineKeyHandler -Chord 'Ctrl+w' -Function BackwardDeleteWord
Set-PSReadLineKeyHandler -Chord 'Alt+d' -Function DeleteWord
Set-PSReadLineKeyHandler -Chord 'Ctrl+LeftArrow' -Function BackwardWord
Set-PSReadLineKeyHandler -Chord 'Ctrl+RightArrow' -Function ForwardWord
Set-PSReadLineKeyHandler -Chord 'Ctrl+z' -Function Undo
Set-PSReadLineKeyHandler -Chord 'Ctrl+y' -Function Redo

#########################################
# Custom completion for common commands #
#########################################
$scriptblock = {
    param($wordToComplete, $commandAst, $cursorPosition)
    $customCompletions = @{
        'git' = @('status', 'add', 'commit', 'push', 'pull', 'clone', 'checkout')
    }
    
    $command = $commandAst.CommandElements[0].Value
    if ($customCompletions.ContainsKey($command)) {
        $customCompletions[$command] | Where-Object { $_ -like "$wordToComplete*" } | ForEach-Object {
            [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
        }
    }
}
Register-ArgumentCompleter -Native -CommandName git -ScriptBlock $scriptblock

###########################
# Import Specific Modules #
###########################
# Define modules to load (add/remove module names as needed)
$desiredModules = @(
    # Add your desired module names here
     "Microsoft.PowerToys.Configure",
     "Microsoft.PowerShell.ConsoleGuiTools"
)

# Load specified modules
foreach ($moduleName in $desiredModules) {
    if (-not (Get-Module -Name $moduleName -ListAvailable)) {
        continue  # Skip if module is not installed
    }
    
    if (-not (Get-Module -Name $moduleName)) {
        try {
            Import-Module -Name $moduleName -ErrorAction Stop
        } catch {
            # Module failed to load, but continue silently
        }
    }
}

#########################
# Terminal-Icons Setup  #
#########################

# Check if Terminal-Icons module is installed and install if needed
if (-not (Get-Module -Name Terminal-Icons -ListAvailable)) {
    try {
        Write-Host "Installing Terminal-Icons module..." -ForegroundColor Cyan
        Install-Module -Name Terminal-Icons -Repository PSGallery -Force -AllowClobber -Scope CurrentUser
    } catch {
        Write-Host "Failed to install Terminal-Icons module. Please install manually." -ForegroundColor Yellow
    }
}

# Import Terminal-Icons if available
if (Get-Module -Name Terminal-Icons -ListAvailable) {
    try {
        Import-Module -Name Terminal-Icons -ErrorAction Stop
    } catch {
        # Module failed to load, but continue silently
    }
}

####################
# Oh My Posh Setup #
####################

# Check if oh-my-posh is installed and install if needed
if (-not (Get-Command oh-my-posh -ErrorAction SilentlyContinue)) {
    # Try to install via winget (fastest method)
    if (Get-Command winget -ErrorAction SilentlyContinue) {
        try {
            Write-Host "Installing Oh My Posh..." -ForegroundColor Cyan
            winget install JanDeDobbeleer.OhMyPosh -s winget --silent --disable-interactivity
            # Refresh PATH to make oh-my-posh available
            $env:PATH = [System.Environment]::GetEnvironmentVariable("PATH", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("PATH", "User")
        } catch {
            Write-Host "Failed to install Oh My Posh via winget. Please install manually." -ForegroundColor Yellow
        }
    }
}

# Initialize Oh My Posh with cobalt2 theme if available
if (Get-Command oh-my-posh -ErrorAction SilentlyContinue) {
    oh-my-posh init pwsh --config "$env:POSH_THEMES_PATH\cobalt2.omp.json" | Invoke-Expression
}

################
# Zoxide Setup #
################

# Check if zoxide is installed and install if needed
if (-not (Get-Command zoxide -ErrorAction SilentlyContinue)) {
    # Try to install via winget (fastest method)
    if (Get-Command winget -ErrorAction SilentlyContinue) {
        try {
            Write-Host "Installing Zoxide..." -ForegroundColor Cyan
            winget install ajeetdsouza.zoxide -s winget --silent --disable-interactivity
            # Refresh PATH to make zoxide available
            $env:PATH = [System.Environment]::GetEnvironmentVariable("PATH", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("PATH", "User")
        } catch {
            Write-Host "Failed to install Zoxide via winget. Please install manually." -ForegroundColor Yellow
        }
    }
}

# Initialize Zoxide if available
if (Get-Command zoxide -ErrorAction SilentlyContinue) {
    Invoke-Expression (& { (zoxide init powershell | Out-String) })
}

###############
# PSFzf Setup #
###############

# Check if PSFzf module is installed and install if needed
if (-not (Get-Module -Name PSFzf -ListAvailable)) {
    try {
        Write-Host "Installing PSFzf module..." -ForegroundColor Cyan
        Install-Module -Name PSFzf -Repository PSGallery -Force -AllowClobber -Scope CurrentUser
    } catch {
        Write-Host "Failed to install PSFzf module. Please install manually." -ForegroundColor Yellow
    }
}

# Import and configure PSFzf if available
if (Get-Module -Name PSFzf -ListAvailable) {
    try {
        Import-Module -Name PSFzf -ErrorAction Stop
        # Set PSFzf options for better integration
        Set-PsFzfOption -PSReadlineChordProvider 'Ctrl+f' -PSReadlineChordReverseHistory 'Ctrl+r'
    } catch {
        # Module failed to load, but continue silently
    }
}

#####################
# Utility Functions #
#####################
function Test-CommandExists {
    param($command)
    $exists = $null -ne (Get-Command $command -ErrorAction SilentlyContinue)
    return $exists
}

########################
# Editor Configuration #
########################
$EDITOR = if (Test-CommandExists cursor) { 'cursor' }
          elseif (Test-CommandExists code) { 'code' }
          elseif (Test-CommandExists notepad++) { 'notepad++' }
          else { 'notepad' }
Set-Alias -Name vim -Value $EDITOR
function Edit-Profile {
    cursor $PROFILE.CurrentUserCurrentHost
}
Set-Alias -Name ep -Value Edit-Profile

#########################
# Remove System Aliases #
#########################
$AliasesToRemove = @("gc")

foreach ($Alias in $AliasesToRemove) {
    if (Get-Alias $Alias -ErrorAction SilentlyContinue) {
        Remove-Item alias:$Alias -Force
    }
    else {
        Write-Debug "No Aliases to remove"
    }
}

###############
# Git aliases #
###############
function gs { git status }
function ga { git add . }
function gc { git commit -m $args }
function gp { git push }
function gpl { git pull }
function gcl { git clone $args }

function gcom {
    git add .
    git commit -m "$args"
}

function lazygit {
    git add .
    git commit -m "$args"
    git push
}

####################
# Enhanced listing #
####################
function ll { Get-ChildItem | Format-Table -AutoSize }
function la { Get-ChildItem -Force | Format-Table -AutoSize }


##########################
# Other Utility Commands #
##########################

function df {
    Get-Volume
}

function Update-Profile {
    & $profile
}

function uptime {
    try {
        # find date/time format
        $dateFormat = [System.Globalization.CultureInfo]::CurrentCulture.DateTimeFormat.ShortDatePattern
        $timeFormat = [System.Globalization.CultureInfo]::CurrentCulture.DateTimeFormat.LongTimePattern
		
        # check powershell version
        if ($PSVersionTable.PSVersion.Major -eq 5) {
            $lastBoot = (Get-WmiObject win32_operatingsystem).LastBootUpTime
            $bootTime = [System.Management.ManagementDateTimeConverter]::ToDateTime($lastBoot)

            # reformat lastBoot
            $lastBoot = $bootTime.ToString("$dateFormat $timeFormat")
        } else {
            $lastBoot = net statistics workstation | Select-String "since" | ForEach-Object { $_.ToString().Replace('Statistics since ', '') }
            $bootTime = [System.DateTime]::ParseExact($lastBoot, "$dateFormat $timeFormat", [System.Globalization.CultureInfo]::InvariantCulture)
        }

        # Format the start time
        $formattedBootTime = $bootTime.ToString("dddd, MMMM dd, yyyy HH:mm:ss", [System.Globalization.CultureInfo]::InvariantCulture) + " [$lastBoot]"
        Write-Host "System started on: $formattedBootTime" -ForegroundColor DarkGray

        # calculate uptime
        $uptime = (Get-Date) - $bootTime

        # Uptime in days, hours, minutes, and seconds
        $days = $uptime.Days
        $hours = $uptime.Hours
        $minutes = $uptime.Minutes
        $seconds = $uptime.Seconds

        # Uptime output
        Write-Host ("Uptime: {0} days, {1} hours, {2} minutes, {3} seconds" -f $days, $hours, $minutes, $seconds) -ForegroundColor Blue

    } catch {
        Write-Error "An error occurred while retrieving system uptime."
    }
}

function admin {
    if ($args.Count -gt 0) {
        $argList = $args -join ' '
        Start-Process wt -Verb runAs -ArgumentList "pwsh.exe -NoExit -Command $argList"
    } else {
        Start-Process wt -Verb runAs
    }
}
Set-Alias -Name su -Value admin

function Get-PubIP { (Invoke-WebRequest http://ifconfig.me/ip).Content }

function touch($file) { "" | Out-File $file -Encoding ASCII }

function ff($name) {
    Get-ChildItem -recurse -filter "*${name}*" -ErrorAction SilentlyContinue | ForEach-Object {
        Write-Output "$($_.FullName)"
    }
}

function Clear-Cache {
    # add clear cache logic here
    Write-Host "Clearing cache..." -ForegroundColor Cyan

    # Clear Windows Prefetch
    Write-Host "Clearing Windows Prefetch..." -ForegroundColor Yellow
    Remove-Item -Path "$env:SystemRoot\Prefetch\*" -Force -ErrorAction SilentlyContinue

    # Clear Windows Temp
    Write-Host "Clearing Windows Temp..." -ForegroundColor Yellow
    Remove-Item -Path "$env:SystemRoot\Temp\*" -Recurse -Force -ErrorAction SilentlyContinue

    # Clear User Temp
    Write-Host "Clearing User Temp..." -ForegroundColor Yellow
    Remove-Item -Path "$env:TEMP\*" -Recurse -Force -ErrorAction SilentlyContinue

    # Clear Internet Explorer Cache
    Write-Host "Clearing Internet Explorer Cache..." -ForegroundColor Yellow
    Remove-Item -Path "$env:LOCALAPPDATA\Microsoft\Windows\INetCache\*" -Recurse -Force -ErrorAction SilentlyContinue

    Write-Host "Cache clearing completed." -ForegroundColor Green
}

######################
# Archive Management #
######################

function Unzip {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true, Position=0)]
        [string]$ArchivePath,
        
        [Parameter(Mandatory=$false, Position=1)] 
        [string]$DestinationPath = ".",
        
        [ValidateSet("Overwrite", "Skip", "Rename")]
        [string]$ConflictAction = "Skip",
        
        [string]$Password
    )

    # Find 7zip executable
    $7zipPaths = @(
        "C:\Program Files\7-Zip\7z.exe",
        "C:\Program Files (x86)\7-Zip\7z.exe"
    )
    
    $7zipExe = $null
    
    # Check common installation paths
    foreach ($path in $7zipPaths) {
        if (Test-Path $path) {
            $7zipExe = $path
            break
        }
    }
    
    # Check if 7z is in PATH
    if (-not $7zipExe) {
        try {
            $7zipExe = (Get-Command 7z -ErrorAction Stop).Source
        } catch {
            Write-Error "7zip not found. Please ensure 7zip is installed."
            return
        }
    }

    # Validate archive file exists
    if (-not (Test-Path $ArchivePath)) {
        Write-Error "Archive file not found: $ArchivePath"
        return
    }

    # Resolve full paths and set smart destination
    $ArchivePath = Resolve-Path $ArchivePath
    
    if ($DestinationPath -eq ".") {
        # Create directory named after archive (without extension)
        $archiveBaseName = [System.IO.Path]::GetFileNameWithoutExtension($ArchivePath)
        $DestinationPath = Join-Path (Get-Location) $archiveBaseName
    } else {
        $DestinationPath = $DestinationPath
    }

    # Create destination directory if it doesn't exist
    if (-not (Test-Path $DestinationPath)) {
        try {
            New-Item -ItemType Directory -Path $DestinationPath -Force | Out-Null
            Write-Host "Created destination directory: $DestinationPath" -ForegroundColor Green
        } catch {
            Write-Error "Failed to create destination directory: $DestinationPath"
            return
        }
    }

    # Set conflict action parameter
    $conflictParam = switch ($ConflictAction) {
        "Overwrite" { "-aoa" }
        "Skip" { "-aos" }
        "Rename" { "-aou" }
    }

    # Build 7zip arguments
    $arguments = @(
        "x",                    # Extract command
        "`"$ArchivePath`"",    # Archive file (quoted for spaces)
        "-o`"$DestinationPath`"", # Output directory (quoted for spaces)
        $conflictParam,         # Conflict handling
        "-bb1",                 # Basic progress info
        "-bsp1",               # Redirect progress to stdout
        "-y"                   # Assume Yes to all prompts
    )

    # Add password if provided
    if ($Password) {
        $arguments += "-p$Password"
    }

    Write-Host "Extracting archive: " -NoNewline -ForegroundColor Cyan
    Write-Host (Split-Path $ArchivePath -Leaf) -ForegroundColor Yellow
    Write-Host "Destination: " -NoNewline -ForegroundColor Cyan  
    Write-Host $DestinationPath -ForegroundColor Yellow
    Write-Host "Conflict action: " -NoNewline -ForegroundColor Cyan
    Write-Host $ConflictAction -ForegroundColor Yellow
    Write-Host ""

    try {
        # Execute 7zip with real-time progress
        $process = Start-Process -FilePath $7zipExe -ArgumentList $arguments -NoNewWindow -PassThru -RedirectStandardOutput "temp_7zip_output.txt" -RedirectStandardError "temp_7zip_error.txt"
        
        # Monitor progress
        $fileCount = 0
        $lastOutputLength = 0
        
        while (-not $process.HasExited) {
            Start-Sleep -Milliseconds 200
            
            if (Test-Path "temp_7zip_output.txt") {
                try {
                    $content = Get-Content "temp_7zip_output.txt" -ErrorAction SilentlyContinue
                    if ($content -and $content.Length -gt $lastOutputLength) {
                        $newLines = $content[$lastOutputLength..($content.Length - 1)]
                        $lastOutputLength = $content.Length
                        
                        foreach ($line in $newLines) {
                            if ($line -and $line -match "^- (.+)$") {
                                $fileCount++
                                $fileName = $matches[1]
                                if ($fileName) {
                                    Write-Host "`rExtracting: " -NoNewline -ForegroundColor Green
                                    Write-Host $fileName -NoNewline -ForegroundColor White
                                    Write-Host " ($fileCount files)" -ForegroundColor Gray
                                }
                            }
                        }
                    }
                } catch {
                    # Continue silently if progress reading fails
                }
            }
        }

        $process.WaitForExit()
        
        # Check for errors
        if ($process.ExitCode -eq 0) {
            Write-Host "`n✅ Extraction completed successfully!" -ForegroundColor Green
            Write-Host "Files extracted to: $DestinationPath" -ForegroundColor Cyan
        } else {
            $errorOutput = ""
            if (Test-Path "temp_7zip_error.txt") {
                $errorOutput = Get-Content "temp_7zip_error.txt" -Raw -ErrorAction SilentlyContinue
            }
            Write-Error "7zip extraction failed with exit code: $($process.ExitCode)`n$errorOutput"
        }

    } catch {
        Write-Error "Failed to execute 7zip: $($_.Exception.Message)"
    } finally {
        # Clean up temporary files
        Remove-Item "temp_7zip_output.txt" -ErrorAction SilentlyContinue
        Remove-Item "temp_7zip_error.txt" -ErrorAction SilentlyContinue
    }
}

# Register custom tab completion for Unzip function - only show archive files
Register-ArgumentCompleter -CommandName Unzip -ParameterName ArchivePath -ScriptBlock {
    param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
    
    # Define supported archive extensions
    $archiveExtensions = @(
        '*.zip', '*.7z', '*.rar', '*.tar', '*.gz', '*.bz2', 
        '*.xz', '*.lzma', '*.cab', '*.iso', '*.wim', '*.deb', 
        '*.rpm', '*.msi', '*.lzh', '*.lha', '*.z', '*.taz'
    )
    
    # Get archive files matching the word being completed
    $files = Get-ChildItem -Path "$wordToComplete*" -Include $archiveExtensions -ErrorAction SilentlyContinue
    
    # Return completion results
    $files | ForEach-Object {
        [System.Management.Automation.CompletionResult]::new(
            $_.Name,           # CompletionText
            $_.Name,           # ListItemText  
            'ParameterValue',  # ResultType
            $_.Name            # ToolTip
        )
    }
}