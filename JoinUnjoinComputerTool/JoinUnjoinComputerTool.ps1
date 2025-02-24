<#
.SYNOPSIS
    A PowerShell GUI tool for managing computer objects in Active Directory using LDAP queries.

.DESCRIPTION
    This script provides a GUI-based tool for managing computer objects in Active Directory. 
    It handles scenarios such as renaming the local computer, disjoining from a domain, deleting 
    from Active Directory, and joining a domain with an Organizational Unit (OU) selection.

.NOTES
    Author  : Mohammad Abdulkader Omar
    Date    : 2025-01-20
#>

###############################################################################
# PARAMETERS
###############################################################################
[CmdletBinding()]
Param(
    [string]$DefaultDomainController = "DC01.company.local",            # Default Domain Controller
    [string]$DefaultDomainName = "company.local",                       # Default Domain Name
    [string]$DefaultSearchBase = "OU=Computers,DC=company,DC=local"     # Default Search Base
)


# Load the required WPF assemblies
Add-Type -AssemblyName PresentationFramework

# Temporarily relax the PowerShell execution policy for this session
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Unrestricted -Force

# Log buffer to capture messages before GUI is loaded
$LogBuffer = @()

# Global variable to store AD credentials
$Global:ADCreds = $null

# Global variable to store AD credentials
$Global:ADCreds = $Global:ADCreds  # Ensure it exists

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

    # Load the PresentationFramework assembly if not already loaded
    Add-Type -AssemblyName PresentationFramework

    # Map the Color parameter to a hex value for the header background
    switch ($Color) {
        "Green"  { $HeaderColor = "#28A745" }  # typical green
        "Orange" { $HeaderColor = "#FFA500" }  # typical orange
        "Red"    { $HeaderColor = "#DC3545" }  # typical red
        "Blue"   { $HeaderColor = "#0078D7" }  # Windows 10 accent blue
    }

    # Window has no standard chrome/title bar. We draw our own rounded border.
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
        # Convert the XAML string into an XML document
        $xamlXml = [xml]$xamlString
        
        # Create an XmlNodeReader to read the XML document
        $reader = New-Object System.Xml.XmlNodeReader($xamlXml)
        
        # Load the WPF window from the XAML
        $window = [System.Windows.Markup.XamlReader]::Load($reader)

        # Set the message text
        $txtMessage = $window.FindName("txtMessage")
        $txtMessage.Text = $Message

        # Close the window when the OK button is clicked
        $btnOK = $window.FindName("btnOK")
        $btnOK.Add_Click({ $window.Close() })

        # Show the window as a modal dialog
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

    # Load PresentationFramework assembly.
    Add-Type -AssemblyName PresentationFramework

    # Map the Color parameter to a hex value.
    switch ($Color) {
        "Green"  { $HeaderColor = "#28A745" }
        "Orange" { $HeaderColor = "#FFA500" }
        "Red"    { $HeaderColor = "#DC3545" }
        "Blue"   { $HeaderColor = "#0078D7" }
    }

    # XAML for the confirmation dialog.
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

        # Attach event handlers that set the window's DialogResult.
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

# Check if the script is running with administrator privileges
Function Test-Admin {
    if (-not (New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
       Show-WPFMessage -Message "Run this script as Administrator." -Title "Insufficient Privileges" -Color Red
        Exit
    }
}


# Prompt Restart AD -Credentials
Function Prompt-Credentials {
    [CmdletBinding()]
    param ()

    # If credentials are already stored, return them.
    if ($Global:ADCreds -and $Global:ADCreds.UserName) {
        return $Global:ADCreds
    }

    # Load the WPF assembly.
    [void][System.Reflection.Assembly]::LoadWithPartialName("presentationframework")
    
    # Define a header color for consistency.
    $HeaderColor = "#0078D7"  # Windows 10 accent blue; adjust as needed

    # Revised XAML: a root Grid is defined so that control layout works as expected.
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
        # Convert the XAML string into an XML document and load the window.
        $xamlXml = [xml]$xamlString
        $reader = New-Object System.Xml.XmlNodeReader($xamlXml)
        $window = [System.Windows.Markup.XamlReader]::Load($reader)

        # Retrieve controls by name.
        $usernameBox = $window.FindName("UsernameBox")
        $passwordBox = $window.FindName("PasswordBox")
        $okButton     = $window.FindName("OkButton")
        $cancelButton = $window.FindName("CancelButton")
        
        # Reset global credential variable.
        $Global:ADCreds = $null

        # OK Button event: Validate credentials via LDAP bind.
       # OK Button event: Validate credentials via LDAP bind.
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
      # Validate credentials via LDAP bind by retrieving a known property.
       
         # Build the LDAP path for the specified domain controller.
        $ldapPath = "LDAP://$DefaultDomainController"
        
        # Create a DirectoryEntry using the provided credentials.
        $entry = New-Object System.DirectoryServices.DirectoryEntry($ldapPath, $cred.UserName, $cred.GetNetworkCredential().Password)
        
        # Force an LDAP bind by retrieving a known property.
        $dummy = $entry.Properties["defaultNamingContext"].Value

        Show-WPFMessage -Message "Domain credentials validated." -Title "Success" -Color Green
        $Global:ADCreds = $cred
        $window.Close()
    }
    catch {
        Show-WPFMessage -Message "Domain credential validation failed." -Title "Error" -Color Red
    }
})

        
        # Cancel Button event: Close the window without saving credentials.
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

# Prompt Restart
Function Prompt-Restart {
    [void][System.Reflection.Assembly]::LoadWithPartialName("presentationframework")
    [void][System.Reflection.Assembly]::LoadWithPartialName("windowsbase")
    
    # Define the XAML for the Restart Confirmation Window
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
        # Load the Restart Confirmation Window
        $Reader = New-Object System.Xml.XmlNodeReader $RestartXAML
        $RestartWindow = [System.Windows.Markup.XamlReader]::Load($Reader)

        # Assign Controls
        $YesButton = $RestartWindow.FindName('YesButton')
        $NoButton = $RestartWindow.FindName('NoButton')

        # Define Global Variable for Restart Confirmation
        $Global:RestartConfirmed = $false

        # Add Event Handlers for Buttons
        $YesButton.Add_Click({
            $Global:RestartConfirmed = $true
            $RestartWindow.Close()
        })

        $NoButton.Add_Click({
            $Global:RestartConfirmed = $false
            $RestartWindow.Close()
        })

        # Ensure the Window Opens in the Center of the Screen
        $RestartWindow.WindowStartupLocation = "CenterScreen"

        # Show the Restart Confirmation Window
        [void]$RestartWindow.ShowDialog()

        # Check User's Choice and Restart If Necessary
        if ($Global:RestartConfirmed) {
            Show-WPFMessage -Message "Restarting the computer..." -Title "Warning" -Color Orange
            Restart-Computer -Force
        } else {
            Show-WPFMessage -Message "Restart postponed by the user." -Title "Info" -Color Blue
        }

    } catch {
        Show-WPFMessage -Message "An error occurred in the Restart Confirmation Window: $($_.Exception.Message)" -Title "Error" -Color Red
    }
}

# Function to Populate PC Info with IP Address and Entra ID Status
Function Update-PCInfo {
    try {
        # ---------------------------------------------------------------------
        # 1) Basic System Info (Computer Name, Domain)
        # ---------------------------------------------------------------------
        $computerSystem = Get-CimInstance -ClassName Win32_ComputerSystem
        $ComputerName   = $computerSystem.Name
        $DomainStatus   = if ($computerSystem.PartOfDomain) { "Domain Joined" } else { "Workgroup" }

        # ---------------------------------------------------------------------
        # 2) Primary IP Address
        #    - Pick the NIC that is 'Up' with highest LinkSpeed, exclude 127.x 
        #      and 169.254.x (APIPA). Then fallback to first valid IPv4 if none found.
        # ---------------------------------------------------------------------
        $IPAddress = $null
        $nic = Get-NetAdapter -Physical | Where-Object { $_.Status -eq 'Up' } |
               Sort-Object -Property LinkSpeed -Descending |
               Select-Object -First 1

        if ($nic) {
            $ip = Get-NetIPAddress -InterfaceIndex $nic.IfIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue |
                  Where-Object { $_.IPAddress -notmatch '^127\.|^169\.254' } |
                  Select-Object -ExpandProperty IPAddress -First 1
            if ($ip) { $IPAddress = $ip }
        }
        # Fallback: if no NIC found above, pick *any* valid IPv4
        if (-not $IPAddress) {
            $IPAddress = Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue |
                         Where-Object { $_.IPAddress -notmatch '^127\.|^169\.254' } |
                         Select-Object -ExpandProperty IPAddress -First 1
        }

        # ---------------------------------------------------------------------
        # 3) Entra ID (Azure AD) Status via dsregcmd
        # ---------------------------------------------------------------------
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

        # ---------------------------------------------------------------------
        # 4) Detect SCCM (ccmexec service)
        # ---------------------------------------------------------------------
        $ccmExecService = Get-Service -Name ccmexec -ErrorAction SilentlyContinue
        if ($ccmExecService) {
            if ($ccmExecService.Status -eq 'Running') {
                $SCCMStatus = "SCCM Client (Running)"
                $SCCMColor  = "#28A745"  # Green
            }
            else {
                $SCCMStatus = "SCCM Client (Stopped)"
                $SCCMColor  = "#FFA500"  # Orange
            }
        }
        else {
            $SCCMStatus = "Not Installed"
            $SCCMColor  = "#DC3545"  # Red
        }

        # ---------------------------------------------------------------------
        # 5) Co-Management Detection
        #    a) Check WMI: root\ccm\CoManagementHandler:CoManagement_Configuration
        #       - 'Enable' is a reliable indicator.
        #    b) Fallback to CoManagementFlags for partial workload info.
        #    c) Also check MDM auto-enrollment registry.
        # ---------------------------------------------------------------------
        $CoManagementStatus = "Not Detected"
        $CoManagementColor  = "#DC3545" # Red by default

        # 5a) WMI approach
        try {
            $cmConfig = Get-WmiObject -Namespace 'root\ccm\CoManagementHandler' -Class 'CoManagement_Configuration' -ErrorAction Stop
            if ($cmConfig) {
                if ($cmConfig.Enable) {
                    # Co-management is actually on
                    $CoManagementStatus = "Co-Management Enabled"
                    $CoManagementColor  = "#28A745" # Green
                }
                else {
                    $CoManagementStatus = "SCCM Present - Co-Management Disabled"
                    $CoManagementColor  = "#DC3545" # Red
                }
            }
        }
        catch {
            # If we can't query WMI, we'll rely on registry fallback
            # or do nothing here
        }

        # 5b) Check the CoManagementFlags registry if present
        $CoManagementRegPath = "HKLM:\SOFTWARE\Microsoft\CCM"
        if (Test-Path $CoManagementRegPath) {
            try {
                $val = Get-ItemProperty -Path $CoManagementRegPath -Name "CoManagementFlags" -ErrorAction SilentlyContinue
                if ($val) {
                    $flags = $val.CoManagementFlags
                    # If WMI didn't confirm 'Enable', we can at least show the flags:
                    # e.g. "Advanced Co-Management (Flags=XYZ)"
                    if ($CoManagementStatus -eq "Not Detected") {
                        $CoManagementStatus = "Co-Management Flags=$flags"
                        $CoManagementColor  = "#28A745" # Green
                    }
                }
            }
            catch {
                # optional logging or ignore
            }
        }

        # 5c) Check Intune Auto-Enrollment policy
        $AutoEnrollRegPath = "HKLM:\Software\Policies\Microsoft\Windows\CurrentVersion\MDM"
        if (Test-Path $AutoEnrollRegPath) {
            try {
                $MDMValue = Get-ItemProperty -Path $AutoEnrollRegPath -Name "AutoEnrollMDM" -ErrorAction SilentlyContinue
                if ($MDMValue -and $MDMValue.AutoEnrollMDM -eq 1) {
                    $CoManagementStatus = "Intune Auto Enrollment Enabled"
                    $CoManagementColor  = "#28A745" # Green
                }
            }
            catch {
                # optional logging or ignore
            }
        }

        # ---------------------------------------------------------------------
        # 6) Update the WPF UI (TextBlocks) via Dispatcher
        # ---------------------------------------------------------------------

        # Computer Name
        $Global:PcNameBlock.Dispatcher.Invoke([action]{
            $Global:PcNameBlock.Text = $ComputerName
        }, "Render")

        # IP Address
        $Global:PcIPAddressBlock.Dispatcher.Invoke([action]{
            $Global:PcIPAddressBlock.Text = if ($IPAddress) { $IPAddress } else { "N/A" }
        }, "Render")

        # Domain or Workgroup
        $Global:PcDomainStatusBlock.Dispatcher.Invoke([action]{
            $Global:PcDomainStatusBlock.Text = $DomainStatus
            $Global:PcDomainStatusBlock.Background = if ($DomainStatus -eq "Domain Joined") { "#28A745" } else { "#DC3545" }
            $Global:PcDomainStatusBlock.Foreground = "White"
        }, "Render")

        # Entra ID
        $Global:PcEntraIDStatusBlock.Dispatcher.Invoke([action]{
            $Global:PcEntraIDStatusBlock.Text = $EntraIDStatus
            $Global:PcEntraIDStatusBlock.Background = if ($EntraIDStatus -match "Joined") { "#28A745" } else { "#DC3545" }
            $Global:PcEntraIDStatusBlock.Foreground = "White"
        }, "Render")

        # SCCM
        $Global:SCCMStatusBlock.Dispatcher.Invoke([action]{
            $Global:SCCMStatusBlock.Text = $SCCMStatus
            $Global:SCCMStatusBlock.Background = $SCCMColor
            $Global:SCCMStatusBlock.Foreground = "White"
        }, "Render")

        # Co-Management
        $Global:CoManagementBlock.Dispatcher.Invoke([action]{
            $Global:CoManagementBlock.Text = $CoManagementStatus
            $Global:CoManagementBlock.Background = $CoManagementColor
            $Global:CoManagementBlock.Foreground = "White"
        }, "Render")

    }
    catch {
        Show-WPFMessage -Message "Failed to update PC information: $($_.Exception.Message)" -Title "Error" -Color Red
    }
}



# Function to Convert Hex Color to WPF Brush
Function ConvertFrom-HexToColor {
    param([string]$HexColor)
    return [System.Windows.Media.ColorConverter]::ConvertFromString($HexColor)
}

# Function to join a computer to a domain with a selected OU
Function Join-ComputerWithOU {
    param (
        [string]$DomainName,
        [string]$OUPath
    )
    try {
        # Check if the computer is already in the domain
        $CurrentDomain = (Get-WmiObject -Class Win32_ComputerSystem).Domain
        if ($CurrentDomain -eq $DomainName) {
           Show-WPFMessage -Message "The computer '$env:COMPUTERNAME' is already a member of the domain '$DomainName'. No action is needed." -Title "Info" -Color Blue
            return
        }

        # If not in the domain, proceed to join
        Add-Computer -DomainName $DomainName -OUPath $OUPath -Credential $Global:ADCreds -Force
        Show-WPFMessage -Message "Computer successfully joined to domain
        - Domain :  $DomainName
        - OU       :  $OUPath." -Title "Success" -Color Green
        Update-PCInfo
        Prompt-Restart
        
    } catch {

    # Check for specific error: "The server is not operational"
                if ($_.Exception.Message -match "The server is not operational") {
                 Show-WPFMessage -Message "Failed to connect to Active Directory. Please check and update the following:
                - Domain Controller
                - Domain Name
                - OU Search Base
                - AD Credential" -Title "Error" -Color Red
                    
                } else {
                    # Handle other unexpected errors
                      Show-WPFMessage -Message "Failed to join the computer to domain: $($_.Exception.Message)" -Title "Error" -Color Red     
    }
    }
}

# Function to disjoin a computer from a domain
Function Disjoin-ComputerFromDomain {
    param ([string]$ComputerName)
    $ComputerDomainStatus = (Get-WmiObject -Class Win32_ComputerSystem).PartOfDomain

    if ($ComputerDomainStatus) {
        try {
         # Show confirmation dialog
             $Confirmation = Show-WPFConfirmation -Message "Are you sure you want to disjoin the computer '$ComputerName' from the domain?" -Title "Disjoin Confirmation" -Color Blue
            
            if (-not $Confirmation) {
            Show-WPFMessage -Message "Deletion operation canceled by the user." -Title "Info" -Color Blue
            return
        }

            # Proceed with disjoin
            Remove-Computer -WorkgroupName "WORKGROUP" -Credential $Global:ADCreds -Force
            Show-WPFMessage -Message "Computer '$ComputerName' successfully disjoined from the domain." -Title "Success" -Color Green
            
            Update-PCInfo
            Prompt-Restart
        } catch {

        # Check for specific error: "The server is not operational"
                if ($_.Exception.Message -match "The server is not operational") {
                    
                     Show-WPFMessage -Message "Failed to connect to Active Directory. Please check and update the following:
                    - Domain Controller
                    - Domain Name
                    - OU Search Base" -Title "Error" -Color Red
                    
                } else {
                    # Handle other unexpected errors
                     Show-WPFMessage -Message  "Failed to disjoin computer '$ComputerName' from the domain: $($_.Exception.Message)" -Title "Error" -Color Red
                    
        }
        }
    } else {
       
        Show-WPFMessage -Message "The computer '$ComputerName' is not part of a domain. Skipping disjoin operation." -Title "Info" -Color Blue
    }
}

# Function to delete a computer from AD
Function Delete-ComputerFromAD {
    param (
        [string]$ComputerName,
        [string]$DomainController,
        [string]$SearchBase
    )
    try {
        # If AD credentials haven't been set, prompt for them.
        if (-not $Global:ADCreds) {
            Show-WPFMessage -Message "Credentials not found. Prompting for credentials..." -Title "Info" -Color Blue
            $Global:ADCreds = Prompt-Credentials
            if (-not $Global:ADCreds) {
                Show-WPFMessage -Message "No credentials provided. Exiting function." -Title "Error" -Color Red
                return
            }
        }

        # Show confirmation dialog using the custom WPF confirmation function.
        $Confirmation = Show-WPFConfirmation -Message "Are you sure you want to delete the computer '$ComputerName' from Active Directory?" -Title "Delete Confirmation" -Color Blue

        if (-not $Confirmation) {
            Show-WPFMessage -Message "Deletion operation canceled by the user." -Title "Info" -Color Blue
            return
        }

        # Build the LDAP path using the provided Domain Controller and Search Base.
        $LDAPPath = "LDAP://$DomainController/$SearchBase"
        $DirectoryEntry = New-Object System.DirectoryServices.DirectoryEntry($LDAPPath, $Global:ADCreds.UserName, $Global:ADCreds.GetNetworkCredential().Password)
        $Searcher = New-Object System.DirectoryServices.DirectorySearcher($DirectoryEntry)
        # Search using sAMAccountName; note the trailing '$' for computer objects.
        $Searcher.Filter = "(sAMAccountName=$ComputerName`$)"
        $SearchResult = $Searcher.FindOne()

        if ($SearchResult) {
            $ComputerEntry = $SearchResult.GetDirectoryEntry()
            # Retrieve userAccountControl attribute.
            $uac = $ComputerEntry.Properties["userAccountControl"].Value
            # The ACCOUNTDISABLE flag has a value of 2.
            $ACCOUNTDISABLE = 2

            # If the account is NOT disabled, assume it is active.
            if (-not ($uac -band $ACCOUNTDISABLE)) {
                Show-WPFMessage -Message "Deletion aborted: The computer '$ComputerName' appears to be active (joined to a domain)." -Title "Error" -Color Red
                return
            }

            # Proceed with deletion.
            $ComputerEntry.DeleteTree()
            $ComputerEntry.CommitChanges()
            Show-WPFMessage -Message "Successfully deleted computer '$ComputerName' from Active Directory." -Title "Success" -Color Green
        } 
        else {
            Show-WPFMessage -Message "Computer '$ComputerName' was not found in Active Directory." -Title "Info" -Color blue
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

     # Show confirmation dialog
             $Confirmation = Show-WPFConfirmation -Message "Are you sure you want to join the computer '$ComputerName' to EntaID?" -Title "Disjoin Confirmation" -Color Blue
            
            if (-not $Confirmation) {
            Show-WPFMessage -Message "Joining operation canceled by the user." -Title "Info" -Color Blue
            return
        }
        
        Start-Process -FilePath "C:\Windows\System32\dsregcmd.exe" -ArgumentList "/join" -NoNewWindow -Wait
        Show-WPFMessage -Message "Device successfully joined to Entra ID." -Title "Success" -Color Green
        Update-PCInfo
    } catch {
        Show-WPFMessage -Message "Failed to join Entra ID: $($_.Exception.Message)" -Title "Error" -Color Red
    }
}

Function Disjoin-EntraID {
    try {
     # Show confirmation dialog
             $Confirmation = Show-WPFConfirmation -Message "Are you sure you want to remove the computer '$ComputerName' from EntraID?" -Title "Disjoin Confirmation" -Color Blue
            
            if (-not $Confirmation) {
            Show-WPFMessage -Message "Remove operation canceled by the user." -Title "Info" -Color Blue
            return
        }
        
        Start-Process -FilePath "C:\Windows\System32\dsregcmd.exe" -ArgumentList "/leave" -NoNewWindow -Wait
        Show-WPFMessage -Message "Device removed from Entra ID." -Title "Success" -Color Red
        Update-PCInfo
    } catch {
        Show-WPFMessage -Message "Failed to remove from Entra ID: $($_.Exception.Message)" -Title "Error" -Color Red
    }
}

Function Join-IntuneAsPersonalDevice {
    try {
    # Show confirmation dialog
             $Confirmation = Show-WPFConfirmation -Message "Are you sure you want to add the computer '$ComputerName' to Intune?" -Title "Disjoin Confirmation" -Color Blue
            
            if (-not $Confirmation) {
            Show-WPFMessage -Message "Operation canceled by the user." -Title "Info" -Color Blue
            return
        }
        Start-Process "ms-device-enrollment:?mode=mdm"
        Show-WPFMessage -Message "Opening Intune enrollment page. Follow the steps to complete enrollment." -Title "Intune Enrollment" -Color Blue
        Update-PCInfo
    } catch {
        Show-WPFMessage -Message "Failed to launch Intune enrollment: $($_.Exception.Message)" -Title "Error" -Color Red
    }
}

# Function to display and select Organizational Units (OUs)
Function Show-OUWindow {
    [xml]$OUXAML = @"
<Window xmlns='http://schemas.microsoft.com/winfx/2006/xaml/presentation'
        xmlns:x='http://schemas.microsoft.com/winfx/2006/xaml'
        Title='Select Organizational Unit' Width='600' Height='400'
        Background='#F0F0F0' WindowStartupLocation='CenterScreen' ResizeMode='NoResize'>
    <Grid>
        <Grid.RowDefinitions>
            <RowDefinition Height='*'/>     <!-- Main Content -->
            <RowDefinition Height='Auto'/>  <!-- Buttons -->
        </Grid.RowDefinitions>

        <!-- DataGrid for OUs -->
        <DataGrid x:Name='OUDataGrid' Grid.Row='0' AutoGenerateColumns='False' CanUserAddRows='False' IsReadOnly='True'
                  BorderBrush='#1E90FF' BorderThickness='1' Margin='10'>
            <DataGrid.Columns>
                <DataGridTextColumn Header='Name' Binding='{Binding Name}' Width='150'/>
                <DataGridTextColumn Header='Description' Binding='{Binding Description}' Width='250'/>
                <DataGridTextColumn Header='Distinguished Name' Binding='{Binding DistinguishedName}' Width='350'/>
            </DataGrid.Columns>
        </DataGrid>

        <!-- Buttons -->
        <StackPanel Grid.Row='1' Orientation='Horizontal' HorizontalAlignment='Right' Margin='10'>
            <Button x:Name='SelectButton' Content='Select' Width='100' Margin='5' Background='#32CD32' Foreground='White' FontWeight='Bold'/>
            <Button x:Name='CancelButton' Content='Cancel' Width='100' Margin='5' Background='#FF6347' Foreground='White' FontWeight='Bold'/>
        </StackPanel>
    </Grid>
</Window>
"@

    try {
        # Load the OU selection GUI
        $OUReader = New-Object System.Xml.XmlNodeReader $OUXAML
        $OUWindow = [System.Windows.Markup.XamlReader]::Load($OUReader)

        # Controls in the OU Window
        $OUDataGrid = $OUWindow.FindName('OUDataGrid')
        $SelectButton = $OUWindow.FindName('SelectButton')
        $CancelButton = $OUWindow.FindName('CancelButton')

        # Populate the OU DataGrid
        try {
            $DomainController = $DomainControllerBox.Text.Trim()
            $SearchBase = $SearchBaseBox.Text.Trim()
            $LDAPPath = "LDAP://$DomainController/$SearchBase"

            # LDAP connection
            $DirectoryEntry = New-Object DirectoryServices.DirectoryEntry(
                $LDAPPath,
                $Global:ADCreds.UserName,
                $Global:ADCreds.GetNetworkCredential().Password
            )

            $Searcher = New-Object DirectoryServices.DirectorySearcher($DirectoryEntry)
            $Searcher.Filter = "(objectClass=organizationalUnit)"
            $Searcher.PropertiesToLoad.Add("name")
            $Searcher.PropertiesToLoad.Add("description")
            $Searcher.PropertiesToLoad.Add("distinguishedName")

            $OUList = @()
            $Results = $Searcher.FindAll()

            foreach ($Result in $Results) {
                $OUItem = [PSCustomObject]@{
                    Name              = $Result.Properties["name"][0]
                    Description       = ($Result.Properties["description"] -join ", ") -replace "^$", "N/A"
                    DistinguishedName = $Result.Properties["distinguishedName"][0]
                }
                $OUList += $OUItem
            }

            # Bind OUs to the DataGrid
            $OUDataGrid.ItemsSource = $OUList
        } catch {


        # Check for specific error: "The server is not operational"
                if ($_.Exception.Message -match "The server is not operational") {
                    Show-WPFMessage -Message "Failed to connect to Active Directory. Please check and update the following:
                    - Domain Controller
                    - Domain Name
                    - OU Search Base" -Title "Error" -Color Red
                    
                } else {
                    # Handle other unexpected errors
                    Show-WPFMessage -Message  "Failed to retrieve OUs: $($_.Exception.Message)" -Title "Error" -Color Red
    }

        }

        # Button Event Handlers
        $SelectedOU = $null
        $SelectButton.Add_Click({
            $SelectedOU = $OUDataGrid.SelectedItem
            if ($SelectedOU -ne $null) {
                $SelectedOUBox.Text = $SelectedOU.DistinguishedName
                Show-WPFMessage -Message "Selected OU: $($SelectedOU.DistinguishedName)" -Title "Info" -Color Blue
                $OUWindow.Close()
            } else {
                Show-WPFMessage -Message  "No OU selected. Please select an OU before proceeding." -Title "Error" -Color Red 
            }
        })

        $CancelButton.Add_Click({
            $OUWindow.Close()
        })

        # Show the OU Window
        [void]$OUWindow.ShowDialog()

    } catch {
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
        <!-- Layout Definitions -->
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
                                 BorderBrush="#1E90FF" BorderThickness="1" Padding="2" Margin="0,5,0,0" Visibility="Collapsed"/>

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


                    <!-- SCCM Agent Status -->
                    <TextBlock Grid.Row="4" Grid.Column="0" Text="SCCM Agent:" FontSize="14" FontWeight="Bold"/>
                    <TextBlock Grid.Row="4" Grid.Column="1" x:Name="SCCMStatusBlock" Text="Loading..." FontSize="14" Padding="2" Margin="5,3,0,0"/>

                    <!-- Co-Management Status -->
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

        <!-- Forth Section -->
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
        # Load GUI
        $Reader = New-Object System.Xml.XmlNodeReader $XAML
        $Window = [System.Windows.Markup.XamlReader]::Load($Reader)

      # Assign GUI controls
        $Console = $Window.FindName('Console')
        $DomainControllerBox = $Window.FindName('DomainControllerBox')
        $DomainNameBox = $Window.FindName('DomainNameBox')
        $SearchBaseBox = $Window.FindName('SearchBaseBox')
        $SelectedOUBox = $Window.FindName('SelectedOUBox')
        $DeleteButton = $Window.FindName('DeleteButton')
        $DisjoinButton = $Window.FindName('DisjoinButton')
        $JoinButton = $Window.FindName('JoinButton')

        # Assign UI elements to global variables
        $Global:PcNameBlock = $Window.FindName('PcNameBlock')
        $Global:PcDomainStatusBlock = $Window.FindName('PcDomainStatusBlock')
        $Global:PcIPAddressBlock = $Window.FindName('PcIPAddressBlock')
        $Global:PcEntraIDStatusBlock = $Window.FindName('PcEntraIDStatusBlock')
        $Global:SCCMStatusBlock = $Window.FindName('SCCMStatusBlock')
        $Global:CoManagementBlock = $Window.FindName('CoManagementBlock')
        $JoinEntraIDButton = $Window.FindName('JoinEntraIDButton')
        $DisjoinEntraIDButton = $Window.FindName('DisjoinEntraIDButton')
        $JoinIntunePersonalButton = $Window.FindName('JoinIntunePersonalButton')



        # Validate controls
        if (-not $Global:PcIPAddressBlock) {Show-WPFMessage -Message "ERROR: PcIPAddressBlock is NULL! Check XAML element name." -Title "Error" -Color Red}
        if (-not $Global:PcEntraIDStatusBlock) {Show-WPFMessage -Message "ERROR: PcEntraIDStatusBlock is NULL! Check XAML element name." -Title "Error" -Color Red}
        if (-not $Global:SCCMStatusBlock) { Write-Host "ERROR: SCCMStatusBlock is NULL!" -ForegroundColor Red }
        if (-not $Global:CoManagementBlock) { Write-Host "ERROR: CoManagementBlock is NULL!" -ForegroundColor Red }
        # Run PC Info update
        Update-PCInfo

   
        # Flush Log Buffer to Console
        foreach ($LogEntry in $LogBuffer) {
            $Console.AppendText("$LogEntry`r`n")
        }

        # Event Handlers
        $DeleteButton.Add_Click({
            Prompt-Credentials
            $ComputerName = $env:COMPUTERNAME
            $DomainController = $DomainControllerBox.Text.Trim()
            $SearchBase = $SearchBaseBox.Text.Trim()
            Delete-ComputerFromAD -ComputerName $ComputerName -DomainController $DomainController -SearchBase $SearchBase
        })

        $DisjoinButton.Add_Click({
            Prompt-Credentials
            $ComputerName = $env:COMPUTERNAME
            $DomainController = $DomainControllerBox.Text.Trim()
            $SearchBase = $SearchBaseBox.Text.Trim()
            Disjoin-ComputerFromDomain -ComputerName $ComputerName
        })

        $JoinButton.Add_Click({
            Prompt-Credentials
            Show-OUWindow
           $SelectedOU = $SelectedOUBox.Text.Trim()
            if ($SelectedOU -ne "") {
                $DomainName = $DomainNameBox.Text.Trim()
                Join-ComputerWithOU -DomainName $DomainName -OUPath $SelectedOU
            } else {
                Show-WPFMessage -Message "No OU selected. Please select an OU before joining." -Title "Error" -Color Red
            }
        })

        # Assign Click Events
        $JoinEntraIDButton.Add_Click({ 
        Join-EntraID 
        })
        $DisjoinEntraIDButton.Add_Click({ 
        Disjoin-EntraID 
        })
        $JoinIntunePersonalButton.Add_Click({
        Join-IntuneAsPersonalDevice 
        })

        # Use DispatcherTimer to delay execution of Update-PCInfo
        $Timer = New-Object System.Windows.Threading.DispatcherTimer
        $Timer.Interval = [TimeSpan]::FromMilliseconds(500)  # Wait 0.5 seconds before updating PC info
        $Timer.Add_Tick({
            $Timer.Stop()
            Update-PCInfo
        })
        $Timer.Start()
        

        # Show the GUI
        [void]$Window.ShowDialog()
        

    } catch {
        Show-WPFMessage -Message "Failed to initialize GUI: $($_.Exception.Message)" -Title "Error" -Color Red
    }
}

###############################################################################
# MAIN SCRIPT
###############################################################################

try {
    Test-Admin
    Show-MainGUI
} catch {
    Show-WPFMessage -Message "An unexpected error occurred: $($_.Exception.Message)" -Title "Error" -Color Red
}
