<#
.SYNOPSIS
    This script adds users from a CSV file to an Azure AD Security Group using the AzureAD PowerShell module.

.DESCRIPTION
    - Ensures the required AzureAD module is installed before execution.
    - Reads a list of users from a CSV file.
    - Checks if each user exists in Azure AD before adding them to the group.
    - Verifies if the user is already a member of the group to prevent duplicate additions.
    - Adds the user to the Azure AD security group if they are not already a member.
    - Uses error handling to log any issues encountered.
    - Includes a short delay between requests to avoid API rate-limiting.

.REQUIREMENTS
    - PowerShell
    - AzureAD Module (`Install-Module -Name AzureAD -Force`)
    - Admin privileges to manage Azure AD groups.

.PARAMETER CSVFilePath
    - The full path to the CSV file containing the list of users.
    - The CSV must have a header column named "UPN" with the users' email addresses.

.EXAMPLE
    - Run the script:
      ```powershell
      .\Add-AzureADUsersToGroup.ps1
      ```
    - Sample CSV file:
      ```
      UPN
      user1@domain.com
      user2@domain.com
      user3@domain.com
      ```

.NOTES
    Author  : Mohammad Abdulkader Omar
    Website : momar.tech
    Date    : 2024-11-04
#>

# Ensure AzureAD module is installed
if (-not (Get-Module -ListAvailable -Name AzureAD)) {
    Write-Host "AzureAD module not found. Installing..." -ForegroundColor Yellow
    Install-Module -Name AzureAD -Force -Confirm:$false
}

# Import AzureAD module
Import-Module AzureAD -ErrorAction Stop

# Connect to Azure AD
if (-not (Get-AzureADTenantDetail -ErrorAction SilentlyContinue)) {
    Write-Host "Connecting to Azure AD..." -ForegroundColor Yellow
    Connect-AzureAD
}

# Define Security Group ID (Replace with actual ObjectId)
$GroupID = "your-group-id" # Change this to your actual Group ObjectId

# Define CSV file path (Ensure it contains a column named 'UPN')
$CSVFilePath = "C:\Users.csv"

# Check if the CSV file exists
if (-not (Test-Path $CSVFilePath)) {
    Write-Host "Error: CSV file not found at $CSVFilePath" -ForegroundColor Red
    Exit
}

# Import CSV file
$Users = Import-Csv -Path $CSVFilePath -Delimiter ","

# Check if CSV is empty
if ($Users.Count -eq 0) {
    Write-Host "Error: No users found in the CSV file." -ForegroundColor Red
    Exit
}

# Loop through each user in the CSV file
foreach ($User in $Users) {
    $UPN = $User.UPN  # Extract UserPrincipalName from CSV
    Write-Progress -Activity "Processing: $UPN"

    Try {
        # Step 1: Get User's ObjectId from Azure AD
        $AzureADUser = Get-AzureADUser -Filter "UserPrincipalName eq '$UPN'" -ErrorAction Stop

        if (-not $AzureADUser) {
            Write-Host "User does not exist in Azure AD: $UPN" -ForegroundColor Yellow
            continue  # Skip to the next user
        }

        # Step 2: Check if the user is already a member of the group
        $ExistingMember = Get-AzureADGroupMember -ObjectId $GroupID | Where-Object { $_.ObjectId -eq $AzureADUser.ObjectId }

        if ($ExistingMember) {
            Write-Host "$UPN is already a member of the security group." -ForegroundColor Cyan
            continue  # Skip to the next user
        }

        # Step 3: Add User to Security Group
        Add-AzureADGroupMember -ObjectId $GroupID -RefObjectId $AzureADUser.ObjectId -ErrorAction Stop
        Write-Host "$UPN successfully added to the security group." -ForegroundColor Green

        # Step 4: Prevent API Rate Limit Issues (Wait 1 second between requests)
        Start-Sleep -Seconds 1
    }
    Catch {
        # Print the exact error message
        Write-Host "Error adding $UPN : $($_.Exception.Message)" -ForegroundColor Red
    }
}

# Disconnect from Azure AD
Disconnect-AzureAD

Write-Host "Process completed. All users have been processed." -ForegroundColor Cyan
