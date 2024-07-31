<#
.SYNOPSIS
    This script collects hardware information from a single device and displays the results in the console.

.DESCRIPTION
    The script performs the following actions:
    1. Prompts the user to input a device name.
    2. Resolves the IPv4 address for the device.
    3. Collects hardware information, including CPU, memory, storage details, and logged-in user for the device.
    4. Displays the results in the console immediately as the device is processed.

.NOTES
    Author  : M.omar
    Website : momar.tech
    Date    : 2024-07-12
    Version : 1.0
#>

[CmdletBinding()]
param (
    [string]$ComputerName
)

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
                @{Name='TotalPhysicalMemoryGB';Expression={[math]::Ceiling($_.TotalPhysicalMemory / 1GB)}},
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
            Select-Object @{Name='SizeGB';Expression={[math]::Ceiling($_.Size / 1GB)}},
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
            'PC Name'                = $csinfo.Name
            'PC IP'                  = $ipinfo.IPAddressToString
            'Logged In User'         = $csinfo.LoggedInUser
            'Manufacturer'           = $csinfo.Manufacturer
            'Model'                  = $csinfo.Model
            'CPU'                    = $csinfo.PhysicalProcessors
            'CPU Cores'              = $csinfo.LogicalProcessors
            'RAM GB'                 = $csinfo.TotalPhysicalMemoryGB
            'Operating System'       = $osinfo.OperatingSystem
            'Architecture'           = $osinfo.Architecture
            'OS Version'             = $osinfo.Version
            'HardDisk Size GB'       = ($diskinfo | Measure-Object -Property SizeGB -Sum).Sum
            'HardDisk Type'          = ($diskinfo | Select-Object -ExpandProperty MediaType -Unique) -join ", "
        }
        return $deviceInfo

    } catch [System.Exception] {
        Write-Warning "Unable to collect information from ${ComputerName}: $_"
        return $null
    }
}

# Main script execution
if (-not $ComputerName) {
    Write-Host ""
    $ComputerName = Read-Host "Enter the computer name or IP" 
    Write-Host ""
}

Write-Host "Collecting data from $ComputerName..." -ForegroundColor Cyan
Write-Host ""
$deviceInfo = Get-HardwareInfo -ComputerName $ComputerName

if ($deviceInfo) { 
    Write-Host "PC Name:                $($deviceInfo.'PC Name')"
    Write-Host "PC IP:                  $($deviceInfo.'PC IP')"
    Write-Host "Logged In User:         $($deviceInfo.'Logged In User')"
    Write-Host "------------------------------------------------------"
    Write-Host "Manufacturer:           $($deviceInfo.'Manufacturer')"
    Write-Host "Model:                  $($deviceInfo.'Model')"
    Write-Host "------------------------------------------------------"
    Write-Host "CPU:                    $($deviceInfo.'CPU')"
    Write-Host "CPU Cores:              $($deviceInfo.'CPU Cores')"
    Write-Host "RAM GB:                 $($deviceInfo.'RAM GB')"
    Write-Host "------------------------------------------------------"
    Write-Host "Operating System:       $($deviceInfo.'Operating System')"
    Write-Host "Architecture:           $($deviceInfo.'Architecture')"
    Write-Host "OS Version:             $($deviceInfo.'OS Version')"
    Write-Host "------------------------------------------------------"
    Write-Host "HardDisk Size GB:       $([math]::Ceiling($deviceInfo.'HardDisk Size GB'))"
    Write-Host "HardDisk Type:          $($deviceInfo.'HardDisk Type')"
    Write-Host ""
    Write-Host "Data collected from $ComputerName." -ForegroundColor Green
    Write-Host ""
} else {
    Write-Host ""
    Write-Host "No data collected from $ComputerName." -ForegroundColor Yellow
    Write-Host ""
}
