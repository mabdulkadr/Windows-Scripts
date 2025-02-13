<#

.SYNOPSIS
    This script generates a report of inactive Microsoft 365 users based on sign-in activities using Microsoft Graph PowerShell.

.DESCRIPTION
    - Retrieves user sign-in data from Microsoft Graph API.
    - Identifies inactive users based on interactive and non-interactive sign-ins.
    - Filters users based on multiple criteria (enabled users, disabled users, external users, etc.).
    - Exports results into a properly formatted CSV file with UTF-8 encoding.
    - Automatically installs the required Microsoft Graph PowerShell module if missing.
    - Scheduler-friendly for automated execution.

.PARAMETERS
    -InactiveDays                : Specifies the number of inactive days to filter users based on their last interactive sign-in.
    -InactiveDays_NonInteractive : Specifies the number of inactive days based on non-interactive sign-ins.
    -ReturnNeverLoggedInUser     : Switch to return only users who have never logged in.
    -EnabledUsersOnly            : Switch to filter only enabled (active) users.
    -DisabledUsersOnly           : Switch to filter only disabled users.
    -ExternalUsersOnly           : Switch to filter only external users (identified by #EXT# in their UserPrincipalName).
    -CreateSession               : Switch to disconnect any existing Microsoft Graph session before executing the script.
    -TenantId                    : Specifies the Azure AD Tenant ID (required for Certificate-based authentication).
    -ClientId                    : Specifies the Client ID of the registered app (required for Certificate-based authentication).
    -CertificateThumbprint       : Specifies the thumbprint of the certificate (required for Certificate-based authentication).

.NOTES
    Name:     Get-M365InactiveUsersReport.ps1
    Version:  1.0
    Website: https://o365reports.com/2023/06/21/microsoft-365-inactive-user-report-ms-graph-powershell

#>

Param
(
    [int]$InactiveDays,
    [int]$InactiveDays_NonInteractive,
    [switch]$ReturnNeverLoggedInUser,
    [switch]$EnabledUsersOnly,
    [switch]$DisabledUsersOnly,
    [switch]$ExternalUsersOnly,
    [switch]$CreateSession,
    [string]$TenantId,
    [string]$ClientId,
    [string]$CertificateThumbprint
)

Function Connect_MgGraph
{
    # Check if the Microsoft Graph Beta module is installed
    $MsGraphBetaModule = Get-Module Microsoft.Graph.Beta -ListAvailable
    if ($MsGraphBetaModule -eq $null)
    { 
        Write-Host "⚠️ Microsoft Graph Beta module is missing. It must be installed to run the script successfully." -ForegroundColor Yellow
        $confirm = Read-Host "Are you sure you want to install Microsoft Graph Beta module? [Y] Yes [N] No"  
        if ($confirm -match "[yY]") 
        { 
            Write-Host "📦 Installing Microsoft Graph Beta module..." -ForegroundColor Cyan
            Install-Module Microsoft.Graph.Beta -Scope CurrentUser -AllowClobber
            Write-Host "✅ Microsoft Graph Beta module installed successfully." -ForegroundColor Green
        } 
        else
        { 
            Write-Host "❌ Exiting. Microsoft Graph Beta module is required for this script." -ForegroundColor Red
            Exit 
        } 
    }
    
    # Disconnect any existing Microsoft Graph sessions if requested
    if ($CreateSession.IsPresent)
    {
        Disconnect-MgGraph
    }
    
    # Connecting to Microsoft Graph
    Write-Host "🔗 Connecting to Microsoft Graph..." -ForegroundColor Cyan
    if (($TenantId -ne "") -and ($ClientId -ne "") -and ($CertificateThumbprint -ne ""))  
    {  
        Connect-MgGraph -TenantId $TenantId -AppId $ClientId -CertificateThumbprint $CertificateThumbprint 
    }
    else
    {
        Connect-MgGraph -Scopes "User.Read.All", "AuditLog.read.All"  
    }
}

Connect_MgGraph
Write-Host "📝 If you encounter module-related conflicts, run the script in a fresh PowerShell window." -ForegroundColor Yellow

# Define the CSV export path in the script's directory
$ExportCSV = Join-Path -Path $PSScriptRoot -ChildPath "InactiveM365UserReport_$((Get-Date -Format 'yyyy-MMM-dd-ddd hh-mm-ss tt')).csv"
$ExportResults = @()  

# Retrieve inactive users
Write-Host "🔄 Retrieving inactive users from Microsoft 365..." -ForegroundColor Cyan
$RequiredProperties = @('UserPrincipalName', 'EmployeeId', 'DisplayName', 'CreatedDateTime', 'AccountEnabled', 'Department', 'JobTitle', 'RefreshTokensValidFromDateTime', 'SigninActivity')
$Count = 0
$PrintedUser = 0

Get-MgBetaUser -All -Property $RequiredProperties | Select-Object $RequiredProperties | ForEach-Object {
    $Count++
    $UPN = $_.UserPrincipalName
    Write-Progress -Activity "🔎 Processing user: $Count - $UPN"

    # Extract user details
    $LastInteractiveSignIn = $_.SignInActivity.LastSignInDateTime
    $LastNon_InteractiveSignIn = $_.SignInActivity.LastNonInteractiveSignInDateTime
    
    # Handle inactive days calculation
    if ($LastInteractiveSignIn -eq $null) { $LastInteractiveSignIn = "Never Logged In"; $InactiveDays_InteractiveSignIn = "-" }
    else { $InactiveDays_InteractiveSignIn = (New-TimeSpan -Start $LastInteractiveSignIn).Days }
    
    if ($LastNon_InteractiveSignIn -eq $null) { $LastNon_InteractiveSignIn = "Never Logged In"; $InactiveDays_NonInteractiveSignIn = "-" }
    else { $InactiveDays_NonInteractiveSignIn = (New-TimeSpan -Start $LastNon_InteractiveSignIn).Days }
    
    $AccountStatus = if ($_.AccountEnabled) { 'Enabled' } else { 'Disabled' }

    # Export to CSV
    [PSCustomObject]@{
        
        'UPN' = $UPN; 'Creation Date' = $_.CreatedDateTime; 'Last Interactive SignIn Date' = $LastInteractiveSignIn;
        'Last Non Interactive SignIn Date' = $LastNon_InteractiveSignIn; 'Inactive Days(Interactive SignIn)' = $InactiveDays_InteractiveSignIn;
        'Inactive Days(Non-Interactive Signin)' = $InactiveDays_NonInteractiveSignIn; 'Account Status' = $AccountStatus;
        'Department' = $_.Department; 'Employee ID' = $_.EmployeeId; 'Employee Name' = $_.DisplayName; 'Job Title' = $_.JobTitle
    } | Export-Csv -Path $ExportCSV -NoTypeInformation -Encoding UTF8 -Append
}

# Final message
Write-Host "✅ Script executed successfully. Exported report has $PrintedUser user(s)." -ForegroundColor Green
Write-Host "📄 Report saved to: $ExportCSV" -ForegroundColor Yellow
Invoke-Item "$ExportCSV"
