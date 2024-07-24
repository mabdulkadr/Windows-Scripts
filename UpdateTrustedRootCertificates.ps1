<#
.SYNOPSIS
    Updates the list of trusted root certificates in Windows and checks for new updates.

.DESCRIPTION
    This script generates the `roots.sst` file, sets necessary permissions, imports the certificates into the trusted root certificate store, checks for new updates, and verifies the import if updates are applied.

.NOTES
    Author: Your Name
    Date: 2024-07-24
    Version: 3.5
#>

# Define the path for the roots.sst file
$sstFilePath = "C:\PS\roots.sst"

# Function to write colored output
function Write-Color {
    param (
        [Parameter(Position = 0, Mandatory = $true)]
        [string] $Text,
        [Parameter(Position = 1, Mandatory = $true)]
        [string] $Color
    )
    Write-Host $Text -ForegroundColor $Color
}

# Collecting the status messages
$statusMessages = @()

try {
    Write-Color "Starting certificate update process..." "Yellow"

    # Ensure the directory exists
    $directoryPath = [System.IO.Path]::GetDirectoryName($sstFilePath)
    if (-not (Test-Path -Path $directoryPath)) {
        New-Item -Path $directoryPath -ItemType Directory -Force | Out-Null
    }

    # Step 1: Generate the roots.sst file
    Write-Color "Generating roots.sst file..." "Yellow"
    certutil.exe -generateSSTFromWU $sstFilePath

    # Verify if the file was created
    if (Test-Path -Path $sstFilePath) {
        Write-Color "roots.sst file generated successfully." "Green"
        $statusMessages += [PSCustomObject]@{Step="Generate SST File"; Status="Success"; Message="roots.sst file generated successfully"}
    } else {
        Write-Color "Failed to generate roots.sst file." "Red"
        $statusMessages += [PSCustomObject]@{Step="Generate SST File"; Status="Failed"; Message="roots.sst file generation failed"}
        throw "roots.sst file generation failed."
    }

    # Step 2: Set permissions for the roots.sst file
    Write-Color "Setting permissions..." "Yellow"
    $icaclsResult = icacls $sstFilePath /grant "$($env:UserName):F" /grant Users:R

    # Check the result of icacls command
    if ($icaclsResult -match "Successfully processed") {
        Write-Color "Permissions set successfully." "Green"
        $statusMessages += [PSCustomObject]@{Step="Set Permissions"; Status="Success"; Message="Permissions set successfully"}
    } else {
        Write-Color "Failed to set permissions." "Red"
        $statusMessages += [PSCustomObject]@{Step="Set Permissions"; Status="Failed"; Message="Failed to set permissions"}
        throw "Setting permissions failed."
    }

    # Step 3: Import certificates from the roots.sst file
    Write-Color "Importing certificates..." "Yellow"
    $sst = New-Object System.Security.Cryptography.X509Certificates.X509Certificate2Collection
    $sst.Import($sstFilePath)

    # Check for updates
    $store = New-Object System.Security.Cryptography.X509Certificates.X509Store("Root", "LocalMachine")
    $store.Open([System.Security.Cryptography.X509Certificates.OpenFlags]::ReadOnly)
    $currentCerts = $store.Certificates
    $newCerts = $sst | Where-Object { $_.Thumbprint -notin $currentCerts.Thumbprint }
    $store.Close()

    if ($newCerts.Count -gt 0) {
        Write-Color "New certificates found: $($newCerts.Count)." "Yellow"
        $statusMessages += [PSCustomObject]@{Step="Check for Updates"; Status="Success"; Message="New certificates found: $($newCerts.Count)"}
        $updatesAvailable = $true
    } else {
        Write-Color "No new certificates found." "Green"
        $statusMessages += [PSCustomObject]@{Step="Check for Updates"; Status="Success"; Message="No new certificates found"}
        $updatesAvailable = $false
    }

    # Step 4: If updates are available, add new certificates
    if ($updatesAvailable) {
        $store = New-Object System.Security.Cryptography.X509Certificates.X509Store("Root", "LocalMachine")
        try {
            $store.Open([System.Security.Cryptography.X509Certificates.OpenFlags]::ReadWrite)
            foreach ($cert in $newCerts) {
                try {
                    $store.Add($cert)
                    Write-Color "Imported: $($cert.Subject)" "Green"
                    $statusMessages += [PSCustomObject]@{Step="Import Certificates"; Status="Success"; Message="Imported: $($cert.Subject)"}
                } catch {
                    Write-Color "Failed to add: $($cert.Subject)" "Red"
                    $statusMessages += [PSCustomObject]@{Step="Import Certificates"; Status="Failed"; Message="Failed to add: $($cert.Subject)"}
                }
            }
            $store.Close()
            Write-Color "Certificates imported successfully." "Green"
        } catch {
            Write-Color "Error opening certificate store." "Red"
            $statusMessages += [PSCustomObject]@{Step="Open Certificate Store"; Status="Failed"; Message="Error opening certificate store"}
            throw "Failed to open certificate store."
        }

        # Step 5: Verify the import
        Write-Color "Verifying certificates..." "Yellow"
        $store.Open([System.Security.Cryptography.X509Certificates.OpenFlags]::ReadOnly)
        foreach ($cert in $store.Certificates) {
            Write-Color "Certificate: $($cert.Subject)" "Cyan"
        }
        $store.Close()
    } else {
        Write-Color "No updates to apply." "Green"
    }

    Write-Color "Certificate update completed." "Green"
    $statusMessages += [PSCustomObject]@{Step="Update Process"; Status="Success"; Message="Certificate update process completed"}
} catch {
    Write-Color "Error: $_" "Red"
    $statusMessages += [PSCustomObject]@{Step="Update Process"; Status="Failed"; Message="Error: $_"}
}

# Output the status messages as a table
$statusMessages | Format-Table -AutoSize
