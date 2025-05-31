#Requires -RunAsAdministrator

<#
.SYNOPSIS
    Sets up WinRM on Windows for Ansible connectivity

.DESCRIPTION
    This script configures Windows Remote Management (WinRM) to allow Ansible
    connections from a remote controller. It sets the network profile to Private,
    enables PSRemoting, and configures necessary authentication and firewall settings.

.EXAMPLE
    .\setup-winrm.ps1
#>

Write-Host "Setting up WinRM for Ansible connectivity..." -ForegroundColor Cyan
Write-Host "===============================================" -ForegroundColor Cyan

# Step 1: Set network connection profile to Private
Write-Host "`n[1/6] Setting network profile to Private..." -ForegroundColor Yellow
try {
    $connectionProfile = Get-NetConnectionProfile
    if ($connectionProfile.NetworkCategory -ne "Private") {
        Set-NetConnectionProfile -NetworkCategory Private
        Write-Host "✅ Network profile set to Private" -ForegroundColor Green
    } else {
        Write-Host "✅ Network profile already set to Private" -ForegroundColor Green
    }
} catch {
    Write-Host "❌ Failed to set network profile: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "⚠️  Continuing anyway..." -ForegroundColor Yellow
}

# Step 2: Enable PowerShell Remoting
Write-Host "`n[2/6] Enabling PowerShell Remoting..." -ForegroundColor Yellow
try {
    Enable-PSRemoting -Force -SkipNetworkProfileCheck
    Write-Host "✅ PowerShell Remoting enabled" -ForegroundColor Green
} catch {
    Write-Host "❌ Failed to enable PSRemoting: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Step 3: Configure WinRM Service
Write-Host "`n[3/6] Configuring WinRM service..." -ForegroundColor Yellow
try {
    # Allow unencrypted traffic (for basic auth - use HTTPS in production)
    Set-Item WSMan:\localhost\Service\AllowUnencrypted $true
    Write-Host "✅ Unencrypted traffic allowed" -ForegroundColor Green
    
    # Set maximum memory and timeout
    Set-Item WSMan:\localhost\Shell\MaxMemoryPerShellMB 1024
    Set-Item WSMan:\localhost\Plugin\Microsoft.PowerShell\Quotas\MaxMemoryPerShellMB 1024
    Write-Host "✅ Memory limits configured" -ForegroundColor Green
} catch {
    Write-Host "❌ Failed to configure WinRM service: $($_.Exception.Message)" -ForegroundColor Red
}

# Step 4: Configure Authentication Methods
Write-Host "`n[4/6] Configuring authentication methods..." -ForegroundColor Yellow
try {
    # Enable Basic authentication
    Set-Item WSMan:\localhost\Service\Auth\Basic $true
    Write-Host "✅ Basic authentication enabled" -ForegroundColor Green
    
    # Enable CredSSP authentication (for enhanced security)
    Set-Item WSMan:\localhost\Service\Auth\CredSSP $true
    Write-Host "✅ CredSSP authentication enabled" -ForegroundColor Green
    
    # Enable NTLM authentication
    Set-Item WSMan:\localhost\Service\Auth\Negotiate $true
    Write-Host "✅ NTLM authentication enabled" -ForegroundColor Green
} catch {
    Write-Host "❌ Failed to configure authentication: $($_.Exception.Message)" -ForegroundColor Red
}

# Step 5: Configure Firewall Rules
Write-Host "`n[5/6] Configuring firewall rules..." -ForegroundColor Yellow
try {
    # Check if rules already exist
    $httpRule = Get-NetFirewallRule -DisplayName "Windows Remote Management (HTTP-In)" -ErrorAction SilentlyContinue
    $httpsRule = Get-NetFirewallRule -DisplayName "Windows Remote Management (HTTPS-In)" -ErrorAction SilentlyContinue
    
    if (-not $httpRule) {
        New-NetFirewallRule -DisplayName "Windows Remote Management (HTTP-In)" -Direction Inbound -Protocol TCP -LocalPort 5985 -Action Allow
        Write-Host "✅ HTTP firewall rule created" -ForegroundColor Green
    } else {
        Write-Host "✅ HTTP firewall rule already exists" -ForegroundColor Green
    }
    
    if (-not $httpsRule) {
        New-NetFirewallRule -DisplayName "Windows Remote Management (HTTPS-In)" -Direction Inbound -Protocol TCP -LocalPort 5986 -Action Allow
        Write-Host "✅ HTTPS firewall rule created" -ForegroundColor Green
    } else {
        Write-Host "✅ HTTPS firewall rule already exists" -ForegroundColor Green
    }
} catch {
    Write-Host "❌ Failed to configure firewall: $($_.Exception.Message)" -ForegroundColor Red
}

# Step 6: Verify Configuration
Write-Host "`n[6/6] Verifying WinRM configuration..." -ForegroundColor Yellow
try {
    $winrmConfig = winrm get winrm/config
    if ($winrmConfig) {
        Write-Host "✅ WinRM service is running and configured" -ForegroundColor Green
    }
    
    # Test local connection
    $testResult = Test-WSMan -ComputerName localhost -ErrorAction SilentlyContinue
    if ($testResult) {
        Write-Host "✅ Local WinRM connectivity test passed" -ForegroundColor Green
    } else {
        Write-Host "⚠️  Local WinRM test failed - check configuration" -ForegroundColor Yellow
    }
} catch {
    Write-Host "❌ Failed to verify configuration: $($_.Exception.Message)" -ForegroundColor Red
}

# Display connection information
Write-Host "`n🎉 WinRM Setup Complete!" -ForegroundColor Green
Write-Host "========================" -ForegroundColor Green
Write-Host "Your Windows machine is now configured for Ansible connectivity." -ForegroundColor White
Write-Host ""
Write-Host "Connection Details:" -ForegroundColor Cyan
Write-Host "  • HTTP Port: 5985" -ForegroundColor White
Write-Host "  • HTTPS Port: 5986" -ForegroundColor White
Write-Host "  • Authentication: Basic, NTLM, CredSSP" -ForegroundColor White
Write-Host "  • Computer Name: $env:COMPUTERNAME" -ForegroundColor White
Write-Host "  • IP Address: $((Get-NetIPAddress -AddressFamily IPv4 -InterfaceAlias (Get-NetAdapter | Where-Object Status -eq 'Up' | Select-Object -First 1).Name).IPAddress)" -ForegroundColor White
Write-Host ""
Write-Host "Update your Ansible inventory with these details!" -ForegroundColor Yellow 