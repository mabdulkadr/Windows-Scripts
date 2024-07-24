<#
.SYNOPSIS
    This script generates a report of Office 365 users' real last logon times and exports it to a CSV file.

.DESCRIPTION
    The script performs the following actions:
    1. Checks if the required Exchange Online and MSOnline modules are installed, and installs them if not.
    2. Loads the necessary modules.
    3. Authenticates to Azure AD and Exchange Online.
    4. Retrieves mailbox statistics for each user.
    5. Filters the users based on various parameters (inactive days, mailbox type, license status, etc.).
    6. Exports the final report to a CSV file at C:\LastAccessTimeReport_<timestamp>.csv.

.PARAMETER MBNamesFile
    The path to a CSV file containing the list of mailbox identities.

.PARAMETER InactiveDays
    The number of days a user has been inactive. Used to filter the results.

.PARAMETER UserMailboxOnly
    If specified, only user mailboxes are included in the report.

.PARAMETER LicensedUserOnly
    If specified, only users with assigned licenses are included in the report.

.PARAMETER ReturnNeverLoggedInMBOnly
    If specified, only mailboxes that have never been logged into are included in the report.

.PARAMETER UserName
    The username for authentication when using non-MFA login.

.PARAMETER Password
    The password for authentication when using non-MFA login.

.PARAMETER FriendlyTime
    If specified, converts date and time to a more human-readable format.

.PARAMETER NoMFA
    If specified, authenticates using non-MFA credentials.

.NOTES
    Author: M.omar
    Website: momar.tech
    Date: 2024-07-11
    Version: 1.0
#>

# Accept input parameters
Param
(
    [Parameter(Mandatory = $false)]
    [string]$MBNamesFile,
    [int]$InactiveDays,
    [switch]$UserMailboxOnly,
    [switch]$LicensedUserOnly,
    [switch]$ReturnNeverLoggedInMBOnly,
    [string]$UserName,
    [string]$Password,
    [switch]$FriendlyTime,
    [switch]$NoMFA
)

Function ConvertTo-HumanDate {
    param (
        [datetime]$InputDate
    )
    return $InputDate.ToString("MMM dd, yyyy hh:mm tt")
}

Function Get_LastLogonTime {
    param (
        [string]$upn,
        [string]$DisplayName,
        [string]$CreationTime,
        [string]$MBType
    )

    $MailboxStatistics = Get-MailboxStatistics -Identity $upn
    $LastActionTime = $MailboxStatistics.LastUserActionTime
    $LastActionTimeUpdatedOn = $MailboxStatistics.LastUserActionUpdateTime
    $RolesAssigned = ""
    Write-Progress -Activity "`nProcessed mailbox count: $MBUserCount " -Status "Currently Processing: $DisplayName"

    # Retrieve last logon time and calculate inactive days 
    if ($LastActionTime -eq $null) {
        $LastActionTime = "Never Logged In"
        $InactiveDaysOfUser = "-"
    } else {
        $InactiveDaysOfUser = (New-TimeSpan -Start $LastActionTime).Days
        # Convert Last Action Time to Friendly Time
        if ($FriendlyTime.IsPresent) {
            $FriendlyLastActionTime = ConvertTo-HumanDate $LastActionTime
            $LastActionTime = "$LastActionTime ($FriendlyLastActionTime)"
        }
    }
    # Convert Last Action Time Updated On to Friendly Time
    if ($LastActionTimeUpdatedOn -ne $null) {
        if ($FriendlyTime.IsPresent) {
            $FriendlyLastActionTimeUpdatedOn = ConvertTo-HumanDate $LastActionTimeUpdatedOn
            $LastActionTimeUpdatedOn = "$LastActionTimeUpdatedOn ($FriendlyLastActionTimeUpdatedOn)"
        }
    } else {
        $LastActionTimeUpdatedOn = "-"
    }

    # Get licenses assigned to mailboxes 
    $User = Get-MsolUser -UserPrincipalName $upn
    $Licenses = $User.Licenses.AccountSkuId
    $AssignedLicense = ""
    $Count = 0

    if ($Licenses.count -eq 0) {
        $AssignedLicense = "No License Assigned"
    } else {
        foreach ($License in $Licenses) {
            $Count++
            $LicenseItem = $License -Split ":" | Select-Object -Last 1
            $AssignedLicense += $LicenseItem
            if ($Count -lt $Licenses.count) {
                $AssignedLicense += ","
            }
        }
    }

    # Inactive days based filter 
    if ($InactiveDaysOfUser -ne "-") {
        if (($InactiveDays -ne "") -and ([int]$InactiveDays -gt $InactiveDaysOfUser)) {
            return
        }
    }

    # Filter result based on user mailbox 
    if ($UserMailboxOnly.IsPresent -and $MBType -ne "UserMailbox") {
        return
    }

    # Never Logged In user
    if ($ReturnNeverLoggedInMBOnly.IsPresent -and $LastActionTime -ne "Never Logged In") {
        return
    }

    # Filter result based on license status
    if ($LicensedUserOnly.IsPresent -and $AssignedLicense -eq "No License Assigned") {
        return
    }

    # Get roles assigned to user 
    $Roles = (Get-MsolUserRole -UserPrincipalName $upn).Name
    if ($Roles.count -eq 0) {
        $RolesAssigned = "No roles"
    } else {
        foreach ($Role in $Roles) {
            $RolesAssigned += $Role
            if ($Roles.indexof($Role) -lt ($Roles.count - 1)) {
                $RolesAssigned += ","
            }
        }
    }

    # Export result to CSV file 
    $Result = @{
        'UserPrincipalName' = $upn
        'DisplayName' = $DisplayName
        'LastUserActionTime' = $LastActionTime
        'LastActionTimeUpdatedOn' = $LastActionTimeUpdatedOn
        'CreationTime' = $CreationTime
        'InactiveDays' = $InactiveDaysOfUser
        'MailboxType' = $MBType
        'AssignedLicenses' = $AssignedLicense
        'Roles' = $RolesAssigned
    }
    $Output = New-Object PSObject -Property $Result
    $Output | Select-Object UserPrincipalName, DisplayName, LastUserActionTime, LastActionTimeUpdatedOn, InactiveDays, CreationTime, MailboxType, AssignedLicenses, Roles | Export-Csv -Path $ExportCSV -NoTypeInformation -Append
}

Function main {
    # Check for EXO v2 module installation
    $Module = Get-Module ExchangeOnlineManagement -ListAvailable
    if ($Module.count -eq 0) {
        Write-Host "Exchange Online PowerShell V2 module is not available" -ForegroundColor yellow
        $Confirm = Read-Host "Are you sure you want to install module? [Y] Yes [N] No"
        if ($Confirm -match "[yY]") {
            Write-Host "Installing Exchange Online PowerShell module"
            Install-Module ExchangeOnlineManagement -Repository PSGallery -AllowClobber -Force
            Import-Module ExchangeOnlineManagement
        } else {
            Write-Host "EXO V2 module is required to connect Exchange Online. Please install module using Install-Module ExchangeOnlineManagement cmdlet."
            Exit
        }
    }
    # Check for Azure AD module
    $Module = Get-Module MsOnline -ListAvailable
    if ($Module.count -eq 0) {
        Write-Host "MSOnline module is not available" -ForegroundColor yellow
        $Confirm = Read-Host "Are you sure you want to install the module? [Y] Yes [N] No"
        if ($Confirm -match "[yY]") {
            Write-Host "Installing MSOnline PowerShell module"
            Install-Module MSOnline -Repository PSGallery -AllowClobber -Force
            Import-Module MSOnline
        } else {
            Write-Host "MSOnline module is required to generate the report. Please install module using Install-Module MSOnline cmdlet."
            Exit
        }
    }

    # Authentication using non-MFA
    if ($NoMFA.IsPresent) {
        # Storing credential in script for scheduling purpose/ Passing credential as parameter
        if ($UserName -ne "" -and $Password -ne "") {
            $SecuredPassword = ConvertTo-SecureString -AsPlainText $Password -Force
            $Credential = New-Object System.Management.Automation.PSCredential $UserName, $SecuredPassword
        } else {
            $Credential = Get-Credential -Credential $null
        }
        Write-Host "Connecting Azure AD..."
        Connect-MsolService -Credential $Credential | Out-Null
        Write-Host "Connecting Exchange Online PowerShell..."
        Connect-ExchangeOnline -Credential $Credential
    } else {
        # Connect to Exchange Online and AzureAD module using MFA
        Write-Host "Connecting Exchange Online PowerShell..."
        Connect-ExchangeOnline
        Write-Host "Connecting Azure AD..."
        Connect-MsolService | Out-Null
    }

    # Friendly DateTime conversion
    if ($FriendlyTime.IsPresent) {
        If ((Get-Module -Name PowerShellHumanizer -ListAvailable).Count -eq 0) {
            Write-Host "Installing PowerShellHumanizer for Friendly DateTime conversion"
            Install-Module -Name PowerShellHumanizer
        }
    }

    $Result = ""
    $Output = @()
    $MBUserCount = 0

    # Set output file
    $ExportCSV = "C:\LastAccessTimeReport_$((Get-Date -format yyyy-MMM-dd-ddd` hh-mm` tt).ToString()).csv"

    # Check for input file
    if ([string]$MBNamesFile -ne "") {
        # We have an input file, read it into memory
        $Mailboxes = @()
        $Mailboxes = Import-Csv -Header "MBIdentity" $MBNamesFile
        foreach ($item in $Mailboxes) {
            $MBDetails = Get-Mailbox -Identity $item.MBIdentity
            $upn = $MBDetails.UserPrincipalName
            $CreationTime = $MBDetails.WhenCreated
            $DisplayName = $MBDetails.DisplayName
            $MBType = $MBDetails.RecipientTypeDetails
            $MBUserCount++
            Get_LastLogonTime -upn $upn -DisplayName $DisplayName -CreationTime $CreationTime -MBType $MBType
        }
    } else {
        # Get all mailboxes from Office 365
        Write-Progress -Activity "Getting Mailbox details from Office 365..." -Status "Please wait."
        Get-Mailbox -ResultSize Unlimited | Where { $_.DisplayName -notlike "Discovery Search Mailbox" } | ForEach {
            $upn = $_.UserPrincipalName
            $CreationTime = $_.WhenCreated
            $DisplayName = $_.DisplayName
            $MBType = $_.RecipientTypeDetails
            $MBUserCount++
            Get_LastLogonTime -upn $upn -DisplayName $DisplayName -CreationTime $CreationTime -MBType $MBType
        }
    }

    # Open output file after execution
    Write-Host "`nScript executed successfully"
    if (Test-Path -Path $ExportCSV) {
        Write-Host "Detailed report available in: $ExportCSV"
        $Prompt = New-Object -ComObject wscript.shell
        $UserInput = $Prompt.popup("Do you want to open output file?", 0, "Open Output File", 4)
        If ($UserInput -eq 6) {
            Invoke-Item "$ExportCSV"
        }
    } else {
        Write-Host "No mailbox found"
    }
    # Clean up session
    Get-PSSession | Remove-PSSession
}

main
