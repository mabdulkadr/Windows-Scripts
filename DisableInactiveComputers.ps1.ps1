<#
.DESCRIPTION
    This PowerShell script is designed to manage computers in an Active Directory (AD) environment based on their inactivity.
    It identifies computers that have been inactive (i.e., those that haven't logged on for a specified number of days),
    and provides options to disable or delete these computers.

    After performing the operations, it generates a combined HTML report containing:
    - List of inactive computers
    - List of disabled computers (if applicable)
    - List of deleted computers (if applicable)

    The HTML report is styled with CSS and saved with a timestamp in the filename for uniqueness.

.PARAMETERS
    -DaysInactive: [int] The number of days used to define computer inactivity. Any computer that hasn't logged on for more than this many days will be considered inactive.
    -SearchBaseOU: [string] The Organizational Unit (OU) within AD to search for computers. The script searches for computers within this specified OU.

.STEPS
    1. Search Active Directory for computers within the specified Organizational Unit (OU).
    2. Filter the computers based on their last logon date. Computers that haven't logged on within the specified number of days are considered inactive.
    3. Prompt the user to disable these inactive computers.
    4. Prompt the user to delete the computers that were disabled.
    5. Generate an HTML report with the following sections:
        - Inactive Computers
        - Disabled Computers (if applicable)
        - Deleted Computers (if applicable)
    6. Save the HTML report with a timestamp to avoid overwriting previous reports.

.OUTPUT
    - HTML report summarizing the inactive, disabled, and deleted computers.
    - Console output for the list of inactive computers and actions performed (disabling and deletion).

.NOTES
    - The script requires sufficient permissions to query Active Directory, disable AD accounts, and delete AD computer objects.
    - It is recommended to test the script in a non-production environment before running it in production.

.EXAMPLE
    # Run the script to process computers in the specified OU and consider any computer inactive if it hasn't logged on in the last 180 days.
    .\DisableInactiveComputers.ps1 -DaysInactive 180 -SearchBaseOU "OU=Domain Computers,DC=QassimU,DC=local"
#>

param (
    [int]$DaysInactive = 230,  # Number of days of inactivity for filtering inactive computers
    [string]$SearchBaseOU = "OU=Domain Computers,DC=QassimU,DC=local"  # Organizational Unit (OU) for searching computers
)

# Function to log messages (optional)
# This can be used for auditing purposes, logging important script actions.
function Log-Message {
    param (
        [string]$Message,      # The message to log
        [string]$LogPath = "C:\InactiveComputers.log"  # Default log file path
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "$timestamp - $Message"
    Add-Content -Path $LogPath -Value $logEntry
}

# Function to generate a combined HTML report
# This function creates a formatted HTML report that combines inactive, disabled, and deleted computers in one report.
function Write-CombinedHTMLReport {
    param (
        [string]$HtmlPath,        # Path to save the final HTML report
        [PSObject]$InactiveData,  # Data for inactive computers
        [int]$TotalInactive,      # Total number of inactive computers
        [PSObject]$DisabledData,  # Data for disabled computers
        [int]$TotalDisabled,      # Total number of disabled computers
        [PSObject]$DeletedData,   # Data for deleted computers
        [int]$TotalDeleted        # Total number of deleted computers
    )

    # Basic HTML structure with inline CSS for formatting the report
    # This includes styling for tables, headers, and alternating row colors.
    $htmlHeader = @"
<!DOCTYPE html>
<html lang='en'>
<head>
    <meta charset='UTF-8'>
    <meta name='viewport' content='width=device-width, initial-scale=1.0'>
    <title>Inactive, Disabled, and Deleted Computers Report</title>
    <style>
        body {
            font-family: Arial, sans-serif;
            margin: 20px;
        }
        h1, h2, h3 {
            color: #2c3e50;
        }
        table {
            border-collapse: collapse;
            width: 100%;
            margin-top: 20px;
        }
        th, td {
            border: 1px solid #dddddd;
            text-align: left;
            padding: 8px;
        }
        th {
            background-color: #2c3e50;
            color: white;
        }
        tr:nth-child(even) {
            background-color: #f2f2f2;
        }
        .summary {
            background-color: #ecf0f1;
            padding: 10px;
            border-radius: 8px;
            margin-top: 20px;
        }
    </style>
</head>
<body>
<h1>Inactive, Disabled, and Deleted Computers Report</h1>
"@

    # Section for Inactive Computers
    $htmlInactiveSection = @"
<h2>Inactive Computers</h2>
<p class='summary'><strong>Total Inactive Computers:</strong> $TotalInactive</p>
<table>
<thead>
<tr>
    <th>Computer Name</th>
    <th>Last Logon Date</th>
    <th>Distinguished Name</th>
</tr>
</thead>
<tbody>
"@

    # Loop through the inactive computers and create HTML rows
    $htmlInactiveRows = foreach ($item in $InactiveData) {
        "<tr>
            <td>$($item.ComputerName)</td>
            <td>$($item.LastLogonDate)</td>
            <td>$($item.DistinguishedName)</td>
        </tr>"
    }

    $htmlInactiveFooter = "</tbody></table>"

    # Section for Disabled Computers
    $htmlDisabledSection = @"
<h2>Disabled Computers</h2>
<p class='summary'><strong>Total Disabled Computers:</strong> $TotalDisabled</p>
<table>
<thead>
<tr>
    <th>Computer Name</th>
    <th>Last Logon Date</th>
    <th>Distinguished Name</th>
</tr>
</thead>
<tbody>
"@

    # Loop through the disabled computers and create HTML rows
    $htmlDisabledRows = foreach ($item in $DisabledData) {
        "<tr>
            <td>$($item.ComputerName)</td>
            <td>$($item.LastLogonDate)</td>
            <td>$($item.DistinguishedName)</td>
        </tr>"
    }

    $htmlDisabledFooter = "</tbody></table>"

    # Section for Deleted Computers
    $htmlDeletedSection = @"
<h2>Deleted Computers</h2>
<p class='summary'><strong>Total Deleted Computers:</strong> $TotalDeleted</p>
<table>
<thead>
<tr>
    <th>Computer Name</th>
    <th>Last Logon Date</th>
    <th>Distinguished Name</th>
</tr>
</thead>
<tbody>
"@

    # Loop through the deleted computers and create HTML rows
    $htmlDeletedRows = foreach ($item in $DeletedData) {
        "<tr>
            <td>$($item.ComputerName)</td>
            <td>$($item.LastLogonDate)</td>
            <td>$($item.DistinguishedName)</td>
        </tr>"
    }

    $htmlDeletedFooter = "</tbody></table>"

    # Combine all sections (Inactive, Disabled, Deleted) and write to the HTML file
    $htmlFooter = "</body></html>"
    $fullHtml = $htmlHeader + $htmlInactiveSection + ($htmlInactiveRows -join "`n") + $htmlInactiveFooter + "`n" +
                $htmlDisabledSection + ($htmlDisabledRows -join "`n") + $htmlDisabledFooter + "`n" +
                $htmlDeletedSection + ($htmlDeletedRows -join "`n") + $htmlDeletedFooter + $htmlFooter

    # Save the full HTML report to the specified path
    Set-Content -Path $HtmlPath -Value $fullHtml
}

# Generate a timestamp for the report filename
$timestamp = Get-Date -Format "yyyy-MM-dd_HH-mm-ss"
$reportFileName = "C:\Computers_Report_$timestamp.html"

# Start processing inactive computers
Write-Host "Processing inactive computers based on LastLogonDate and $DaysInactive days of inactivity..." -ForegroundColor Cyan

# Get the threshold date for inactivity (current date minus DaysInactive)
$InactiveThreshold = (Get-Date).AddDays(-$DaysInactive)

# Fetch all computers from the specified Organizational Unit (OU)
Try {
    $AllComputers = Get-ADComputer -Filter * -SearchBase $SearchBaseOU -Property Name, LastLogonDate -ErrorAction Stop
} Catch {
    Write-Error "Failed to retrieve computers from the specified OU: $_"
    Exit
}

# Filter inactive computers: Those with no LastLogonDate or last logon date older than the threshold
$InactiveComputers = foreach ($Computer in $AllComputers) {
    $LastLogonDate = if ($Computer.LastLogonDate) { $Computer.LastLogonDate } else { "No Logon Information" }

    if ($LastLogonDate -eq "No Logon Information" -or [DateTime]$LastLogonDate -lt $InactiveThreshold) {
        [PSCustomObject]@{
            ComputerName      = $Computer.Name
            LastLogonDate     = $LastLogonDate
            DistinguishedName = $Computer.DistinguishedName
        }
    }
}

# Initialize arrays for Disabled and Deleted computers
$DisabledComputers = @()
$DeletedComputers = @()

# Check if there are any inactive computers to process
if ($InactiveComputers.Count -gt 0) {
    # List inactive computers in the console
    Write-Host "`nInactive Computers List:" -ForegroundColor Cyan
    $InactiveComputers | Format-Table -Property ComputerName, LastLogonDate -AutoSize

    # Ask if you want to disable the inactive computers
    $DisableInput = Read-Host "`nDo you want to disable all the inactive computers? (Yes/No)"
    
    if ($DisableInput -eq "Yes") {
        # Loop through inactive computers and disable them
        foreach ($Computer in $InactiveComputers) {
            Try {
                Write-Host "Disabling computer: $($Computer.ComputerName)" -ForegroundColor Yellow
                Disable-ADAccount -Identity $Computer.DistinguishedName -ErrorAction Stop
                Write-Host "Disabled: $($Computer.ComputerName)" -ForegroundColor Green
                
                # Add the computer to the DisabledComputers array
                $DisabledComputers += $Computer
            } Catch {
                Write-Error "Failed to disable computer $($Computer.ComputerName): $_"
            }
        }
    } else {
        Write-Host "`nNo computers were disabled." -ForegroundColor Yellow
    }

    # Ask if you want to delete the disabled computers
    $DeleteInput = Read-Host "`nDo you want to delete all disabled computers? (Yes/No)"
    
    if ($DeleteInput -eq "Yes" -and $DisabledComputers.Count -gt 0) {
        # Loop through disabled computers and delete them
        foreach ($Computer in $DisabledComputers) {
            Try {
                Write-Host "Deleting computer: $($Computer.ComputerName)" -ForegroundColor Red
                Remove-ADComputer -Identity $Computer.DistinguishedName -Confirm:$false -ErrorAction Stop
                Write-Host "Deleted: $($Computer.ComputerName)" -ForegroundColor Green

                # Add the computer to the DeletedComputers array
                $DeletedComputers += $Computer
            } Catch {
                Write-Error "Failed to delete computer $($Computer.ComputerName): $_"
            }
        }
    } else {
        Write-Host "`nNo computers were deleted." -ForegroundColor Yellow
    }

    # Generate the combined HTML report and save it to the specified path
    Write-CombinedHTMLReport -HtmlPath $reportFileName -InactiveData $InactiveComputers -TotalInactive $InactiveComputers.Count `
        -DisabledData $DisabledComputers -TotalDisabled $DisabledComputers.Count `
        -DeletedData $DeletedComputers -TotalDeleted $DeletedComputers.Count

    Write-Host "`nReport has been generated at $reportFileName" -ForegroundColor Green

} else {
    Write-Host "`nNo computers have been inactive for more than $DaysInactive days." -ForegroundColor Yellow
}

Write-Host "`nScript completed." -ForegroundColor Cyan
