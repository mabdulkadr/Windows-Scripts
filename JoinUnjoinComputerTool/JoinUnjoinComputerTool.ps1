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

# Global variable to store AD credentials
$Global:ADCreds = $null

# Log buffer to capture messages before GUI is loaded
$LogBuffer = @()

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

# Display error messages in both message boxes and the console
Function Show-Error {
    param ([string]$Msg)
    [System.Windows.MessageBox]::Show($Msg, "Error", [System.Windows.MessageBoxButton]::OK, [System.Windows.MessageBoxImage]::Error)
    Show-Output "ERROR: $Msg"
}

# Prompt for AD credentials
Function Prompt-Credentials {
    try {
        Show-Output "Prompting for Active Directory credentials..."
        $Global:ADCreds = Get-Credential -Message "Enter Active Directory credentials"
        if (-not $Global:ADCreds) {
            Show-Error "No credentials were entered. Exiting script."
            Exit
        }
        Show-Output "Credentials successfully entered."
    } catch {
        Show-Error "Failed to enter credentials: $($_.Exception.Message)"
        Exit
    }
}

# Prompt Restart
Function Prompt-Restart {
    # Ask the user if they want to restart the computer
    $RestartConfirmation = [System.Windows.MessageBox]::Show(
        "The computer needs to restart to complete the operation. Do you want to restart now?",
        "Restart Required",
        [System.Windows.MessageBoxButton]::YesNo,
        [System.Windows.MessageBoxImage]::Question
    )

    # If the user selects 'Yes', restart the computer
    if ($RestartConfirmation -eq 'Yes') {
        Show-Output "Restarting the computer..." "Orange"
        Restart-Computer -Force
    } else {
        Show-Output "Restart postponed by the user." "Yellow"
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

        if (-not $Global:ADCreds) {
            Show-Error "No credentials provided. Please authenticate first."
            return
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

        # Proceed with deletion
        $LDAPPath = "LDAP://$DomainController/$SearchBase"
        $DirectoryEntry = New-Object DirectoryServices.DirectoryEntry($LDAPPath, $Global:ADCreds.UserName, $Global:ADCreds.GetNetworkCredential().Password)
        $Searcher = New-Object DirectoryServices.DirectorySearcher($DirectoryEntry)
        $Searcher.Filter = "(sAMAccountName=$ComputerName`$)"
        $SearchResult = $Searcher.FindOne()

        if ($SearchResult) {
            $ComputerEntry = $SearchResult.GetDirectoryEntry()
            $ComputerEntry.DeleteTree()
            $ComputerEntry.CommitChanges()
            Show-Output "----------------------------------------------------------------"
            Show-Output "Successfully deleted computer '$ComputerName' from Active Directory."
            Show-Output "----------------------------------------------------------------"
        } else {
            Show-Output "----------------------------------------------------------------"
            Show-Output "Computer '$ComputerName' was not found in Active Directory."
            Show-Output "----------------------------------------------------------------"
        }
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
            Show-Output "Computer '$ComputerName' successfully disjoined from the domain."
            Show-Output "----------------------------------------------------------------"
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
        Show-Output "Computer successfully joined to domain '$DomainName' in OU '$OUPath'."
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
                     Show-Error "Failed to join the computer to domain: $($_.Exception.Message)"
                    Show-Output "----------------------------------------------------------------"
    }
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
        Title='Join / Unjoin Computer Tool' Width='700' Height='620'
        Background='#F0F0F0' WindowStartupLocation='CenterScreen' ResizeMode='NoResize'>
    <Grid>
        <Grid.RowDefinitions>
            <RowDefinition Height='Auto'/>   <!-- Header -->
            <RowDefinition Height='*'/>      <!-- Main Content -->
            <RowDefinition Height='Auto'/>   <!-- Footer -->
        </Grid.RowDefinitions>

        <!-- Header Section -->
        <Border Grid.Row='0' Background='#1E90FF' Padding='15'>
            <TextBlock Text='Join / Unjoin Computer Tool'
                       Foreground='White'
                       FontSize='20'
                       FontWeight='Bold'
                       HorizontalAlignment='Center'/>
            
        </Border>

        <!-- Main Content Section -->
        <StackPanel Grid.Row="1" Margin="20">
            <!-- Form Section -->
            <Grid>
                <Grid.RowDefinitions>
                    <RowDefinition Height="Auto"/> <!-- Domain Controller Row -->
                    <RowDefinition Height="Auto"/> <!-- Domain Name Row -->
                    <RowDefinition Height="Auto"/> <!-- Search Base Row -->
                    <RowDefinition Height="Auto"/> <!-- Selected OU Row -->
                </Grid.RowDefinitions>
                <Grid.ColumnDefinitions>
                    <ColumnDefinition Width="150"/> <!-- Label Column -->
                    <ColumnDefinition Width="*"/>   <!-- Input Box Column -->
                </Grid.ColumnDefinitions>

                <!-- Domain Controller Section -->
                <TextBlock Grid.Row="0" Grid.Column="0" Text="Domain Controller:" FontSize="13" FontWeight="Bold" VerticalAlignment="Center" Margin="0,5,10,5"/>
                <TextBox Grid.Row="0" Grid.Column="1" x:Name="DomainControllerBox" Width="400" Height="25" FontSize="12" Text="$DefaultDomainController"
                         BorderBrush="#1E90FF" BorderThickness="1" Padding="3" Margin="0,5,0,5"/>

                <!-- Domain Name Section -->
                <TextBlock Grid.Row="1" Grid.Column="0" Text="Domain Name:" FontSize="13" FontWeight="Bold" VerticalAlignment="Center" Margin="0,5,10,5"/>
                <TextBox Grid.Row="1" Grid.Column="1" x:Name="DomainNameBox" Width="400" Height="25" FontSize="12" Text="$DefaultDomainName"
                         BorderBrush="#1E90FF" BorderThickness="1" Padding="3" Margin="0,5,0,5"/>

                <!-- Search Base Section -->
                <TextBlock Grid.Row="2" Grid.Column="0" Text="Search Base (OU):" FontSize="13" FontWeight="Bold" VerticalAlignment="Center" Margin="0,5,10,5"/>
                <TextBox Grid.Row="2" Grid.Column="1" x:Name="SearchBaseBox" Width="400" Height="25" FontSize="12" Text="$DefaultSearchBase"
                         BorderBrush="#1E90FF" BorderThickness="1" Padding="3" Margin="0,5,0,5"/>

                <!-- Selected OU Section -->
                <TextBlock Grid.Row="3" Grid.Column="0" Text="Selected OU:" FontSize="13" FontWeight="Bold" VerticalAlignment="Center" Margin="0,5,10,5"/>
                <TextBox Grid.Row="3" Grid.Column="1" x:Name="SelectedOUBox" Width="400" Height="25" FontSize="12" IsReadOnly="True" Background="WhiteSmoke"
                         BorderBrush="#1E90FF" BorderThickness="1" Padding="3" Margin="0,5,0,5"/>
            </Grid>

            <!-- Buttons Section -->
            <StackPanel Orientation="Horizontal" HorizontalAlignment="Center" Margin="0,10,0,10">
                <Button x:Name="DeleteButton" Content="Delete from AD" Width="180" Height="30" Background="#FF6347" Foreground="White"
                        FontSize="12" FontWeight="Bold" Margin="5"/>
                <Button x:Name="DisjoinButton" Content="Disjoin from Domain" Width="180" Height="30" Background="#FFA500" Foreground="White"
                        FontSize="12" FontWeight="Bold" Margin="5"/>
                <Button x:Name="JoinButton" Content="Join to Domain + OU" Width="180" Height="30" Background="#32CD32" Foreground="White"
                        FontSize="12" FontWeight="Bold" Margin="5"/>
            </StackPanel>

            <!-- Console Section -->
            <StackPanel Orientation="Vertical" Margin="0,10,0,0">
                <TextBlock Text="Output Console:" FontSize="14" FontWeight="Bold" Margin="0,0,0,3"/>
                <TextBox x:Name="Console" IsReadOnly="True" Background="Black" Foreground="White" FontFamily="Consolas" FontSize="11"
                         TextWrapping="Wrap" VerticalScrollBarVisibility="Auto" Height="240" BorderBrush="#1E90FF" BorderThickness="1"/>
            </StackPanel>
        </StackPanel>


        <!-- Footer Section -->
        <Border Grid.Row='2' Background='#D3D3D3' Padding='5'>
            <TextBlock Text='© 2025 M.omar(momar.tech) - All Rights Reserved'
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

        # Flush Log Buffer to Console
        foreach ($LogEntry in $LogBuffer) {
            $Console.AppendText("$LogEntry`r`n")
        }

        # Event Handlers
        $DeleteButton.Add_Click({
            if (-not $Global:ADCreds) {
                Prompt-Credentials
            }
            $ComputerName = $env:COMPUTERNAME
            $DomainController = $DomainControllerBox.Text.Trim()
            $SearchBase = $SearchBaseBox.Text.Trim()
            Show-Output "Deleting computer '$ComputerName' from AD..."
            Delete-ComputerFromAD -ComputerName $ComputerName -DomainController $DomainController -SearchBase $SearchBase
        })

        $DisjoinButton.Add_Click({
            if (-not $Global:ADCreds) {
                Prompt-Credentials
            }
            $ComputerName = $env:COMPUTERNAME
            $DomainController = $DomainControllerBox.Text.Trim()
            $SearchBase = $SearchBaseBox.Text.Trim()
            Show-Output "Disjoining computer '$ComputerName' from domain..."
            Disjoin-ComputerFromDomain -ComputerName $ComputerName
            Show-Output "Deleting computer '$ComputerName' from AD..."
            Delete-ComputerFromAD -ComputerName $ComputerName -DomainController $DomainController -SearchBase $SearchBase
        })

        $JoinButton.Add_Click({
            if (-not $Global:ADCreds) {
                Prompt-Credentials
            }
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
    # Show the GUI first
    Show-MainGUI
} catch {
    Show-Error "An unexpected error occurred: $($_.Exception.Message)"
}
