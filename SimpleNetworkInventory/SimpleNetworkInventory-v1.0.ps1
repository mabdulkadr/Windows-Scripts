<#
.SYNOPSIS
    Simple Network Inventory Tool v1.0 – Modern WPF GUI for Parallel Network Device Discovery and Categorization.
.DESCRIPTION
    A fast, robust, and user-friendly PowerShell WPF application for scanning, identifying, and documenting devices across any IPv4 network.
    
    Key Features:
      - Modern WPF interface for intuitive use and real-time results.
      - High-speed, parallel scanning of networks and IP ranges (CIDR, dash, or full range notation).
      - Automatically detects the local subnet or allows manual input for flexible scanning.
      - Device reachability and status detection with instant “Hide Unreachable” filter.
      - Detailed device inventory: Hostname, IP, MAC, Manufacturer, OS, Model, CPU, RAM, Storage, and more.
      - True manufacturer detection via local WMI (Windows) or IEEE OUI database (all platforms).
      - Intelligent device categorization (PC, Server, Printer, Network, IoT, Linux, etc.) using open port signatures and vendor rules.
      - Real-time UI updates and progress status, optimized for large-scale networks and mixed environments (workgroup/domain).
      - One-click CSV export, load/save previous scans, and comprehensive logging for audit and troubleshooting.
      - Secure and efficient: no OUI “guesswork”, all data sources are locally verified or from official registries.
    
    Typical Use Cases:
      - Enterprise network auditing, asset inventory, and compliance.
      - Troubleshooting and documenting both Windows and non-Windows devices (Linux, printers, network equipment).
      - Rapid pre/post change management scans and export for reporting.
      - Classroom or training environments for demonstrating practical network discovery.

.NOTES
    Author     : Mohammad Abdulkader Omar
    Website    : momar.tech
    Version    : 1.0
    Date       : 11-6-2025
#>

#region [1]--- Globals & Configuration ---

<#
.SYNOPSIS
    Initializes global variables, file paths, and configuration settings.
.DESCRIPTION
    - Sets application name, folder locations, and key file paths.
    - Initializes global/in-memory data collections for UI binding and scan data.
    - Pre-defines port profiles, OUI database location, and scan defaults.
.NOTES
    Author: Enhanced ScriptForge, June 2025.
#>

# ---- Application Info ----
$global:AppName    = "SimpleNetworkInventory"
$global:AppFolder  = "C:\SimpleNetworkInventory"

# ---- Data & Log File Paths ----
$global:MemoryFile = Join-Path $global:AppFolder "$($global:AppName)-memory.json"
$global:LogFile    = Join-Path $global:AppFolder "$($global:AppName)-log.txt"
$global:ExportDir  = $global:AppFolder

# ---- Persistent OUI Database ----
$global:OuiPath = Join-Path $global:AppFolder "oui.txt"
$global:OuiMap  = @{}

# ---- In-memory Data Collections ----
$global:ScanCollection = [System.Collections.ObjectModel.ObservableCollection[object]]::new()
$global:ScanView       = [System.Collections.ObjectModel.ObservableCollection[object]]::new()

# ---- Background Job State ----
$global:scanJob       = $null
$global:ScanTimer     = $null
$global:ScanCompleted = $false
$global:TotalScanCount = 0

# ---- ARP Table (refreshed per scan) ----
$global:ArpTable = @{}

# ---- Port Profiles (for device detection/category) ----
$global:PortProfiles = @{
    "Default"      = @(22, 80, 443, 5060, 554, 8080, 445, 139, 9100, 1900, 5353, 3000, 8200)
    "IoT"          = @(80, 443, 5678, 8000, 8080, 8888, 5000, 1900, 5353)
    "VoIP"         = @(5060, 5061, 161, 162)
    "Surveillance" = @(80, 443, 554, 8000, 8080, 8554, 10001)
}
$global:ActivePorts = $global:PortProfiles["Default"]

# ---- Scan Target Defaults (editable via UI) ----
$global:DefaultSubnet = "192.168.1.0/24"
$global:DefaultProfile = "Default"

# ---- Miscellaneous/Other ----
$global:scan = $global:ScanCollection   # For script brevity/compatibility

# ---- Ensure main application directory exists ----
if (-not (Test-Path $global:AppFolder)) {
    New-Item $global:AppFolder -ItemType Directory | Out-Null
}

#endregion

#region [2]--- Utility Functions ---

<#
.SYNOPSIS
    Reusable functions for Simple Network Inventory Tool.
.DESCRIPTION
    - Logging (Write-Log)
    - Subnet/range parsing (Parse-SubnetRange)
    - Local subnet detection (Get-LocalCIDR)
    - File operations (Save-Scan, Load-LastScan)
    - Data export (Export-Data)
    - UI/grid updates (Clear-Grid, Update-GridView)
    - ARP table retrieval
    - OUI vendor lookup
    - Device category assignment
#>

# ---- Logging ----
function Write-Log {
    param (
        [string]$Message,
        [ValidateSet("INFO","SUCCESS","ERROR","WARNING")]
        [string]$Level = "INFO"
    )
    $ts = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $prefix = switch ($Level) {
        "SUCCESS" { "[+]" }
        "ERROR"   { "[!]" }
        "WARNING" { "[~]" }
        default   { "[ ]" }
    }
    $msg = "$ts $prefix $Message"
    $color = switch ($Level) {
        "SUCCESS" {"Green"}
        "ERROR"   {"Red"}
        "WARNING" {"Yellow"}
        default   {"Cyan"}
    }
    Write-Host $msg -ForegroundColor $color
    $msg | Out-File -FilePath $global:LogFile -Append -Encoding UTF8
}

# ---- Parse subnet/range into array of IPs ----
function Parse-SubnetRange {
    param([string]$subnet)

    $subnet = $subnet.Trim()

    # Helper function to validate IP addresses
    function Test-ValidIP {
        param([string]$ip)
        $octets = $ip -split '\.'
        if ($octets.Count -ne 4) { return $false }
        foreach ($octet in $octets) {
            if (-not ($octet -match '^\d+$')) { return $false }
            $num = [int]$octet
            if ($num -lt 0 -or $num -gt 255) { return $false }
        }
        return $true
    }

    # CIDR notation: 192.168.1.0/24
    if ($subnet -match '^(\d{1,3}\.){3}\d{1,3}/\d{1,2}$') {
        $ip, $prefix = $subnet -split '/'
        $prefix = [int]$prefix
        
        if (-not (Test-ValidIP $ip)) { throw "Invalid IP address in CIDR: $subnet" }
        if ($prefix -lt 0 -or $prefix -gt 32) { throw "Invalid prefix length in CIDR: $subnet" }
        
        $ipBytes = [System.Net.IPAddress]::Parse($ip).GetAddressBytes()
        $maskBytes = @(0,0,0,0)
        $remaining = $prefix
        for ($i = 0; $i -lt 4; $i++) {
            if ($remaining -ge 8) {
                $maskBytes[$i] = 255
                $remaining -= 8
            } else {
                $maskBytes[$i] = 255 -shl (8 - $remaining)
                $remaining = 0
            }
        }

        $networkBytes = @(0,0,0,0)
        for ($i = 0; $i -lt 4; $i++) {
            $networkBytes[$i] = ($ipBytes[$i] -band $maskBytes[$i])
        }

        $startIP = [System.Net.IPAddress]::new($networkBytes).ToString()
        
        $broadcastBytes = @(0,0,0,0)
        for ($i = 0; $i -lt 4; $i++) {
            $broadcastBytes[$i] = ($networkBytes[$i] -bor (-bnot $maskBytes[$i] -band 0xFF))
        }
        $endIP = [System.Net.IPAddress]::new($broadcastBytes).ToString()

        $current = [System.Net.IPAddress]::Parse($startIP).GetAddressBytes()
        $last = [System.Net.IPAddress]::Parse($endIP).GetAddressBytes()
        $ips = @()
        while ($true) {
            $ips += ([System.Net.IPAddress]::new($current.Clone())).ToString()
            if ($current[0] -eq $last[0] -and $current[1] -eq $last[1] -and 
                $current[2] -eq $last[2] -and $current[3] -eq $last[3]) { break }
            
            for ($i = 3; $i -ge 0; $i--) {
                if ($current[$i] -lt 255) { 
                    $current[$i]++
                    break 
                } else { 
                    $current[$i] = 0 
                }
            }
        }
        return $ips
    }

    # Short dash: 192.168.1.10-20 (same subnet, last octet range)
    if ($subnet -match '^(\d{1,3}\.\d{1,3}\.\d{1,3}\.)(\d+)-(\d+)$') {
        $m = [regex]::Match($subnet, '^(\d{1,3}\.\d{1,3}\.\d{1,3}\.)(\d+)-(\d+)$')
        $base = $m.Groups[1].Value
        $from = [int]$m.Groups[2].Value
        $to   = [int]$m.Groups[3].Value
        
        # Validate base IP
        if (-not (Test-ValidIP ($base + "0"))) { throw "Invalid base IP in range: $subnet" }
        if ($from -gt $to) { throw "Start value ($from) cannot be greater than end value ($to)" }
        if ($from -lt 0 -or $to -gt 255) { throw "Octet values must be between 0 and 255" }
        
        return @($from..$to | ForEach-Object { "$base$_" })
    }

    # Full IP range: 192.168.1.100-192.168.2.20
    if ($subnet -match '^(\d{1,3}(\.\d{1,3}){3})-(\d{1,3}(\.\d{1,3}){3})$') {
        $m = [regex]::Match($subnet, '^(\d{1,3}(?:\.\d{1,3}){3})-(\d{1,3}(?:\.\d{1,3}){3})$')
        $startIP = $m.Groups[1].Value
        $endIP   = $m.Groups[2].Value
        
        if (-not (Test-ValidIP $startIP)) { throw "Invalid start IP: $startIP" }
        if (-not (Test-ValidIP $endIP)) { throw "Invalid end IP: $endIP" }
        
        $current = [System.Net.IPAddress]::Parse($startIP).GetAddressBytes()
        $last    = [System.Net.IPAddress]::Parse($endIP).GetAddressBytes()
        
        # Validate IP order
        $startUint = [BitConverter]::ToUInt32($current[3..0], 0)
        $endUint = [BitConverter]::ToUInt32($last[3..0], 0)
        if ($startUint -gt $endUint) { throw "Start IP ($startIP) cannot be greater than end IP ($endIP)" }
        
        $ips = @()
        while ($true) {
            $ips += ([System.Net.IPAddress]::new($current.Clone())).ToString()
            if ($current[0] -eq $last[0] -and $current[1] -eq $last[1] -and 
                $current[2] -eq $last[2] -and $current[3] -eq $last[3]) { break }
                
            for ($i = 3; $i -ge 0; $i--) {
                if ($current[$i] -lt 255) { $current[$i]++; break }
                else { $current[$i] = 0 }
            }
        }
        return $ips
    }

    # Single IP
    if ($subnet -match '^\d{1,3}(\.\d{1,3}){3}$') {
        if (-not (Test-ValidIP $subnet)) { throw "Invalid IP address: $subnet" }
        return @($subnet)
    }

    throw "Invalid subnet format: $subnet"
}

# ---- Get local subnet CIDR ----
function Get-LocalCIDR {
    $ip = Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.IPAddress -notlike '169.*' -and $_.IPAddress -ne '127.0.0.1' } | Select-Object -First 1
    if ($ip) {
        $subnet = $ip.IPAddress -replace '\.\d+$', '.0'
        return "$subnet/$($ip.PrefixLength)"
    } else {
        throw "Could not determine local subnet."
    }
}

# ---- Save/Load scan data ----
function Save-Scan {
    try { $global:ScanCollection | ConvertTo-Json -Depth 5 | Set-Content -Path $global:MemoryFile }
    catch { Write-Log "Failed to save scan: $_" "ERROR" }
}
function Load-LastScan {
    try {
        if (Test-Path $global:MemoryFile) {
            $data = Get-Content $global:MemoryFile -Raw | ConvertFrom-Json
            $global:ScanCollection.Clear(); $data | ForEach-Object { $global:ScanCollection.Add($_) }
            Update-GridView
            Write-Log "Loaded previous scan" "SUCCESS"
        }
    } catch { Write-Log "Failed to load previous scan: $_" "ERROR" }
}

# ---- Export scan data ----
function Export-Data($format) {
    $dialog = New-Object System.Windows.Forms.SaveFileDialog
    $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
    $dialog.InitialDirectory = $global:ExportDir
    $dialog.FileName = "$global:AppName-$timestamp"
    $dialog.Filter = if ($format -eq 'CSV') { 'CSV files (*.csv)|*.csv' } else { 'HTML files (*.html)|*.html' }
    if ($dialog.ShowDialog() -eq 'OK') {
        try {
            $global:ScanView | Export-Csv -Path $dialog.FileName -NoTypeInformation -Encoding UTF8
            Write-Log "Exported data to $dialog.FileName" "SUCCESS"
        } catch {
            [System.Windows.MessageBox]::Show("Export failed: $_", "Export Error", 'OK', 'Error')
            Write-Log "Export failed: $_" "ERROR"
        }
    }
}

# ---- Clear and update grid ----
function Clear-Grid {
    $global:ScanCollection.Clear()
    Update-GridView
    Write-Log "Grid cleared." "INFO"
}
function Update-GridView {
    $global:ScanView.Clear()
    $rows = $global:ScanCollection
    if ($script:chkHideUnreachable -and $script:chkHideUnreachable.IsChecked) {
        $rows = $rows | Where-Object { $_.Status -eq "OK" }
    }
    $rows | ForEach-Object { $global:ScanView.Add($_) }
    $script:grid.Items.Refresh()
}

# ---- Get ARP Table for MAC detection ----
function Get-ArpTable {
    $arpLines = arp -a | Where-Object { $_ -match '\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}' }
    $arpEntries = @{}
    foreach ($line in $arpLines) {
        if ($line -match '(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})\s+([0-9a-fA-F\-]+)') {
            $ip = $matches[1]
            $mac = $matches[2].Replace('-',':').ToLower()
            $arpEntries[$ip] = $mac
        }
    }
    return $arpEntries
}

# ---- Load OUI map from oui.txt ----
function Load-OuiMap {
    if (-not (Test-Path $global:OuiPath)) {
        # Show status before download
        $status.Dispatcher.Invoke([action]{ $status.Text = "🌐 Downloading OUI vendor database..." })
        [System.Windows.Forms.Application]::DoEvents()
        Write-Log "Downloading IEEE OUI vendor database..." "INFO"
        try {
            [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
            Invoke-WebRequest -Uri "https://standards-oui.ieee.org/oui/oui.txt" -OutFile $global:OuiPath
            Write-Log "Downloaded OUI database." "SUCCESS"
        } catch {
            Write-Log "Failed to download OUI database: $_" "ERROR"
            $status.Dispatcher.Invoke([action]{ $status.Text = "⚠️ OUI vendor DB download failed (MAC vendor lookup limited)." })
            [System.Windows.Forms.Application]::DoEvents()
            return
        }
    }
    if (Test-Path $global:OuiPath) {
        $status.Dispatcher.Invoke([action]{ $status.Text = "🔎 Parsing OUI vendor database..." })
        [System.Windows.Forms.Application]::DoEvents()
        Write-Log "Parsing OUI vendor database..." "INFO"
        try {
            Get-Content $global:OuiPath | Where-Object { $_ -match '^([0-9A-F]{6})' } | ForEach-Object {
                $global:OuiMap[$matches[1].ToUpper()] = ($_ -split '\)')[1].Trim()
            }
            Write-Log "Parsed OUI vendor database." "SUCCESS"
        } catch {
            Write-Log "Failed to parse OUI database: $_" "ERROR"
            $status.Dispatcher.Invoke([action]{ $status.Text = "⚠️ OUI vendor DB parse error." })
            [System.Windows.Forms.Application]::DoEvents()
        }
    }
}

# ---- Get vendor (manufacturer) from MAC ----
function Get-MacVendorOffline {
    param([string]$MacAddress)
    $cleanMac = $MacAddress -replace '[^A-Fa-f0-9]', ''
    if ($cleanMac.Length -ge 6) {
        $oui = $cleanMac.Substring(0,6).ToUpper()
        return $global:OuiMap[$oui]
    } else {
        return "Unknown"
    }
}

#endregion

#region [3]--- Scan Logic (Job-based, Enhanced ARP/OUI/Category Detection) ---

<#
.SYNOPSIS
    Main scan engine for Simple Network Inventory Tool.
.DESCRIPTION
    - Launches parallel scan job for given subnet/range.
    - Handles OUI vendor database loading and parsing.
    - Pings each device, collects OS and hardware info (WMI/ARP), open ports.
    - Assigns Manufacturer (from WMI or OUI) and smart device Category.
    - Writes scan results to memory file for live UI updates.
    - Robust error handling, supports large-scale and mixed networks.
#>

function Start-Scan {

    $global:ScanCompleted = $false
    Clear-Grid
    $status.Text = "🔄 Scanning..."

    $btnScan.IsEnabled = $false
    $btnStop.IsEnabled = $true

    # OUI PREP: Download/parse if needed (once per run)
    Load-OuiMap

    # Parse subnet input and ports
    $subnetInput = if ($chkAutoDetect.IsChecked) { Get-LocalCIDR } else { $txtRange.Text.Trim() }
    try {
        $ips = Parse-SubnetRange $subnetInput
        $global:TotalScanCount = $ips.Count
    }
    catch {
        [System.Windows.MessageBox]::Show("Invalid subnet format.`nExamples:`n192.168.1.0/24`n192.168.1.10-20`n192.168.0.1-192.168.1.255", "Error", 'OK', 'Error')
        $btnScan.IsEnabled = $true
        $btnStop.IsEnabled = $false
        return
    }
    Write-Log "Started scan of $subnetInput" "INFO"

    # Build ARP Table (best for MAC of non-Windows devices)
    $global:ArpTable = Get-ArpTable

    # Clean up previous jobs
    if ($global:scanJob) { Remove-Job -Job $global:scanJob -ErrorAction SilentlyContinue }
    $mem    = $global:MemoryFile
    $log    = $global:LogFile
    $ouiMap = $global:OuiMap
    $arpTable = $global:ArpTable
    $portsToScan = $global:ActivePorts

    $global:scanJob = Start-Job -ScriptBlock {
        param($ips, $mem, $log, $ouiMap, $arpTable, $portsToScan)

        function Try-GetWMI { param($class, $ip) try { Get-WmiObject -Class $class -ComputerName $ip -ErrorAction Stop } catch { $null } }

        $resultList = @()

        foreach ($ip in $ips) {
            $osHint      = "-"
            $printerHint = "-"
            $netbiosName = "-"
            $openPorts   = @()
            $mac         = "-"
            $vendor      = "Unknown"

            # Ping
            $isOnline = Test-Connection -ComputerName $ip -Count 1 -Quiet -ErrorAction SilentlyContinue
            if (-not $isOnline) {
                $deviceInfo = [PSCustomObject]@{
                    Status             = "Unreachable"
                    Hostname           = "-"
                    IPAddress          = $ip
                    MACAddress         = "-"
                    Vendor             = "Unknown"
                    Category           = "Offline Device"
                    NetBIOSName        = "-"
                    DeviceModel        = "-"
                    ProcessorModel     = "-"
                    CPUSpeed           = "-"
                    ProcessorCores     = "-"
                    ProcessorThreads   = "-"
                    TotalRAM_GB        = "-"
                    StorageCapacity_GB = "-"
                    StorageType        = "-"
                    OSName             = "-"
                    OSVersion          = "-"
                    OSArchitecture     = "-"
                    OSInstallDate      = "-"
                    OSType             = $osHint
                    Uptime             = "-"
                    LoggedInUsers      = "-"
                }
                $resultList += $deviceInfo
                $resultList | ConvertTo-Json -Depth 5 | Set-Content -Path $mem -Force
                continue
            }

            # Port scan for categorization
            foreach ($port in $portsToScan) {
                try {
                    $tcp = New-Object System.Net.Sockets.TcpClient
                    $iar = $tcp.BeginConnect($ip, $port, $null, $null)
                    $iar.AsyncWaitHandle.WaitOne(120)
                    if ($tcp.Connected) { $openPorts += $port }
                    $tcp.Close()
                } catch {}
            }

            # NetBIOS
            try { $netbiosName = ([System.Net.Dns]::GetHostEntry($ip)).HostName } catch {}

            # TTL/OS hint
            $ttl = $null
            try { $ttl = (Test-Connection -ComputerName $ip -Count 1 -ErrorAction Stop) | Select-Object -ExpandProperty ResponseTimeToLive } catch {}
            if ($ttl) {
                if ($ttl -le 65) { $osHint = "Linux/Unix" }
                elseif ($ttl -ge 120) { $osHint = "Windows" }
            }

            # Printer detection
            $hasPrinterPort = $openPorts -contains 9100
            if ($hasPrinterPort) { $printerHint = "Possible Printer (9100)" }

            # MAC from ARP (first, reliable for non-Windows devices)
            if ($arpTable.ContainsKey($ip)) {
                $mac = $arpTable[$ip]
            }

            # Fallback: WMI MAC for Windows (when ARP fails)
            if (-not $mac -or $mac -eq "" -or $mac -eq "-") {
                $ipinfo = try { Get-WmiObject -Class Win32_NetworkAdapterConfiguration -ComputerName $ip | Where-Object { $_.IPAddress -contains $ip } | Select-Object -First 1 } catch { $null }
                $mac = if ($ipinfo) { $ipinfo.MACAddress } else { "-" }
            }

            # Vendor/OUI lookup from MAC
            if ($mac -and $mac -ne "-" -and $mac.Length -ge 8) {
                $cleanMac = $mac -replace '[^A-Fa-f0-9]', ''
                if ($cleanMac.Length -ge 6) {
                    $oui = $cleanMac.Substring(0,6).ToUpper()
                    if ($ouiMap.ContainsKey($oui)) { $vendor = $ouiMap[$oui] }
                }
            }

            # WMI details (Windows only)
            $csinfo   = Try-GetWMI -class Win32_ComputerSystem -ip $ip
            $osinfo   = Try-GetWMI -class Win32_OperatingSystem -ip $ip
            $procinfo = Try-GetWMI -class Win32_Processor -ip $ip

            $Uptime = if ($osinfo -and $osinfo.LastBootUpTime) {
                $boot = [Management.ManagementDateTimeConverter]::ToDateTime($osinfo.LastBootUpTime)
                $span = (Get-Date) - $boot
                "{0}d {1}h {2}m" -f $span.Days, $span.Hours, $span.Minutes
            } else { "-" }

            # Storage
            $diskinfo   = Try-GetWMI -class Win32_DiskDrive -ip $ip
            $storageType = "-"
            $storageModel = "-"
            if ($diskinfo) {
                $mediaTypes = $diskinfo | Select-Object -ExpandProperty MediaType -Unique
                $storageModel = ($diskinfo | Select-Object -ExpandProperty Model -Unique) -join ", "
                foreach ($media in $mediaTypes) {
                    if ($media -match "solid state|ssd") { $storageType = "SSD"; break }
                    elseif ($media -match "fixed|hard disk") { $storageType = "HDD"; break }
                    elseif ($media) { $storageType = $media }
                }
                if ($storageType -eq "-" -or !$storageType) {
                    if ($storageModel -match "ssd") { $storageType = "SSD" }
                    elseif ($storageModel -match "hdd") { $storageType = "HDD" }
                }
            }

            # Category (Vendor+Port+OS logic)
            $category = "Other"
            try {
        $category = & {
            # --- Printer detection ---
            if ($printerHint -like "*Printer*" -or $openPorts -contains 9100 -or $vendor -match "HP|Canon|Epson|Brother|Lexmark|Xerox|Ricoh|Kyocera|OKI|Sharp|Toshiba|Samsung.*Printer") {
                "Printer"
            }
            # --- Windows Server ---
            elseif ($osName -like "*Windows Server*" -or $osHint -like "*Server*") {
                "Windows Server"
            }
            # --- Network Devices: Switch/Router/Firewall ---
            elseif ($vendor -match "Cisco|Juniper|Ubiquiti|Aruba|Netgear|Fortinet|MikroTik|TP-Link|D-Link|Zyxel|DrayTek|Huawei|Dell EMC|HPE|SonicWall|Palo Alto|Brocade|F5 Networks|Extreme Networks|Alcatel-Lucent|Allied Telesis|Edgecore|EnGenius|TRENDnet|Linksys|Cambium|Ruckus|Avaya|sophos") {
                "Network Device"
            }
            # --- IP Phones ---
            elseif ($vendor -match "Fanvil|Yealink|Grandstream|Polycom|Cisco|Avaya|Snom|Aastra|Siemens|Alcatel-Lucent|Mitel|Unify" -and $openPorts -contains 5060) {
                "VoIP Phone"
            }
            elseif ($openPorts -contains 5060) {
                "VoIP Phone"
            }
            # --- Cameras/Surveillance ---
            elseif ($vendor -match "Hikvision|Dahua|Uniview|Axis Communications|Hanwha Techwin|Bosch Security|Mobotix|Vivotek|FLIR|Avigilon|Pelco|Lorex|Reolink|Wyze" -or $openPorts -contains 554 -or $openPorts -contains 8554) {
                "IP Camera"
            }
            elseif ($openPorts -contains 554 -or $openPorts -contains 8554) {
                "RTSP Camera"
            }
            elseif ($openPorts -contains 10001) {
                "NVR/DVR"
            }
            # --- Storage/NAS ---
            elseif ($vendor -match "QNAP|Synology|Western Digital|NetApp|Seagate|Buffalo|Drobo|Thecus|Asustor|LaCie|TerraMaster|Promise Technology|EMC|Hitachi|Dell EMC|LenovoEMC") {
                "NAS Storage"
            }
            # --- Windows PC ---
            elseif ($openPorts -contains 445 -or $openPorts -contains 139) {
                if ($osName -like "*Windows Server*") { "Windows Server" } else { "Windows PC" }
            }
            elseif ($osHint -like "*Windows*" -and $osName -notlike "*Server*") {
                "Windows PC"
            }
            # --- Linux/Unix Devices/SBC ---
            elseif ($openPorts -contains 22 -and $osHint -match "Linux|Unix") {
                "Linux Device"
            }
            elseif ($vendor -match "Raspberry Pi|Odroid|BeagleBone|Hardkernel|PINE64|Banana Pi|Orange Pi|NanoPi|LattePanda") {
                "Linux SBC"
            }
            elseif ($openPorts -contains 22) {
                "Linux Device"
            }
            # --- Consumer Electronics/Smartphones/Smart TVs/Tablets ---
            elseif ($vendor -like "*Apple*" -or $vendor -match "iPhone|iPad|iPod") {
                "Smartphone/Tablet"
            }
            elseif ($vendor -like "*Samsung*" -and $openPorts.Count -gt 0) {
                "Smart TV/Android"
            }
            elseif ($vendor -match "LG Electronics|Sony|TCL|Hisense|Philips|Sharp|Panasonic|Vizio|Skyworth|Insignia|Element|JVC" -and $openPorts.Count -gt 0) {
                "Smart TV/Screen"
            }
            elseif ($vendor -like "*Google*" -and $openPorts -contains 3000) {
                "Chromecast"
            }
            elseif ($vendor -like "*Amazon*" -and $openPorts -contains 8080) {
                "Amazon Echo/Fire Device"
            }
            # --- IoT and Home Automation ---
            elseif ($openPorts -contains 1900) {
                "UPnP Device"
            }
            elseif ($openPorts -contains 5353) {
                "Bonjour Device"
            }
            elseif ($vendor -match "Espressif|Sonoff|Tuya|Shelly|Wyze|Tasmota|Espressif|Xiaomi|Aqara|TP-Link.*Kasa|TP-Link.*Tapo|Tuya|SmartThings|Home Assistant" -or $vendor -like "*SmartThings*") {
                "IoT Device"
            }
            # --- More Camera/Screen types ---
            elseif ($openPorts -contains 80 -and $openPorts -contains 443 -and $vendor -match "Hikvision|Dahua|Uniview|Axis") {
                "IP Camera"
            }
            elseif ($vendor -like "*Raspberry Pi*") {
                "IoT (Raspberry Pi)"
            }
            # --- Offline ---
            elseif ($openPorts.Count -eq 0) {
                "Offline Device"
            }
            # --- Fallback/Other ---
            else {
                "Other Device"
            }
        }
        } catch {}


            $deviceInfo = [PSCustomObject]@{
                Status             = "OK"
                Hostname           = $netbiosName
                IPAddress          = $ip
                MACAddress         = $mac
                Vendor             = $vendor
                Category           = $category
                NetBIOSName        = $netbiosName
                DeviceModel        = if ($csinfo -and $csinfo.Model) { $csinfo.Model } else { "-" }
                ProcessorModel     = if ($procinfo -and $procinfo.Name) { $procinfo.Name.Trim() } else { "-" }
                CPUSpeed           = if ($procinfo -and $procinfo.MaxClockSpeed) { "$($procinfo.MaxClockSpeed / 1000) GHz" } else { "-" }
                ProcessorCores     = if ($csinfo -and $csinfo.NumberOfProcessors) { $csinfo.NumberOfProcessors } else { "-" }
                ProcessorThreads   = if ($csinfo -and $csinfo.NumberOfLogicalProcessors) { $csinfo.NumberOfLogicalProcessors } else { "-" }
                TotalRAM_GB        = if ($csinfo -and $csinfo.TotalPhysicalMemory) { [math]::Round($csinfo.TotalPhysicalMemory/1GB,2) } else { "-" }
                StorageCapacity_GB = if ($diskinfo) { [math]::Round( ($diskinfo | Measure-Object -Property Size -Sum).Sum / 1GB, 1) } else { "-" }
                StorageType        = $storageType
                OSName             = if ($osinfo -and $osinfo.Caption) { $osinfo.Caption } else { "-" }
                OSVersion          = if ($osinfo -and $osinfo.Version) { $osinfo.Version } else { "-" }
                OSArchitecture     = if ($osinfo -and $osinfo.OSArchitecture) { $osinfo.OSArchitecture } else { "-" }
                OSInstallDate      = if ($osinfo -and $osinfo.InstallDate) { try { [Management.ManagementDateTimeConverter]::ToDateTime($osinfo.InstallDate).ToString("yyyy-MM-dd") } catch { "-" } } else { "-" }
                OSType             = $osHint
                Uptime             = $Uptime
                LoggedInUsers      = if ($csinfo -and $csinfo.UserName) { $csinfo.UserName } else { "-" }
            }
            $resultList += $deviceInfo
            $resultList | ConvertTo-Json -Depth 5 | Set-Content -Path $mem -Force
        }

        # Final save and log
        $resultList | ConvertTo-Json -Depth 5 | Set-Content -Path $mem -Force
        Add-Content -Path $log -Value "$((Get-Date).ToString('s')) - Scan job finished."
    } -ArgumentList $ips, $mem, $log, $ouiMap, $arpTable, $portsToScan

    # ----- UI Dispatcher Timer -----
    $timer = New-Object System.Windows.Threading.DispatcherTimer
    $timer.Interval = [TimeSpan]::FromMilliseconds(800)
    $timer.Add_Tick({
        if (Test-Path $global:MemoryFile) {
            try {
                $data = Get-Content $global:MemoryFile -Raw | ConvertFrom-Json
                $global:ScanCollection.Clear(); $data | ForEach-Object { $global:ScanCollection.Add($_) }
                Update-GridView
                $currentCount = $global:ScanCollection.Count
                $totalCount   = if ($global:TotalScanCount) { $global:TotalScanCount } else { "?" }
                $status.Text  = "🔎 Scanning... $currentCount of $totalCount devices"
            } catch { }
        }
        if ($global:scanJob.State -in @("Completed","Stopped","Failed")) {
            if ($global:ScanTimer -and $global:ScanTimer.IsEnabled) {
                $global:ScanTimer.Stop()
                $global:ScanTimer = $null
            }
            if (-not $global:ScanCompleted) {
                $global:ScanCompleted = $true
                if (Test-Path $global:MemoryFile) {
                    try {
                        $data = Get-Content $global:MemoryFile -Raw | ConvertFrom-Json
                        $global:ScanCollection.Clear(); $data | ForEach-Object { $global:ScanCollection.Add($_) }
                        Update-GridView
                        $status.Text = "✅ Scan complete. Devices: $($global:ScanCollection.Count)"
                        Write-Log "✔ Scan complete. Found $($global:ScanCollection.Count) devices." "SUCCESS"
                        Save-Scan
                    } catch { }
                }
                $btnScan.IsEnabled = $true
                $btnStop.IsEnabled = $false
            }
        }
    })
    $timer.Start()
    $global:ScanTimer = $timer
}

function Stop-Scan {
    try {
        if ($global:ScanTimer -and $global:ScanTimer.IsEnabled) {
            $global:ScanTimer.Stop()
        }
        if ($global:scanJob) {
            if ($global:scanJob.State -eq "Running" -or $global:scanJob.State -eq "NotStarted") {
                Stop-Job -Job $global:scanJob -ErrorAction SilentlyContinue
                Write-Log "Scan manually stopped." "WARNING"
                $status.Text = 'Scan manually stopped.'
            }
            Remove-Job -Job $global:scanJob -ErrorAction SilentlyContinue
            $global:scanJob = $null
        }
    } catch {
        Write-Log "Error while stopping scan: $_" "ERROR"
    }
    $btnScan.IsEnabled = $true
    $btnStop.IsEnabled = $false
}
#endregion

#region [4]--- WPF UI Setup & Event Handlers ---

<#
.SYNOPSIS
    User interface (UI) setup for Simple Network Inventory Tool.
.DESCRIPTION
    - Defines modern WPF XAML layout (sidebar, grid, status bar).
    - Initializes all UI controls and binds event handlers.
    - Handles user actions: scan, stop, export, load, grid clearing.
    - Maintains live data binding for device grid and status updates.
    - Ensures graceful resource cleanup on window close.
#>

# 1. Define XAML layout as string
$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Simple Network Inventory"
        Height="650" Width="1100"
        WindowStartupLocation="CenterScreen"
        FontFamily="Segoe UI">
  <Border Background="#F5F7FA" CornerRadius="12" BorderBrush="#E1E4EA" BorderThickness="1">
    <Grid>
      <Grid.ColumnDefinitions>
        <ColumnDefinition Width="200"/>
        <ColumnDefinition Width="*"/>
      </Grid.ColumnDefinitions>
      <!-- Sidebar -->
      <StackPanel Background="#102E50" Grid.Column="0" Margin="0,0,0,0">
        <TextBlock Text="Simple" FontWeight="Bold" FontSize="20" Foreground="#FF7601" Margin="24,30,0,0"/>
        <TextBlock Text="Network Inventory" FontWeight="Normal" FontSize="17" Foreground="#4DA8DA" Margin="24,-4,0,18"/>
        <Separator Height="2" Background="#2E3743" Margin="0,4,0,10"/>
        <!-- Scan and Stop buttons -->
        <Button x:Name="btnScan" Content="Scan Network"
                Margin="20,8,20,0" Padding="8"
                Background="#2979FF" Foreground="White" FontWeight="SemiBold"
                BorderThickness="0" FontSize="15" Cursor="Hand"/>
        <Button x:Name="btnStop" Content="Stop Scan"
                Margin="20,8,20,0" Padding="8"
                Background="#FF5252" Foreground="White"
                FontWeight="SemiBold" FontSize="15" BorderThickness="0" Cursor="Hand" IsEnabled="False"/>
        <!-- Secondary buttons -->
        <Button x:Name="btnLoad" Content="Load Previou Scan"
                Margin="20,14,20,0" Padding="8"
                Background="#129990" Foreground="White"
                BorderThickness="0" FontSize="14" Cursor="Hand"/>
        <Button x:Name="btnCSV" Content="Export CSV"
                Margin="20,8,20,0" Padding="8"
                Background="#43A047" Foreground="White"
                BorderThickness="0" FontSize="14" Cursor="Hand"/>
        <Button x:Name="btnClear" Content="Clear Grid"
                Margin="20,8,20,0" Padding="8"
                Background="#607D8B" Foreground="White"
                BorderThickness="0" FontSize="14" Cursor="Hand"/>
        <StackPanel Height="auto" VerticalAlignment="Bottom" Margin="0,200,0,30">
            <TextBlock Text="© 2025 M.omar (momar.tech)" HorizontalAlignment="Center" Foreground="#A4CCD9" FontSize="10" Margin="5"/>
            <TextBlock Text="All Rights Reserved" HorizontalAlignment="Center" Foreground="#A4CCD9" FontSize="10" Margin="0"/>
            <TextBlock Text="v1.0" HorizontalAlignment="Center" Foreground="#A4CCD9" FontSize="10" Margin="5"/>
        </StackPanel>
      </StackPanel>
      <!-- Main Panel -->
      <Grid Grid.Column="1" Margin="0">
        <Grid.RowDefinitions>
          <RowDefinition Height="Auto"/>
          <RowDefinition Height="*"/>
          <RowDefinition Height="32"/>
        </Grid.RowDefinitions>
        <!-- Top Filter Bar (Fixed!) -->
        <Border Grid.Row="0" Background="#FAFAFB" Padding="12,10,12,8">
          <StackPanel Orientation="Horizontal">
            <CheckBox x:Name="chkAutoDetect" Content="Auto-Detect Subnet"
                      IsChecked="True" Margin="0,0,18,0" Foreground="#333"
                      FontWeight="SemiBold"/>
            <TextBox x:Name="txtRange" Width="200" Height="28"
                     VerticalAlignment="Center" Padding="6,0"
                     ToolTip="CIDR, dash, or range"
                     Margin="0,0,18,0"
                     FontSize="14"
                     Background="#FFFFFF" Foreground="#111"
                     BorderBrush="#D7D9DE" BorderThickness="1"/>
            <CheckBox x:Name="chkHideUnreachable" Content="Hide Unreachable IP's"
                      IsChecked="True" Margin="0,0,18,0" Foreground="#333"
                      FontWeight="SemiBold"/>
          </StackPanel>
        </Border>
        <!-- DataGrid modern table -->
        <DataGrid x:Name="grid" Grid.Row="1"
                  ItemsSource="{Binding}"
                  AutoGenerateColumns="True"
                  IsReadOnly="True"
                  AlternatingRowBackground="#F2F5FB"
                  RowBackground="#FFFFFF"
                  Margin="12,0,12,0"
                  HeadersVisibility="All"
                  FontSize="13"
                  FontWeight="Normal"
                  RowHeaderWidth="0"
                  CanUserResizeRows="False"
                  Background="#FFFFFF"
                  Foreground="#222"
                  BorderThickness="0"
                  SelectionMode="Extended"
                  SelectionUnit="FullRow"
                  RowHeight="25"
                  HorizontalGridLinesBrush="#E0E0E0"
                  VerticalGridLinesBrush="#E0E0E0">
          <DataGrid.ColumnHeaderStyle>
            <Style TargetType="DataGridColumnHeader">
              <Setter Property="Background" Value="#EDF0F6"/>
              <Setter Property="Foreground" Value="#222"/>
              <Setter Property="FontWeight" Value="SemiBold"/>
              <Setter Property="FontSize" Value="13"/>
              <Setter Property="BorderThickness" Value="0,0,1,1"/>
              <Setter Property="BorderBrush" Value="#E1E4EA"/>
              <Setter Property="HorizontalContentAlignment" Value="Center"/>
              <Setter Property="Height" Value="28"/>
              <Setter Property="Padding" Value="16,2"/>
              <Setter Property="SnapsToDevicePixels" Value="True"/>
            </Style>
          </DataGrid.ColumnHeaderStyle>
          <DataGrid.CellStyle>
            <Style TargetType="DataGridCell">
              <Setter Property="Foreground" Value="#212A36"/>
              <Setter Property="FontSize" Value="13"/>
              <Setter Property="BorderThickness" Value="0"/>
              <Setter Property="Padding" Value="8,2"/>
              <Setter Property="Background" Value="Transparent"/>
              <Setter Property="HorizontalContentAlignment" Value="Center"/>
              <Setter Property="VerticalContentAlignment" Value="Center"/>
            </Style>
          </DataGrid.CellStyle>
        </DataGrid>
        <!-- Modern Status Bar -->
        <Border Grid.Row="2" Background="#EDF0F6" Height="32" VerticalAlignment="Bottom">
          <TextBlock x:Name="status"
                     VerticalAlignment="Center"
                     FontSize="13"
                     Foreground="#0078D4"
                     Margin="15,0,0,0"
                     Text="Ready."/>
        </Border>
      </Grid>
    </Grid>
  </Border>
</Window>
"@

# 2. Parse XAML and find controls
$reader = [System.Xml.XmlReader]::Create([System.IO.StringReader]$xaml)
$window = [Windows.Markup.XamlReader]::Load($reader)

$btnScan   = $window.FindName("btnScan")
$btnStop   = $window.FindName("btnStop")
$btnCSV    = $window.FindName("btnCSV")
$btnLoad   = $window.FindName("btnLoad")
$btnClear  = $window.FindName("btnClear")
$txtRange  = $window.FindName("txtRange")
$grid      = $window.FindName("grid")
$status    = $window.FindName("status")
$chkAutoDetect      = $window.FindName("chkAutoDetect")
$chkHideUnreachable = $window.FindName("chkHideUnreachable")

# 3. Bind DataGrid to global scan view collection
$grid.ItemsSource = $global:ScanView

# 4. Control UI behavior (enable/disable/auto-populate)
$chkAutoDetect.Add_Checked({ $txtRange.IsEnabled = $false; $txtRange.Text = Get-LocalCIDR })
$chkAutoDetect.Add_Unchecked({ $txtRange.IsEnabled = $true; $txtRange.Text = "" })
if ($chkAutoDetect.IsChecked) { $txtRange.IsEnabled = $false; $txtRange.Text = Get-LocalCIDR }
else { $txtRange.IsEnabled = $true }

$chkHideUnreachable.Add_Checked({ Update-GridView })
$chkHideUnreachable.Add_Unchecked({ Update-GridView })

# 5. Attach button event handlers
$btnScan.Add_Click({ Start-Scan })
$btnStop.Add_Click({ Stop-Scan })
$btnCSV.Add_Click({ Export-Data 'CSV' })
$btnLoad.Add_Click({ Load-LastScan })
$btnClear.Add_Click({ Clear-Grid })

# 6. Load previous scan at startup
Load-LastScan

# 7. Window cleanup on close
$window.Add_Closing({
    try {
        if ($global:ScanTimer -and $global:ScanTimer.IsEnabled) {
            $global:ScanTimer.Stop()
        }
        if ($global:scanJob) {
            if ($global:scanJob.State -eq "Running" -or $global:scanJob.State -eq "NotStarted") {
                Stop-Job -Job $global:scanJob -ErrorAction SilentlyContinue
            }
            Remove-Job -Job $global:scanJob -ErrorAction SilentlyContinue
            $global:scanJob = $null
        }
    } catch {}
})

# 8. Show WPF window
$window.ShowDialog() | Out-Null

#endregion
