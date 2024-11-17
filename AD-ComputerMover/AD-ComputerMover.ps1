<#
.SYNOPSIS
    Flexible script to move computers in AD to matching OUs based on the prefix in the computer name.

.DESCRIPTION
    This script extracts the prefix from the computer name (e.g., "BACKUP" from "BACKUP-01" or "BACKUP2")
    and matches it with OU names using flexible partial matching logic. It ensures that the prefix is at the 
    beginning of the computer name and matches the OU name only if the OU name appears as the prefix, not in the middle.

.NOTES
    Version: 1.6
    Author: PowerShell Expert
#>

# Import the Active Directory module for cmdlets such as Get-ADComputer and Move-ADObject
Import-Module ActiveDirectory

# Define the base OU for searching computers and sub-OUs
$ComputersOU = "OU=Computers,OU=Osrah,DC=osrah,DC=sa"  # Update this as needed

# Function to move computers to matching OUs based on name prefix
function Move-ComputersToMatchingOU {
    Write-Host "Starting automatic OU assignment based on name prefix matching within '$ComputersOU'..." -ForegroundColor Cyan

    # Get all computers within the specified OU and its sub-OUs
    $computers = Get-ADComputer -Filter * -SearchBase $ComputersOU -Properties Name, DistinguishedName
    if (-not $computers) {
        Write-Host "No computers found in '$ComputersOU'." -ForegroundColor Yellow
        return
    }

    # Get all OUs within the specified OU structure for potential matches
    $allOUs = Get-ADOrganizationalUnit -Filter * -SearchBase $ComputersOU -SearchScope Subtree
    if (-not $allOUs) {
        Write-Host "No OUs found in '$ComputersOU'." -ForegroundColor Yellow
        return
    }

    Write-Host "Number of computers found: $($computers.Count)" -ForegroundColor Cyan
    Write-Host "Number of OUs found: $($allOUs.Count)" -ForegroundColor Cyan

    # Loop through each computer and attempt to match with OUs
    foreach ($computer in $computers) {
        $computerName = $computer.Name.ToUpper()  # Convert to uppercase for case-insensitive comparison
        $matched = $false
        Write-Host "Processing computer: $computerName" -ForegroundColor White

        # Extract the prefix from the computer name (e.g., "BACKUP" from "BACKUP-01")
        # The split is done by common delimiters such as '-' or '_', and it stops before any digits
        $prefix = ($computerName -split '[-_0-9]')[0]
        Write-Host "Extracted prefix: $prefix" -ForegroundColor Magenta

        if ($prefix) {
            foreach ($ou in $allOUs) {
                $ouName = ($ou.Name).ToUpper()  # Convert OU name to uppercase for case-insensitive comparison
                Write-Host "Checking if extracted prefix '$prefix' matches OU '$ouName'..." -ForegroundColor DarkCyan

                # Flexible matching: Only match if the prefix matches the start of the computer name
                if ($prefix -eq $ouName -or $ouName -like "$prefix*") {
                    try {
                        Write-Host "Match found: '$computerName' matches with OU '$ouName'." -ForegroundColor Green

                        # Attempt to move the computer to the matching OU
                        Move-ADObject -Identity $computer.DistinguishedName -TargetPath $ou.DistinguishedName
                        Write-Host "Computer '$computerName' moved to OU '$ouName' successfully." -ForegroundColor Green
                        $matched = $true
                        break # Stop checking other OUs once a match is found
                    } catch {
                        # Log and display any errors that occur during the move operation
                        Write-Host "Error moving '$computerName' to OU '$ouName': $_" -ForegroundColor Red
                    }
                }
            }
        } else {
            # Log if no valid prefix is found for the computer name
            Write-Host "No valid prefix found for '$computerName'. Skipping." -ForegroundColor Yellow
        }

        if (-not $matched) {
            # Log if no matching OU is found for the computer name
            Write-Host "No matching OU found for computer '$computerName'. Skipping." -ForegroundColor Yellow
        }
    }

    Write-Host "OU assignment completed within '$ComputersOU'." -ForegroundColor Cyan
}

# Run the function to start processing computers
Move-ComputersToMatchingOU
