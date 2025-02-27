<#
.SYNOPSIS
    A PowerShell GUI tool for managing computer objects in Active Directory, Entra ID, and Intune.

.DESCRIPTION
    This script provides a GUI-based tool that allows administrators to manage computer objects in 
    Active Directory, Entra ID (Azure AD), and Intune. The tool provides functionality to:
    
    - Join and disjoin computers from Active Directory domains, with support for selecting an Organizational Unit (OU).
    - Delete inactive or unwanted computer accounts from Active Directory.
    - Retrieve and display real-time system information such as:
        - Computer Name
        - IP Address
        - Domain Join Status
        - Entra ID Join Status (Hybrid or Azure AD Joined)
        - SCCM Agent Installation and Status
        - Co-Management (SCCM + Intune) Status
    - Join or disjoin the computer from Entra ID (Azure AD).
    - Enroll the computer into Intune as a personal device.
    - Provide a user-friendly interface with WPF-based GUI elements, color-coded status indicators, and real-time updates.

.PARAMETERS
    DefaultDomainController  - The default domain controller to query Active Directory.
    DefaultDomainName        - The default domain name used for domain joins.
    DefaultSearchBase        - The default Active Directory Organizational Unit (OU) path.

.FUNCTIONALITY
    - `Update-PCInfo`: Spawns a background job to gather system details, then updates the GUI via a DispatcherTimer.
    - `Join-ComputerWithOU`: Joins a computer to Active Directory with an assigned OU.
    - `Disjoin-ComputerFromDomain`: Removes a computer from Active Directory and places it in a workgroup.
    - `Delete-ComputerFromAD`: Deletes a computer account from Active Directory if it is inactive.
    - `Join-EntraID`: Uses `dsregcmd /join` to register the device with Entra ID.
    - `Disjoin-EntraID`: Uses `dsregcmd /leave` to unregister the device from Entra ID.
    - `Join-IntuneAsPersonalDevice`: Launches the Intune enrollment page for personal device enrollment.
    - `Show-OUWindow`: Displays an OU selection window for Active Directory join operations.
    - `Prompt-Credentials`: Prompts the user for Active Directory credentials when necessary.
    - `Prompt-Restart`: Prompts and initiates a system restart if required.
    - `Show-WPFMessage`: Displays formatted WPF-based message dialogs.

.REQUIREMENTS
    - Windows 10/11 or Windows Server with PowerShell 5.1+.
    - Administrative privileges to modify domain memberships.
    - SCCM (Configuration Manager) agent installed for co-management detection.
    - Active Directory module installed for domain operations.

.EXAMPLE
    # Run the script with default domain settings
    .\JoinUnjoinComputerTool.ps1

    # Run the script specifying a different domain controller
    .\JoinUnjoinComputerTool.ps1 -DefaultDomainController "DC02.company.local"

.NOTES
    Author  : Mohammad Abdulkader Omar
    Website : https://momar.tech
    Date    : 2025-01-20
    Version : 2.0
#>

###############################################################################
# PARAMETERS
###############################################################################
[CmdletBinding()]
Param(
    [string]$DefaultDomainController = "DC01.company.local",                  # Default Domain Controller
    [string]$DefaultDomainName       = "company.local",                       # Default Domain Name
    [string]$DefaultSearchBase       = "OU=Computers,DC=company,DC=local"     # Default Search Base
)

# Load the required WPF assemblies
Add-Type -AssemblyName PresentationFramework

# Temporarily relax the PowerShell execution policy for this session
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Unrestricted -Force

# Log buffer to capture messages before GUI is loaded
$LogBuffer = @()

# Global variable to store AD credentials
$Global:ADCreds = $null

# We will store references to our job and timer here:
$Global:PCInfoJob    = $null
$Global:PCInfoTimer  = $null

###############################################################################
# FUNCTIONS
###############################################################################

# Show-WPFMessage function
Function Show-WPFMessage {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,

        [Parameter(Mandatory = $false)]
        [string]$Title = "Message",

        [Parameter(Mandatory = $false)]
        [ValidateSet("Green","Orange","Red","Blue")]
        [string]$Color = "Red"
    )

    Add-Type -AssemblyName PresentationFramework

    switch ($Color) {
        "Green"  { $HeaderColor = "#28A745" }
        "Orange" { $HeaderColor = "#FFA500" }
        "Red"    { $HeaderColor = "#DC3545" }
        "Blue"   { $HeaderColor = "#0078D7" }
    }

    $xamlString = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        ResizeMode="NoResize"
        WindowStartupLocation="CenterScreen"
        SizeToContent="Height"
        Width="600">
    <Grid>
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
            <RowDefinition Height="Auto"/>
        </Grid.RowDefinitions>

        <!-- Header Section -->
        <Border Grid.Row="0" Background="$HeaderColor"  Padding="10">
            <TextBlock Text="$Title"
                       Foreground="White"
                       FontSize="16"
                       FontWeight="Bold"
                       VerticalAlignment="Center"/>
        </Border>

        <!-- Message Section -->
        <TextBlock Grid.Row="1"
                   x:Name="txtMessage"
                   TextWrapping="Wrap"
                   Margin="20"
                   FontSize="14"
                   Foreground="#333333"
                   HorizontalAlignment="Center"
                   VerticalAlignment="Center"/>

        <!-- Button Section -->
        <Button Grid.Row="2"
                x:Name="btnOK"
                Content="OK"
                Width="80"
                Height="30"
                Margin="10"
                HorizontalAlignment="Center"
                Background="$HeaderColor"
                Foreground="White"
                FontWeight="Bold"
                BorderThickness="0"
                Cursor="Hand"/>
    </Grid>
</Window>
"@

    try {
        $xamlXml = [xml]$xamlString
        $reader = New-Object System.Xml.XmlNodeReader($xamlXml)
        $window = [System.Windows.Markup.XamlReader]::Load($reader)

        $txtMessage = $window.FindName("txtMessage")
        $txtMessage.Text = $Message

        $btnOK = $window.FindName("btnOK")
        $btnOK.Add_Click({ $window.Close() })

        [void]$window.ShowDialog()
    }
    catch {
        Write-Error "Failed to show message: $($_.Exception.Message)"
    }
}

Function Show-WPFConfirmation {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$Message,

        [Parameter(Mandatory = $false)]
        [string]$Title = "Confirmation",

        [Parameter(Mandatory = $false)]
        [ValidateSet("Green", "Orange", "Red", "Blue")]
        [string]$Color = "Blue"
    )

    Add-Type -AssemblyName PresentationFramework

    switch ($Color) {
        "Green"  { $HeaderColor = "#28A745" }
        "Orange" { $HeaderColor = "#FFA500" }
        "Red"    { $HeaderColor = "#DC3545" }
        "Blue"   { $HeaderColor = "#0078D7" }
    }

    $xamlString = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        ResizeMode="NoResize"
        WindowStartupLocation="CenterScreen"
        SizeToContent="WidthAndHeight">
    <Grid>
      <Grid.RowDefinitions>
        <RowDefinition Height="Auto"/>
        <RowDefinition Height="Auto"/>
        <RowDefinition Height="Auto"/>
      </Grid.RowDefinitions>

      <!-- Header Section -->
      <Border Grid.Row="0" Background="$HeaderColor" Padding="10">
        <TextBlock Text="$Title" Foreground="White" FontSize="16" FontWeight="Bold" HorizontalAlignment="Center"/>
      </Border>

      <!-- Message Section -->
      <TextBlock Grid.Row="1" x:Name="txtMessage" TextWrapping="Wrap" Margin="20" FontSize="14" Foreground="#333333" HorizontalAlignment="Center" VerticalAlignment="Center" Text="$Message"/>

      <!-- Button Section -->
      <StackPanel Grid.Row="2" Orientation="Horizontal" HorizontalAlignment="Center" Margin="0,10,0,10">
        <Button x:Name="btnYes" Content="Yes" Width="80" Height="30" Margin="10" Background="$HeaderColor" Foreground="White" FontWeight="Bold" BorderThickness="0" Cursor="Hand"/>
        <Button x:Name="btnNo" Content="No" Width="80" Height="30" Margin="10" Background="$HeaderColor" Foreground="White" FontWeight="Bold" BorderThickness="0" Cursor="Hand"/>
      </StackPanel>
    </Grid>
</Window>
"@

    try {
        $xamlXml = [xml]$xamlString
        $reader = New-Object System.Xml.XmlNodeReader($xamlXml)
        $window = [System.Windows.Markup.XamlReader]::Load($reader)

        $btnYes = $window.FindName("btnYes")
        $btnNo  = $window.FindName("btnNo")

        $btnYes.Add_Click({
            $window.DialogResult = $true
            $window.Close()
        })
        $btnNo.Add_Click({
            $window.DialogResult = $false
            $window.Close()
        })

        [void]$window.ShowDialog()
        return $window.DialogResult
    }
    catch {
        Write-Error "Failed to show confirmation: $($_.Exception.Message)"
    }
}

Function Test-Admin {
    if (-not (New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        Show-WPFMessage -Message "Run this script as Administrator." -Title "Insufficient Privileges" -Color Red
        Exit
    }
}

Function Prompt-Credentials {
    [CmdletBinding()]
    param ()

    if ($Global:ADCreds -and $Global:ADCreds.UserName) {
        return $Global:ADCreds
    }

    [void][System.Reflection.Assembly]::LoadWithPartialName("presentationframework")

    $HeaderColor = "#0078D7"
    $xamlString = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        ResizeMode="NoResize"
        WindowStartupLocation="CenterScreen"
        SizeToContent="WidthAndHeight">

      <Grid>
        <Grid.RowDefinitions>
          <RowDefinition Height="Auto"/>
          <RowDefinition Height="Auto"/>
          <RowDefinition Height="Auto"/>
        </Grid.RowDefinitions>
        <!-- Header Section -->
        <Border Grid.Row="0" Background="$HeaderColor" Padding="10">
          <TextBlock Text="Enter AD Credentials"
                     Foreground="White"
                     FontSize="16"
                     FontWeight="Bold"
                     HorizontalAlignment="Center"/>
        </Border>
        <!-- Fields Section -->
        <StackPanel Grid.Row="1" Margin="20">
          <StackPanel Orientation="Horizontal" Margin="0,10,0,10">
            <Label Content="Username:" Width="100" VerticalAlignment="Center"/>
            <TextBox x:Name="UsernameBox" Width="250"/>
          </StackPanel>
          <StackPanel Orientation="Horizontal" Margin="0,10,0,10">
            <Label Content="Password:" Width="100" VerticalAlignment="Center"/>
            <PasswordBox x:Name="PasswordBox" Width="250"/>
          </StackPanel>
        </StackPanel>
        <!-- Buttons Section -->
        <StackPanel Grid.Row="2" Orientation="Horizontal" HorizontalAlignment="Center" Margin="0,10,0,10">
          <Button x:Name="OkButton" Content="OK" Width="100" Height="30" Margin="10" Background="$HeaderColor" Foreground="White" FontWeight="Bold" BorderThickness="0" Cursor="Hand"/>
          <Button x:Name="CancelButton" Content="Cancel" Width="100" Height="30" Margin="10" Background="$HeaderColor" Foreground="White" FontWeight="Bold" BorderThickness="0" Cursor="Hand"/>
        </StackPanel>
      </Grid>

</Window>
"@

    try {
        $xamlXml = [xml]$xamlString
        $reader = New-Object System.Xml.XmlNodeReader($xamlXml)
        $window = [System.Windows.Markup.XamlReader]::Load($reader)

        $usernameBox = $window.FindName("UsernameBox")
        $passwordBox = $window.FindName("PasswordBox")
        $okButton     = $window.FindName("OkButton")
        $cancelButton = $window.FindName("CancelButton")

        $Global:ADCreds = $null

        $okButton.Add_Click({
            if (-not $usernameBox.Text -or -not $passwordBox.Password) {
                Show-WPFMessage -Message "Username and Password required" -Title "Info" -Color Blue
                return
            }
            try {
                $secPwd = ConvertTo-SecureString $passwordBox.Password -AsPlainText -Force
                $cred = New-Object System.Management.Automation.PSCredential ($usernameBox.Text, $secPwd)
            }
            catch {
                Show-WPFMessage -Message "Error creating credentials." -Title "Error" -Color Red
                return
            }
            try {
                $ldapPath = "LDAP://$DefaultDomainController"
                $entry = New-Object System.DirectoryServices.DirectoryEntry($ldapPath, $cred.UserName, $cred.GetNetworkCredential().Password)
                $dummy = $entry.Properties["defaultNamingContext"].Value

                Show-WPFMessage -Message "Domain credentials validated." -Title "Success" -Color Green
                $Global:ADCreds = $cred
                $window.Close()
            }
            catch {
                Show-WPFMessage -Message "Domain credential validation failed." -Title "Error" -Color Red
            }
        })

        $cancelButton.Add_Click({
            $Global:ADCreds = $null
            $window.Close()
        })
        
        [void]$window.ShowDialog()
        return $Global:ADCreds
    }
    catch {
        Write-Error $_.Exception.Message
    }
}

Function Prompt-Restart {
    [void][System.Reflection.Assembly]::LoadWithPartialName("presentationframework")
    [void][System.Reflection.Assembly]::LoadWithPartialName("windowsbase")

    [xml]$RestartXAML = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        ResizeMode="NoResize"
        WindowStartupLocation="CenterScreen"
        SizeToContent="WidthAndHeight">
  <Grid>
    <Grid>
        <Grid.RowDefinitions>
          <RowDefinition Height="Auto"/>
          <RowDefinition Height="Auto"/>
          <RowDefinition Height="Auto"/>
        </Grid.RowDefinitions>

        <!-- Header Section -->
        <Border Grid.Row='0' Background='#0078D7' Padding='5'>
            <StackPanel Orientation="Horizontal" HorizontalAlignment="Center">
                <TextBlock Text="Restart Confirmation" Foreground="White" FontSize="18" FontWeight="Bold" VerticalAlignment="Center"/>
            </StackPanel>
        </Border>

        <!-- Content Section -->
        <StackPanel Grid.Row="1" Margin="10" VerticalAlignment="Center" HorizontalAlignment="Center">
            <TextBlock Text="The computer needs to restart to complete the operation." FontSize="14" TextAlignment="Center" Margin="10"/>
            <TextBlock Text="Do you want to restart now?" FontSize="14" FontWeight="Bold" TextAlignment="Center" Margin="10"/>
        </StackPanel>

        <!-- Footer Section -->
        <StackPanel Grid.Row="2" Orientation="Horizontal" HorizontalAlignment="Center" Margin="10">
            <Button x:Name="YesButton" Content="Yes, Restart" Width="120" Height="30" Background="#32CD32" Foreground="White" FontWeight="Bold" Margin="5"/>
            <Button x:Name="NoButton" Content="No, Postpone" Width="120" Height="30" Background="#FF6347" Foreground="White" FontWeight="Bold" Margin="5"/>
        </StackPanel>
      </Grid>
  </Grid>
</Window>
"@

    try {
        $Reader = New-Object System.Xml.XmlNodeReader $RestartXAML
        $RestartWindow = [System.Windows.Markup.XamlReader]::Load($Reader)

        $YesButton = $RestartWindow.FindName('YesButton')
        $NoButton  = $RestartWindow.FindName('NoButton')

        $Global:RestartConfirmed = $false

        $YesButton.Add_Click({
            $Global:RestartConfirmed = $true
            $RestartWindow.Close()
        })
        $NoButton.Add_Click({
            $Global:RestartConfirmed = $false
            $RestartWindow.Close()
        })

        $RestartWindow.WindowStartupLocation = "CenterScreen"
        [void]$RestartWindow.ShowDialog()

        if ($Global:RestartConfirmed) {
            Show-WPFMessage -Message "Restarting the computer..." -Title "Warning" -Color Orange
            Restart-Computer -Force
        }
        else {
            Show-WPFMessage -Message "Restart postponed by the user." -Title "Info" -Color Blue
        }
    }
    catch {
        Show-WPFMessage -Message "An error occurred in the Restart Confirmation Window: $($_.Exception.Message)" -Title "Error" -Color Red
    }
}

Function Update-PCInfo {

    # 1) Clear any old job if it’s finished or failed
    if ($Global:PCInfoJob -and ($Global:PCInfoJob.State -in @('Completed','Failed','Stopped'))) {
        Receive-Job -Job $Global:PCInfoJob -ErrorAction SilentlyContinue | Out-Null
        Remove-Job  -Job $Global:PCInfoJob -Force | Out-Null
        $Global:PCInfoJob = $null
    }
    elseif ($Global:PCInfoJob -and ($Global:PCInfoJob.State -eq 'Running')) {
        # If you prefer to allow only one job at a time, uncomment next line:
        Show-WPFMessage -Message "A PC Info update is already in progress." -Title "Info" -Color Blue
        return
    }

    # 2) Start a background job to gather PC info
    $Global:PCInfoJob = Start-Job -ScriptBlock {
        try {
            # 1) Basic System Info
            $computerSystem = Get-CimInstance -ClassName Win32_ComputerSystem -ErrorAction Stop
            $ComputerName   = $computerSystem.Name
            $DomainStatus   = if ($computerSystem.PartOfDomain) { "Domain Joined" } else { "Workgroup" }

            # 2) Primary IP
            $IPAddress = $null
            try {
                $nic = Get-NetAdapter -Physical | Where-Object { $_.Status -eq 'Up' } |
                       Sort-Object -Property LinkSpeed -Descending | Select-Object -First 1
                if ($nic) {
                    $ip = Get-NetIPAddress -InterfaceIndex $nic.IfIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue |
                          Where-Object { $_.IPAddress -notmatch '^127\.|^169\.254' } |
                          Select-Object -ExpandProperty IPAddress -First 1
                    if ($ip) { $IPAddress = $ip }
                }
                if (-not $IPAddress) {
                    $IPAddress = Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue |
                                 Where-Object { $_.IPAddress -notmatch '^127\.|^169\.254' } |
                                 Select-Object -ExpandProperty IPAddress -First 1
                }
            }
            catch { }

            # 3) Entra ID (Azure AD) Status
            $dsregcmdOutput = dsregcmd /status 2>$null | Out-String
            if ($dsregcmdOutput -match "AzureAdJoined\s*:\s*YES" -and $dsregcmdOutput -match "DomainJoined\s*:\s*YES") {
                $EntraIDStatus = "Hybrid AD Joined"
            }
            elseif ($dsregcmdOutput -match "AzureAdJoined\s*:\s*YES") {
                $EntraIDStatus = "Azure AD Joined"
            }
            else {
                $EntraIDStatus = "Not Joined"
            }

            # 4) SCCM (ccmexec)
            $SCCMStatus = "Not Installed"
            $SCCMColor  = "#DC3545"
            $ccmExecService = Get-Service -Name ccmexec -ErrorAction SilentlyContinue
            if ($ccmExecService) {
                if ($ccmExecService.Status -eq 'Running') {
                    $SCCMStatus = "SCCM Client (Running)"
                    $SCCMColor  = "#28A745"
                }
                else {
                    $SCCMStatus = "SCCM Client (Stopped)"
                    $SCCMColor  = "#FFA500"
                }
            }

            # 5) Co-Management
            $CoManagementStatus = "Not Detected"
            $CoManagementColor  = "#DC3545"
            try {
                $cmConfig = Get-WmiObject -Namespace 'root\ccm\CoManagementHandler' -Class 'CoManagement_Configuration' -ErrorAction Stop
                if ($cmConfig -and $cmConfig.Enable) {
                    $CoManagementStatus = "Co-Management Enabled"
                    $CoManagementColor  = "#28A745"
                }
                elseif ($cmConfig) {
                    $CoManagementStatus = "SCCM Present - Co-Management Disabled"
                    $CoManagementColor  = "#DC3545"
                }
            } catch { }

            # Registry checks
            $CoManagementRegPath = "HKLM:\SOFTWARE\Microsoft\CCM"
            if (Test-Path $CoManagementRegPath) {
                try {
                    $val = Get-ItemProperty -Path $CoManagementRegPath -Name "CoManagementFlags" -ErrorAction SilentlyContinue
                    if ($val) {
                        $flags = $val.CoManagementFlags
                        if ($CoManagementStatus -eq "Not Detected") {
                            $CoManagementStatus = "Co-Management Flags=$flags"
                            $CoManagementColor  = "#28A745"
                        }
                    }
                } catch { }
            }
            $AutoEnrollRegPath = "HKLM:\Software\Policies\Microsoft\Windows\CurrentVersion\MDM"
            if (Test-Path $AutoEnrollRegPath) {
                try {
                    $MDMValue = Get-ItemProperty -Path $AutoEnrollRegPath -Name "AutoEnrollMDM" -ErrorAction SilentlyContinue
                    if ($MDMValue -and $MDMValue.AutoEnrollMDM -eq 1) {
                        $CoManagementStatus = "Intune Auto Enrollment Enabled"
                        $CoManagementColor  = "#28A745"
                    }
                } catch { }
            }

            # Build a single PSCustomObject
            [PSCustomObject]@{
                ComputerName       = $ComputerName
                DomainStatus       = $DomainStatus
                IPAddress          = if ($IPAddress) { $IPAddress } else { "N/A" }
                EntraIDStatus      = $EntraIDStatus
                SCCMStatus         = $SCCMStatus
                SCCMColor          = $SCCMColor
                CoManagementStatus = $CoManagementStatus
                CoManagementColor  = $CoManagementColor
            }
        }
        catch {
            # Let the job throw if there's an error
            throw $_
        }
    }

    # 3) Use a DispatcherTimer to poll the job and update UI
    if ($Global:PCInfoTimer) {
        # Stop old timer if still around
        $Global:PCInfoTimer.Stop()
        $Global:PCInfoTimer = $null
    }

    Add-Type -AssemblyName PresentationFramework -ErrorAction SilentlyContinue
    $Global:PCInfoTimer = New-Object System.Windows.Threading.DispatcherTimer
    $Global:PCInfoTimer.Interval = [TimeSpan]::FromMilliseconds(500)

    $Global:PCInfoTimer.Add_Tick({
        if (-not $Global:PCInfoJob) { return }

        # Collect any new output from the job (usually just once).
        $newData = Receive-Job -Job $Global:PCInfoJob -Keep -ErrorAction SilentlyContinue
        if ($newData) {
            # We expect a single PSCustomObject. Let's take the last item in case.
            $result = $newData[-1]

            # Update UI via dispatcher
            try {
                $Global:PcNameBlock.Dispatcher.Invoke([action]{
                    $Global:PcNameBlock.Text = $result.ComputerName
                })
                $Global:PcIPAddressBlock.Dispatcher.Invoke([action]{
                    $Global:PcIPAddressBlock.Text = $result.IPAddress
                })
                $Global:PcDomainStatusBlock.Dispatcher.Invoke([action]{
                    $Global:PcDomainStatusBlock.Text = $result.DomainStatus
                    $Global:PcDomainStatusBlock.Background = if ($result.DomainStatus -eq "Domain Joined") { "#28A745" } else { "#DC3545" }
                    $Global:PcDomainStatusBlock.Foreground = "White"
                })
                $Global:PcEntraIDStatusBlock.Dispatcher.Invoke([action]{
                    $Global:PcEntraIDStatusBlock.Text = $result.EntraIDStatus
                    $Global:PcEntraIDStatusBlock.Background = if ($result.EntraIDStatus -match "Joined") { "#28A745" } else { "#DC3545" }
                    $Global:PcEntraIDStatusBlock.Foreground = "White"
                })
                $Global:SCCMStatusBlock.Dispatcher.Invoke([action]{
                    $Global:SCCMStatusBlock.Text = $result.SCCMStatus
                    $Global:SCCMStatusBlock.Background = $result.SCCMColor
                    $Global:SCCMStatusBlock.Foreground = "White"
                })
                $Global:CoManagementBlock.Dispatcher.Invoke([action]{
                    $Global:CoManagementBlock.Text = $result.CoManagementStatus
                    $Global:CoManagementBlock.Background = $result.CoManagementColor
                    $Global:CoManagementBlock.Foreground = "White"
                })
            }
            catch {
                Show-WPFMessage -Message "Error updating UI: $($_.Exception.Message)" -Title "Error" -Color Red
            }
        }

        # If the job is no longer running, clean up
        if ($Global:PCInfoJob.State -in @('Completed','Failed','Stopped')) {
            $Global:PCInfoTimer.Stop()
            Receive-Job -Job $Global:PCInfoJob -ErrorAction SilentlyContinue | Out-Null
            Remove-Job -Job $Global:PCInfoJob -Force | Out-Null
            $Global:PCInfoJob = $null
        }
    })
    $Global:PCInfoTimer.Start()
}


Function ConvertFrom-HexToColor {
    param([string]$HexColor)
    return [System.Windows.Media.ColorConverter]::ConvertFromString($HexColor)
}

Function Join-ComputerWithOU {
    param (
        [string]$DomainName,
        [string]$OUPath
    )
    try {
        $CurrentDomain = (Get-WmiObject -Class Win32_ComputerSystem).Domain
        if ($CurrentDomain -eq $DomainName) {
            Show-WPFMessage -Message "The computer '$env:COMPUTERNAME' is already a member of the domain '$DomainName'. No action is needed." -Title "Info" -Color Blue
            return
        }

        Add-Computer -DomainName $DomainName -OUPath $OUPath -Credential $Global:ADCreds -Force
        Show-WPFMessage -Message "Computer successfully joined to domain
        - Domain :  $DomainName
        - OU     :  $OUPath." -Title "Success" -Color Green

        Update-PCInfo
        Prompt-Restart
    }
    catch {
        if ($_.Exception.Message -match "The server is not operational") {
            Show-WPFMessage -Message "Failed to connect to Active Directory. Please check and update the following:
            - Domain Controller
            - Domain Name
            - OU Search Base
            - AD Credential" -Title "Error" -Color Red
        }
        else {
            Show-WPFMessage -Message "Failed to join the computer to domain: $($_.Exception.Message)" -Title "Error" -Color Red
        }
    }
}

Function Disjoin-ComputerFromDomain {
    param ([string]$ComputerName)
    $ComputerDomainStatus = (Get-WmiObject -Class Win32_ComputerSystem).PartOfDomain

    if ($ComputerDomainStatus) {
        try {
            $Confirmation = Show-WPFConfirmation -Message "Are you sure you want to disjoin the computer '$ComputerName' from the domain?" -Title "Disjoin Confirmation" -Color Blue
            if (-not $Confirmation) {
                Show-WPFMessage -Message "Deletion operation canceled by the user." -Title "Info" -Color Blue
                return
            }

            Remove-Computer -WorkgroupName "WORKGROUP" -Credential $Global:ADCreds -Force
            Show-WPFMessage -Message "Computer '$ComputerName' successfully disjoined from the domain." -Title "Success" -Color Green

            Update-PCInfo
            Prompt-Restart
        }
        catch {
            if ($_.Exception.Message -match "The server is not operational") {
                Show-WPFMessage -Message "Failed to connect to Active Directory. Please check and update the following:
                - Domain Controller
                - Domain Name
                - OU Search Base" -Title "Error" -Color Red
            }
            else {
                Show-WPFMessage -Message  "Failed to disjoin computer '$ComputerName' from the domain: $($_.Exception.Message)" -Title "Error" -Color Red
            }
        }
    }
    else {
        Show-WPFMessage -Message "The computer '$ComputerName' is not part of a domain. Skipping disjoin operation." -Title "Info" -Color Blue
    }
}

Function Delete-ComputerFromAD {
    param (
        [string]$ComputerName,
        [string]$DomainController,
        [string]$SearchBase
    )
    try {
        if (-not $Global:ADCreds) {
            Show-WPFMessage -Message "Credentials not found. Prompting for credentials..." -Title "Info" -Color Blue
            $Global:ADCreds = Prompt-Credentials
            if (-not $Global:ADCreds) {
                Show-WPFMessage -Message "No credentials provided. Exiting function." -Title "Error" -Color Red
                return
            }
        }

        $Confirmation = Show-WPFConfirmation -Message "Are you sure you want to delete the computer '$ComputerName' from Active Directory?" -Title "Delete Confirmation" -Color Blue
        if (-not $Confirmation) {
            Show-WPFMessage -Message "Deletion operation canceled by the user." -Title "Info" -Color Blue
            return
        }

        $LDAPPath = "LDAP://$DomainController/$SearchBase"
        $DirectoryEntry = New-Object System.DirectoryServices.DirectoryEntry($LDAPPath, $Global:ADCreds.UserName, $Global:ADCreds.GetNetworkCredential().Password)
        $Searcher = New-Object System.DirectoryServices.DirectorySearcher($DirectoryEntry)
        $Searcher.Filter = "(sAMAccountName=$ComputerName`$)"
        $SearchResult = $Searcher.FindOne()

        if ($SearchResult) {
            $ComputerEntry = $SearchResult.GetDirectoryEntry()
            $uac = $ComputerEntry.Properties["userAccountControl"].Value
            $ACCOUNTDISABLE = 2

            if (-not ($uac -band $ACCOUNTDISABLE)) {
                Show-WPFMessage -Message "Deletion aborted: The computer '$ComputerName' appears to be active (joined to a domain)." -Title "Error" -Color Red
                return
            }

            $ComputerEntry.DeleteTree()
            $ComputerEntry.CommitChanges()
            Show-WPFMessage -Message "Successfully deleted computer '$ComputerName' from Active Directory." -Title "Success" -Color Green
        }
        else {
            Show-WPFMessage -Message "Computer '$ComputerName' was not found in Active Directory." -Title "Info" -Color Blue
        }
    }
    catch {
        if ($_.Exception.Message -match "The server is not operational") {
            Show-WPFMessage -Message "Failed to connect to Active Directory. Please check and update the following:
            - Domain Controller
            - Domain Name
            - OU Search Base" -Title "Error" -Color Red
        }
        else {
            Show-WPFMessage -Message "Failed to delete the computer from Active Directory: $($_.Exception.Message)" -Title "Error" -Color Red
        }
    }
}

Function Join-EntraID {
    try {
        $Confirmation = Show-WPFConfirmation -Message "Are you sure you want to join the computer '$ComputerName' to EntraID?" -Title "Disjoin Confirmation" -Color Blue
        if (-not $Confirmation) {
            Show-WPFMessage -Message "Joining operation canceled by the user." -Title "Info" -Color Blue
            return
        }
        Start-Process -FilePath "C:\Windows\System32\dsregcmd.exe" -ArgumentList "/join" -NoNewWindow -Wait
        Show-WPFMessage -Message "Device successfully joined to Entra ID." -Title "Success" -Color Green
        Update-PCInfo
    }
    catch {
        Show-WPFMessage -Message "Failed to join Entra ID: $($_.Exception.Message)" -Title "Error" -Color Red
    }
}

Function Disjoin-EntraID {
    try {
        $Confirmation = Show-WPFConfirmation -Message "Are you sure you want to remove the computer '$ComputerName' from EntraID?" -Title "Disjoin Confirmation" -Color Blue
        if (-not $Confirmation) {
            Show-WPFMessage -Message "Remove operation canceled by the user." -Title "Info" -Color Blue
            return
        }
        Start-Process -FilePath "C:\Windows\System32\dsregcmd.exe" -ArgumentList "/leave" -NoNewWindow -Wait
        Show-WPFMessage -Message "Device removed from Entra ID." -Title "Success" -Color Red
        Update-PCInfo
    }
    catch {
        Show-WPFMessage -Message "Failed to remove from Entra ID: $($_.Exception.Message)" -Title "Error" -Color Red
    }
}

Function Join-IntuneAsPersonalDevice {
    try {
        $Confirmation = Show-WPFConfirmation -Message "Are you sure you want to add the computer '$ComputerName' to Intune?" -Title "Disjoin Confirmation" -Color Blue
        if (-not $Confirmation) {
            Show-WPFMessage -Message "Operation canceled by the user." -Title "Info" -Color Blue
            return
        }
        Start-Process "ms-device-enrollment:?mode=mdm"
        Show-WPFMessage -Message "Opening Intune enrollment page. Follow the steps to complete enrollment." -Title "Intune Enrollment" -Color Blue
        Update-PCInfo
    }
    catch {
        Show-WPFMessage -Message "Failed to launch Intune enrollment: $($_.Exception.Message)" -Title "Error" -Color Red
    }
}

Function Show-OUWindow {
    [xml]$OUXAML = @"
<Window xmlns='http://schemas.microsoft.com/winfx/2006/xaml/presentation'
        xmlns:x='http://schemas.microsoft.com/winfx/2006/xaml'
        Title='Select Organizational Unit'
        Width='700'
        Height='450'
        Background='#F0F0F0'
        WindowStartupLocation='CenterScreen'
        ResizeMode='NoResize'>
    <Grid>
        <Grid.RowDefinitions>
            <RowDefinition Height='Auto'/>   <!-- Search Panel -->
            <RowDefinition Height='*'/>      <!-- DataGrid -->
            <RowDefinition Height='Auto'/>   <!-- Buttons -->
        </Grid.RowDefinitions>

        <!-- Search Panel -->
        <StackPanel Grid.Row='0' Orientation='Horizontal' Margin='10'>
            <Label Content='Search:' VerticalAlignment='Center'/>
            <TextBox x:Name='SearchTextBox' Width='300' Margin='5,0,0,0'/>
            <Button x:Name='SearchButton' Content='Search' Width='80' Margin='5,0,0,0'
                    Background='#0078D7' Foreground='White'/>
        </StackPanel>

        <!-- DataGrid for OUs -->
        <DataGrid x:Name='OUDataGrid'
                  Grid.Row='1'
                  AutoGenerateColumns='False'
                  CanUserAddRows='False'
                  IsReadOnly='True'
                  BorderBrush='#1E90FF'
                  BorderThickness='1'
                  Margin='10'>
            <DataGrid.Columns>
                <DataGridTextColumn Header='Name' Binding='{Binding Name}' Width='150'/>
                <DataGridTextColumn Header='Description' Binding='{Binding Description}' Width='250'/>
                <DataGridTextColumn Header='Distinguished Name' Binding='{Binding DistinguishedName}' Width='*'/>
            </DataGrid.Columns>
        </DataGrid>

        <!-- Buttons -->
        <StackPanel Grid.Row='2' Orientation='Horizontal' HorizontalAlignment='Right' Margin='10'>
            <Button x:Name='SelectButton' Content='Select' Width='100' Height='30' Margin='5'
                    Background='#32CD32' Foreground='White' FontWeight='Bold'/>
            <Button x:Name='CancelButton' Content='Cancel' Width='100' Height='30' Margin='5'
                    Background='#FF6347' Foreground='White' FontWeight='Bold'/>
        </StackPanel>
    </Grid>
</Window>
"@

    try {
        $OUReader = New-Object System.Xml.XmlNodeReader $OUXAML
        $OUWindow = [System.Windows.Markup.XamlReader]::Load($OUReader)

        # Retrieve controls
        $OUDataGrid    = $OUWindow.FindName('OUDataGrid')
        $SearchTextBox = $OUWindow.FindName('SearchTextBox')
        $SearchButton  = $OUWindow.FindName('SearchButton')
        $SelectButton  = $OUWindow.FindName('SelectButton')
        $CancelButton  = $OUWindow.FindName('CancelButton')

        # Retrieve OUs from Active Directory and store them in $AllOUs
        $AllOUs = @()
        try {
            $DomainController = $DomainControllerBox.Text.Trim()
            $SearchBase       = $SearchBaseBox.Text.Trim()
            $LDAPPath         = "LDAP://$DomainController/$SearchBase"

            $DirectoryEntry = New-Object DirectoryServices.DirectoryEntry(
                $LDAPPath,
                $Global:ADCreds.UserName,
                $Global:ADCreds.GetNetworkCredential().Password
            )
            $Searcher = New-Object DirectoryServices.DirectorySearcher($DirectoryEntry)
            $Searcher.Filter = "(objectClass=organizationalUnit)"
            $Searcher.PropertiesToLoad.Add("name") | Out-Null
            $Searcher.PropertiesToLoad.Add("description") | Out-Null
            $Searcher.PropertiesToLoad.Add("distinguishedName") | Out-Null

            $Results = $Searcher.FindAll()

            foreach ($Result in $Results) {
                $OUItem = [PSCustomObject]@{
                    Name              = $Result.Properties["name"][0]
                    Description       = ($Result.Properties["description"] -join ", ") -replace "^$", "N/A"
                    DistinguishedName = $Result.Properties["distinguishedName"][0]
                }
                $AllOUs += $OUItem
            }

            # Set the initial DataGrid ItemsSource to all retrieved OUs
            $OUDataGrid.ItemsSource = $AllOUs
        }
        catch {
            if ($_.Exception.Message -match "The server is not operational") {
                Show-WPFMessage -Message "Failed to connect to Active Directory. Please check and update the following:
                - Domain Controller
                - Domain Name
                - OU Search Base" -Title "Error" -Color Red
            }
            else {
                Show-WPFMessage -Message "Failed to retrieve OUs: $($_.Exception.Message)" -Title "Error" -Color Red
            }
        }

        # Add search functionality: filter the OU list when Search is clicked.
        $SearchButton.Add_Click({
            $searchText = $SearchTextBox.Text.Trim()
            if ($searchText -eq "") {
                # Reset to all OUs if search text is empty.
                $OUDataGrid.ItemsSource = $AllOUs
            }
            else {
                $filteredOUs = @(
                    $AllOUs | Where-Object {
                        $_.Name -match $searchText -or
                        $_.Description -match $searchText -or
                        $_.DistinguishedName -match $searchText
                    }
                )
                $OUDataGrid.ItemsSource = $filteredOUs
            }
        })

        # Handle selection and cancellation
        $SelectedOU = $null
        $SelectButton.Add_Click({
            $SelectedOU = $OUDataGrid.SelectedItem
            if ($SelectedOU -ne $null) {
                $SelectedOUBox.Text = $SelectedOU.DistinguishedName
                Show-WPFMessage -Message "Selected OU: $($SelectedOU.DistinguishedName)" -Title "Info" -Color Blue
                $OUWindow.Close()
            }
            else {
                Show-WPFMessage -Message "No OU selected. Please select an OU before proceeding." -Title "Error" -Color Red
            }
        })
        $CancelButton.Add_Click({
            $OUWindow.Close()
        })

        [void]$OUWindow.ShowDialog()
    }
    catch {
        Show-WPFMessage -Message "Failed to load the OU selection window: $($_.Exception.Message)" -Title "Error" -Color Red
    }
}


###############################################################################
# MAIN GUI
###############################################################################

Function Show-MainGUI {
    [xml]$XAML = @"
<Window xmlns='http://schemas.microsoft.com/winfx/2006/xaml/presentation'
        xmlns:x='http://schemas.microsoft.com/winfx/2006/xaml'
        Title='Join / Unjoin Computer Tool' 
        Background='#F8F8F8' 
        WindowStartupLocation='CenterScreen' 
        ResizeMode='NoResize'
        SizeToContent="WidthAndHeight">
    <Grid>
        <Grid.RowDefinitions>
            <RowDefinition Height='Auto'/>   <!-- Header -->
            <RowDefinition Height='*'/>      <!-- Main Content -->
            <RowDefinition Height='Auto'/>   <!-- Footer -->
        </Grid.RowDefinitions>

        <!-- Header Section -->
        <Border Grid.Row='0' Background='#0078D7' Padding='15'>
            <StackPanel Orientation="Horizontal" HorizontalAlignment="Center">
                <TextBlock Text="Join / Unjoin Computer Tool"
                           Foreground="White"
                           FontSize="24"
                           FontWeight="Bold"
                           VerticalAlignment="Center"/>
            </StackPanel>
        </Border>

        <!-- Main Content Section -->
        <StackPanel Grid.Row="1" Margin="20" Orientation="Vertical" VerticalAlignment="Top">
            <!-- First Section: Domain Controller, Domain Name, Search Base OU -->
            <Border BorderBrush="#D3D3D3" BorderThickness="0.5"  Padding="10"  Margin="0,5,0,5">
                <StackPanel Orientation="Vertical">
                    <TextBlock Text="Domain Configuration:" FontSize="16" FontWeight="Bold" Margin="0,0,0,10"/>
                    <Grid>
                        <Grid.RowDefinitions>
                            <RowDefinition Height="Auto"/>
                            <RowDefinition Height="Auto"/>
                            <RowDefinition Height="Auto"/>
                            <RowDefinition Height="Auto"/>
                        </Grid.RowDefinitions>
                        <Grid.ColumnDefinitions>
                            <ColumnDefinition Width="200"/>
                            <ColumnDefinition Width="*"/>
                        </Grid.ColumnDefinitions>

                        <!-- Domain Controller -->
                        <TextBlock Grid.Row="0" Grid.Column="0" Text="Domain Controller:" FontSize="14" FontWeight="Bold" VerticalAlignment="Center"/>
                        <TextBox Grid.Row="0" Grid.Column="1" x:Name="DomainControllerBox" FontSize="14" Text="$DefaultDomainController"
                                 BorderBrush="#1E90FF" BorderThickness="1" Padding="2" Margin="0,5,0,0"/>

                        <!-- Domain Name -->
                        <TextBlock Grid.Row="1" Grid.Column="0" Text="Domain Name:" FontSize="14" FontWeight="Bold" VerticalAlignment="Center"/>
                        <TextBox Grid.Row="1" Grid.Column="1" x:Name="DomainNameBox"  FontSize="14" Text="$DefaultDomainName"
                                 BorderBrush="#1E90FF" BorderThickness="1" Padding="2" Margin="0,5,0,0"/>

                        <!-- Search Base OU -->
                        <TextBlock Grid.Row="2" Grid.Column="0" Text="Search Base (OU):" FontSize="14" FontWeight="Bold" VerticalAlignment="Center"/>
                        <TextBox Grid.Row="2" Grid.Column="1" x:Name="SearchBaseBox"  FontSize="14" Text="$DefaultSearchBase"
                                 BorderBrush="#1E90FF" BorderThickness="1" Padding="2" Margin="0,5,0,0"/>

                        <!-- Selected OU Section -->
                        <TextBlock Grid.Row="3" Grid.Column="0" Text="Selected OU:" FontSize="14" FontWeight="Bold" VerticalAlignment="Center" Margin="0,5,10,5" Visibility="Collapsed"/>
                        <TextBox Grid.Row="3" Grid.Column="1" x:Name="SelectedOUBox"  FontSize="14" IsReadOnly="True" Background="WhiteSmoke"
                                 BorderBrush="#1E90FF" BorderThickness="1" Padding="2" Margin="0,5,0,0" Visibility="Collapsed" />
                    </Grid>
                </StackPanel>
            </Border>

            <!-- Second Section: PC Info -->
            <Border BorderBrush="#D3D3D3" BorderThickness="0.5" Padding="10" Margin="0,5,0,5">
                <StackPanel Orientation="Vertical">
                    <TextBlock Text="PC Information:" FontSize="16" FontWeight="Bold" Margin="0,0,0,10"/>
                    <Grid>
                        <Grid.ColumnDefinitions>
                            <ColumnDefinition Width="200"/>
                            <ColumnDefinition Width="*"/>
                        </Grid.ColumnDefinitions>
                        <Grid.RowDefinitions>
                            <RowDefinition Height="Auto"/>
                            <RowDefinition Height="Auto"/>
                            <RowDefinition Height="Auto"/>
                            <RowDefinition Height="Auto"/>
                            <RowDefinition Height="Auto"/>
                            <RowDefinition Height="Auto"/>
                        </Grid.RowDefinitions>

                        <TextBlock Grid.Row="0" Grid.Column="0" Text="Computer Name:" FontSize="14" FontWeight="Bold"/>
                        <TextBlock Grid.Row="0" Grid.Column="1" x:Name="PcNameBlock" Text="Loading..." FontSize="14" Padding="2" Margin="5,3,0,0"/>

                        <TextBlock Grid.Row="1" Grid.Column="0" Text="IP Address:" FontSize="14" FontWeight="Bold"/>
                        <TextBlock Grid.Row="1" Grid.Column="1" x:Name="PcIPAddressBlock" Text="Loading..." FontSize="14" Padding="2" Margin="5,3,0,0"/>

                        <TextBlock Grid.Row="2" Grid.Column="0" Text="Domain Status:" FontSize="14" FontWeight="Bold"/>
                        <TextBlock Grid.Row="2" Grid.Column="1" x:Name="PcDomainStatusBlock" Text="Loading..." FontSize="14" Padding="2" Margin="5,3,0,0"/>
                        
                        <TextBlock Grid.Row="3" Grid.Column="0" Text="Entra ID Status:" FontSize="14" FontWeight="Bold"/>
                        <TextBlock Grid.Row="3" Grid.Column="1" x:Name="PcEntraIDStatusBlock" Text="Loading..." FontSize="14" Padding="2" Margin="5,3,0,0"/>

                        <TextBlock Grid.Row="4" Grid.Column="0" Text="SCCM Agent:" FontSize="14" FontWeight="Bold"/>
                        <TextBlock Grid.Row="4" Grid.Column="1" x:Name="SCCMStatusBlock" Text="Loading..." FontSize="14" Padding="2" Margin="5,3,0,0"/>

                        <TextBlock Grid.Row="5" Grid.Column="0" Text="Co-Management:" FontSize="14" FontWeight="Bold"/>
                        <TextBlock Grid.Row="5" Grid.Column="1" x:Name="CoManagementBlock" Text="Loading..." FontSize="14" Padding="2" Margin="5,3,0,0"/>
                    </Grid>
                </StackPanel>
            </Border>

            <!-- Third Section -->
            <Border BorderBrush="#D3D3D3" BorderThickness="0.5"  Padding="10"  Margin="0,5,0,5">
                <StackPanel Orientation="Horizontal" HorizontalAlignment="Center">
                    <Button x:Name="JoinButton" Content="➕ Join to Domain + OU" Width="200" Height="40" Background="#32CD32" Foreground="White"
                            FontSize="14" FontWeight="Bold" Margin="10"/>
                    <Button x:Name="DisjoinButton" Content="🔌 Disjoin from Domain" Width="200" Height="40" Background="#FFA500" Foreground="White"
                            FontSize="14" FontWeight="Bold" Margin="10"/>
                    <Button x:Name="DeleteButton" Content="🗑️ Delete from AD" Width="200" Height="40" Background="#FF6347" Foreground="White"
                            FontSize="14" FontWeight="Bold" Margin="10"/>
                </StackPanel>
            </Border>

            <!-- Fourth Section -->
            <Border BorderBrush="#D3D3D3" BorderThickness="0.5"  Padding="10"  Margin="0,5,0,5">
                <StackPanel Orientation="Horizontal" HorizontalAlignment="Center">
                    <Button x:Name="JoinEntraIDButton" Content="🔹 Join to Entra ID" Width="200" Height="40" Background="#0078D7" Foreground="White"
                            FontSize="14" FontWeight="Bold" Margin="10"/>
                    <Button x:Name="DisjoinEntraIDButton" Content="🔻 Disjoin from Entra ID" Width="200" Height="40" Background="#DC3545" Foreground="White"
                            FontSize="14" FontWeight="Bold" Margin="10"/>
                    <Button x:Name="JoinIntunePersonalButton" Content="📲 Join Intune (Personal)" Width="200" Height="40" Background="#0078D7" Foreground="White"
                            FontSize="14" FontWeight="Bold" Margin="10"/>
                </StackPanel>
            </Border>
        </StackPanel>

        <!-- Footer Section -->
        <Border Grid.Row='2' Background='#D3D3D3' Padding='5'>
            <TextBlock Text='© 2025 M.omar (momar.tech) - All Rights Reserved'
                       Foreground='Black' 
                       FontSize='10' 
                       HorizontalAlignment='Center'/>
        </Border>
    </Grid>
</Window>
"@

    try {
        $Reader = New-Object System.Xml.XmlNodeReader $XAML
        $Window = [System.Windows.Markup.XamlReader]::Load($Reader)

        # Assign GUI controls
        $DomainControllerBox = $Window.FindName('DomainControllerBox')
        $DomainNameBox       = $Window.FindName('DomainNameBox')
        $SearchBaseBox       = $Window.FindName('SearchBaseBox')
        $SelectedOUBox       = $Window.FindName('SelectedOUBox')

        $DeleteButton   = $Window.FindName('DeleteButton')
        $DisjoinButton  = $Window.FindName('DisjoinButton')
        $JoinButton     = $Window.FindName('JoinButton')

        $Global:PcNameBlock         = $Window.FindName('PcNameBlock')
        $Global:PcDomainStatusBlock = $Window.FindName('PcDomainStatusBlock')
        $Global:PcIPAddressBlock    = $Window.FindName('PcIPAddressBlock')
        $Global:PcEntraIDStatusBlock= $Window.FindName('PcEntraIDStatusBlock')
        $Global:SCCMStatusBlock     = $Window.FindName('SCCMStatusBlock')
        $Global:CoManagementBlock   = $Window.FindName('CoManagementBlock')

        $JoinEntraIDButton          = $Window.FindName('JoinEntraIDButton')
        $DisjoinEntraIDButton       = $Window.FindName('DisjoinEntraIDButton')
        $JoinIntunePersonalButton   = $Window.FindName('JoinIntunePersonalButton')

        # Basic validation
        if (-not $Global:PcIPAddressBlock)    { Show-WPFMessage -Message "ERROR: PcIPAddressBlock is NULL! Check XAML element name." -Title "Error" -Color Red }
        if (-not $Global:PcEntraIDStatusBlock){ Show-WPFMessage -Message "ERROR: PcEntraIDStatusBlock is NULL! Check XAML element name." -Title "Error" -Color Red }
        if (-not $Global:SCCMStatusBlock)     { Write-Host "ERROR: SCCMStatusBlock is NULL!" -ForegroundColor Red }
        if (-not $Global:CoManagementBlock)   { Write-Host "ERROR: CoManagementBlock is NULL!" -ForegroundColor Red }

        # Immediately run PC info update (async, no freeze).
        Update-PCInfo

        # Event Handlers
        $DeleteButton.Add_Click({
            Prompt-Credentials
            $ComputerName    = $env:COMPUTERNAME
            $DomainController= $DomainControllerBox.Text.Trim()
            $SearchBase      = $SearchBaseBox.Text.Trim()
            Delete-ComputerFromAD -ComputerName $ComputerName -DomainController $DomainController -SearchBase $SearchBase
        })

        $DisjoinButton.Add_Click({
            Prompt-Credentials
            $ComputerName    = $env:COMPUTERNAME
            $DomainController= $DomainControllerBox.Text.Trim()
            $SearchBase      = $SearchBaseBox.Text.Trim()
            Disjoin-ComputerFromDomain -ComputerName $ComputerName
        })

        $JoinButton.Add_Click({
            Prompt-Credentials
            Show-OUWindow
            $SelectedOU = $SelectedOUBox.Text.Trim()
            if ($SelectedOU -ne "") {
                $DomainName = $DomainNameBox.Text.Trim()
                Join-ComputerWithOU -DomainName $DomainName -OUPath $SelectedOU
            }
            else {
                Show-WPFMessage -Message "No OU selected. Please select an OU before joining." -Title "Error" -Color Red
            }
        })

        $JoinEntraIDButton.Add_Click({ Join-EntraID })
        $DisjoinEntraIDButton.Add_Click({ Disjoin-EntraID })
        $JoinIntunePersonalButton.Add_Click({ Join-IntuneAsPersonalDevice })

        # Show the GUI
        [void]$Window.ShowDialog()
    }
    catch {
        Show-WPFMessage -Message "Failed to initialize GUI: $($_.Exception.Message)" -Title "Error" -Color Red
    }
}

###############################################################################
# MAIN SCRIPT
###############################################################################

try {
    Test-Admin          # Ensure script runs as admin
    Show-MainGUI        # Load main GUI
}
catch {
    Show-WPFMessage -Message "An unexpected error occurred: $($_.Exception.Message)" -Title "Error" -Color Red
}
