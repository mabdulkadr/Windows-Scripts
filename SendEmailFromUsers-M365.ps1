<#
.SYNOPSIS
    This script connects to Microsoft Graph, retrieves a list of all user mailboxes, and sends a test email from each user's account to a specified target email.

.DESCRIPTION
    The script performs the following actions:
    1. Checks if the required Microsoft.Graph module is installed, and installs it if not.
    2. Loads the Microsoft.Graph module.
    3. Obtains an access token from Azure AD using client credentials.
    4. Connects to Microsoft Graph using the access token.
    5. Retrieves a list of all users in the organization.
    6. For each user, sends a test email from their account to a specified target email.
    7. Logs the progress and any errors encountered during the process.
    8. Outputs the results of the email sending process.

.PARAMETER TenantId
    The Azure AD Tenant ID.

.PARAMETER ClientId
    The Client ID of the registered app in Azure AD.

.PARAMETER ClientSecret
    The Client Secret of the registered app in Azure AD.

.PARAMETER TargetEmail
    The email address to send test emails to.

.NOTES
    Author: M.omar
    Website: momar.tech
    Date: 2024-07-14
    Version: 1.0
#>


$tenantId = "Put Here Your Tenant ID"  			# Azure AD Tenant ID
$clientId = "Put Here Your App Client ID"  		# Registered App Client ID
$clientSecret = "Put Here Your App Secret Value" 	# Registered App Client Secret
$targetEmail = "tergetemail@example.com" 		# Target email address to send test emails to


# Log file path
$logFilePath = "C:\SendTestEmailsLog.txt"

# Function to write to log file
function Write-Log {
    param (
        [string]$message
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "$timestamp - $message"
    Write-Output $logMessage
    Add-Content -Path $logFilePath -Value $logMessage
}

# Start logging
Write-Log "Script started."

# Authenticate and get an access token
Write-Log "Authenticating with Azure AD..."
$authBody = @{
    client_id     = $clientId
    scope         = "https://graph.microsoft.com/.default"
    client_secret = $clientSecret
    grant_type    = "client_credentials"
}

try {
    # Request the access token from Azure AD
    $authResponse = Invoke-RestMethod -Method Post -Uri "https://login.microsoftonline.com/$tenantId/oauth2/v2.0/token" -ContentType "application/x-www-form-urlencoded" -Body $authBody
    $accessToken = $authResponse.access_token
    Write-Log "Authentication successful."
} catch {
    Write-Log ("Failed to authenticate: {0}" -f $_.Exception.Message)
    exit
}

# Function to get all user emails with pagination
function Get-AllUsers {
    param (
        [string]$accessToken
    )
    $users = @()
    $uri = "https://graph.microsoft.com/v1.0/users"
    do {
        $response = Invoke-RestMethod -Uri $uri -Headers @{ Authorization = "Bearer $accessToken" }
        $users += $response.value
        $uri = $response.'@odata.nextLink'
    } while ($uri -ne $null)
    return $users
}

# Get all user emails using Microsoft Graph
Write-Log "Retrieving user email addresses..."
try {
    $allUsers = Get-AllUsers -accessToken $accessToken
    $userEmails = $allUsers | Select-Object -ExpandProperty userPrincipalName
    Write-Log "Retrieved user email addresses successfully."
} catch {
    Write-Log ("Failed to retrieve user email addresses: {0}" -f $_.Exception.Message)
    exit
}

# Iterate through each user and send a test email
foreach ($userEmail in $userEmails) {
    Write-Log "Sending test email from $userEmail"
    
    # Compose the email
    $emailBody = @{
        message = @{
            subject = "Test Email"
            body = @{
                contentType = "Text"
                content = "This is a test email."
            }
            toRecipients = @(@{ emailAddress = @{ address = $targetEmail } })
        }
    }

    # Send the email using Microsoft Graph
    try {
        Invoke-RestMethod -Method Post -Uri "https://graph.microsoft.com/v1.0/users/$userEmail/sendMail" -Headers @{ Authorization = "Bearer $accessToken" } -Body ($emailBody | ConvertTo-Json -Depth 10) -ContentType "application/json"
        Write-Log "Test email sent from $userEmail successfully."
    } catch {
        Write-Log ("Failed to send test email from {0}: {1}" -f $userEmail, $_.Exception.Message)
    }
}

Write-Log "Script completed."

# Summary of the script's execution
Write-Log "Summary:"
Write-Log "Total users processed: $($userEmails.Count)"
Write-Log "Log file saved to: $logFilePath"

# Output the summary to the console
Write-Host "Summary:"
Write-Host "Total users processed: $($userEmails.Count)"
Write-Host "Log file saved to: $logFilePath"
