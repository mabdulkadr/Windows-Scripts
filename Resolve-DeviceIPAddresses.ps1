<#
.SYNOPSIS
    This script resolves IPv4 addresses from device names for a group of devices or a single device, displays the results in the console, and optionally saves the results to a CSV file.

.DESCRIPTION
    The script performs the following actions:
    1. Prompts the user to input a device name or upload a CSV file containing multiple device names.
    2. Resolves the IPv4 address and ping status for each device.
    3. Displays the results in the console immediately as each device is processed.
    4. Optionally saves the results to a CSV file.

    Note: The CSV file must contain a header with the name "Device Name".

.NOTES
    Author  : M.omar
    Website : momar.tech
    Date    : 2024-07-12
    Version : 1.0
#>

# Load the required assembly for Windows Forms to enable file dialog
Add-Type -AssemblyName System.Windows.Forms

# Function to resolve IPv4 addresses and ping status from device names
function Resolve-DeviceIP {
    param (
        [string]$DeviceName,
        [int]$Index
    )

    Write-Host "Processing device: $DeviceName" -ForegroundColor Green

    try {
        # Resolve the IPv4 address of the device
        $ipAddress = [System.Net.Dns]::GetHostAddresses($DeviceName) | Where-Object { $_.AddressFamily -eq 'InterNetwork' } | Select-Object -First 1
        # Ping the device to check connectivity
        $pingStatus = Test-Connection -ComputerName $DeviceName -Count 1 -Quiet

        # Create a custom object with the results
        $result = [PSCustomObject]@{
            Index      = $Index
            DeviceName = $DeviceName
            IPAddress  = if ($ipAddress) { $ipAddress.IPAddressToString } else { "No IPv4 address found" }
            PingStatus = if ($pingStatus) { "Success" } else { "Failed" }
        }
    } catch {
        # Handle any errors (e.g., if the device name cannot be resolved)
        $result = [PSCustomObject]@{
            Index      = $Index
            DeviceName = $DeviceName
            IPAddress  = "Error resolving IP"
            PingStatus = "N/A"
        }
    }

    # Return the result
    return $result
}

# Function to open file dialog for CSV selection
function Select-CSVFile {
    # Create a new OpenFileDialog instance
    $fileDialog = New-Object System.Windows.Forms.OpenFileDialog
    # Set the filter to only show CSV files
    $fileDialog.Filter = "CSV files (*.csv)|*.csv"
    # Set the dialog title
    $fileDialog.Title = "Select a CSV file containing device names"

    # Show the dialog and return the selected file path if a file is selected
    if ($fileDialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        return $fileDialog.FileName
    } else {
        return $null
    }
}

# Display the main menu
function Display-Menu {
    cls
    Write-Host ""
    Write-Host "######################################################" -ForegroundColor Cyan
    Write-Host "Select input method:" -ForegroundColor Yellow
    Write-Host "1: Enter a single device name manually." -ForegroundColor Yellow
    Write-Host "2: Upload a CSV file containing multiple device names." -ForegroundColor Yellow
    Write-Host "0: Exit." -ForegroundColor Yellow
    Write-Host "######################################################" -ForegroundColor Cyan
    Write-Host ""
}

# Main script logic
function Main {
    $deviceNames = @()
    $exitFlag = $false

    while (-not $exitFlag) {
        Display-Menu
        $inputMethod = Read-Host "Enter your choice"

        switch ($inputMethod) {
            '1' {
                # User inputs a single device name
                $deviceName = Read-Host "Enter the device name"
                $deviceNames = @($deviceName)
                $exitFlag = $true
            }
            '2' {
                # User selects a CSV file
                $csvPath = Select-CSVFile
                if ($csvPath) {
                    try {
                        # Inform the user to wait while loading the CSV file
                        Write-Host ""
                        Write-Host "Loading device names from the CSV file. Please wait..." -ForegroundColor Cyan
                        # Import device names from the selected CSV file with column name "Device name"
                        $deviceNames = Import-Csv -Path $csvPath | ForEach-Object { $_.'Device name' }
                        Write-Host ""
                        Write-Host "Loaded $($deviceNames.Count) device names." -ForegroundColor Green
                        $exitFlag = $true
                    } catch {
                        Write-Host ""
                        Write-Host "Failed to read the CSV file. Please ensure it has a 'Device name' column." -ForegroundColor Red
                    }
                } else {
                    Write-Host ""
                    Write-Host "No file selected. Please choose an option from the menu." -ForegroundColor Red
                }
            }
            '0' {
                Write-Host ""
                Write-Host "Exiting..." -ForegroundColor Red
                $exitFlag = $true
            }
            default {
                Write-Host ""
                Write-Host "Invalid option selected. Please select a valid option." -ForegroundColor Red
            }
        }
    }

    if ($deviceNames.Count -gt 0) {
        # Initialize an array to hold all results
        $allResults = @()

        # Process each device name and store the result
        for ($i = 0; $i -lt $deviceNames.Count; $i++) {
            $deviceName = $deviceNames[$i]
            $result = Resolve-DeviceIP -DeviceName $deviceName -Index ($i + 1)
            $allResults += $result
        }

        # Display all results in the console
        $allResults | Format-Table -AutoSize -Wrap

        # Prompt the user to save the results to a CSV file
        $saveResults = Read-Host "Do you want to save the results to a CSV file? (y/n)"
        if ($saveResults -eq 'y') {
            $saveFileDialog = New-Object System.Windows.Forms.SaveFileDialog
            $saveFileDialog.Filter = "CSV files (*.csv)|*.csv"
            $saveFileDialog.Title = "Save the results to a CSV file"
            $saveFileDialog.FileName = "ResolvedDeviceIPs.csv"

            if ($saveFileDialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
                $outputPath = $saveFileDialog.FileName
                $allResults | Export-Csv -Path $outputPath -NoTypeInformation
                Write-Host ""
                Write-Host "Results saved to $outputPath" -ForegroundColor Cyan
            } else {
                Write-Host ""
                Write-Host "Save operation cancelled." -ForegroundColor Red
            }
        }
    } else {
        Write-Host ""
        Write-Host "No device names were processed." -ForegroundColor Red
    }
}

# Run the main function
Main
