<#
.SYNOPSIS
    This script connects to Microsoft Graph, retrieves a list of all user mailboxes, and uploads a specified file to each user's OneDrive.

.DESCRIPTION
    The script performs the following actions:
    1. Checks if the required Microsoft.Graph module and sub-modules are installed, and installs them if not.
    2. Loads the Microsoft.Graph module and sub-modules.
    3. Obtains an access token from Azure AD using client credentials.
    4. Connects to Microsoft Graph using the access token.
    5. Retrieves a list of all users in the organization.
    6. For each user, retrieves their OneDrive and uploads a specified file to the root of their OneDrive.
    7. Logs the progress and any errors encountered during the process.
    8. Outputs the results of the file upload process.

.PARAMETER TenantId
    The Azure AD Tenant ID.

.PARAMETER ClientId
    The Client ID of the registered app in Azure AD.

.PARAMETER ClientSecret
    The Client Secret of the registered app in Azure AD.

.PARAMETER FilePath
    The path to the file you want to upload to each user's OneDrive.

.PARAMETER FileName
    The name of the file to be uploaded in OneDrive.

.NOTES
    Author: M.omar
    Website: momar.tech
    Date: 2024-07-11
    Version: 1.0
#>

# Parameters for authentication and file upload
$TenantId = "Put Your Tenent ID here"      				   # Azure AD Tenant ID
$ClientId = "Put Your App Client ID here"        		   # Registered App Client ID
$ClientSecret = "Put Your App Secret Value here" 		   # Registered App Client Secret
$FilePath = "C:\"                                          # Path to the file you want to upload
$FileName = "file-name.txt"                                # Name of the file to be uploaded in OneDrive
$CsvFilePath = "C:\OneDriveUploadResults.csv"              # Path to save the results CSV
$LogFilePath = "C:\Intune\OneDriveUploadLog.txt"           # Path to the log file
$StatusCsvFilePath = "C:\Intune\OneDriveUploadStatus.csv"  # Path to save the status CSV


# Increase function capacity limit
$maximumFunctionCount = 32768
$runspace = [runspacefactory]::CreateRunspace()
$runspace.Open()
$runspace.SessionStateProxy.SetVariable("maximumFunctionCount", $maximumFunctionCount)
$runspace.Close()

# Ensure the required Microsoft.Graph module is installed and updated
$moduleName = "Microsoft.Graph"
if (-not (Get-Module -ListAvailable -Name $moduleName)) {
    Write-Host "Installing module $moduleName..."
    Install-Module -Name $moduleName -AllowClobber -Scope CurrentUser -Force
} else {
    Write-Host "Module $moduleName is already installed. Updating module..."
    Update-Module -Name $moduleName
}

# Import the unified Microsoft.Graph module
Write-Host "Importing module $moduleName..."
Import-Module Microsoft.Graph -ErrorAction Stop

# Function to get an access token from Azure AD using client credentials
function Get-GraphToken {
    param (
        [string]$TenantId,        # Azure AD Tenant ID
        [string]$ClientId,        # Registered App Client ID
        [string]$ClientSecret     # Registered App Client Secret
    )
    $body = @{
        Grant_Type    = "client_credentials"
        Scope         = "https://graph.microsoft.com/.default"
        Client_Id     = $ClientId
        Client_Secret = $ClientSecret
    }
    # Request the token from Azure AD
    $oauth = Invoke-RestMethod -Method Post -Uri "https://login.microsoftonline.com/$TenantId/oauth2/v2.0/token" -ContentType "application/x-www-form-urlencoded" -Body $body
    return $oauth.access_token
}

# Convert string to secure string
function ConvertTo-SecureStringFromPlainText {
    param (
        [string]$plainText
    )
    $secureString = ConvertTo-SecureString -String $plainText -AsPlainText -Force
    return $secureString
}


# Create Intune directory if it does not exist
if (-not (Test-Path "C:\Intune")) {
    New-Item -ItemType Directory -Path "C:\Intune"
}

# Function to log messages
function Log-Message {
    param (
        [string]$message
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "$timestamp - $message"
    Add-Content -Path $LogFilePath -Value $logMessage
}

# Get the access token using the function
Write-Host "Requesting access token..."
Log-Message "Requesting access token..."
$Token = Get-GraphToken -TenantId $TenantId -ClientId $ClientId -ClientSecret $ClientSecret
Write-Host "Access token received."
Log-Message "Access token received."

# Convert token to secure string
$SecureToken = ConvertTo-SecureStringFromPlainText -plainText $Token

# Connect to Microsoft Graph using the access token
Write-Host "Connecting to Microsoft Graph..."
Log-Message "Connecting to Microsoft Graph..."
Connect-MgGraph -AccessToken $SecureToken
Write-Host "Connected to Microsoft Graph."
Log-Message "Connected to Microsoft Graph."

# Retrieve all users in the tenant
Write-Host "Retrieving users from the tenant..."
Log-Message "Retrieving users from the tenant..."
$Users = Get-MgUser -All
Write-Host "Retrieved $($Users.Count) users from the tenant."
Log-Message "Retrieved $($Users.Count) users from the tenant."

# Initialize counters and results array for progress tracking
$totalUsers = $Users.Count
$processedUsers = 0
$logonSuccessCount = 0
$uploadSuccessCount = 0
$results = @()

# Start the file upload process
Write-Host "Starting file upload process to $totalUsers users."
Log-Message "Starting file upload process to $totalUsers users."

# Loop through each user and upload the file to their OneDrive
foreach ($User in $Users) {
    $result = [PSCustomObject]@{
        UserPrincipalName = $User.UserPrincipalName
        LogonSuccess      = $false
        UploadSuccess     = $false
    }

    try {
        # Get the user's OneDrive
        Write-Host "Retrieving OneDrive for user $($User.UserPrincipalName)..."
        Log-Message "Retrieving OneDrive for user $($User.UserPrincipalName)..."
        $Drive = Get-MgUserDrive -UserId $User.Id
        Write-Host "OneDrive retrieved for user $($User.UserPrincipalName)."
        Log-Message "OneDrive retrieved for user $($User.UserPrincipalName)."
        $result.LogonSuccess = $true
        $logonSuccessCount++

        # Upload the file to the root of the user's OneDrive
        Write-Host "Uploading file to $($User.UserPrincipalName)'s OneDrive..."
        Log-Message "Uploading file to $($User.UserPrincipalName)'s OneDrive..."
        $uploadUrl = "https://graph.microsoft.com/v1.0/users/$($User.Id)/drive/root:/$($FileName):/content"
        $uploadContent = Get-Content -Path $FilePath -Raw
        Invoke-MgGraphRequest -Method PUT -Uri $uploadUrl -Body $uploadContent
        Write-Host "File uploaded to $($User.UserPrincipalName)'s OneDrive."
        Log-Message "File uploaded to $($User.UserPrincipalName)'s OneDrive."
        $result.UploadSuccess = $true
        $uploadSuccessCount++
    } catch {
        # Log failure
        Write-Host "Failed to upload file to $($User.UserPrincipalName)'s OneDrive. Error: $_"
        Log-Message "Failed to upload file to $($User.UserPrincipalName)'s OneDrive. Error: $_"
    }

    # Add result to the results array
    $results += $result

    $processedUsers++
    Write-Progress -Activity "Uploading file to OneDrive" -Status "Processing user $processedUsers of $totalUsers" -PercentComplete (($processedUsers / $totalUsers) * 100)
}

# Save results to CSV
$results | Export-Csv -Path $CsvFilePath -NoTypeInformation
Write-Host "Results saved to $CsvFilePath."
Log-Message "Results saved to $CsvFilePath."

# Save status results to CSV
$results | Export-Csv -Path $StatusCsvFilePath -NoTypeInformation
Write-Host "Status results saved to $StatusCsvFilePath."
Log-Message "Status results saved to $StatusCsvFilePath."

# Log the completion of the process
Write-Host "File upload process completed for $processedUsers users."
Log-Message "File upload process completed for $processedUsers users."
Write-Host "File upload process completed."
Log-Message "File upload process completed."

# Output summary
Write-Host "Summary:"
Write-Host "Total users processed: $totalUsers"
Write-Host "Users successfully logged in: $logonSuccessCount"
Write-Host "Users successfully uploaded file: $uploadSuccessCount"
Log-Message "Summary: Total users processed: $totalUsers, Users successfully logged in: $logonSuccessCount, Users successfully uploaded file: $uploadSuccessCount"

# Display table with logon and upload status
$results | Format-Table -Property UserPrincipalName, LogonSuccess, UploadSuccess
