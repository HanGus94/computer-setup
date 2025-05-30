# PowerShell 7+ Profile Configuration
# Version: 1.2.0
# Description: Enhanced PowerShell profile with useful aliases and functions

# Set console to UTF-8
[console]::InputEncoding = [console]::OutputEncoding = New-Object System.Text.UTF8Encoding

# Improved tab completion
Set-PSReadLineOption -PredictionSource History -PredictionViewStyle ListView
Set-PSReadLineKeyHandler -Key Tab -Function MenuComplete

# Useful aliases
Set-Alias -Name ll -Value Get-ChildItem
Set-Alias -Name grep -Value Select-String
Set-Alias -Name which -Value Get-Command

# Custom functions
function Get-PublicIP {
    (Invoke-WebRequest -uri "https://api.ipify.org/").Content
}

function Get-Weather {
    param([string]$City = "Stockholm")
    $weather = Invoke-RestMethod "https://wttr.in/${City}?format=3"
    Write-Host $weather -ForegroundColor Yellow
}

function Get-GitStatus {
    git status --porcelain
}

# Set location to a useful directory if it exists
if (Test-Path "C:\dev") {
    Set-Location "C:\dev"
}

Write-Host "PowerShell Profile v1.2.0 loaded successfully!" -ForegroundColor Green 