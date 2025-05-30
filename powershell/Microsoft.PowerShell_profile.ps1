# PowerShell Profile
# Version: 1.2.0
# Description: Custom PowerShell profile with enhanced functionality

# Set console properties
$Host.UI.RawUI.WindowTitle = "PowerShell - $(Get-Location)"
$Host.UI.RawUI.ForegroundColor = "White"

# Custom prompt function
function prompt {
    $currentPath = (Get-Location).Path
    $currentTime = Get-Date -Format "HH:mm:ss"
    
    # Shorten path if too long
    if ($currentPath.Length -gt 50) {
        $parentPath = Split-Path $currentPath -Parent
        $currentDir = Split-Path $currentPath -Leaf
        $shortenedParent = $parentPath.Substring(0, [Math]::Min(20, $parentPath.Length)) + "..."
        $currentPath = Join-Path $shortenedParent $currentDir
    }
    
    Write-Host "[$currentTime] " -NoNewline -ForegroundColor Gray
    Write-Host "$currentPath" -NoNewline -ForegroundColor Cyan
    Write-Host " PS>" -NoNewline -ForegroundColor Green
    return " "
}

# Useful aliases
Set-Alias -Name ll -Value Get-ChildItem
Set-Alias -Name grep -Value Select-String
Set-Alias -Name which -Value Get-Command

# Custom functions
function Get-Weather {
    param([string]$City = "London")
    try {
        $weather = Invoke-RestMethod -Uri "https://wttr.in/$City?format=3"
        Write-Host $weather -ForegroundColor Yellow
    } catch {
        Write-Warning "Could not fetch weather data"
    }
}

function Update-Profile {
    . $PROFILE
    Write-Host "Profile reloaded!" -ForegroundColor Green
}

function Get-SystemInfo {
    $info = @{
        'Computer Name' = $env:COMPUTERNAME
        'Username' = $env:USERNAME
        'OS Version' = (Get-CimInstance Win32_OperatingSystem).Caption
        'PowerShell Version' = $PSVersionTable.PSVersion
        'Current Time' = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    }
    
    $info.GetEnumerator() | Sort-Object Name | Format-Table -AutoSize
}

# Module auto-loading
$modules = @('PSReadLine', 'posh-git')
foreach ($module in $modules) {
    if (Get-Module -ListAvailable -Name $module) {
        Import-Module $module -ErrorAction SilentlyContinue
    }
}

# PSReadLine configuration (if available)
if (Get-Module PSReadLine) {
    Set-PSReadLineOption -PredictionSource History
    Set-PSReadLineOption -EditMode Emacs
    Set-PSReadLineKeyHandler -Key Tab -Function Complete
}

Write-Host "PowerShell Profile v1.2.0 loaded successfully!" -ForegroundColor Green 