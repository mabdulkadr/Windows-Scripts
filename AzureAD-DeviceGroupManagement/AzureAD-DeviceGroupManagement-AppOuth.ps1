<#
.SYNOPSIS
    Manages static Azure AD groups by adding devices from Intune to these groups.

.DESCRIPTION
    This script automatically connects to Microsoft Graph using app-based authentication with the provided Tenant ID, App ID, and App Secret.
    It then allows for a manual connection to Azure AD. The script checks for existing static groups with a specified prefix, creates new groups if necessary,
    and adds devices from Intune to these groups. It ensures that no group exceeds 500 members by distributing devices across available groups
    or creating new ones as needed.

.NOTES
    - Ensure the script is run with the necessary permissions for Microsoft Graph and Azure AD.
    - This script manages static groups; it does not handle dynamic group memberships.
    - Store the App Secret securely and avoid hardcoding sensitive information in scripts.

.EXAMPLE
    .\AzureAD-DeviceGroupManagement.ps1

.NOTES
    Author  : Mohammad Abdulkader Omar
    Website : momar.tech
    Date    : 2024-11-04
#>


# Parameters for batch processing and group management
Param (
    [int]$BatchSize = 500,
    [string]$GroupNamePrefix = "Devices-group",
    [int]$NamePadding = 2,  # Number of digits in group numbering
    [switch]$EnableLogging, # Enable logging to a file
    [string]$LogFilePath = "C:\CreateStaticGroup\GroupCreationLog.txt"
)

# Automatically Connect to Microsoft Graph using App-based Authentication
$tenantID = "c2b04da6-8487-41cc-8803-90321048a772"
$appID = "6c70c0c3-e3a6-489c-973e-51e8138540f9"          #ClientID
$appSecret = "Uoj8Q~1_acd.7WU4Ol3vOczrfeYQbdHR_mzhTb6n"  #Client Secret

# Function to log messages with timestamps and color-coded output
Function Log-Message {
    param (
        [string]$Message,
        [string]$MessageType = "INFO"
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $formattedMessage = "[$timestamp] [$MessageType] $Message"

    switch ($MessageType) {
        "INFO" { Write-Host $formattedMessage -ForegroundColor Cyan }
        "SUCCESS" { Write-Host $formattedMessage -ForegroundColor Green }
        "WARNING" { Write-Host $formattedMessage -ForegroundColor Yellow }
        "ERROR" { Write-Host $formattedMessage -ForegroundColor Red }
        default { Write-Host $formattedMessage }
    }

    if ($EnableLogging) {
        # Ensure the log directory exists
        $logDir = Split-Path -Path $LogFilePath
        if (-not (Test-Path -Path $logDir)) {
            New-Item -Path $logDir -ItemType Directory -Force | Out-Null
        }
        Add-Content -Path $LogFilePath -Value $formattedMessage
    }
}

# Connect to Microsoft Graph

# Install and Import Microsoft Graph Modules
Write-Host "Installing Microsoft Graph modules if required (current user scope)" -ForegroundColor Cyan

# Install Microsoft Graph Authentication Module if not installed
if (-not (Get-Module -ListAvailable -Name Microsoft.Graph.Authentication)) {
    try {
        Install-Module -Name Microsoft.Graph.Authentication -Scope CurrentUser -Repository PSGallery -Force
        Write-Host "Microsoft Graph Authentication Module Installed Successfully" -ForegroundColor Green
    } catch {
        Write-Host "Failed to Install Microsoft Graph Authentication Module: $($_.Exception.Message)" -ForegroundColor Red
        exit
    }
} else {
    Write-Host "Microsoft Graph Authentication Module Already Installed" -ForegroundColor Green
}

# Install Microsoft.Graph.Beta.DeviceManagement.Actions if not installed
if (-not (Get-Module -ListAvailable -Name Microsoft.Graph.Beta.DeviceManagement.Actions)) {
    try {
        Install-Module -Name Microsoft.Graph.Beta.DeviceManagement.Actions -Scope CurrentUser -Repository PSGallery -Force
        Write-Host "Microsoft Graph Beta Device Management Module Installed Successfully" -ForegroundColor Green
    } catch {
        Write-Host "Failed to Install Microsoft Graph Beta Device Management Module: $($_.Exception.Message)" -ForegroundColor Red
        exit
    }
} else {
    Write-Host "Microsoft Graph Beta Device Management Module Already Installed" -ForegroundColor Green
}

# Import necessary modules
Import-Module Microsoft.Graph.Authentication
Import-Module Microsoft.Graph.Beta.DeviceManagement.Actions


# Authenticate with an MFA enabled account
Connect-MgGraph -Scopes "DeviceManagementConfiguration.ReadWrite.All"


# Function to Connect to Microsoft Graph
function Connect-ToGraph {
    param (
        [Parameter(Mandatory = $false)] [string]$Tenant,
        [Parameter(Mandatory = $false)] [string]$AppId,
        [Parameter(Mandatory = $false)] [string]$AppSecret,
        [Parameter(Mandatory = $false)] [string]$Scopes = "DeviceManagementConfiguration.ReadWrite.All"
    )

    $version = (Get-Module microsoft.graph.authentication).Version.Major

    if ($AppId) {
        # App-based Authentication
        $body = @{
            grant_type    = "client_credentials"
            client_id     = $AppId
            client_secret = $AppSecret
            scope         = "https://graph.microsoft.com/.default"
        }

        $response = Invoke-RestMethod -Method Post -Uri "https://login.microsoftonline.com/$Tenant/oauth2/v2.0/token" -Body $body
        $accessToken = $response.access_token

        if ($version -eq 2) {
            Write-Host "Version 2 module detected" -ForegroundColor Yellow
            $accessTokenFinal = ConvertTo-SecureString -String $accessToken -AsPlainText -Force
        } else {
            Write-Host "Version 1 Module Detected" -ForegroundColor Yellow
            Select-MgProfile -Name Beta
            $accessTokenFinal = $accessToken
        }
        Connect-MgGraph -AccessToken $accessTokenFinal
        Write-Host "Connected to Intune tenant $Tenant using App-based Authentication" -ForegroundColor Green
    } else {
        # User-based Authentication
        if ($version -eq 2) {
            Write-Host "Version 2 module detected" -ForegroundColor Yellow
        } else {
            Write-Host "Version 1 Module Detected" -ForegroundColor Yellow
            Select-MgProfile -Name Beta
        }
        Connect-MgGraph -Scopes $Scopes
        Write-Host "Connected to Intune tenant $((Get-MgTenant).TenantId)" -ForegroundColor Green
    }
}

# Connect to Microsoft Graph
Connect-ToGraph -Tenant $tenantID -AppId $appID -AppSecret $appSecret


# Function to connect to Azure AD automatically
function Connect-ToAzureAD {
    param (
        [Parameter(Mandatory = $true)]
        [string]$TenantID,

        [Parameter(Mandatory = $true)]
        [string]$AppID,  # ClientID

        [Parameter(Mandatory = $true)]
        [string]$AppSecret  # Client Secret Value
    )

    # Connect using AzureAD module
    $AzureADToken = Connect-AzAccount -ServicePrincipal -TenantId $TenantID -ApplicationId $AppID -Credential (New-Object PSCredential($AppID, (ConvertTo-SecureString $AppSecret -AsPlainText -Force)))

    if ($AzureADToken) {
        Write-Host "Connected to Azure AD!" -ForegroundColor Green
    } else {
        Write-Error "Failed to authenticate to Azure AD."
    }
}

# Connect to AzureAD
Connect-ToAzureAD -Tenant $tenantID -AppId $appID -AppSecret $appSecret

# Function to determine the next group number based on existing groups
Function Get-NextGroupNumber {
    param (
        [array]$ExistingNames,
        [string]$Prefix,
        [int]$Padding
    )

    $pattern = "^$Prefix(\d{$Padding})$"
    $numbers = foreach ($name in $ExistingNames) {
        if ($name -match $pattern) {
            [int]$matches[1]
        }
    }

    if ($numbers.Count -eq 0) {
        return 1
    } else {
        return ($numbers | Measure-Object -Maximum).Maximum + 1
    }
}

# Function to create a new Azure AD group
Function Create-NewGroup {
    param (
        [string]$GroupName
    )

    try {
        $newGroup = New-AzureADGroup -DisplayName $GroupName `
                                     -MailEnabled $false `
                                     -SecurityEnabled $true `
                                     -MailNickname $GroupName `
                                     -Description "Static security group containing up to $BatchSize Windows devices."

        Log-Message "Created group: $GroupName (Id: $($newGroup.ObjectId))" -MessageType "SUCCESS"
        return $newGroup
    } catch {
        Log-Message "Failed to create group $GroupName : $_" -MessageType "ERROR"
        return $null
    }
}

# Function to add devices to an Azure AD group
Function Add-DevicesToGroup {
    param (
        [string]$GroupId,
        [array]$Devices,
        [string]$GroupName
    )

    try {
        Log-Message "Retrieving existing members of group '$GroupName'..." -MessageType "INFO"
        $existingMembers = Get-AzureADGroupMember -ObjectId $GroupId -All $true | Select-Object -ExpandProperty ObjectId
        $existingMemberSet = @{}
        foreach ($memberId in $existingMembers) {
            $existingMemberSet[$memberId] = $true
        }

        $devicesToAdd = $Devices | Where-Object { -not $existingMemberSet.ContainsKey($_.Id) }

        if ($devicesToAdd.Count -eq 0) {
            Log-Message "All devices in batch are already members of group '$GroupName'. Skipping." -MessageType "WARNING"
            return
        }

        Log-Message "Adding $($devicesToAdd.Count) devices to group '$GroupName'..." -MessageType "INFO"

        foreach ($device in $devicesToAdd) {
            try {
                Add-AzureADGroupMember -ObjectId $GroupId -RefObjectId $device.Id -ErrorAction Stop
                Log-Message "Added device '$($device.DisplayName)' (Id: $($device.Id)) to group '$GroupName'." -MessageType "SUCCESS"
            } catch {
                Log-Message "Failed to add device '$($device.DisplayName)' (Id: $($device.Id)) to group '$GroupName': $_" -MessageType "ERROR"
            }
        }

        Log-Message "Completed adding devices to group '$GroupName'." -MessageType "SUCCESS"
    } catch {
        Log-Message "Error processing group '$GroupName': $_" -MessageType "ERROR"
    }
}


# Main function to retrieve devices and assign them to groups
Function Get-DevicesAndAssignToGroups {
    Log-Message "Retrieving all Windows PC devices from Microsoft Graph..." -MessageType "INFO"
    try {
        $allDevices = Get-MgDevice -Filter "startswith(operatingSystem,'Windows')" -All
        if ($allDevices.Count -eq 0) {
            Log-Message "No Windows PC devices found. Exiting script." -MessageType "WARNING"
            return
        }
        Log-Message "Total devices retrieved: $($allDevices.Count)" -MessageType "INFO"
    } catch {
        Log-Message "Error retrieving devices: $_" -MessageType "ERROR"
        exit
    }

    # Initialize hash table to track already assigned devices
    $assignedDevices = @{}

    Log-Message "Retrieving existing groups with prefix '$GroupNamePrefix'..." -MessageType "INFO"
    try {
        $existingGroups = Get-AzureADGroup -Filter "startswith(DisplayName,'$GroupNamePrefix')"
        $existingGroupNames = $existingGroups | Select-Object -ExpandProperty DisplayName
    } catch {
        Log-Message "Error retrieving existing groups: $_" -MessageType "ERROR"
        exit
    }

    $nextGroupNumber = Get-NextGroupNumber -ExistingNames $existingGroupNames -Prefix $GroupNamePrefix -Padding $NamePadding
    Log-Message "Next group number to create: $nextGroupNumber" -MessageType "INFO"

    # Split devices into batches while respecting the group member limit
    $deviceGroups = @()
    $currentBatch = @()

    foreach ($device in $allDevices) {
        if (-not $assignedDevices.ContainsKey($device.Id)) {
            $currentBatch += $device
            $assignedDevices[$device.Id] = $true

            # Start a new batch if the current batch reaches the BatchSize limit
            if ($currentBatch.Count -eq $BatchSize) {
                $deviceGroups += ,$currentBatch
                $currentBatch = @()
            }
        }
    }

    # Add the remaining devices to the final batch
    if ($currentBatch.Count -gt 0) {
        $deviceGroups += ,$currentBatch
    }

    # Iterate through each device group and assign to groups
    for ($groupIndex = 0; $groupIndex -lt $deviceGroups.Count; $groupIndex++) {
        $groupNumber = $groupIndex + 1
        $groupName = "{0}{1}" -f $GroupNamePrefix, ($groupNumber.ToString()).PadLeft($NamePadding, '0')

        $existingGroup = $existingGroups | Where-Object { $_.DisplayName -eq $groupName }

        if ($existingGroup) {
            Log-Message "Group '$groupName' already exists. Assigning devices to this group." -MessageType "INFO"
            Add-DevicesToGroup -GroupId $existingGroup.ObjectId -Devices $deviceGroups[$groupIndex] -GroupName $groupName
        } else {
            Log-Message "Group '$groupName' does not exist. Creating new group." -MessageType "INFO"
            $newGroup = Create-NewGroup -GroupName $groupName

            if ($newGroup) {
                Add-DevicesToGroup -GroupId $newGroup.ObjectId -Devices $deviceGroups[$groupIndex] -GroupName $groupName
            } else {
                Log-Message "Skipping device assignment for group '$groupName' due to creation failure." -MessageType "ERROR"
            }
        }

        Write-Host "--------------------------------------------------" -ForegroundColor DarkGray
    }

    Log-Message "All groups processed and devices assigned successfully." -MessageType "SUCCESS"
}



# Execute the main function
Get-DevicesAndAssignToGroups






