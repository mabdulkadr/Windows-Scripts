<#
.SYNOPSIS
    PowerShell GUI Script for Remote Script Execution

.DESCRIPTION
    This script provides a graphical user interface (GUI) for executing scripts on remote computers.
    Users can input remote PC names or IPs, provide credentials, and either upload a script file or enter custom commands.
    The script supports displaying execution results and logging them to a file.
    The results of command execution are shown for each PC one at a time, and then cleared before showing the next PC's results.
    It also provides a summary of device statuses at the end of the execution.

    Log file path: C:\remote_script_execution_log.txt

.AUTHOR
    © Mohammad Omar. All rights reserved. Visit: momar.tech

.NOTES
    Ensure the user account used for credentials has the necessary administrative permissions on the remote machines.
    WinRM should be properly configured on all target machines.
    Date: 2024-07-11
    Version: 1.0

.LINK
    Visit: momar.tech

.FILENAME
    RemoteScriptExecutorGUI.ps1
#>

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

# Create the form
$form = New-Object System.Windows.Forms.Form
$form.Text = "Remote Script Execution"
$form.Size = New-Object System.Drawing.Size(700, 800)
$form.StartPosition = "CenterScreen"

# Set default font for controls
$defaultFont = New-Object System.Drawing.Font("Segoe UI", 10)

# Group for PC Names or IPs
$groupBoxPCNames = New-Object System.Windows.Forms.GroupBox
$groupBoxPCNames.Text = "Devices Names or IPs"
$groupBoxPCNames.Location = New-Object System.Drawing.Point(10, 20)
$groupBoxPCNames.Size = New-Object System.Drawing.Size(650, 80)
$groupBoxPCNames.Font = $defaultFont
$form.Controls.Add($groupBoxPCNames)

$labelPCName = New-Object System.Windows.Forms.Label
$labelPCName.Text = "Remote PC Name or IP:"
$labelPCName.Location = New-Object System.Drawing.Point(10, 30)
$labelPCName.AutoSize = $true
$labelPCName.Font = $defaultFont
$groupBoxPCNames.Controls.Add($labelPCName)

$textBoxPCName = New-Object System.Windows.Forms.TextBox
$textBoxPCName.Location = New-Object System.Drawing.Point(180, 30)
$textBoxPCName.Size = New-Object System.Drawing.Size(300, 25)
$textBoxPCName.Font = $defaultFont
$groupBoxPCNames.Controls.Add($textBoxPCName)

$buttonUploadCSV = New-Object System.Windows.Forms.Button
$buttonUploadCSV.Text = "Import from CSV"
$buttonUploadCSV.Location = New-Object System.Drawing.Point(500, 27)
$buttonUploadCSV.AutoSize = $true
$buttonUploadCSV.Font = $defaultFont
$groupBoxPCNames.Controls.Add($buttonUploadCSV)

# Group for Credentials
$groupBoxCredentials = New-Object System.Windows.Forms.GroupBox
$groupBoxCredentials.Text = "Enter Your Credential"
$groupBoxCredentials.Location = New-Object System.Drawing.Point(10, 110)
$groupBoxCredentials.Size = New-Object System.Drawing.Size(650, 65)
$groupBoxCredentials.Font = $defaultFont
$form.Controls.Add($groupBoxCredentials)

$labelUsername = New-Object System.Windows.Forms.Label
$labelUsername.Text = "Username:"
$labelUsername.Location = New-Object System.Drawing.Point(10, 30)
$labelUsername.AutoSize = $true
$labelUsername.Font = $defaultFont
$groupBoxCredentials.Controls.Add($labelUsername)

$textBoxUsername = New-Object System.Windows.Forms.TextBox
$textBoxUsername.Location = New-Object System.Drawing.Point(100, 30)
$textBoxUsername.Size = New-Object System.Drawing.Size(200, 25)
$textBoxUsername.Font = $defaultFont
$groupBoxCredentials.Controls.Add($textBoxUsername)

$labelPassword = New-Object System.Windows.Forms.Label
$labelPassword.Text = "Password:"
$labelPassword.Location = New-Object System.Drawing.Point(340, 30)
$labelPassword.AutoSize = $true
$labelPassword.Font = $defaultFont
$groupBoxCredentials.Controls.Add($labelPassword)

$textBoxPassword = New-Object System.Windows.Forms.TextBox
$textBoxPassword.Location = New-Object System.Drawing.Point(430, 30)
$textBoxPassword.Size = New-Object System.Drawing.Size(200, 25)
$textBoxPassword.UseSystemPasswordChar = $true
$textBoxPassword.Font = $defaultFont
$groupBoxCredentials.Controls.Add($textBoxPassword)

# Group for Custom Script
$groupBoxCustomScript = New-Object System.Windows.Forms.GroupBox
$groupBoxCustomScript.Text = "Custom Script"
$groupBoxCustomScript.Location = New-Object System.Drawing.Point(10, 180)
$groupBoxCustomScript.Size = New-Object System.Drawing.Size(650, 200)
$groupBoxCustomScript.Font = $defaultFont
$form.Controls.Add($groupBoxCustomScript)

$labelCustomScript = New-Object System.Windows.Forms.Label
$labelCustomScript.Text = "Enter Custom Script:"
$labelCustomScript.Location = New-Object System.Drawing.Point(10, 30)
$labelCustomScript.AutoSize = $true
$labelCustomScript.Font = $defaultFont
$groupBoxCustomScript.Controls.Add($labelCustomScript)

$textBoxCustomScript = New-Object System.Windows.Forms.TextBox
$textBoxCustomScript.Location = New-Object System.Drawing.Point(160, 30)
$textBoxCustomScript.Size = New-Object System.Drawing.Size(470, 120)
$textBoxCustomScript.Multiline = $true
$textBoxCustomScript.Font = $defaultFont
$groupBoxCustomScript.Controls.Add($textBoxCustomScript)

# Checkbox to enable Custom Script
$checkBoxCustomScript = New-Object System.Windows.Forms.CheckBox
$checkBoxCustomScript.Text = "Enable Custom Script"
$checkBoxCustomScript.Location = New-Object System.Drawing.Point(10, 160)
$checkBoxCustomScript.AutoSize = $true
$checkBoxCustomScript.Font = $defaultFont
$groupBoxCustomScript.Controls.Add($checkBoxCustomScript)

# Group for Upload Script
$groupBoxUploadScript = New-Object System.Windows.Forms.GroupBox
$groupBoxUploadScript.Text = "Upload Script"
$groupBoxUploadScript.Location = New-Object System.Drawing.Point(10, 390)
$groupBoxUploadScript.Size = New-Object System.Drawing.Size(650, 120)
$groupBoxUploadScript.Font = $defaultFont
$form.Controls.Add($groupBoxUploadScript)

$labelUploadScript = New-Object System.Windows.Forms.Label
$labelUploadScript.Text = "Upload Script File:"
$labelUploadScript.Location = New-Object System.Drawing.Point(10, 30)
$labelUploadScript.AutoSize = $true
$labelUploadScript.Font = $defaultFont
$groupBoxUploadScript.Controls.Add($labelUploadScript)

$textBoxUploadScript = New-Object System.Windows.Forms.TextBox
$textBoxUploadScript.Location = New-Object System.Drawing.Point(160, 30)
$textBoxUploadScript.Size = New-Object System.Drawing.Size(400, 25)
$textBoxUploadScript.Font = $defaultFont
$textBoxUploadScript.ReadOnly = $true
$groupBoxUploadScript.Controls.Add($textBoxUploadScript)

$buttonBrowseScript = New-Object System.Windows.Forms.Button
$buttonBrowseScript.Text = "Browse"
$buttonBrowseScript.Location = New-Object System.Drawing.Point(570, 28)
$buttonBrowseScript.AutoSize = $true
$buttonBrowseScript.Font = $defaultFont
$groupBoxUploadScript.Controls.Add($buttonBrowseScript)

# Checkbox to enable Upload Script
$checkBoxUploadScript = New-Object System.Windows.Forms.CheckBox
$checkBoxUploadScript.Text = "Enable Upload Script"
$checkBoxUploadScript.Location = New-Object System.Drawing.Point(10, 70)
$checkBoxUploadScript.AutoSize = $true
$checkBoxUploadScript.Font = $defaultFont
$groupBoxUploadScript.Controls.Add($checkBoxUploadScript)

# Create button to execute scripts
$buttonExecute = New-Object System.Windows.Forms.Button
$buttonExecute.Text = "Execute Scripts"
$buttonExecute.Location = New-Object System.Drawing.Point(10, 530)
$buttonExecute.AutoSize = $true
$buttonExecute.Font = $defaultFont
$buttonExecute.Anchor = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Left
$form.Controls.Add($buttonExecute)

# Create button to stop execution
$buttonStop = New-Object System.Windows.Forms.Button
$buttonStop.Text = "Stop Execution"
$buttonStop.Location = New-Object System.Drawing.Point(200, 530)
$buttonStop.AutoSize = $true
$buttonStop.Font = $defaultFont
$buttonStop.Anchor = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Left
$form.Controls.Add($buttonStop)

# Create rich text box for output
$richTextBoxOutput = New-Object System.Windows.Forms.RichTextBox
$richTextBoxOutput.Location = New-Object System.Drawing.Point(10, 570)
$richTextBoxOutput.Size = New-Object System.Drawing.Size(670, 150)
$richTextBoxOutput.Multiline = $true
$richTextBoxOutput.ScrollBars = "Vertical"
$richTextBoxOutput.ReadOnly = $true
$richTextBoxOutput.BackColor = [System.Drawing.Color]::White
$richTextBoxOutput.Font = New-Object System.Drawing.Font("Segoe UI", 10)
$richTextBoxOutput.Anchor = [System.Windows.Forms.AnchorStyles]::Top -bor [System.Windows.Forms.AnchorStyles]::Left -bor [System.Windows.Forms.AnchorStyles]::Right -bor [System.Windows.Forms.AnchorStyles]::Bottom
$form.Controls.Add($richTextBoxOutput)

# Create progress bar
$progressBar = New-Object System.Windows.Forms.ProgressBar
$progressBar.Location = New-Object System.Drawing.Point(10, 730)
$progressBar.Size = New-Object System.Drawing.Size(670, 20)
$progressBar.Anchor = [System.Windows.Forms.AnchorStyles]::Left -bor [System.Windows.Forms.AnchorStyles]::Right -bor [System.Windows.Forms.AnchorStyles]::Bottom
$form.Controls.Add($progressBar)

# Log file path
$logFilePath = "C:\remote_script_execution_log.txt"

# Function to handle CSV upload
$buttonUploadCSV.Add_Click({
    Append-RichTextBox -richTextBox $richTextBoxOutput -text "Uploading CSV..." -color ([System.Drawing.Color]::Orange)
    $openFileDialog = New-Object System.Windows.Forms.OpenFileDialog
    $openFileDialog.Filter = "CSV Files (*.csv)|*.csv"
    if ($openFileDialog.ShowDialog() -eq "OK") {
        $csvContent = Import-Csv -Path $openFileDialog.FileName -Header @("PCNameOrIP")
        $pcNames = ($csvContent.PCNameOrIP -join ",").Replace(" ", "")
        $textBoxPCName.Text = $pcNames
        Append-RichTextBox -richTextBox $richTextBoxOutput -text "CSV uploaded successfully." -color ([System.Drawing.Color]::Green)
    } else {
        Append-RichTextBox -richTextBox $richTextBoxOutput -text "CSV upload canceled." -color ([System.Drawing.Color]::Red)
    }
})

# Function to handle script file upload
$buttonBrowseScript.Add_Click({
    $openFileDialog = New-Object System.Windows.Forms.OpenFileDialog
    $openFileDialog.Filter = "PowerShell Scripts (*.ps1)|*.ps1"
    if ($openFileDialog.ShowDialog() -eq "OK") {
        $textBoxUploadScript.Text = $openFileDialog.FileName
        Append-RichTextBox -richTextBox $richTextBoxOutput -text "Script file uploaded successfully." -color ([System.Drawing.Color]::Green)
    } else {
        Append-RichTextBox -richTextBox $richTextBoxOutput -text "Script upload canceled." -color ([System.Drawing.Color]::Red)
    }
})

# Function to append text to rich text box with color and preserve formatting
function Append-RichTextBox {
    param (
        [System.Windows.Forms.RichTextBox]$richTextBox,
        [string]$text,
        [System.Drawing.Color]$color
    )
    $richTextBox.Invoke([Action]{
        $richTextBox.SelectionStart = $richTextBox.Text.Length
        $richTextBox.SelectionColor = $color
        $richTextBox.AppendText($text + "`r`n")
        $richTextBox.SelectionColor = $richTextBox.ForeColor
    })
    # Write to log file
    Add-Content -Path $logFilePath -Value $text
}

# Function to ensure WinRM service is running and configured on remote machine
function Ensure-WinRM {
    param (
        [string]$ComputerName,
        [pscredential]$Credential
    )
    Append-RichTextBox -richTextBox $richTextBoxOutput -text "Configuring WinRM on $ComputerName..." -color ([System.Drawing.Color]::Orange)
    Invoke-Command -ComputerName $ComputerName -Credential $Credential -ScriptBlock {
        # Ensure WinRM service is running
        if ((Get-Service -Name WinRM).Status -ne 'Running') {
            Start-Service -Name WinRM
        }

        # Enable WinRM quickconfig
        try {
            winrm quickconfig -force
        } catch {
            Write-Output "WinRM quickconfig is already done."
        }

        # Enable Basic authentication
        winrm set winrm/config/service/auth '@{Basic="true"}'

        # Allow Unencrypted traffic
        winrm set winrm/config/service '@{AllowUnencrypted="true"}'

        # Add firewall rule to allow WinRM
        if (-not (Get-NetFirewallRule -DisplayName 'Allow WinRM')) {
            New-NetFirewallRule -Name "AllowWinRM" -DisplayName "Allow WinRM" -Enabled True -Profile Any -Action Allow -Direction Inbound -Protocol TCP -LocalPort 5985
        }
    } -ErrorAction Stop
    Append-RichTextBox -richTextBox $richTextBoxOutput -text "WinRM configured successfully on $ComputerName." -color ([System.Drawing.Color]::Green)
}

# Function to execute remote command and update output
function Execute-RemoteCommand {
    param (
        [string]$ComputerName,
        [System.Management.Automation.PSCredential]$Credential,
        [scriptblock]$ScriptBlock,
        [string]$Message
    )

    Append-RichTextBox -richTextBox $richTextBoxOutput -text ("--- Start execution: " + $Message + " on " + $ComputerName + " ---") -color ([System.Drawing.Color]::Blue)

    try {
        $output = Invoke-Command -ComputerName $ComputerName -Credential $Credential -ScriptBlock $ScriptBlock -ErrorAction Stop
        $output -split "`r?`n" | ForEach-Object {
            Append-RichTextBox -richTextBox $richTextBoxOutput -text $_ -color ([System.Drawing.Color]::Black)
        }
        Append-RichTextBox -richTextBox $richTextBoxOutput -text ("--- End execution: " + $Message + " on " + $ComputerName + " ---") -color ([System.Drawing.Color]::Blue)
        Append-RichTextBox -richTextBox $richTextBoxOutput -text ("-" * 50) -color ([System.Drawing.Color]::Black)
    } catch {
        Append-RichTextBox -richTextBox $richTextBoxOutput -text ("--- Failed to execute " + $Message + " on " + $ComputerName + ": " + $_.Exception.Message + " ---") -color ([System.Drawing.Color]::Red)
    }
}

# Function to execute scripts
$buttonExecute.Add_Click({
    $richTextBoxOutput.Clear()
    Append-RichTextBox -richTextBox $richTextBoxOutput -text "Starting script execution..." -color ([System.Drawing.Color]::Blue)
    $RemotePCName = $textBoxPCName.Text
    $Username = $textBoxUsername.Text
    $Password = $textBoxPassword.Text

    # Validate credentials
    if ([string]::IsNullOrWhiteSpace($Username) -or [string]::IsNullOrWhiteSpace($Password)) {
        Append-RichTextBox -richTextBox $richTextBoxOutput -text "Username and Password are required." -color ([System.Drawing.Color]::Red)
        return
    }

    # Set credentials
    $SecurePassword = $Password | ConvertTo-SecureString -AsPlainText -Force
    $cred = New-Object System.Management.Automation.PSCredential ($Username, $SecurePassword)

    # Convert the PC Name or IPs to an array
    $RemotePCNames = $RemotePCName -split ","

    $progressBar.Value = 0
    $progressBar.Maximum = $RemotePCNames.Count

    $upCount = 0
    $downCount = 0

    foreach ($RemotePC in $RemotePCNames) {
        if ([string]::IsNullOrWhiteSpace($RemotePC)) {
            Append-RichTextBox -richTextBox $richTextBoxOutput -text "Invalid PC Name or IP: $RemotePC" -color ([System.Drawing.Color]::Red)
            continue
        }

        $richTextBoxOutput.Clear()  # Clear output for next PC

        try {
            if (Test-Connection -ComputerName $RemotePC -Count 1 -Quiet) {
                Append-RichTextBox -richTextBox $richTextBoxOutput -text ("--- The computer " + $RemotePC + " is UP ---") -color ([System.Drawing.Color]::Green)
                Append-RichTextBox -richTextBox $richTextBoxOutput -text ("--- Starting execution on " + $RemotePC + " ---") -color ([System.Drawing.Color]::Blue)

                # Enable PowerShell Remoting on the local PC
                Enable-PSRemoting -Force -ErrorAction Stop

                # Set up trusted hosts if necessary
                $trustedHosts = Get-Item WSMan:\localhost\Client\TrustedHosts
                if (-not ($trustedHosts.Value -contains $RemotePC)) {
                    Set-Item WSMan:\localhost\Client\TrustedHosts -Value $RemotePC -Force
                }

                # Ensure WinRM is configured correctly on the remote machine
                Ensure-WinRM -ComputerName $RemotePC -Credential $cred

                if ($checkBoxUploadScript.Checked -and -not [string]::IsNullOrWhiteSpace($textBoxUploadScript.Text)) {
                    $scriptContent = Get-Content -Path $textBoxUploadScript.Text -Raw
                    $scriptBlock = [ScriptBlock]::Create($scriptContent)

                    # Disable UI elements if script content contains any user interface references
                    if ($scriptContent -match 'ShowDialog|MessageBox') {
                        Append-RichTextBox -richTextBox $richTextBoxOutput -text ("--- The script contains UI elements and cannot be executed remotely. ---") -color ([System.Drawing.Color]::Red)
                    } else {
                        Execute-RemoteCommand -ComputerName $RemotePC -Credential $cred -ScriptBlock $scriptBlock -Message "Uploaded Script"
                    }
                } elseif ($checkBoxCustomScript.Checked -and -not [string]::IsNullOrWhiteSpace($textBoxCustomScript.Text)) {
                    $customScript = $textBoxCustomScript.Text
                    $customScriptBlock = [ScriptBlock]::Create($customScript)

                    # Disable UI elements if custom script contains any user interface references
                    if ($customScript -match 'ShowDialog|MessageBox') {
                        Append-RichTextBox -richTextBox $richTextBoxOutput -text ("--- The custom script contains UI elements and cannot be executed remotely. ---") -color ([System.Drawing.Color]::Red)
                    } else {
                        Execute-RemoteCommand -ComputerName $RemotePC -Credential $cred -ScriptBlock $customScriptBlock -Message "Custom Script"
                    }
                }

                $upCount++
            } else {
                Append-RichTextBox -richTextBox $richTextBoxOutput -text ("--- The computer " + $RemotePC + " is down or unreachable. ---") -color ([System.Drawing.Color]::Red)
                $downCount++
            }
        }
        catch {
            Append-RichTextBox -richTextBox $richTextBoxOutput -text ("--- Failed to execute on " + $RemotePC + ": " + $_.Exception.Message + " ---") -color ([System.Drawing.Color]::Red)
            $downCount++
        }

        $progressBar.PerformStep()
    }

    Append-RichTextBox -richTextBox $richTextBoxOutput -text "--- Script execution completed. ---" -color ([System.Drawing.Color]::Blue)

    # Display summary of device statuses
    $summary = "Summary:`r`nTotal Devices: " + $RemotePCNames.Count + "`r`nDevices Up: " + $upCount + "`r`nDevices Down: " + $downCount
    Append-RichTextBox -richTextBox $richTextBoxOutput -text $summary -color ([System.Drawing.Color]::Blue)
})

# Function to stop execution
$buttonStop.Add_Click({
    # Logic to stop execution
    # Placeholder for now
    Append-RichTextBox -richTextBox $richTextBoxOutput -text "--- Execution stopped. ---" -color ([System.Drawing.Color]::Orange)
})

# Add copyright section
$labelCopyright = New-Object System.Windows.Forms.Label
$labelCopyright.Text = "© Mohammad Omar. All rights reserved. Visit: momar.tech"
$labelCopyright.Location = New-Object System.Drawing.Point(10, 760)
$labelCopyright.Size = New-Object System.Drawing.Size(670, 30)
$labelCopyright.Font = $defaultFont
$labelCopyright.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
$labelCopyright.Anchor = [System.Windows.Forms.AnchorStyles]::Bottom -bor [System.Windows.Forms.AnchorStyles]::Left -bor [System.Windows.Forms.AnchorStyles]::Right
$form.Controls.Add($labelCopyright)

# Show the form
$form.Add_Shown({$form.Activate()})
[void]$form.ShowDialog()
