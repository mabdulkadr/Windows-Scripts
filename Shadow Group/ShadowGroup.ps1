<#
.SYNOPSIS
    Maintains a shadow group in Active Directory that mirrors users in one or more Organizational Units (OUs).

.DESCRIPTION
    This script ensures that all users in the specified OUs are members of a corresponding shadow group.
    It also removes users from the shadow group if they are no longer in the specified OUs.
    The script supports multiple OUs and an option to include/exclude child OUs.
    Additionally, it supports logging and can run in "dry-run" mode for testing purposes.

.EXAMPLE
    .\ShadowGroup.ps1
    Runs the script with predefined settings to update the shadow group.

.NOTES
    Author  : Mohammad Abdelkader
    Website : momar.tech
    Date    : 2025-02-02
    Version : 1.0
#>

###############################################################################
# PARAMETERS
###############################################################################

# Domain Controller that supports Active Directory module
$Server = "dc01.example.com"

# Log file location
$LogFile = "C:\ShadowGroups\ShadowGroup.log"

# Ensure log file exists
If (!(Test-Path $LogFile)) {
    New-Item -ItemType File -Path $LogFile -Force | Out-Null
}

# Enable/Disable actual modifications (True applies changes, False logs only)
$Update = $true

# Include only enabled users (True excludes disabled accounts)
$EnabledOnly = $True

# Organizational Units to monitor
$OUDNs = @("OU=HR,OU=Company,DC=example,DC=com", "OU=IT,OU=Company,DC=example,DC=com")

# Include child OUs (True considers sub-OUs, False restricts to direct OU members)
$ChildOUs = $true

# Shadow Group Distinguished Name (Must exist in AD)
$GroupDN = "CN=Shadow-Group,OU=Security,DC=example,DC=com"

# Maximum modifications per run to prevent excessive network load
$MaxChanges = 4000

###############################################################################
# SCRIPT EXECUTION
###############################################################################

# Import Active Directory Module
Try {
    Import-Module ActiveDirectory -ErrorAction Stop -WarningAction Stop
} Catch {
    Write-Host "Active Directory module not found. Script aborted." -ForegroundColor Red
    Break
}

# Verify Domain Controller connectivity
If (-Not (Test-Connection -ComputerName $Server -Count 1 -Quiet)) {
    Write-Host "Error: Unable to connect to $Server. Script aborted." -ForegroundColor Red
    Break
}

# Ensure valid OUs
ForEach ($OUDN In $OUDNs) {
    Try {
        [ADSI]"LDAP://$OUDN" | Out-Null
    } Catch {
        Write-Host "Error: Invalid OU $OUDN. Script aborted." -ForegroundColor Red
        Break
    }
}

# Validate shadow group existence
Try {
    [ADSI]"LDAP://$GroupDN" | Out-Null
} Catch {
    Write-Host "Error: Invalid group $GroupDN. Script aborted." -ForegroundColor Red
    Break
}

# Determine LDAP search scope
$Scope = If ($ChildOUs) { "SubTree" } Else { "OneLevel" }

# Retrieve current group members
Try {
    $Members = Get-ADUser -LDAPFilter "(memberOf=$GroupDN)" -Server $Server | Select distinguishedName, Enabled
} Catch {
    Write-Host "Error: Unable to retrieve group members. Script aborted." -ForegroundColor Red
    Break
}

# Prepare logging
Try {
    Add-Content -Path $LogFile -Value "--- Script Execution Start: $(Get-Date) ---"
} Catch {
    Write-Host "Error: Cannot write to log file. Script aborted." -ForegroundColor Red
    Break
}

# Users to add and remove
$UsersToAdd = @()
$UsersToRemove = @()

# Evaluate group membership
ForEach ($Member In $Members) {
    If ($EnabledOnly -and -Not $Member.Enabled) {
        $UsersToRemove += $Member.distinguishedName
    } Else {
        $UserOU = ($Member.distinguishedName -split ",", 2)[1]
        If ($OUDNs -notcontains $UserOU) {
            $UsersToRemove += $Member.distinguishedName
        }
    }
}

# Fetch users in OUs not in the group
$Filter = "(!(memberOf=$GroupDN))"
If ($EnabledOnly) {
    $Filter = "(&" + $Filter + "(!(userAccountControl:1.2.840.113556.1.4.803:=2)))"
}

ForEach ($OUDN In $OUDNs) {
    $UsersInOU = Get-ADUser -SearchBase $OUDN -SearchScope $Scope -LDAPFilter $Filter -Server $Server
    ForEach ($User in $UsersInOU) {
        $UsersToAdd += $User.distinguishedName
    }
}

# Apply changes if enabled
If ($Update) {
    If ($UsersToRemove.Count -gt 0) {
        Remove-ADGroupMember -Identity $GroupDN -Members $UsersToRemove -Server $Server -Confirm:$False
    }
    If ($UsersToAdd.Count -gt 0) {
        Add-ADGroupMember -Identity $GroupDN -Members $UsersToAdd -Server $Server
    }
}

# Log completion
Add-Content -Path $LogFile -Value "Users Removed: $($UsersToRemove.Count)"
Add-Content -Path $LogFile -Value "Users Added: $($UsersToAdd.Count)"
Add-Content -Path $LogFile -Value "--- Script Execution End: $(Get-Date) ---"

# Display summary
Write-Host "Execution completed. See log: $LogFile"
Write-Host "Users removed: $($UsersToRemove.Count)" -ForegroundColor Yellow
Write-Host "Users added: $($UsersToAdd.Count)" -ForegroundColor Green
