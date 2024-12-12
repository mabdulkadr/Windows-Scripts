<#
.SYNOPSIS
    Enhanced PowerShell CLI Script for Remote Script Execution with Stylized Banners and Menus

.DESCRIPTION
    Provides a user-friendly and visually appealing command-line interface to execute scripts or commands on remote computers.
    Users are guided through a sequential process: selecting PCs, selecting scripts/commands, executing,
    and exporting reports. Execution results are displayed with progress indicators and detailed logging.
    Incorporates file browsing, detailed reporting, input validation, confirmation prompts, script parameterization,
    stylized banners, and enhanced menu designs for an improved user experience.

.AUTHOR
    Author  : Mohammad Abdulkader Omar
    Website : momar.tech
    Date    : 2024-12-12

.NOTES
    - Ensure the user account has administrative permissions on remote machines.
    - WinRM must be properly configured on all target machines via GPO.
    - Date: 2024-12-12
    - Version: 1.0
#>

# ============================ #
#        Global Variables      #
# ============================ #

$global:PCList = @()                   # Array to store target PC names/IPs
$global:ScriptPath = ""                # Path to the PowerShell script to execute
$global:ScriptParameters = ""          # Parameters for the selected script
$global:CustomCommand = ""             # Custom PowerShell command entered by the user
$global:LogPath = "RemoteScriptExecutorCLI_Log_$(Get-Date -Format 'yyyyMMdd_HHmmss').txt" # Log file path
$global:HtmlReportPath = "ExecutionReport_$(Get-Date -Format 'yyyyMMdd_HHmmss').html"            # HTML report path
$global:CsvReportPath = "ExecutionResults_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv"             # CSV report path
$global:LogLevel = "INFO"               # Default logging level
$global:CancellationRequested = $false # Flag to handle execution cancellation
$global:ExecutionResults = @()          # Array to store execution results

# ============================ #
#      Load Necessary Assemblies#
# ============================ #

# Load Windows Forms assembly for file browsing dialogs
Add-Type -AssemblyName System.Windows.Forms

# ============================ #
#          Functions            #
# ============================ #

# Function: Show-Banner
# Purpose: Displays a stylized banner with branding and contact information.
function Show-Banner {
    $banner = @"
╔══════════════════════════════════════════════════════════════════╗
║                                                                  ║
║                     REMOTE SCRIPT EXECUTOR                       ║
║                                                                  ║
║                    Empowering IT Automation                      ║
║                                                                  ║
╠══════════════════════════════════════════════════════════════════╣
║                                                                  ║
║ 💡 Simplify IT Management and Automation                         ║
║ 🌐 Website:    momar.tech                                        ║
║ 🔗 LinkedIn:   linkedin.com/in/mabdulkadr/                       ║
║ 📧 Email:      m.abdulkadr@gmail.com                             ║
║                                                                  ║
╚══════════════════════════════════════════════════════════════════╝

"@
    $title = @"
╔══════════════════════════════════════════════════════════════════╗
║                                                                  ║
║               REMOTE SCRIPT EXECUTOR - MAIN MENU                 ║
║                                                                  ║
╚══════════════════════════════════════════════════════════════════╝

"@
    Write-Host $banner -ForegroundColor Magenta
    Write-Host $title -ForegroundColor Cyan
    Write-Host "    Version: 3.3 | Last Updated: 2024-11-06" -ForegroundColor Gray
    Write-Host "    Powered by PowerShell and Microsoft Graph API`n" -ForegroundColor Gray
}

# Function: Show-MainMenu
# Purpose: Displays the main interactive menu with stylized options.
function Show-MainMenu {
    Write-Host "    ╔══════════════════════════════════════╗" -ForegroundColor Green
    Write-Host "    ║           AVAILABLE OPTIONS          ║" -ForegroundColor Green
    Write-Host "    ╠══════════════════════════════════════╣" -ForegroundColor Green
    Write-Host "    ║                                      ║" -ForegroundColor Green
    Write-Host "    ║    1. Step 1: Select PCs             ║" -ForegroundColor Cyan
    Write-Host "    ║    2. Step 2: Select Script/Command  ║" -ForegroundColor Cyan
    Write-Host "    ║    3. Step 3: Execute Scripts        ║" -ForegroundColor Cyan
    Write-Host "    ║    4. Step 4: Export Results         ║" -ForegroundColor Cyan
    Write-Host "    ║    5. Step 5: Exit                   ║" -ForegroundColor Red
    Write-Host "    ║                                      ║" -ForegroundColor Green
    Write-Host "    ╚══════════════════════════════════════╝" -ForegroundColor Green
    Write-Host "`n    Select an option (1-5): " -ForegroundColor Yellow -NoNewline
}

# Function: Log-Message
# Purpose: Logs messages with timestamps to the specified log file.
function Log-Message {
    param (
        [Parameter(Mandatory = $true)]
        [string]$Level,      # INFO, WARNING, ERROR, DEBUG

        [Parameter(Mandatory = $true)]
        [string]$Message
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logEntry = "${timestamp} [$Level] - ${Message}"

    # Define log level hierarchy
    $levels = @{ "DEBUG" = 1; "INFO" = 2; "WARNING" = 3; "ERROR" = 4 }

    if ($levels[$Level] -ge $levels[$global:LogLevel]) {
        # Write to log file
        $logEntry | Out-File -FilePath $global:LogPath -Append -Encoding UTF8

        # Optionally, send logs to centralized systems or email (not implemented here)
    }
}

# Function: Browse-File
# Purpose: Opens a file browsing dialog for the user to select a file.
function Browse-File {
    param (
        [string]$Filter = "All Files (*.*)|*.*", # File type filter
        [string]$Title = "Select a File"          # Dialog title
    )

    # Initialize OpenFileDialog
    $openFileDialog = New-Object System.Windows.Forms.OpenFileDialog
    $openFileDialog.Filter = $Filter
    $openFileDialog.Title = $Title
    $openFileDialog.InitialDirectory = [Environment]::GetFolderPath("Desktop") # Start at Desktop

    # Show dialog and capture result
    $dialogResult = $openFileDialog.ShowDialog()

    # Return selected file path or $null if canceled
    if ($dialogResult -eq [System.Windows.Forms.DialogResult]::OK) {
        return $openFileDialog.FileName
    }
    else {
        return $null
    }
}

# Function: Import-PCList
# Purpose: Imports PC names/IPs from a user-selected CSV file.
function Import-PCList {
    Write-Host "🔍 Browsing for CSV file containing PC Names/IPs..." -ForegroundColor Cyan
    $csvPath = Browse-File -Filter "CSV Files (*.csv)|*.csv" -Title "Select CSV File with Device Names or IPs"

    if ($csvPath) {
        if (Test-Path -Path $csvPath) {
            try {
                # Import CSV and extract PC names/IPs
                $importedList = Import-Csv -Path $csvPath -Header @("Device")
                $pcs = $importedList.Device | Where-Object { $_ -ne "" } | ForEach-Object { $_.Trim() }

                # Validate PCs
                $invalidPCs = @()
                foreach ($pc in $pcs) {
                    if (-not (Validate-Device -Device $pc)) {
                        $invalidPCs += $pc
                    }
                }

                if ($invalidPCs.Count -gt 0) {
                    Write-Host "⚠️ The following PC names/IPs are invalid and will be skipped:" -ForegroundColor Yellow
                    $invalidPCs | ForEach-Object { Write-Host $_ -ForegroundColor Yellow }
                    Log-Message -Level "WARNING" -Message "Invalid PC entries from CSV: $($invalidPCs -join ', ')"
                }

                # Add only valid PCs to the global list
                $validPCs = $pcs | Where-Object { (Validate-Device -Device $_) }
                $global:PCList += $validPCs

                Write-Host "✅ Successfully imported $($validPCs.Count) valid devices from CSV." -ForegroundColor Green
                Log-Message -Level "INFO" -Message "Imported $($validPCs.Count) valid devices from CSV: $csvPath"
            }
            catch {
                Write-Host "❌ Error importing CSV: $_" -ForegroundColor Red
                Log-Message -Level "ERROR" -Message "Error importing CSV ($csvPath): $_"
            }
        }
        else {
            Write-Host "❌ File not found: $csvPath" -ForegroundColor Red
            Log-Message -Level "ERROR" -Message "Failed to import CSV. File not found: $csvPath"
        }
    }
    else {
        Write-Host "⚠️ CSV import canceled." -ForegroundColor Yellow
        Log-Message -Level "WARNING" -Message "CSV import canceled by user."
    }

    Pause # Wait for user to acknowledge
}

# Function: Enter-PCNamesManually
# Purpose: Allows the user to manually enter PC names/IPs separated by commas.
function Enter-PCNamesManually {
    Write-Host "✏️ Enter PC Names or IP Addresses separated by commas (e.g., PC1, PC2, 192.168.1.10):" -ForegroundColor Cyan
    $input = Read-Host "PC Names/IPs"

    if (![string]::IsNullOrWhiteSpace($input)) {
        # Split input by commas, trim whitespace, and remove empty entries
        $pcs = $input -split "," | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne "" }

        # Validate PCs
        $invalidPCs = @()
        foreach ($pc in $pcs) {
            if (-not (Validate-Device -Device $pc)) {
                $invalidPCs += $pc
            }
        }

        if ($invalidPCs.Count -gt 0) {
            Write-Host "⚠️ The following PC names/IPs are invalid and will be skipped:" -ForegroundColor Yellow
            $invalidPCs | ForEach-Object { Write-Host $_ -ForegroundColor Yellow }
            Log-Message -Level "WARNING" -Message "Invalid PC entries entered manually: $($invalidPCs -join ', ')"
        }

        # Add only valid PCs to the global list
        $validPCs = $pcs | Where-Object { (Validate-Device -Device $_) }
        $global:PCList += $validPCs

        Write-Host "✅ Successfully added $($validPCs.Count) valid devices." -ForegroundColor Green
        Log-Message -Level "INFO" -Message "Manually entered $($validPCs.Count) valid devices: $($validPCs -join ', ')"
    }
    else {
        Write-Host "⚠️ No input detected." -ForegroundColor Yellow
        Log-Message -Level "WARNING" -Message "No PC names/IPs entered manually."
    }

    Pause # Wait for user to acknowledge
}

# Function: Select-Script
# Purpose: Allows the user to browse and select a PowerShell script (.ps1) to execute remotely.
function Select-Script {
    Write-Host "🔍 Browsing for PowerShell script to execute..." -ForegroundColor Cyan
    $scriptPath = Browse-File -Filter "PowerShell Scripts (*.ps1)|*.ps1" -Title "Select PowerShell Script to Execute"

    if ($scriptPath) {
        if (Test-Path -Path $scriptPath) {
            $global:ScriptPath = $scriptPath
            Write-Host "✅ Script selected: $scriptPath" -ForegroundColor Green
            Log-Message -Level "INFO" -Message "Selected script: $scriptPath"

            # Prompt for script parameters
            Write-Host "🔧 Enter any parameters for the script (separated by spaces), or leave blank:" -ForegroundColor Cyan
            $scriptParams = Read-Host "Script Parameters"
            $global:ScriptParameters = $scriptParams
            Log-Message -Level "INFO" -Message "Entered script parameters: $scriptParams"
        }
        else {
            Write-Host "❌ File not found: $scriptPath" -ForegroundColor Red
            Log-Message -Level "ERROR" -Message "Failed to select script. File not found: $scriptPath"
        }
    }
    else {
        Write-Host "⚠️ Script selection canceled." -ForegroundColor Yellow
        Log-Message -Level "WARNING" -Message "Script selection canceled by user."
    }

    Pause # Wait for user to acknowledge
}

# Function: Enter-CustomCommand
# Purpose: Allows the user to enter a custom PowerShell command or multiple commands separated by semicolons.
function Enter-CustomCommand {
    Write-Host "📝 Enter your custom PowerShell command(s)." -ForegroundColor Cyan
    Write-Host "To execute multiple commands, separate them with semicolons (;)." -ForegroundColor DarkGray
    Write-Host "Example: Get-Service; Get-Process" -ForegroundColor DarkGray
    $command = Read-Host "Custom Command"

    if (![string]::IsNullOrWhiteSpace($command)) {
        $global:CustomCommand = $command
        Write-Host "✅ Custom command set successfully." -ForegroundColor Green
        Log-Message -Level "INFO" -Message "Entered custom command: $command"
    }
    else {
        Write-Host "⚠️ No command entered." -ForegroundColor Yellow
        Log-Message -Level "WARNING" -Message "No custom command entered."
    }

    Pause # Wait for user to acknowledge
}

# Function: Execute-Scripts
# Purpose: Executes the selected script and/or custom command on all specified PCs sequentially.
function Execute-Scripts {
    # Confirm before proceeding
    if (-not (Confirm-Action -Message "Are you sure you want to execute the scripts on all specified PCs?")) {
        return
    }

    # Check if PC list is empty
    if ($global:PCList.Count -eq 0) {
        Write-Host "⚠️ No PCs specified. Please import or enter PC names/IPs first." -ForegroundColor Yellow
        Log-Message -Level "WARNING" -Message "Execution aborted. No PCs specified."
        Pause
        return
    }

    # Check if script or custom command is specified
    if ([string]::IsNullOrWhiteSpace($global:ScriptPath) -and [string]::IsNullOrWhiteSpace($global:CustomCommand)) {
        Write-Host "⚠️ No script or custom command specified. Please select a script or enter a custom command." -ForegroundColor Yellow
        Log-Message -Level "WARNING" -Message "Execution aborted. No script or custom command specified."
        Pause
        return
    }

    Write-Host "🚀 Starting script execution on $($global:PCList.Count) PC(s)..." -ForegroundColor Cyan
    Log-Message -Level "INFO" -Message "Starting script execution on $($global:PCList.Count) PC(s)."

    # Initialize counters
    $upCount = 0   # Successful executions
    $downCount = 0 # Failed executions

    # Initialize results array for reporting
    $global:ExecutionResults = @()

    # Iterate through each PC
    foreach ($PC in $global:PCList) {
        if ($global:CancellationRequested) {
            Write-Host "`n⏹️ Execution canceled by user." -ForegroundColor Red
            Log-Message -Level "WARNING" -Message "Execution canceled by user."
            break
        }

        Write-Host "`n----------------------------------------" -ForegroundColor DarkGray
        Write-Host "📟 Processing PC: $PC" -ForegroundColor Yellow
        Log-Message -Level "INFO" -Message "Processing PC: $PC"

        # Validate PC format
        if (-not (Validate-Device -Device $PC)) {
            Write-Host "❌ Invalid PC Name or IP Address format: $PC" -ForegroundColor Red
            Log-Message -Level "ERROR" -Message "Invalid PC format: $PC"
            $downCount++
            # Add to execution results
            $global:ExecutionResults += [PSCustomObject]@{
                PC         = $PC
                Status     = "Invalid Format"
                Output     = ""
                Error      = "Invalid PC Name or IP Address format."
                Timestamp  = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
            }
            continue
        }

        # Test connectivity
        Write-Host "🔍 Checking connectivity to $PC..." -ForegroundColor White
        Log-Message -Level "INFO" -Message "Checking connectivity to $PC."

        try {
            if (Test-Connection -ComputerName $PC -Count 2 -Quiet) {
                Write-Host "✅ $PC is ONLINE." -ForegroundColor Green
                Log-Message -Level "INFO" -Message "$PC is ONLINE."

                # Initialize output variables
                $customOutput = ""
                $scriptOutput = ""

                # Execute Custom Command if provided
                if (-not [string]::IsNullOrWhiteSpace($global:CustomCommand)) {
                    Write-Host "💻 Executing custom command on $PC..." -ForegroundColor Cyan
                    Log-Message -Level "INFO" -Message "Executing custom command on $PC."

                    try {
                        # Execute custom command remotely
                        $customOutput = Invoke-Command -ComputerName $PC -ScriptBlock ([ScriptBlock]::Create($global:CustomCommand)) -ArgumentList $global:ScriptParameters -ErrorAction Stop

                        # Display and log output
                        Write-Host "📄 Custom Command Output on ${PC}:" -ForegroundColor White
                        Write-Host $customOutput -ForegroundColor White
                        Log-Message -Level "INFO" -Message "Custom Command Output on ${PC}:\n$customOutput"
                    }
                    catch {
                        Write-Host "❌ Error executing custom command on ${PC}: $_" -ForegroundColor Red
                        Log-Message -Level "ERROR" -Message "Error executing custom command on ${PC}: $_"
                    }
                }

                # Execute Uploaded Script if provided
                if (-not [string]::IsNullOrWhiteSpace($global:ScriptPath)) {
                    Write-Host "📝 Executing script on $PC..." -ForegroundColor Cyan
                    Log-Message -Level "INFO" -Message "Executing script on $PC."

                    try {
                        # Read script content
                        $scriptContent = Get-Content -Path $global:ScriptPath -Raw

                        # Execute script remotely with parameters
                        $scriptOutput = Invoke-Command -ComputerName $PC -ScriptBlock ([ScriptBlock]::Create($scriptContent)) -ArgumentList $global:ScriptParameters -ErrorAction Stop

                        # Display and log output
                        Write-Host "📄 Script Output on ${PC}:" -ForegroundColor White
                        Write-Host $scriptOutput -ForegroundColor White
                        Log-Message -Level "INFO" -Message "Script Output on ${PC}:\n$scriptOutput"
                    }
                    catch {
                        Write-Host "❌ Error executing script on ${PC}: $_" -ForegroundColor Red
                        Log-Message -Level "ERROR" -Message "Error executing script on ${PC}:\n $_"
                    }
                }

                # Increment successful execution counter
                $upCount++

                # Add to execution results
                $global:ExecutionResults += [PSCustomObject]@{
                    PC         = $PC
                    Status     = "Success"
                    Output     = ($customOutput + "`n" + $scriptOutput).Trim()
                    Error      = ""
                    Timestamp  = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
                }
            }
            else {
                Write-Host "❌ $PC is OFFLINE or Unreachable." -ForegroundColor Red
                Log-Message -Level "WARNING" -Message "$PC is OFFLINE or Unreachable."
                $downCount++

                # Add to execution results
                $global:ExecutionResults += [PSCustomObject]@{
                    PC         = $PC
                    Status     = "Offline"
                    Output     = ""
                    Error      = "$PC is offline or unreachable."
                    Timestamp  = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
                }
            }
        }
        catch {
            Write-Host "❌ Error testing connectivity to ${PC}: $_" -ForegroundColor Red
            Log-Message -Level "ERROR" -Message "Error testing connectivity to ${PC}: $_"
            $downCount++

            # Add to execution results
            $global:ExecutionResults += [PSCustomObject]@{
                PC         = $PC
                Status     = "Connectivity Error"
                Output     = ""
                Error      = $_.Exception.Message
                Timestamp  = (Get-Date).ToString("yyyy-MM-dd HH:mm:ss")
            }
        }

        # Update progress visualization
        $percent = [math]::Round((($upCount + $downCount) / $global:PCList.Count) * 100, 2)
        Write-Progress -Activity "Executing Scripts" -Status "Processing $PC ($upCount Success, $downCount Failures)" -PercentComplete $percent

        # Small delay for readability
        Start-Sleep -Seconds 1
    }

    # Completion Summary
    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host "📊 Execution Summary:" -ForegroundColor Cyan
    Write-Host "Total PCs Processed    : $($upCount + $downCount)"
    Write-Host "✅ Successful Executions: $upCount" -ForegroundColor Green
    Write-Host "❌ Failed Executions    : $downCount" -ForegroundColor Red
    Write-Host "📝 Log File             : $global:LogPath" -ForegroundColor Yellow
    Write-Host "========================================" -ForegroundColor Cyan
    Log-Message -Level "INFO" -Message "Execution Summary: Total: $($upCount + $downCount), Successful: $upCount, Failed: $downCount"
    Log-Message -Level "INFO" -Message "Log file located at: $global:LogPath"

    # Export results to CSV and/or HTML based on user choice
    Export-Results -Results $global:ExecutionResults

    # Pause before exiting
    Pause # Wait for user to acknowledge
}

# Function: Export-Results
# Purpose: Exports execution results to CSV and/or HTML for reporting.
function Export-Results {
    param (
        [Parameter(Mandatory = $true)]
        [array]$Results
    )

    if ($Results.Count -eq 0) {
        Write-Host "⚠️ No execution data available to export. Please execute scripts first." -ForegroundColor Yellow
        Log-Message -Level "WARNING" -Message "Export attempted without executing scripts."
        Pause
        return
    }

    Write-Host "`n=== Step 4: Export Execution Results ===`n" -ForegroundColor Cyan
    Write-Host "Select export format:"
    Write-Host "1. CSV"
    Write-Host "2. HTML"
    Write-Host "3. Both CSV and HTML"
    Write-Host "4. Cancel"
    Write-Host ""
    $exportChoice = Read-Host "📥 Please select an option (1-4)"

    switch ($exportChoice) {
        '1' { # Export to CSV
            # Initialize SaveFileDialog for CSV
            $saveFileDialog = New-Object System.Windows.Forms.SaveFileDialog
            $saveFileDialog.Filter = "CSV Files (*.csv)|*.csv"
            $saveFileDialog.Title = "Save CSV Report"
            $saveFileDialog.InitialDirectory = [Environment]::GetFolderPath("Desktop")
            $saveFileDialog.FileName = "ExecutionResults.csv"

            $dialogResult = $saveFileDialog.ShowDialog()

            if ($dialogResult -eq [System.Windows.Forms.DialogResult]::OK) {
                $csvPath = $saveFileDialog.FileName
                try {
                    $Results | Export-Csv -Path $csvPath -NoTypeInformation -Encoding UTF8
                    Write-Host "✅ Execution results exported to CSV at: $csvPath" -ForegroundColor Green
                    Log-Message -Level "INFO" -Message "Execution results exported to CSV at: $csvPath"
                }
                catch {
                    Write-Host "❌ Error exporting results to CSV: $_" -ForegroundColor Red
                    Log-Message -Level "ERROR" -Message "Error exporting results to CSV: $_"
                }
            }
            else {
                Write-Host "⚠️ CSV export canceled." -ForegroundColor Yellow
                Log-Message -Level "WARNING" -Message "CSV export canceled by user."
            }
        }
        '2' { # Export to HTML
            # Initialize SaveFileDialog for HTML
            $saveFileDialog = New-Object System.Windows.Forms.SaveFileDialog
            $saveFileDialog.Filter = "HTML Files (*.html)|*.html"
            $saveFileDialog.Title = "Save HTML Report"
            $saveFileDialog.InitialDirectory = [Environment]::GetFolderPath("Desktop")
            $saveFileDialog.FileName = "ExecutionReport.html"

            $dialogResult = $saveFileDialog.ShowDialog()

            if ($dialogResult -eq [System.Windows.Forms.DialogResult]::OK) {
                $htmlPath = $saveFileDialog.FileName
                try {
                    $style = @"
<style>
    table {
        width: 100%;
        border-collapse: collapse;
    }
    th, td {
        border: 1px solid #dddddd;
        text-align: left;
        padding: 8px;
    }
    th {
        background-color: #f2f2f2;
    }
    .Success {
        background-color: #d4edda;
    }
    .Offline, .Connectivity_Error, .Invalid_Format {
        background-color: #fff3cd;
    }
    .Error {
        background-color: #f8d7da;
    }
</style>
"@

                    $htmlBody = $Results | ForEach-Object {
                        $rowClass = $_.Status -replace ' ', '_'
                        "<tr class='$rowClass'>
                            <td>$($_.PC)</td>
                            <td>$($_.Status)</td>
                            <td>$($_.Output)</td>
                            <td>$($_.Error)</td>
                            <td>$($_.Timestamp)</td>
                        </tr>"
                    } | Out-String

                    $htmlDocument = @"
<html>
<head>
    <title>Remote Script Executor - Execution Report</title>
    $style
</head>
<body>
    <h1>Remote Script Executor - Execution Report</h1>
    <table>
        <tr>
            <th>PC</th>
            <th>Status</th>
            <th>Output</th>
            <th>Error</th>
            <th>Timestamp</th>
        </tr>
        $htmlBody
    </table>
</body>
</html>
"@

                    $htmlDocument | Out-File -FilePath $htmlPath -Encoding UTF8
                    Write-Host "✅ Execution results exported to HTML at: $htmlPath" -ForegroundColor Green
                    Log-Message -Level "INFO" -Message "Execution results exported to HTML at: $htmlPath"
                }
                catch {
                    Write-Host "❌ Error exporting results to HTML: $_" -ForegroundColor Red
                    Log-Message -Level "ERROR" -Message "Error exporting results to HTML: $_"
                }
            }
            else {
                Write-Host "⚠️ HTML export canceled." -ForegroundColor Yellow
                Log-Message -Level "WARNING" -Message "HTML export canceled by user."
            }
        }
        '3' { # Export to Both CSV and HTML
            # Export to CSV
            # Initialize SaveFileDialog for CSV
            $saveFileDialogCSV = New-Object System.Windows.Forms.SaveFileDialog
            $saveFileDialogCSV.Filter = "CSV Files (*.csv)|*.csv"
            $saveFileDialogCSV.Title = "Save CSV Report"
            $saveFileDialogCSV.InitialDirectory = [Environment]::GetFolderPath("Desktop")
            $saveFileDialogCSV.FileName = "ExecutionResults.csv"

            $dialogResultCSV = $saveFileDialogCSV.ShowDialog()

            if ($dialogResultCSV -eq [System.Windows.Forms.DialogResult]::OK) {
                $csvPath = $saveFileDialogCSV.FileName
                try {
                    $Results | Export-Csv -Path $csvPath -NoTypeInformation -Encoding UTF8
                    Write-Host "✅ Execution results exported to CSV at: $csvPath" -ForegroundColor Green
                    Log-Message -Level "INFO" -Message "Execution results exported to CSV at: $csvPath"
                }
                catch {
                    Write-Host "❌ Error exporting results to CSV: $_" -ForegroundColor Red
                    Log-Message -Level "ERROR" -Message "Error exporting results to CSV: $_"
                }
            }
            else {
                Write-Host "⚠️ CSV export canceled." -ForegroundColor Yellow
                Log-Message -Level "WARNING" -Message "CSV export canceled by user."
            }

            # Export to HTML
            # Initialize SaveFileDialog for HTML
            $saveFileDialogHTML = New-Object System.Windows.Forms.SaveFileDialog
            $saveFileDialogHTML.Filter = "HTML Files (*.html)|*.html"
            $saveFileDialogHTML.Title = "Save HTML Report"
            $saveFileDialogHTML.InitialDirectory = [Environment]::GetFolderPath("Desktop")
            $saveFileDialogHTML.FileName = "ExecutionReport.html"

            $dialogResultHTML = $saveFileDialogHTML.ShowDialog()

            if ($dialogResultHTML -eq [System.Windows.Forms.DialogResult]::OK) {
                $htmlPath = $saveFileDialogHTML.FileName
                try {
                    $style = @"
<style>
    table {
        width: 100%;
        border-collapse: collapse;
    }
    th, td {
        border: 1px solid #dddddd;
        text-align: left;
        padding: 8px;
    }
    th {
        background-color: #f2f2f2;
    }
    .Success {
        background-color: #d4edda;
    }
    .Offline, .Connectivity_Error, .Invalid_Format {
        background-color: #fff3cd;
    }
    .Error {
        background-color: #f8d7da;
    }
</style>
"@

                    $htmlBody = $Results | ForEach-Object {
                        $rowClass = $_.Status -replace ' ', '_'
                        "<tr class='$rowClass'>
                            <td>$($_.PC)</td>
                            <td>$($_.Status)</td>
                            <td>$($_.Output)</td>
                            <td>$($_.Error)</td>
                            <td>$($_.Timestamp)</td>
                        </tr>"
                    } | Out-String

                    $htmlDocument = @"
<html>
<head>
    <title>Remote Script Executor - Execution Report</title>
    $style
</head>
<body>
    <h1>Remote Script Executor - Execution Report</h1>
    <table>
        <tr>
            <th>PC</th>
            <th>Status</th>
            <th>Output</th>
            <th>Error</th>
            <th>Timestamp</th>
        </tr>
        $htmlBody
    </table>
</body>
</html>
"@

                    $htmlDocument | Out-File -FilePath $htmlPath -Encoding UTF8
                    Write-Host "✅ Execution results exported to HTML at: $htmlPath" -ForegroundColor Green
                    Log-Message -Level "INFO" -Message "Execution results exported to HTML at: $htmlPath"
                }
                catch {
                    Write-Host "❌ Error exporting results to HTML: $_" -ForegroundColor Red
                    Log-Message -Level "ERROR" -Message "Error exporting results to HTML: $_"
                }
            }
            else {
                Write-Host "⚠️ HTML export canceled." -ForegroundColor Yellow
                Log-Message -Level "WARNING" -Message "HTML export canceled by user."
            }
        }
        '4' { # Cancel
            Write-Host "⚠️ Export canceled by user." -ForegroundColor Yellow
            Log-Message -Level "WARNING" -Message "Export canceled by user."
        }
        default {
            Write-Host "⚠️ Invalid selection. Export skipped." -ForegroundColor Red
            Log-Message -Level "WARNING" -Message "Invalid export selection. Export skipped."
        }
    }

    Pause # Wait for user to acknowledge
}

# Function: Confirm-Action
# Purpose: Prompts the user to confirm an action.
function Confirm-Action {
    param (
        [Parameter(Mandatory = $true)]
        [string]$Message
    )

    $confirmation = Read-Host "$Message (Y/N)"
    if ($confirmation -ne 'Y' -and $confirmation -ne 'y') {
        Write-Host "⚠️ Action canceled by user." -ForegroundColor Yellow
        Log-Message -Level "WARNING" -Message "Action canceled by user: $Message"
        return $false
    }
    else {
        return $true
    }
}

# Function: Validate-Device
# Purpose: Validates the format of PC names and IP addresses.
function Validate-Device {
    param (
        [Parameter(Mandatory = $true)]
        [string]$Device
    )

    # Trim whitespace
    $Device = $Device.Trim()

    # Regex patterns
    $ipRegex = '^(\d{1,3}\.){3}\d{1,3}$'        # Basic IP address validation
    $nameRegex = '^[a-zA-Z0-9\-]+$'            # Basic PC name validation

    if ($Device -match $ipRegex) {
        # Validate each octet is <= 255
        $octets = $Device -split '\.'
        foreach ($octet in $octets) {
            if ([int]$octet -gt 255) {
                return $false
            }
        }
        return $true
    }
    elseif ($Device -match $nameRegex) {
        # Additional checks for PC names (e.g., length, prohibited characters)
        if ($Device.Length -le 15) { # Assuming NetBIOS name limit
            return $true
        }
        else {
            return $false
        }
    }
    else {
        return $false
    }
}

# ============================ #
#          Main Loop            #
# ============================ #

# Function: Show-SubMenu
# Purpose: Displays stylized submenus for each step.
function Show-SubMenu {
    param (
        [string]$StepTitle,
        [array]$Options
    )

    Write-Host "`n    ╔══════════════════════════════════════╗" -ForegroundColor Green
    Write-Host "    ║           $StepTitle          ║" -ForegroundColor Green
    Write-Host "    ╠══════════════════════════════════════╣" -ForegroundColor Green
    Write-Host "    ║                                      ║" -ForegroundColor Green
    foreach ($option in $Options) {
        Write-Host "    ║    $option" -ForegroundColor Cyan
    }
    Write-Host "    ║    $(if ($Options.Count + 1 -le 9) { ' ' } else { '' })   Return to Main Menu           ║" -ForegroundColor Green
    Write-Host "    ║                                      ║" -ForegroundColor Green
    Write-Host "    ╚══════════════════════════════════════╝" -ForegroundColor Green
    Write-Host "`n    Select an option: " -ForegroundColor Yellow -NoNewline
}

# Main interactive loop
while ($true) {
    Show-Banner
    Show-MainMenu
    $choice = Read-Host

    switch ($choice) {
        '1' { # Step 1: Select PCs
            Show-SubMenu -StepTitle "Step 1: Select PCs" -Options @(
                "1. Import PC List from CSV File"
                "2. Enter PC Names/IPs Manually"
            )
            $subChoice = Read-Host

            switch ($subChoice) {
                '1' {
                    Import-PCList
                }
                '2' {
                    Enter-PCNamesManually
                }
                default {
                    Write-Host "⚠️ Returning to Main Menu." -ForegroundColor Yellow
                    Pause
                }
            }
        }
        '2' { # Step 2: Select Script/Command
            # Ensure Step 1 is completed
            if ($global:PCList.Count -eq 0) {
                Write-Host "⚠️ Please complete Step 1: Select PCs before proceeding." -ForegroundColor Yellow
                Log-Message -Level "WARNING" -Message "Attempted Step 2 without completing Step 1."
                Pause
                continue
            }

            Show-SubMenu -StepTitle "Step 2: Select Script/Command" -Options @(
                "1. Select PowerShell Script to Execute"
                "2. Enter Custom PowerShell Command"
            )
            $subChoice = Read-Host

            switch ($subChoice) {
                '1' {
                    Select-Script
                }
                '2' {
                    Enter-CustomCommand
                }
                default {
                    Write-Host "⚠️ Returning to Main Menu." -ForegroundColor Yellow
                    Pause
                }
            }
        }
        '3' { # Step 3: Execute Scripts on All PCs
            # Ensure Steps 1 and 2 are completed
            if ($global:PCList.Count -eq 0) {
                Write-Host "⚠️ Please complete Step 1: Select PCs before proceeding." -ForegroundColor Yellow
                Log-Message -Level "WARNING" -Message "Attempted Step 3 without completing Step 1."
                Pause
                continue
            }

            if ([string]::IsNullOrWhiteSpace($global:ScriptPath) -and [string]::IsNullOrWhiteSpace($global:CustomCommand)) {
                Write-Host "⚠️ Please complete Step 2: Select Script/Command before proceeding." -ForegroundColor Yellow
                Log-Message -Level "WARNING" -Message "Attempted Step 3 without completing Step 2."
                Pause
                continue
            }

            Execute-Scripts
        }
        '4' { # Step 4: Export Execution Results to CSV and/or HTML
            Export-Results -Results $global:ExecutionResults
        }
        '5' { # Step 5: Exit
            Write-Host "`n👋 Exiting Remote Script Executor. Goodbye!" -ForegroundColor Cyan
            Log-Message -Level "INFO" -Message "User exited the script."
            break
        }
        default {
            Write-Host "⚠️ Invalid selection. Please choose a valid option (1-5)." -ForegroundColor Red
            Pause # Wait for user to acknowledge
        }
    }
}

# ============================ #
#          End of Script        #
# ============================ #
