<#
.SYNOPSIS
    This script adds users or devices from a CSV file to an Intune Security Group using Microsoft Graph API.

.DESCRIPTION
    - Provides an interactive menu to choose between adding **Users** or **Devices**.
    - Uses Microsoft Graph API (modern replacement for AzureAD module).
    - Allows the user to **browse for a CSV file** instead of hardcoding paths.
    - Checks if each user/device exists in Azure AD before adding them.
    - Verifies if the user/device is already a member of the group to prevent duplicates.
    - Logs successful and failed additions for audit purposes.
    - Implements error handling to log issues encountered.

.REQUIREMENTS
    - PowerShell
    - Microsoft.Graph Module (`Install-Module Microsoft.Graph -Force`)
    - Admin privileges to manage Intune Security Groups.

.PARAMETER None
    - The script prompts the user for input via an interactive menu.

.EXAMPLE
    - Run the script:
      ```powershell
      .\Add-UsersOrDevicesToIntuneGroup.ps1
      ```

.NOTES
    Author  : Mohammad Abdulkader Omar
    Website : momar.tech
    Date    : 2025-02-10
#>

# Install & Import Microsoft Graph Module if needed
if (-not (Get-Module -Name Microsoft.Graph -ListAvailable)) {
    Install-Module Microsoft.Graph -Force
}
Import-Module Microsoft.Graph

# Authenticate with Microsoft Graph (Interactive login)
Try {
    Connect-MgGraph -Scopes "GroupMember.ReadWrite.All", "User.Read.All", "Device.Read.All" -ErrorAction Stop
} Catch {
    Write-Host "Error connecting to Microsoft Graph: $($_.Exception.Message)" -ForegroundColor Red
    Exit
}

# Get the Tenant Information
$Tenant = Get-MgOrganization
Write-Host "Connected to Tenant: $($Tenant.DisplayName)" -ForegroundColor Cyan

# Fancy Menu Selection
$selection = @("Add Users to Group", "Add Devices to Group") | Out-GridView -Title "Select Operation" -OutputMode Single

if (-not $selection) {
    Write-Host "Operation cancelled by user." -ForegroundColor Yellow
    Exit
}

# Browse for CSV File
Add-Type -AssemblyName System.Windows.Forms
$FileDialog = New-Object System.Windows.Forms.OpenFileDialog
$FileDialog.InitialDirectory = [Environment]::GetFolderPath("Desktop")
$FileDialog.Filter = "CSV files (*.csv)|*.csv|All files (*.*)|*.*"
$FileDialog.Title = "Select CSV File"
$null = $FileDialog.ShowDialog()
$CSVFilePath = $FileDialog.FileName

if (-not $CSVFilePath) {
    Write-Host "No file selected. Exiting script." -ForegroundColor Red
    Exit
}

# Import CSV File
$Entries = Import-Csv -Path $CSVFilePath -Delimiter ","

# Check if CSV is empty
if ($Entries.Count -eq 0) {
    Write-Host "Error: No entries found in the CSV file." -ForegroundColor Red
    Exit
}

# Define Intune Security Group ID (Change This)
$GroupID = "your-group-id"  # Replace with your actual Group ObjectId

# Function to Add Users to Intune Security Group
function Add-UserToIntuneGroup {
    foreach ($Entry in $Entries) {
        $UPN = $Entry.UPN  # Extract UserPrincipalName from CSV
        Write-Progress -Activity "Processing: $UPN"

        Try {
            # Step 1: Get User's ObjectId from Microsoft Graph
            $User = Get-MgUser -Filter "userPrincipalName eq '$UPN'" -ErrorAction Stop

            if (-not $User) {
                Write-Host "User does not exist in Azure AD: $UPN" -ForegroundColor Yellow
                continue
            }

            # Step 2: Check if the user is already a member of the group
            $ExistingMembers = Get-MgGroupMember -GroupId $GroupID -All | Select-Object -ExpandProperty Id
            if ($ExistingMembers -contains $User.Id) {
                Write-Host "$UPN is already a member of the security group." -ForegroundColor Cyan
                continue
            }

            # Step 3: Add User to Security Group
            New-MgGroupMember -GroupId $GroupID -DirectoryObjectId $User.Id -ErrorAction Stop
            Write-Host "$UPN successfully added to the security group." -ForegroundColor Green

            # Log Success
            "$UPN,Success" | Out-File -Append -FilePath "Intune_Group_Addition_Log.csv"
        }
        Catch {
            Write-Host "Error adding $UPN : $($_.Exception.Message)" -ForegroundColor Red
            "$UPN,Failed,$($_.Exception.Message)" | Out-File -Append -FilePath "Intune_Group_Addition_Log.csv"
        }
    }
}

# Function to Add Devices to Intune Security Group
function Add-DeviceToIntuneGroup {
    foreach ($Entry in $Entries) {
        $DeviceID = $Entry.DeviceID  # Extract Device ID from CSV
        Write-Progress -Activity "Processing: $DeviceID"

        Try {
            # Step 1: Get Device's ObjectId from Microsoft Graph
            $Device = Get-MgDevice -Filter "deviceId eq '$DeviceID'" -ErrorAction Stop

            if (-not $Device) {
                Write-Host "Device does not exist in Azure AD: $DeviceID" -ForegroundColor Yellow
                continue
            }

            # Step 2: Check if the device is already a member of the group
            $ExistingMembers = Get-MgGroupMember -GroupId $GroupID -All | Select-Object -ExpandProperty Id
            if ($ExistingMembers -contains $Device.Id) {
                Write-Host "$DeviceID is already a member of the security group." -ForegroundColor Cyan
                continue
            }

            # Step 3: Add Device to Security Group
            New-MgGroupMember -GroupId $GroupID -DirectoryObjectId $Device.Id -ErrorAction Stop
            Write-Host "$DeviceID successfully added to the security group." -ForegroundColor Green

            # Log Success
            "$DeviceID,Success" | Out-File -Append -FilePath "Intune_Group_Addition_Log.csv"
        }
        Catch {
            Write-Host "Error adding $DeviceID : $($_.Exception.Message)" -ForegroundColor Red
            "$DeviceID,Failed,$($_.Exception.Message)" | Out-File -Append -FilePath "Intune_Group_Addition_Log.csv"
        }
    }
}

# Execute Based on User Selection
if ($selection -eq "Add Users to Group") {
    Add-UserToIntuneGroup
} elseif ($selection -eq "Add Devices to Group") {
    Add-DeviceToIntuneGroup
}

# Disconnect from Microsoft Graph
Disconnect-MgGraph

Write-Host "Process completed. Check the log file 'Intune_Group_Addition_Log.csv' for details." -ForegroundColor Cyan
