<#
.SYNOPSIS
    PowerShell WPF GUI Script for Remote Script Execution

.DESCRIPTION
    Provides a graphical user interface (GUI) to execute scripts on remote computers.
    Users can input remote PC names or IPs, upload a script file or enter custom commands.
    Execution results are displayed in real-time.

.AUTHOR
    Author  : Mohammad Abdulkader Omar
    Website : momar.tech
    Date    : 2024-12-12

.NOTES
    - Ensure the user account has administrative permissions on remote machines.
    - WinRM must be properly configured on all target machines via GPO.
    - Date: 2024-12-12
    - Version: 1.0

.FILENAME
    RemoteScriptExecutorGUI.ps1
#>

# Load necessary assemblies
try {
    Add-Type -AssemblyName PresentationFramework
    Add-Type -AssemblyName PresentationCore
    Add-Type -AssemblyName WindowsBase
    Add-Type -AssemblyName System.Xaml
    # Write-Host "WPF assemblies loaded successfully."
}
catch {
    Write-Host "Error loading WPF assemblies: $_"
    exit
}

function Initialize-Window {
    [xml]$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        Title="Remote Script Executor" Height="900" Width="700" WindowStartupLocation="CenterScreen" Background="#f0f0f0">
    <Grid Margin="10">
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/> <!-- Target Devices -->
            <RowDefinition Height="Auto"/> <!-- Custom Command -->
            <RowDefinition Height="Auto"/> <!-- Script Upload -->
            <RowDefinition Height="Auto"/> <!-- Action Buttons -->
            <RowDefinition Height="*"/>    <!-- Execution Output -->
            <RowDefinition Height="Auto"/> <!-- Progress Bar & Footer -->
        </Grid.RowDefinitions>

        <!-- Target Devices Group -->
        <GroupBox Header="Target Devices" Grid.Row="0" Margin="0,0,0,10" Padding="10" Background="#ffffff">
            <Grid>
                <Grid.ColumnDefinitions>
                    <ColumnDefinition Width="200"/>
                    <ColumnDefinition Width="*"/>
                    <ColumnDefinition Width="150"/>
                </Grid.ColumnDefinitions>
                <Label Content="Device Name or IP Address:" VerticalAlignment="Center" FontSize="12"/>
                <TextBox Name="txtPCNames" Grid.Column="1" Margin="10,0" FontSize="12"/>
                <Button Name="btnUploadCSV" Content="Import from File" Grid.Column="2" Width="130" FontSize="12" Background="#4CAF50" Foreground="White"/>
            </Grid>
        </GroupBox>

        <!-- Custom Command Group -->
        <GroupBox Header="Custom Command" Grid.Row="1" Margin="0,0,0,10" Padding="10" Background="#ffffff">
            <Grid>
                <Grid.RowDefinitions>
                    <RowDefinition Height="Auto"/>
                    <RowDefinition Height="*"/>
                </Grid.RowDefinitions>
                <Label Content="Enter Command or Script:" Grid.Row="0" FontSize="12"/>
                <TextBox Name="txtCustomScript" Grid.Row="1" Margin="0,5,0,5" AcceptsReturn="True" VerticalScrollBarVisibility="Auto" FontSize="12" MinHeight="200" VerticalAlignment="Stretch"/>
            </Grid>
        </GroupBox>

        <!-- Script Upload Group -->
        <GroupBox Header="Script Upload" Grid.Row="2" Margin="0,0,0,10" Padding="10" Background="#ffffff">
            <Grid>
                <Grid.RowDefinitions>
                    <RowDefinition Height="Auto"/>
                    <RowDefinition Height="Auto"/>
                </Grid.RowDefinitions>
                <Grid.ColumnDefinitions>
                    <ColumnDefinition Width="200"/>
                    <ColumnDefinition Width="*"/>
                    <ColumnDefinition Width="100"/>
                </Grid.ColumnDefinitions>
                <Label Content="Select Script File:" Grid.Row="0" Grid.Column="0" VerticalAlignment="Center" FontSize="12"/>
                <TextBox Name="txtUploadScript" Grid.Row="0" Grid.Column="1" Margin="10,0" FontSize="12" IsReadOnly="True"/>
                <Button Name="btnBrowseScript" Content="Select Script" Grid.Row="0" Grid.Column="2" Width="100" FontSize="12" Background="#2196F3" Foreground="White"/>
            </Grid>
        </GroupBox>

        <!-- Action Buttons -->
        <StackPanel Grid.Row="3" Orientation="Horizontal" HorizontalAlignment="Left" Margin="0,0,0,10">
            <Button Name="btnExecute" Content="Run Scripts" Width="150" FontSize="12" Background="#FF9800" Foreground="White" Margin="0,0,10,0"/>
            <Button Name="btnStop" Content="Cancel Execution" Width="150" FontSize="12" Background="#F44336" Foreground="White"/>
        </StackPanel>

        <!-- Execution Output RichTextBox -->
        <GroupBox Header="Execution Output" Grid.Row="4" Margin="0,0,0,10" Padding="10" Background="#ffffff">
            <Grid>
                <RichTextBox Name="rtbOutput" FontSize="12" IsReadOnly="True" VerticalScrollBarVisibility="Auto" Background="#002b36" Foreground="White" FontFamily="Consolas"/>
            </Grid>
        </GroupBox>

        <!-- Progress Bar and Footer -->
        <StackPanel Grid.Row="5" Orientation="Vertical">
            <ProgressBar Name="progressBar" Height="20" Foreground="#4CAF50" Background="#e0e0e0" Margin="0,0,0,5"/>
            <TextBlock Text="© Mohammad Omar. All rights reserved. Visit: momar.tech" HorizontalAlignment="Center" FontSize="10" Foreground="#555555"/>
        </StackPanel>
    </Grid>
</Window>
"@

    try {
        $reader = (New-Object System.Xml.XmlNodeReader $xaml)
        $window = [Windows.Markup.XamlReader]::Load($reader)
        # Write-Host "Window initialized successfully."
    }
    catch {
        Write-Host "Error loading XAML: $_"
        exit
    }

    return $window
}

function Append-Output {
    param (
        [System.Windows.Controls.RichTextBox]$rtb,
        [string]$text,
        [System.Windows.Media.Brush]$color = [System.Windows.Media.Brushes]::White
    )
    if ($null -eq $rtb) {
        # Write-Host "RichTextBox is null. Cannot append text."
        return
    }

    $rtb.Dispatcher.Invoke({
        $paragraph = New-Object System.Windows.Documents.Paragraph
        # Split the text into lines
        $lines = $text -split "`n"
        foreach ($line in $lines) {
            $run = New-Object System.Windows.Documents.Run($line)
            $run.Foreground = $color
            $paragraph.Inlines.Add($run)
            # Add a line break after each line except the last
            if ($line -ne $lines[-1]) {
                $paragraph.Inlines.Add([System.Windows.Documents.LineBreak]::new())
            }
        }
        $paragraph.LineHeight = 14 # Set line height for the paragraph
        $rtb.Document.Blocks.Add($paragraph)
        $rtb.ScrollToEnd()
    })
}

function Execute-RemoteCommand {
    param (
        [string]$ComputerName,
        [System.Management.Automation.PSCredential]$Credential,
        [ScriptBlock]$ScriptBlock,
        [string]$Message,
        [System.Windows.Controls.RichTextBox]$rtb
    )

    Append-Output -rtb $rtb -text ("--- Start Execution: " + $Message + " on " + $ComputerName + " ---") -color ([System.Windows.Media.Brushes]::Cyan)

    try {
        # Convert the ScriptBlock to a string to pass to the job
        $scriptContent = $ScriptBlock.ToString()

        # Start the remote command as a background job
        $job = Start-Job -ScriptBlock {
            param($ComputerName, $Credential, $ScriptContent)
            try {
                # Recreate the ScriptBlock inside the job
                $ScriptBlock = [ScriptBlock]::Create($ScriptContent)
                # Execute the remote command
                $output = Invoke-Command -ComputerName $ComputerName -Credential $Credential -ScriptBlock $ScriptBlock -ErrorAction Stop -Verbose:$true -WarningAction SilentlyContinue -InformationVariable InfoOutput
                # Return both output and info
                return @{ Output = $output; Info = $InfoOutput }
            }
            catch {
                # Return the error message
                return @{ Error = $_.Exception.Message }
            }
        } -ArgumentList $ComputerName, $Credential, $scriptContent

        # Wait for the job to complete
        $job | Wait-Job | Out-Null

        # Retrieve the results
        $result = Receive-Job -Job $job

        # Check for errors
        if ($result.Error) {
            Append-Output -rtb $rtb -text ("--- Failed to Execute " + $Message + " on " + $ComputerName + ": " + $result.Error + " ---") -color ([System.Windows.Media.Brushes]::Red)
        }
        else {
            # Append standard output
            foreach ($line in $result.Output) {
                Append-Output -rtb $rtb -text $line -color ([System.Windows.Media.Brushes]::White)
            }

            # Append Information stream (captures Write-Host in PowerShell 5.0+)
            if ($result.Info) {
                foreach ($info in $result.Info) {
                    Append-Output -rtb $rtb -text $info.MessageData -color ([System.Windows.Media.Brushes]::White)
                }
            }

            Append-Output -rtb $rtb -text ("--- End Execution: " + $Message + " on " + $ComputerName + " ---") -color ([System.Windows.Media.Brushes]::Cyan)
            Append-Output -rtb $rtb -text ("-" * 50) -color ([System.Windows.Media.Brushes]::White)
        }
    }
    catch {
        # Capture and display errors related to job creation or execution
        Append-Output -rtb $rtb -text ("--- Failed to Execute " + $Message + " on " + $ComputerName + ": " + $_.Exception.Message + " ---") -color ([System.Windows.Media.Brushes]::Red)
    }
    finally {
        # Remove the job to free resources
        if ($job) {
            Remove-Job -Job $job -Force | Out-Null
        }
    }
}

function Register-EventHandlers {
    param (
        [System.Windows.Window]$window,
        [System.Windows.Controls.RichTextBox]$rtb
    )

    # Button: Import from CSV
    $btnUploadCSV = $window.FindName("btnUploadCSV")
    $txtPCNames = $window.FindName("txtPCNames")
    if ($btnUploadCSV -eq $null) {
        # Write-Host "Error: Button 'btnUploadCSV' not found in XAML."
        exit
    }
    # Write-Host "Button 'btnUploadCSV' found successfully."

    if ($txtPCNames -eq $null) {
        # Write-Host "Error: TextBox 'txtPCNames' not found in XAML."
        exit
    }
    else {
        # Write-Host "TextBox 'txtPCNames' found successfully."
        $global:txtPCNames = $txtPCNames
    }

    $global:rtbOutput = $rtb

    $btnUploadCSV.Add_Click({
        Append-Output -rtb $global:rtbOutput -text "Uploading CSV..." -color ([System.Windows.Media.Brushes]::Orange)
        $openFileDialog = New-Object Microsoft.Win32.OpenFileDialog
        $openFileDialog.Filter = "CSV Files (*.csv)|*.csv"
        if ($openFileDialog.ShowDialog() -eq $true) {
            try {
                $csvContent = Import-Csv -Path $openFileDialog.FileName -Header @("PCNameOrIP")
                $pcNames = ($csvContent.PCNameOrIP -join ",").Replace(" ", "")
                $global:txtPCNames.Text = $pcNames
                Append-Output -rtb $global:rtbOutput -text "CSV imported successfully." -color ([System.Windows.Media.Brushes]::Yellow)
                # Write-Host "CSV imported and PC names set."
            }
            catch {
                Append-Output -rtb $global:rtbOutput -text "Failed to import CSV: $_" -color ([System.Windows.Media.Brushes]::Red)
                # Write-Host "Failed to import CSV: $_"
            }
        }
        else {
            Append-Output -rtb $global:rtbOutput -text "CSV import canceled." -color ([System.Windows.Media.Brushes]::Red)
            # Write-Host "CSV import canceled."
        }
    })

    # Button: Browse Script
    $btnBrowseScript = $window.FindName("btnBrowseScript")
    $txtUploadScript = $window.FindName("txtUploadScript")
    if ($btnBrowseScript -eq $null) {
        # Write-Host "Error: Button 'btnBrowseScript' not found in XAML."
        exit
    }
    # Write-Host "Button 'btnBrowseScript' found successfully."

    if ($txtUploadScript -eq $null) {
        # Write-Host "Error: TextBox 'txtUploadScript' not found in XAML."
        exit
    }
    else {
        # Write-Host "TextBox 'txtUploadScript' found successfully."
        $global:txtUploadScript = $txtUploadScript
    }

    $btnBrowseScript.Add_Click({
        $openFileDialog = New-Object Microsoft.Win32.OpenFileDialog
        $openFileDialog.Filter = "PowerShell Scripts (*.ps1)|*.ps1"
        if ($openFileDialog.ShowDialog() -eq $true) {
            $global:txtUploadScript.Text = $openFileDialog.FileName
            Append-Output -rtb $global:rtbOutput -text "Script file selected successfully." -color ([System.Windows.Media.Brushes]::Yellow)
            # Write-Host "Script file selected: $($openFileDialog.FileName)"
        }
        else {
            Append-Output -rtb $global:rtbOutput -text "Script file selection canceled." -color ([System.Windows.Media.Brushes]::Red)
            # Write-Host "Script file selection canceled."
        }
    })

    # Button: Execute Scripts
    $btnExecute = $window.FindName("btnExecute")
    if ($btnExecute -eq $null) {
        # Write-Host "Error: Button 'btnExecute' not found in XAML."
        exit
    }
    # Write-Host "Button 'btnExecute' found successfully."

    $btnExecute.Add_Click({
        Start-ScriptExecution
    })

    # Button: Stop Execution
    $btnStop = $window.FindName("btnStop")
    if ($btnStop -eq $null) {
        # Write-Host "Error: Button 'btnStop' not found in XAML."
        exit
    }
    # Write-Host "Button 'btnStop' found successfully."

    $btnStop.Add_Click({
        Append-Output -rtb $global:rtbOutput -text "--- Cancellation is not supported at this time. ---" -color ([System.Windows.Media.Brushes]::Red)
        # Write-Host "Attempted to cancel execution, but cancellation is not implemented."
    })
}

function Start-ScriptExecution {
    $rtb = $global:rtbOutput

    if ($null -eq $rtb) {
        # Write-Host "Error: RichTextBox 'rtbOutput' is null."
        return
    }

    $rtb.Document.Blocks.Clear()
    Append-Output -rtb $rtb -text "Initiating script execution..." -color ([System.Windows.Media.Brushes]::Cyan)

    # Access controls
    $window = $global:window
    $txtPCNames = $global:txtPCNames
    $txtCustomScript = $window.FindName("txtCustomScript")
    $txtUploadScript = $global:txtUploadScript
    $progressBar = $window.FindName("progressBar")
    $btnExecute = $window.FindName("btnExecute")

    # Validate inputs
    $RemotePCName = $txtPCNames.Text

    if ([string]::IsNullOrWhiteSpace($RemotePCName)) {
        Append-Output -rtb $rtb -text "Device Name or IP Address is required." -color ([System.Windows.Media.Brushes]::Red)
        return
    }

    # Convert Device Names or IPs to an array
    $RemotePCNames = $RemotePCName -split "," | ForEach-Object { $_.Trim() }

    if ($RemotePCNames.Count -eq 0) {
        Append-Output -rtb $rtb -text "No valid Device Names or IP Addresses provided." -color ([System.Windows.Media.Brushes]::Red)
        return
    }

    $progressBar.Value = 0
    $progressBar.Maximum = $RemotePCNames.Count

    # Disable Execute button to prevent multiple runs
    $btnExecute.IsEnabled = $false

    # Use current session's credentials
    try {
        $Credential = [System.Management.Automation.PSCredential]::Empty
    }
    catch {
        Append-Output -rtb $rtb -text "Failed to retrieve current credentials: $_" -color ([System.Windows.Media.Brushes]::Red)
        $btnExecute.IsEnabled = $true
        return
    }

    $upCount = 0
    $downCount = 0

    foreach ($RemotePC in $RemotePCNames) {
        if ([string]::IsNullOrWhiteSpace($RemotePC)) {
            Append-Output -rtb $rtb -text "Invalid Device Name or IP Address: '$RemotePC'" -color ([System.Windows.Media.Brushes]::Red)
            continue
        }

        try {
            if (Test-Connection -ComputerName $RemotePC -Count 1 -Quiet) {
                Append-Output -rtb $rtb -text ("--- Device " + $RemotePC + " is ONLINE ---") -color ([System.Windows.Media.Brushes]::Yellow)
                Append-Output -rtb $rtb -text ("--- Initiating execution on " + $RemotePC + " ---") -color ([System.Windows.Media.Brushes]::Cyan)

                # Execute Custom Command if not empty
                if (-not [string]::IsNullOrWhiteSpace($txtCustomScript.Text)) {
                    $customCommand = $txtCustomScript.Text
                    $customScriptBlock = [ScriptBlock]::Create($customCommand)

                    if ($customCommand -match 'ShowDialog|MessageBox') {
                        Append-Output -rtb $rtb -text "--- The custom command contains UI elements and cannot be executed remotely. ---" -color ([System.Windows.Media.Brushes]::Red)
                    }
                    else {
                        Execute-RemoteCommand -ComputerName $RemotePC -Credential $Credential -ScriptBlock $customScriptBlock -Message "Custom Command" -rtb $rtb
                    }
                }

                # Execute Uploaded Script if not empty
                if (-not [string]::IsNullOrWhiteSpace($txtUploadScript.Text)) {
                    $scriptPath = $txtUploadScript.Text
                    if (Test-Path -Path $scriptPath) {
                        $scriptContent = Get-Content -Path $scriptPath -Raw
                        $scriptBlock = [ScriptBlock]::Create($scriptContent)

                        if ($scriptContent -match 'ShowDialog|MessageBox') {
                            Append-Output -rtb $rtb -text "--- The uploaded script contains UI elements and cannot be executed remotely. ---" -color ([System.Windows.Media.Brushes]::Red)
                        }
                        else {
                            Execute-RemoteCommand -ComputerName $RemotePC -Credential $Credential -ScriptBlock $scriptBlock -Message "Uploaded Script" -rtb $rtb
                        }
                    }
                    else {
                        Append-Output -rtb $rtb -text "Uploaded script file not found: $scriptPath" -color ([System.Windows.Media.Brushes]::Red)
                    }
                }

                $upCount++
            }
            else {
                Append-Output -rtb $rtb -text ("--- Device " + $RemotePC + " is OFFLINE or Unreachable. ---") -color ([System.Windows.Media.Brushes]::Red)
                $downCount++
            }
        }
        catch {
            Append-Output -rtb $rtb -text ("--- Failed to execute on " + $RemotePC + ": " + $_.Exception.Message + " ---") -color ([System.Windows.Media.Brushes]::Red)
            $downCount++
        }

        # Update Progress
        $progressBar.Dispatcher.Invoke({
            $progressBar.Value += 1
        })
    }

    Append-Output -rtb $rtb -text "--- Script execution process completed. ---" -color ([System.Windows.Media.Brushes]::Cyan)

    # Display summary of device statuses
    $summary = @(
        "Summary:",
        "Total Devices: $($RemotePCNames.Count)",
        "Devices Online: $upCount",
        "Devices Offline: $downCount"
    ) -join "`n"
    Append-Output -rtb $rtb -text $summary -color ([System.Windows.Media.Brushes]::Cyan)

    # Re-enable Execute button after completion
    $btnExecute.Dispatcher.Invoke({
        $btnExecute.IsEnabled = $true
    })
}

# -------------------------- #
#           Main              #
# -------------------------- #

# Initialize Window
$window = Initialize-Window

# Get RichTextBox for output and set as global variable
$global:rtbOutput = $window.FindName("rtbOutput")

if ($null -eq $global:rtbOutput) {
    # Write-Host "Error: Could not find RichTextBox named 'rtbOutput'. Ensure the XAML defines it correctly."
    exit
}
else {
    # Write-Host "RichTextBox 'rtbOutput' found."
}

# Register Event Handlers
Register-EventHandlers -window $window -rtb $global:rtbOutput

# Show the Window and set global window variable for access within functions
$global:window = $window
$window.ShowDialog() | Out-Null
