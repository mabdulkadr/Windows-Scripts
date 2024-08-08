<#
.SYNOPSIS
    This script tests the connection to a domain controller and optionally resets the secure channel to fix the trust relationship if needed.

.DESCRIPTION
    The script provides a menu with three options:
    1. Test the connection to the domain controller.
    2. Reset the secure channel to fix the trust relationship if the connection fails.
    3. Exit the script.

.PARAMETER DomainController
    The name of the domain controller to test the connection with and reset the secure channel if needed.

.NOTES
    Author  : M.omar
    Website : momar.tech
    Date    : 2024-08-07
    Version : 1.0
#>

Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass

param (
    [string]$DomainController
)

# Function to test the connection to the domain controller
function Test-DomainConnection {
    param (
        [string]$DC
    )
    try {
        $ping = Test-Connection -ComputerName $DC -Count 1 -Quiet
        if ($ping) {
            Write-Host "Connection to domain controller $DC is successful." -ForegroundColor Green
            return $true
        } else {
            Write-Host "Failed to connect to domain controller $DC." -ForegroundColor Red
            return $false
        }
    } catch {
        Write-Host "Error testing connection to domain controller: $_" -ForegroundColor Red
        return $false
    }
}

# Function to reset the secure channel with the domain controller
function Reset-SecureChannel {
    param (
        [string]$DC
    )
    Write-Host "Resetting secure channel with domain controller: $DC" -ForegroundColor Cyan
    try {
        $Credential = Get-Credential -Message "Enter domain admin credentials"
        Reset-ComputerMachinePassword -Server $DC -Credential $Credential
        Write-Host "Secure channel reset successfully." -ForegroundColor Green
        Write-Host ""
    } catch {
        Write-Host "Error resetting secure channel: $_" -ForegroundColor Red
    }
}

# Menu function to provide user options
function Show-Menu {
    Clear-Host
    Write-Host "======================================" -ForegroundColor Cyan
    Write-Host "           Domain Trust Fixer          " -ForegroundColor Cyan
    Write-Host "======================================" -ForegroundColor Cyan
    Write-Host "Select an option:" -ForegroundColor Cyan
    Write-Host "1. Test connection to the domain controller" -ForegroundColor Yellow
    Write-Host "2. Fix trust relationship (Reset secure channel)" -ForegroundColor Yellow
    Write-Host "3. Exit" -ForegroundColor Yellow
    Write-Host "======================================" -ForegroundColor Cyan
    Write-Host ""
}

    Clear-Host
    Write-Host ""
# Main script logic
if (-not $DomainController) {
    $DomainController = Read-Host "Enter the domain controller name"
}

while ($true) {
    Show-Menu
    $choice = Read-Host "Enter your choice (1-3)"
    switch ($choice) {
        1 {
            Test-DomainConnection -DC $DomainController
            Write-Host ""
            Pause
        }
        2 {
            Write-Host "Attempting to reset the secure channel." -ForegroundColor Yellow
            Reset-SecureChannel -DC $DomainController
            Write-Host ""
            Pause
        }
        3 {
            Write-Host "Exiting script." -ForegroundColor Yellow
            Write-Host ""
            break
        }
        default {
            Write-Host "Invalid choice. Please select 1, 2, or 3." -ForegroundColor Red
            Write-Host ""
            Pause
        }
    }
}
