<#
.SYNOPSIS
    This script collects hardware information from a group of devices or a single device, displays the results in the console, and optionally saves the results to an Excel file.

.DESCRIPTION
    The script performs the following actions:
    1. Prompts the user to input a device name or upload a CSV file containing multiple device names.
    2. Resolves the IPv4 address for each device.
    3. Collects hardware information, including CPU, memory, storage details, and logged-in user for each device.
    4. Displays the results in the console immediately as each device is processed.
    5. Optionally saves the results to an Excel file.

    The CSV file must contain a header with the name 'Name'.

.NOTES
    Author  : M.omar
    Website : momar.tech
    Date    : 2024-07-12
    Version : 1.0
#>



[CmdletBinding()]
param (
    [string]$OutputFile = "HardwareInventory.xlsx"
)


Add-Type -AssemblyName System.Windows.Forms

# Function to collect hardware information
function Get-HardwareInfo {
    param (
        [string]$ComputerName
    )
    
    try {
        $pingResult = Test-Connection -ComputerName $ComputerName -Count 1 -Quiet
        if (-not $pingResult) {
            Write-Host "Unable to reach $ComputerName. Skipping." -ForegroundColor Yellow
            return $null
        }

        $csinfo = Get-WmiObject Win32_ComputerSystem -ComputerName $ComputerName -ErrorAction Stop |
            Select-Object Name, Manufacturer, Model,
                @{Name='PhysicalProcessors';Expression={$_.NumberOfProcessors}},
                @{Name='LogicalProcessors';Expression={$_.NumberOfLogicalProcessors}},
                @{Name='TotalPhysicalMemoryGB';Expression={[math]::round($_.TotalPhysicalMemory / 1GB, 2)}},
                DnsHostName, Domain,
                @{Name='LoggedInUser';Expression={$_.UserName}}

        $osinfo = Get-WmiObject Win32_OperatingSystem -ComputerName $ComputerName -ErrorAction Stop | 
            Select-Object @{Name='OperatingSystem';Expression={$_.Caption}},
                @{Name='Architecture';Expression={$_.OSArchitecture}},
                Version, Organization,
                @{Name='InstallDate';Expression={[datetime]::ParseExact($_.InstallDate.Substring(0, 8), "yyyyMMdd", $null)}},
                WindowsDirectory

        # Get IP address
        $ipinfo = [System.Net.Dns]::GetHostAddresses($ComputerName) | Where-Object { $_.AddressFamily -eq 'InterNetwork' }

        # Get storage information
        $diskinfo = Get-WmiObject Win32_DiskDrive -ComputerName $ComputerName -ErrorAction Stop |
            Select-Object @{Name='SizeGB';Expression={[math]::round($_.Size / 1GB, 2)}},
                         @{Name='MediaType';Expression={
                             if ($_.Model -match "SSD|NVMe|Solid State" -or $_.MediaType -match "SSD|Solid State") {
                                 "SSD"
                             } elseif ($_.MediaType -match "HDD|Fixed hard disk media") {
                                 "HDD"
                             } else {
                                 $_.MediaType
                             }
                         }}

        # Combine the information into a single object
        $deviceInfo = [PSCustomObject]@{
            'Computer Name'          = $csinfo.Name
            'Computer IP'            = $ipinfo.IPAddressToString
            'Logged In User'         = $csinfo.LoggedInUser
            'Manufacturer'           = $csinfo.Manufacturer
            'Model'                  = $csinfo.Model
            'PhysicalProcessors'     = $csinfo.PhysicalProcessors
            'Logical Processors'     = $csinfo.LogicalProcessors
            'Total Memory GB'        = $csinfo.TotalPhysicalMemoryGB
            'Operating System'       = $osinfo.OperatingSystem
            'Architecture'           = $osinfo.Architecture
            'OS Version'             = $osinfo.Version
            'Install Date'           = $osinfo.InstallDate
            'Storage Size GB'        = ($diskinfo | Measure-Object -Property SizeGB -Sum).Sum
            'Storage Type'           = ($diskinfo | Select-Object -ExpandProperty MediaType -Unique) -join ", "
        }
        return $deviceInfo

    } catch [System.Exception] {
        Write-Warning "Unable to collect information from ${ComputerName}: $_"
        return $null
    }
}

# Menu function
function Show-Menu {
    Clear-Host
    Write-Host "##############################################" -ForegroundColor Cyan
    Write-Host "#         Hardware Inventory Manager         #" -ForegroundColor Cyan
    Write-Host "##############################################" -ForegroundColor Cyan
    Write-Host "1: Collect hardware info from a single device" -ForegroundColor Green
    Write-Host "2: Collect hardware info from multiple devices (csv)" -ForegroundColor Green
    Write-Host "3: Collect hardware info from all devices" -ForegroundColor Green
    Write-Host "Q: Exit" -ForegroundColor Green
}

# Prompt user for menu selection
function Get-UserChoice {
    param (
        [string]$prompt
    )
    Write-Host $prompt -ForegroundColor Cyan
    return Read-Host
}

# Function to export inventory to Excel
function Export-InventoryToExcel {
    param (
        [string]$OutputFile,
        [array]$Inventory
    )
    if ($Inventory.Count -gt 0) {
        $Excel = New-Object -ComObject Excel.Application
        $Excel.Visible = $false
        $Workbook = $Excel.Workbooks.Add()
        $Sheet = $Workbook.Worksheets.Item(1)

        # Add header
        $Headers = $Inventory[0].PSObject.Properties.Name
        $Sheet.Cells.Item(1, 1).Resize(1, $Headers.Count).Value = $Headers

        # Add data
        $row = 2
        foreach ($item in $Inventory) {
            $col = 1
            foreach ($header in $Headers) {
                $Sheet.Cells.Item($row, $col).Value = $item.$header
                $col++
            }
            $row++
        }

        # Save and close Excel
        $Workbook.SaveAs($OutputFile)
        $Workbook.Close()
        $Excel.Quit()
        Write-Host "Hardware inventory collection completed. Results saved to $OutputFile." -ForegroundColor Green
    } else {
        Write-Host "No data collected. Exiting script." -ForegroundColor Yellow
    }
}

# Handle script exit and prompt for saving
function Save-InventoryOnExit {
    if ($Inventory.Count -gt 0) {
        $saveFile = Read-Host "Do you want to save the collected data? (Y/N)"
        if ($saveFile -eq "Y" -or $saveFile -eq "y") {
            $SaveFileDialog = New-Object System.Windows.Forms.SaveFileDialog
            $SaveFileDialog.Filter = "Excel Workbook (*.xlsx)|*.xlsx"
            $SaveFileDialog.FileName = "HardwareInventory.xlsx"
            if ($SaveFileDialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
                Export-InventoryToExcel -OutputFile $SaveFileDialog.FileName -Inventory $Inventory
            } else {
                Write-Host "Data not saved." -ForegroundColor Yellow
            }
        } else {
            Write-Host "Data not saved." -ForegroundColor Yellow
        }
    } else {
        Write-Host "No data collected to save." -ForegroundColor Yellow
    }
}

# Function to browse and select a CSV file
function Get-CsvFilePath {
    $OpenFileDialog = New-Object System.Windows.Forms.OpenFileDialog
    $OpenFileDialog.Filter = "CSV files (*.csv)|*.csv"
    if ($OpenFileDialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        return $OpenFileDialog.FileName
    } else {
        return $null
    }
}

# Collect hardware info based on user choice
$Inventory = @()
$choice = ""

try {
    while ($choice -ne "Q") {
        Show-Menu
        $choice = Get-UserChoice "Please make a selection (1, 2, 3, Q):"
        switch ($choice) {
            "1" {
                $ComputerName = Read-Host "Enter the computer name or IP"
                Write-Host "Collecting data from $ComputerName..." -ForegroundColor Cyan
                $deviceInfo = Get-HardwareInfo -ComputerName $ComputerName
                if ($deviceInfo) { 
                    $Inventory += $deviceInfo 
                    Write-Host "Data collected from $ComputerName." -ForegroundColor Green
                    Save-InventoryOnExit
                } else {
                    Write-Host "No data collected from $ComputerName." -ForegroundColor Yellow
                }
                Pause
            }
            "2" {
                $csvFilePath = Get-CsvFilePath
                if ($csvFilePath) {
                    $ComputerNames = Import-Csv -Path $csvFilePath | Select-Object -ExpandProperty Name
                    foreach ($ComputerName in $ComputerNames) {
                        Write-Host "Collecting data from $ComputerName..." -ForegroundColor Cyan
                        $deviceInfo = Get-HardwareInfo -ComputerName $ComputerName.Trim()
                        if ($deviceInfo) { 
                            $Inventory += $deviceInfo 
                            Write-Host "Data collected from $ComputerName." -ForegroundColor Green
                        } else {
                            Write-Host "No data collected from $ComputerName." -ForegroundColor Yellow
                        }
                    }
                    Save-InventoryOnExit
                } else {
                    Write-Host "No CSV file selected. Returning to menu." -ForegroundColor Yellow
                }
                Pause
            }
            "3" {
                Write-Host "Collecting data from all devices in the domain..." -ForegroundColor Cyan
                $ComputerNames = Get-ADComputer -Filter * | Select-Object -ExpandProperty DNSHostName
                foreach ($ComputerName in $ComputerNames) {
                    Write-Host "Collecting data from $ComputerName..." -ForegroundColor Cyan
                    $deviceInfo = Get-HardwareInfo -ComputerName $ComputerName.Trim()
                    if ($deviceInfo) { 
                        $Inventory += $deviceInfo 
                        Write-Host "Data collected from $ComputerName." -ForegroundColor Green
                    } else {
                        Write-Host "No data collected from $ComputerName." -ForegroundColor Yellow
                    }
                }
                Save-InventoryOnExit
                Pause
            }
            "Q" {
                Write-Host "Quitting the script..." -ForegroundColor Cyan
                Save-InventoryOnExit
            }
            default {
                Write-Host "Invalid choice. Please try again." -ForegroundColor Red
                Pause
            }
        }
    }
} catch {
    Write-Warning "Script interrupted: $_"
    Save-InventoryOnExit
}
