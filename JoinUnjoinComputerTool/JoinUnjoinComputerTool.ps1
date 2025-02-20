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



###############################################################################
# FUNCTIONS
###############################################################################

# Load the required WPF assemblies
Add-Type -AssemblyName PresentationFramework

# Check if the script is running with administrator privileges
Function Test-Admin {
    if (-not (New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        [System.Windows.MessageBox]::Show("Run this script as Administrator.", "Insufficient Privileges", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Error)
        Exit
    }
}
Test-Admin

# Temporarily relax the PowerShell execution policy for this session
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Unrestricted -Force

# Log buffer to capture messages before GUI is loaded
$LogBuffer = @()

# Global variable to store AD credentials
$Global:ADCreds = $null

# Utility to log output before GUI is loaded
Function Buffer-Log {
    param ([string]$Message)
    $LogBuffer += $Message
    Write-Host $Message
}

# Display logs in the GUI console
Function Show-Output {
    param ([string]$Message)

    # If GUI console is not ready, buffer the message
    if (-not $Console) {
        Buffer-Log $Message
    } else {
        # Append message to GUI console
        $Console.AppendText("$Message`r`n")
        
    }
}

# Display Success messages in both message boxes and the console
Function Show-Success {
    param ([string]$Msg)
    # Display the success message in a MessageBox with an Information icon
    [System.Windows.MessageBox]::Show($Msg, "Success", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Information)

    # Log the success message in the console using Show-Output
    Show-Output "SUCCESS: $Msg"
}

# Display error messages in both message boxes and the console
Function Show-Error {
    param ([string]$Msg)
    [System.Windows.MessageBox]::Show($Msg, "Error", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Error)
    Show-Output "ERROR: $Msg"
}

# Global variable to store AD credentials
$Global:ADCreds = $Global:ADCreds  # Ensure it exists

Function Prompt-Credentials {
    [CmdletBinding()]
    param ()

    # If credentials are already stored, return them.
    if ($Global:ADCreds -and $Global:ADCreds.UserName) {
        return $Global:ADCreds
    }

    # Load WPF assembly
    [void][System.Reflection.Assembly]::LoadWithPartialName("presentationframework")
    
    # Define XAML for a simple credentials window (username and password only)
    [xml]$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" 
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Enter Credentials" Height="250" Width="400" 
        WindowStartupLocation="CenterScreen" ResizeMode="NoResize">
    <Grid Margin="10">
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="Auto"/>
        </Grid.RowDefinitions>
        <TextBlock Grid.Row="0" Text="Enter AD Credentials" 
                   FontSize="18" FontWeight="Bold" 
                   HorizontalAlignment="Center" Margin="0,0,0,20"/>
        <StackPanel Grid.Row="1" Orientation="Horizontal" Margin="0,0,0,10">
            <Label Content="Username:" Width="100"/>
            <TextBox x:Name="UsernameBox" Width="250"/>
        </StackPanel>
        <StackPanel Grid.Row="2" Orientation="Horizontal" Margin="0,0,0,10">
            <Label Content="Password:" Width="100"/>
            <PasswordBox x:Name="PasswordBox" Width="250"/>
        </StackPanel>
        <StackPanel Grid.Row="3" Orientation="Horizontal" HorizontalAlignment="Center" Margin="0,20,0,0">
            <Button x:Name="OkButton" Content="OK" Width="100" Margin="10,0"/>
            <Button x:Name="CancelButton" Content="Cancel" Width="100" Margin="10,0"/>
        </StackPanel>
    </Grid>
</Window>
"@

    try {
        $reader = New-Object System.Xml.XmlNodeReader $xaml
        $window = [System.Windows.Markup.XamlReader]::Load($reader)
        $usernameBox = $window.FindName("UsernameBox")
        $passwordBox = $window.FindName("PasswordBox")
        $okButton = $window.FindName("OkButton")
        $cancelButton = $window.FindName("CancelButton")
        
        # Reset the global credential variable (optional, if you want to force re-prompt)
        $Global:ADCreds = $null

        # OK Button event: Validate AD credentials using an LDAP bind
        $okButton.Add_Click({
            if (-not $usernameBox.Text -or -not $passwordBox.Password) {
                [System.Windows.MessageBox]::Show("Username and Password required.")
                return
            }
            try {
                $secPwd = ConvertTo-SecureString $passwordBox.Password -AsPlainText -Force
                $cred = New-Object System.Management.Automation.PSCredential ($usernameBox.Text, $secPwd)
            }
            catch {
                [System.Windows.MessageBox]::Show("Error creating credentials.")
                return
            }
            
            try {
                # Validate credentials via LDAP bind to RootDSE
                $ldapPath = "LDAP://RootDSE"
                $entry = New-Object System.DirectoryServices.DirectoryEntry($ldapPath, $cred.UserName, $cred.GetNetworkCredential().Password)
                $null = $entry.NativeObject  # Force the bind; exception if validation fails
                [System.Windows.MessageBox]::Show("Domain credentials validated.")
                $Global:ADCreds = $cred
                $window.Close()
            }
            catch {
                [System.Windows.MessageBox]::Show("Domain credential validation failed.")
            }
        })
        
        # Cancel Button event: Close the window without storing credentials
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
        Title="Restart Confirmation" Height="200" Width="400" 
        WindowStartupLocation="CenterScreen" ResizeMode="NoResize"
        Background="#F8F8F8">
    <Grid>
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
            <RowDefinition Height="Auto"/>
        </Grid.RowDefinitions>

        <!-- Header Section -->
        <Border Grid.Row='0' Background='#1E90FF' Padding='5'>
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
            Show-Output "Restarting the computer..." "Orange"
            Restart-Computer -Force
        } else {
            Show-Output "Restart postponed by the user." "Yellow"
        }

    } catch {
        Show-Error "An error occurred in the Restart Confirmation Window: $($_.Exception.Message)"
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
            Show-Output "Credentials not found. Prompting for credentials..."
            $Global:ADCreds = Prompt-Credentials
            if (-not $Global:ADCreds) {
                Show-Error "No credentials provided. Exiting function."
                return
            }
        }

        # Show confirmation dialog
        $Confirmation = [System.Windows.MessageBox]::Show(
            "Are you sure you want to delete the computer '$ComputerName' from Active Directory?",
            "Delete Confirmation",
            [System.Windows.MessageBoxButton]::YesNo,
            [System.Windows.MessageBoxImage]::Question
        )
        
        # If user cancels the operation, exit the function
        if ($Confirmation -ne 'Yes') {
            Show-Output "----------------------------------------------------------------"
            Show-Output "Deletion operation canceled by the user."
            Show-Output "----------------------------------------------------------------"
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

            # If the account is NOT disabled, we assume it is active (joined to the domain).
            if (-not ($uac -band $ACCOUNTDISABLE)) {
                Show-Output "----------------------------------------------------------------"
                Show-Error "Deletion aborted: The computer '$ComputerName' appears to be active (joined to a domain)."
                Show-Output "----------------------------------------------------------------"
                return
            }

            # Proceed with deletion since the account appears disabled.
            $ComputerEntry.DeleteTree()
            $ComputerEntry.CommitChanges()

            Show-Output "----------------------------------------------------------------"
            Show-Success "Successfully deleted computer '$ComputerName' from Active Directory."
            Show-Output "----------------------------------------------------------------"
        } else {
            Show-Output "----------------------------------------------------------------"
            Show-Output "Computer '$ComputerName' was not found in Active Directory."
            Show-Output "----------------------------------------------------------------"
        }
    }
    catch {
        if ($_.Exception.Message -match "The server is not operational") {
            Show-Output "----------------------------------------------------------------"
            Show-Error "Failed to connect to Active Directory. Please check and update the following:
    - Domain Controller
    - Domain Name
    - OU Search Base"
            Show-Output "----------------------------------------------------------------"
        }
        else {
            Show-Output "----------------------------------------------------------------"
            Show-Error "Failed to delete the computer from Active Directory: $($_.Exception.Message)"
            Show-Output "----------------------------------------------------------------"
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
            $Confirmation = [System.Windows.MessageBox]::Show(
                "Are you sure you want to disjoin the computer '$ComputerName' from the domain?",
                "Disjoin Confirmation",
                [System.Windows.MessageBoxButton]::YesNo,
                [System.Windows.MessageBoxImage]::Question
            )
            
            # If user cancels the operation, exit the function
            if ($Confirmation -ne 'Yes') {
                Show-Output "----------------------------------------------------------------"
                Show-Output "Disjoin operation canceled by the user."
                Show-Output "----------------------------------------------------------------"
                return
            }

            # Proceed with disjoin
            Remove-Computer -WorkgroupName "WORKGROUP" -Credential $Global:ADCreds -Force
            Show-Output "----------------------------------------------------------------"
            Show-Success "Computer '$ComputerName' successfully disjoined from the domain."
            Show-Output "----------------------------------------------------------------"
            
            # Prompt the user to restart the computer
            Prompt-Restart
        } catch {

        # Check for specific error: "The server is not operational"
                if ($_.Exception.Message -match "The server is not operational") {
                    Show-Output "----------------------------------------------------------------"
                    Show-Error "Failed to connect to Active Directory. Please check and update the following:
        - Domain Controller
        - Domain Name
        - OU Search Base"
                    Show-Output "----------------------------------------------------------------"
                    
                } else {
                    # Handle other unexpected errors
                    Show-Output "----------------------------------------------------------------"
                    Show-Error "Failed to disjoin computer '$ComputerName' from the domain: $($_.Exception.Message)"
                    Show-Output "----------------------------------------------------------------"
        }
        }
    } else {
        Show-Output "----------------------------------------------------------------"
        Show-Output "The computer '$ComputerName' is not part of a domain. Skipping disjoin operation."
        Show-Output "----------------------------------------------------------------"
    }
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
            Show-Output "----------------------------------------------------------------"
            Show-Output "The computer '$env:COMPUTERNAME' is already a member of the domain '$DomainName'. No action is needed."
            Show-Output "----------------------------------------------------------------"
            return
        }

        # If not in the domain, proceed to join
        Add-Computer -DomainName $DomainName -OUPath $OUPath -Credential $Global:ADCreds -Force
        Show-Output "----------------------------------------------------------------"
        Show-Success "Computer successfully joined to domain '$DomainName' in OU '$OUPath'."
        Show-Output "----------------------------------------------------------------"

        # Prompt the user to restart the computer
        Prompt-Restart
        
    } catch {

    # Check for specific error: "The server is not operational"
                if ($_.Exception.Message -match "The server is not operational") {
                    Show-Output "----------------------------------------------------------------"
                    Show-Error "Failed to connect to Active Directory. Please check and update the following:
        - Domain Controller
        - Domain Name
        - OU Search Base
        - AD Credential"
                    Show-Output "----------------------------------------------------------------"
                } else {
                    # Handle other unexpected errors
                    Show-Output "----------------------------------------------------------------"
                     Show-Error "Failed to join the computer to domain: $($_.Exception.Message)"
                    Show-Output "----------------------------------------------------------------"
    }
    }
}

#Function to Populate PC Info
Function Update-PCInfo {
    param (
        [ref]$PcNameBlock,
        [ref]$PcDomainStatusBlock
    )

    try {
        # Get computer information
        $ComputerName = $env:COMPUTERNAME
        $PartOfDomain = (Get-WmiObject -Class Win32_ComputerSystem).PartOfDomain
        $DomainName = (Get-WmiObject -Class Win32_ComputerSystem).Domain

        # Update the PC Name Block
        $PcNameBlock.Value.Text = "Computer Name:  $ComputerName"

        # Update the Domain Status Block
        if ($PartOfDomain) {
            $PcDomainStatusBlock.Value.Text = "Domain Status:  Joined to '$DomainName'"
        } else {
            $PcDomainStatusBlock.Value.Text = "Domain Status:  Not joined to a domain (Workgroup)"
        }
    } catch {
        # Handle errors
        $PcNameBlock.Value.Text = "Computer Name: Unable to retrieve"
        $PcDomainStatusBlock.Value.Text = "Domain Status: Unable to retrieve"
        Display-Message "Failed to update PC information: $($_.Exception.Message)" -Type "Error"
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
            Show-Output "Fetching Organizational Units from Active Directory..."
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
                    Show-Output "----------------------------------------------------------------"
                    Show-Error "Failed to connect to Active Directory. Please check and update the following:
        - Domain Controller
        - Domain Name
        - OU Search Base"
                    Show-Output "----------------------------------------------------------------"
                } else {
                    # Handle other unexpected errors
                    Show-Output "----------------------------------------------------------------"
                    Show-Error "Failed to retrieve OUs: $($_.Exception.Message)"
                    Show-Output "----------------------------------------------------------------"
    }

        }

        # Button Event Handlers
        $SelectedOU = $null
        $SelectButton.Add_Click({
            $SelectedOU = $OUDataGrid.SelectedItem
            if ($SelectedOU -ne $null) {
                $SelectedOUBox.Text = $SelectedOU.DistinguishedName
                Show-Output "Selected OU: $($SelectedOU.DistinguishedName)"
                $OUWindow.Close()
            } else {
                Show-Output "----------------------------------------------------------------"
                Show-Error "No OU selected. Please select an OU before proceeding."
                Show-Output "----------------------------------------------------------------"
            }
        })

        $CancelButton.Add_Click({
            $OUWindow.Close()
        })

        # Show the OU Window
        [void]$OUWindow.ShowDialog()

    } catch {
        Show-Output "----------------------------------------------------------------"
        Show-Error "Failed to load the OU selection window: $($_.Exception.Message)"
        Show-Output "----------------------------------------------------------------"
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
        Width='700' 
        Height='700'
        Background='#F8F8F8' 
        WindowStartupLocation='CenterScreen' 
        ResizeMode='NoResize'>

    <Grid>
        <!-- Layout Definitions -->
        <Grid.RowDefinitions>
            <RowDefinition Height='Auto'/>   <!-- Header -->
            <RowDefinition Height='*'/>      <!-- Main Content -->
            <RowDefinition Height='Auto'/>   <!-- Footer -->
        </Grid.RowDefinitions>

        <!-- Header Section -->
        <Border Grid.Row='0' Background='#1E90FF' Padding='15'>
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
            <Border BorderBrush="#D3D3D3" BorderThickness="0.5"  Padding="10"  Margin="0,0,0,5">
                <StackPanel Orientation="Vertical">
                    <TextBlock Text="Domain Configuration:" FontSize="16" FontWeight="Bold" Margin="0,0,0,10"/>
                    <Grid>
                        <Grid.RowDefinitions>
                            <RowDefinition Height="Auto"/> <!-- Domain Controller -->
                            <RowDefinition Height="Auto"/> <!-- Domain Name -->
                            <RowDefinition Height="Auto"/> <!-- Search Base -->
                            <RowDefinition Height="Auto"/> <!-- Selected OU Row -->
                        </Grid.RowDefinitions>
                        <Grid.ColumnDefinitions>
                            <ColumnDefinition Width="150"/> <!-- Label -->
                            <ColumnDefinition Width="*"/>   <!-- Textbox -->
                        </Grid.ColumnDefinitions>

                        <!-- Domain Controller -->
                        <TextBlock Grid.Row="0" Grid.Column="0" Text="Domain Controller:" FontSize="13" FontWeight="Bold" VerticalAlignment="Center"/>
                        <TextBox Grid.Row="0" Grid.Column="1" x:Name="DomainControllerBox" Width="400" Height="25" FontSize="12" Text="$DefaultDomainController"
                                 BorderBrush="#1E90FF" BorderThickness="1" Padding="3" Margin="0,5,0,5"/>

                        <!-- Domain Name -->
                        <TextBlock Grid.Row="1" Grid.Column="0" Text="Domain Name:" FontSize="13" FontWeight="Bold" VerticalAlignment="Center"/>
                        <TextBox Grid.Row="1" Grid.Column="1" x:Name="DomainNameBox" Width="400" Height="25" FontSize="12" Text="$DefaultDomainName"
                                 BorderBrush="#1E90FF" BorderThickness="1" Padding="3" Margin="0,5,0,5"/>

                        <!-- Search Base OU -->
                        <TextBlock Grid.Row="2" Grid.Column="0" Text="Search Base (OU):" FontSize="13" FontWeight="Bold" VerticalAlignment="Center"/>
                        <TextBox Grid.Row="2" Grid.Column="1" x:Name="SearchBaseBox" Width="400" Height="25" FontSize="12" Text="$DefaultSearchBase"
                                 BorderBrush="#1E90FF" BorderThickness="1" Padding="3" Margin="0,5,0,5"/>

                        <!-- Selected OU Section -->
                        <TextBlock Grid.Row="3" Grid.Column="0" Text="Selected OU:" FontSize="13" FontWeight="Bold" VerticalAlignment="Center" Margin="0,5,10,5" Visibility="Collapsed"/>
                        <TextBox Grid.Row="3" Grid.Column="1" x:Name="SelectedOUBox" Width="400" Height="25" FontSize="12" IsReadOnly="True" Background="WhiteSmoke"
                                 BorderBrush="#1E90FF" BorderThickness="1" Padding="3" Margin="0,5,0,5" Visibility="Collapsed"/>

                    </Grid>
                </StackPanel>
            </Border>

            <!-- Second Section: PC Info -->
            <Border BorderBrush="#D3D3D3" BorderThickness="0.5"  Padding="10"  Margin="0,5,0,5">
                <StackPanel Orientation="Vertical">
                    <TextBlock Text="PC Info:" FontSize="16" FontWeight="Bold" Margin="0,0,0,10"/>
                    <TextBlock x:Name="PcNameBlock" Text="Computer Name:  Loading..." FontSize="14" Margin="0,5,0,0"/>
                    <TextBlock x:Name="PcDomainStatusBlock" Text="Domain Status:  Loading..." FontSize="14" Margin="0,5,0,0"/>
                </StackPanel>
            </Border>

            <!-- Third Section: Disjoin and Delete -->
         
                <StackPanel Orientation="Horizontal" HorizontalAlignment="Center">
                <Button x:Name="JoinButton" Content="➕ Join to Domain + OU" Width="200" Height="40" Background="#32CD32" Foreground="White"
                                FontSize="14" FontWeight="Bold" Margin="10"/>
                    <Button x:Name="DisjoinButton" Content="🔌 Disjoin from Domain" Width="200" Height="40" Background="#FFA500" Foreground="White"
                            FontSize="14" FontWeight="Bold" Margin="10"/>
                    <Button x:Name="DeleteButton" Content="🗑️ Delete from AD" Width="200" Height="40" Background="#FF6347" Foreground="White"
                            FontSize="14" FontWeight="Bold" Margin="10"/>
                </StackPanel>


            <!-- Fourth Section: Console -->

                <StackPanel Orientation="Vertical">
                    <TextBlock Text="Output Console:" FontSize="14" FontWeight="Bold" Margin="0,0,0,5"/>
                    <TextBox x:Name="Console" IsReadOnly="True" Background="Black" Foreground="White" FontFamily="Consolas" FontSize="12"
                             TextWrapping="Wrap" VerticalScrollBarVisibility="Auto" Height="170" BorderBrush="#1E90FF" BorderThickness="1"/>
                </StackPanel>


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
        $PcNameBlock = $Window.FindName('PcNameBlock')
        $PcDomainStatusBlock = $Window.FindName('PcDomainStatusBlock')

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
            Show-Output "Deleting computer '$ComputerName' from AD..."
            Delete-ComputerFromAD -ComputerName $ComputerName -DomainController $DomainController -SearchBase $SearchBase
        })

        $DisjoinButton.Add_Click({
            Prompt-Credentials
            $ComputerName = $env:COMPUTERNAME
            $DomainController = $DomainControllerBox.Text.Trim()
            $SearchBase = $SearchBaseBox.Text.Trim()
            Show-Output "Disjoining computer '$ComputerName' from domain..."
            Disjoin-ComputerFromDomain -ComputerName $ComputerName
        })

        $JoinButton.Add_Click({
            Prompt-Credentials
            Show-Output "Opening the Join + OU window..."
            Show-OUWindow
           $SelectedOU = $SelectedOUBox.Text.Trim()
            if ($SelectedOU -ne "") {
                $DomainName = $DomainNameBox.Text.Trim()
                Show-Output "Joining computer to domain '$DomainName' in OU '$SelectedOU'..."
                Join-ComputerWithOU -DomainName $DomainName -OUPath $SelectedOU
            } else {
                Show-Output "----------------------------------------------------------------"
                Show-Error "No OU selected. Please select an OU before joining."
                Show-Output "----------------------------------------------------------------"
            }
        })

        # Update PC Info
        Update-PCInfo -PcNameBlock ([ref]$PcNameBlock) -PcDomainStatusBlock ([ref]$PcDomainStatusBlock)
        
        # Show the GUI
        [void]$Window.ShowDialog()
        

    } catch {
        Show-Error "Failed to initialize GUI: $($_.Exception.Message)"
    }
}

###############################################################################
# MAIN SCRIPT
###############################################################################

try {
    Show-MainGUI
} catch {
    Show-Error "An unexpected error occurred: $($_.Exception.Message)"
}
