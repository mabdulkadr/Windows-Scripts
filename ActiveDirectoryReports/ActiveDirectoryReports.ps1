<#
.SYNOPSIS
    Responsive Active Directory Reports Script with Enhanced Console Menu & Modern HTML Output

.DESCRIPTION
    Combines six essential AD reporting scripts into one menu-driven tool. 
    Each report outputs a modern, responsive HTML file, ready for browser viewing.
    Features:
      - Centralized CSS for consistent, professional look
      - Responsive, mobile-friendly table design
      - Timestamped reports saved to C:\ADReports
      - Console menu for easy use (works in PowerShell ISE and classic console)
      - Error handling and user prompts

.NOTES
    Author: Combined and Enhanced by ChatGPT (2025-06-16)
    Original scripts by: Mohammed Omar

.REQUIREMENTS
    - Run as Administrator
    - ActiveDirectory PowerShell module (part of RSAT)
#>

# ========== GLOBAL SETTINGS ==========

# Output directory for all reports
$ReportPath = "C:\ADReports"

# Timestamp for filenames
$NowString = Get-Date -Format "yyyy-MM-dd_HH-mm"

# Modern, responsive CSS for all HTML reports
$CSS = @"
<style>
body { font-family: 'Segoe UI', Arial, sans-serif; margin: 0; background: #eef2f6; color: #333; }
.header {
    background: #073261;
    color: #fff;
    padding: 32px 16px 16px 16px;
    text-align: center;
    border-radius: 10px;
    box-shadow: 0 4px 16px #07326144;
    margin: 20px 0;
}
.header h1 { margin: 0 0 8px 0; font-size: 2.1rem; letter-spacing: 1px; }
.header p { margin: 0; color: #d4e3fa; font-size: 1rem;}
/* Optional: add your logo here */
.header img { height: 48px; margin-bottom: 10px; }
.report-section {
    max-width: 98vw;
    margin: 0 auto 40px auto;
    background: #fff;
    box-shadow: 0 2px 12px #0001;
    border-radius: 10px;
    padding: 28px 24px 20px 24px;
    border: 1px solid #d4dbe8;
}
h2, h3 { color: #073261; }
.table-wrap { overflow-x: auto; }
table {
    width: 100%;
    border-collapse: collapse;
    margin-top: 18px;
    background: #fafbff;
    font-size: 1rem;
    min-width: 920px;
}
th, td {
    border: 1px solid #e6eaf1;
    padding: 10px 8px;
    text-align: left;
}
th {
    background: #153a61;
    color: #fff;
    text-transform: uppercase;
    position: sticky;
    top: 0;
    z-index: 1;
}
tr:nth-child(even) { background: #f5f8fc; }
tr:hover { background: #d4e3fa55; }
@media (max-width: 900px) {
    .report-section { padding: 8px 2px; }
    table, th, td { font-size: 0.93rem; }
    .header h1 { font-size: 1.15rem; }
}
</style>
"@

# Ensure Active Directory module is loaded, and output folder exists
try {
    Import-Module ActiveDirectory -ErrorAction Stop
} catch {
    Write-Host "ActiveDirectory module is required. Please install RSAT and try again." -ForegroundColor Red
    exit
}
If (-not (Test-Path $ReportPath)) { New-Item -Path $ReportPath -ItemType Directory | Out-Null }

# ========== UTILITY FUNCTIONS ==========

<#
.SYNOPSIS
    Writes a fancy, colored menu header.
#>
function Write-Header($text) {
    Write-Host ""
    Write-Host ("=" * 65) -ForegroundColor Cyan
    Write-Host (" " + $text) -ForegroundColor Yellow
    Write-Host ("=" * 65) -ForegroundColor Cyan
    Write-Host ""
}

<#
.SYNOPSIS
    Builds the HTML report with consistent styling, header, and responsive section.
.DESCRIPTION
    Accepts a title, the HTML fragment (table), and a precontent block (section title).
#>
function Build-HtmlReport($title, $fragment, $precontent) {
    return @"
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <title>$title</title>
    $CSS
</head>
<body>
    <div class="header">
        <!-- <img src='logo.png' alt='Logo' /> Uncomment and set your logo path -->
        <h1>$title</h1>
        <p>Generated on $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')</p>
    </div>
    <div class="report-section">
        $precontent
        <div class='table-wrap'>
            $fragment
        </div>
    </div>
</body>
</html>
"@
}

<#
.SYNOPSIS
    Prompts user to open the generated report in their browser (ISE-friendly).
#>
function Prompt-OpenReport($path) {
    Write-Host ""
    $resp = Read-Host "Type 'O' and press ENTER to open the last report, or just press ENTER to return"
    if ($resp -eq 'O' -or $resp -eq 'o') { Start-Process $path }
}

<#
.SYNOPSIS
    Simple "press any key" pause that works in all PowerShell hosts.
#>
function Wait-AnyKey {
    Read-Host "Press ENTER to continue"
}

# ========== REPORT FUNCTIONS ==========

<#
.SYNOPSIS
    Generates a complete report of all AD computer objects.
#>
function Show-CompleteComputerObjectReport {
    Write-Header "Complete Computer Object Report"
    $ReportFile = "$ReportPath\AD_CompleteComputerReport_$NowString.html"
    try {
        $Computers = Get-ADComputer -Filter * -Properties * | Sort-Object Name
        $ComputerData = $Computers | Select-Object Name, DNSHostName, IPv4Address, OperatingSystem, OperatingSystemServicePack, OperatingSystemVersion, LastLogonDate, Enabled, Description, @{Name='OU';Expression={$_.DistinguishedName -replace '^CN=.*?,(OU=.*?|DC=.*?)$','$1'}}
        $frag = $ComputerData | ConvertTo-Html -Fragment
        $html = Build-HtmlReport "Complete AD Computer Report" $frag "<h2>All Computer Objects</h2>"
        $html | Out-File $ReportFile -Encoding UTF8
        Write-Host "Complete Computer Report generated: $ReportFile" -ForegroundColor Green
        Prompt-OpenReport $ReportFile
    } catch {
        Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    }
}

<#
.SYNOPSIS
    Generates a report for all Domain Controllers.
#>
function Show-DomainControllersReport {
    Write-Header "Domain Controllers Report"
    $ReportFile = "$ReportPath\AD_DomainControllersReport_$NowString.html"
    try {
        $DCs = Get-ADDomainController -Filter * | Select-Object Name, HostName, IPv4Address, Site, OperatingSystem, OperatingSystemServicePack, OperatingSystemVersion, IsGlobalCatalog, IsReadOnlyDC, Enabled | Sort-Object Name
        $frag = $DCs | ConvertTo-Html -Fragment
        $html = Build-HtmlReport "AD Domain Controllers Report" $frag "<h2>Domain Controllers</h2>"
        $html | Out-File $ReportFile -Encoding UTF8
        Write-Host "Domain Controllers Report generated: $ReportFile" -ForegroundColor Green
        Prompt-OpenReport $ReportFile
    } catch {
        Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    }
}

<#
.SYNOPSIS
    Generates a report for all workstations (non-servers).
#>
function Show-WorkstationsReport {
    Write-Header "Workstations Report"
    $ReportFile = "$ReportPath\AD_WorkstationsReport_$NowString.html"
    try {
        $Workstations = Get-ADComputer -Filter {OperatingSystem -NotLike "*Server*"} -Properties * | Sort-Object Name
        $WorkstationData = $Workstations | Select-Object Name, DNSHostName, IPv4Address, OperatingSystem, OperatingSystemServicePack, OperatingSystemVersion, LastLogonDate, Enabled, Description, @{Name='OU';Expression={$_.DistinguishedName -replace '^CN=.*?,(OU=.*?|DC=.*?)$','$1'}}
        $frag = $WorkstationData | ConvertTo-Html -Fragment
        $html = Build-HtmlReport "AD Workstations Report" $frag "<h2>Workstations</h2>"
        $html | Out-File $ReportFile -Encoding UTF8
        Write-Host "Workstations Report generated: $ReportFile" -ForegroundColor Green
        Prompt-OpenReport $ReportFile
    } catch {
        Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    }
}

<#
.SYNOPSIS
    Generates a report for all Windows Server computers.
#>
function Show-ServersReport {
    Write-Header "Servers Report"
    $ReportFile = "$ReportPath\AD_ServersReport_$NowString.html"
    try {
        $Servers = Get-ADComputer -Filter {OperatingSystem -Like "*Server*"} -Properties * | Sort-Object Name
        $ServerData = $Servers | Select-Object Name, DNSHostName, IPv4Address, OperatingSystem, OperatingSystemServicePack, OperatingSystemVersion, LastLogonDate, Enabled, Description, @{Name='OU';Expression={$_.DistinguishedName -replace '^CN=.*?,(OU=.*?|DC=.*?)$','$1'}}
        $frag = $ServerData | ConvertTo-Html -Fragment
        $html = Build-HtmlReport "AD Servers Report" $frag "<h2>Servers</h2>"
        $html | Out-File $ReportFile -Encoding UTF8
        Write-Host "Servers Report generated: $ReportFile" -ForegroundColor Green
        Prompt-OpenReport $ReportFile
    } catch {
        Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    }
}

<#
.SYNOPSIS
    Generates a report showing the enabled/disabled status of computer accounts.
#>
function Show-ComputerAccountStatusReport {
    Write-Header "Computer Account Status Report"
    $ReportFile = "$ReportPath\AD_ComputerAccountStatusReport_$NowString.html"
    try {
        $Computers = Get-ADComputer -Filter * -Properties Name, Enabled, LastLogonDate, DNSHostName | Sort-Object Name
        $AccountStatusData = $Computers | Select-Object Name, DNSHostName, Enabled, LastLogonDate, @{Name='AccountStatus'; Expression={if ($_.Enabled) {'Enabled'} else {'Disabled'}}}
        $frag = $AccountStatusData | ConvertTo-Html -Fragment
        $html = Build-HtmlReport "AD Computer Account Status Report" $frag "<h2>Computer Account Status</h2>"
        $html | Out-File $ReportFile -Encoding UTF8
        Write-Host "Computer Account Status Report generated: $ReportFile" -ForegroundColor Green
        Prompt-OpenReport $ReportFile
    } catch {
        Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    }
}

<#
.SYNOPSIS
    Generates a report grouping computers by Operating System.
#>
function Show-OSBasedReports {
    Write-Header "OS-Based Computer Report"
    $ReportFile = "$ReportPath\AD_OSBasedReport_$NowString.html"
    try {
        $Computers = Get-ADComputer -Filter * -Properties Name, OperatingSystem, OperatingSystemServicePack, OperatingSystemVersion, LastLogonDate, DNSHostName, Enabled, Description | Sort-Object OperatingSystem, Name
        $OSGroups = $Computers | Group-Object OperatingSystem | Sort-Object Name

        $OSBasedHTML = ""
        foreach ($OSGroup in $OSGroups) {
            $OSName = $OSGroup.Name
            $OSCount = $OSGroup.Count
            $OSBasedHTML += "<h3>$OSName ($OSCount computers)</h3>"
            $OSGroup.Group | Select-Object Name, DNSHostName, OperatingSystem, OperatingSystemServicePack, OperatingSystemVersion, LastLogonDate, Enabled, Description | ConvertTo-Html -Fragment | Out-String | ForEach-Object { $OSBasedHTML += $_ }
        }
        $html = Build-HtmlReport "AD OS-Based Computer Report" $OSBasedHTML "<h2>Computers by Operating System</h2>"
        $html | Out-File $ReportFile -Encoding UTF8
        Write-Host "OS-Based Computer Report generated: $ReportFile" -ForegroundColor Green
        Prompt-OpenReport $ReportFile
    } catch {
        Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    }
}

<#
.SYNOPSIS
    Runs all report functions in sequence.
#>
function Run-AllReports {
    Write-Header "Running ALL REPORTS"
    Show-CompleteComputerObjectReport
    Show-DomainControllersReport
    Show-WorkstationsReport
    Show-ServersReport
    Show-ComputerAccountStatusReport
    Show-OSBasedReports
    Write-Host "`nAll reports have been generated." -ForegroundColor Green
}

# ========== MAIN MENU ==========

<#
.SYNOPSIS
    Displays the main menu and handles user input.
#>
function Show-Menu {
    Write-Host ""
    Write-Host ("=" * 65) -ForegroundColor Cyan
    Write-Host "                  Active Directory Reports                 " -ForegroundColor Yellow
    Write-Host ("=" * 65) -ForegroundColor Cyan
    Write-Host ""
    Write-Host " 1. Complete Computer Object Report"
    Write-Host " 2. Domain Controllers Report"
    Write-Host " 3. Workstations Report"
    Write-Host " 4. Servers Report"
    Write-Host " 5. Computer Account Status Report"
    Write-Host " 6. OS Based Reports"
    Write-Host " 7. Run ALL Reports"
    Write-Host " 0. Exit"
    Write-Host ""
}

# ========== MAIN EXECUTION LOOP ==========

do {
    Show-Menu
    $choice = Read-Host "Enter your choice (0-7)"
    switch ($choice) {
        '1' { Show-CompleteComputerObjectReport }
        '2' { Show-DomainControllersReport }
        '3' { Show-WorkstationsReport }
        '4' { Show-ServersReport }
        '5' { Show-ComputerAccountStatusReport }
        '6' { Show-OSBasedReports }
        '7' { Run-AllReports }
        '0' { Write-Host "Exiting. Goodbye!" -ForegroundColor Cyan }
        default { Write-Host "Invalid choice. Please enter a number from 0 to 7." -ForegroundColor Red }
    }
    if ($choice -ne '0') {
        Write-Host ""
        Write-Host "Press ENTER to return to the menu..." -ForegroundColor DarkGray
        Wait-AnyKey
    }
} while ($choice -ne '0')
