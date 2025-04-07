<#
.SYNOPSIS
    Devices Inactive Cleanup Tool

.DESCRIPTION
    This script creates a WPF-based GUI to search for and manage inactive computers in Active Directory.
    It allows you to specify how many days a computer should be considered inactive, then displays
    all matching computers in a DataGrid. Each computer’s name, last logon date, inactivity duration,
    and distinguished name are shown.

    The script uses a background job to avoid freezing the GUI while searching AD, and periodically checks
    job status via a DispatcherTimer. Once the job completes, it populates the DataGrid with the results.

    It also provides buttons to:
      - Disable Selected Computers
      - Delete Selected Computers
      - Export the Grid to a CSV (only four columns: ComputerName, LastLogonDate, InactiveDays, and DistinguishedName)
      - Exit the tool

    After deleting selected computers, the grid is refreshed to remove them from the view.

.NOTES
    Author  : Mohammad Abdulkader Omar
    Website : https://momar.tech
    Date    : 2025-02-26
#>

#------------------------------------------------------------------------------
# Custom WPF Message Functions
#------------------------------------------------------------------------------

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

#------------------------------------------------------------------------------
# Load the WPF GUI
#------------------------------------------------------------------------------
Add-Type -AssemblyName PresentationFramework

[xml]$XAML = @"
<Window xmlns='http://schemas.microsoft.com/winfx/2006/xaml/presentation'
        xmlns:x='http://schemas.microsoft.com/winfx/2006/xaml'
        Title='Devices Inactive Cleanup Tool' 
        Background='#F8F8F8' 
        WindowStartupLocation='CenterScreen'
        ResizeMode='NoResize'
        Width='750' Height='750'>

    <Grid>
        <Grid.RowDefinitions>
            <RowDefinition Height='Auto'/>   <!-- Header row -->
            <RowDefinition Height='*'/>      <!-- Main content row -->
            <RowDefinition Height='Auto'/>   <!-- Footer row -->
        </Grid.RowDefinitions>

        <!-- Header Section -->
        <Border Grid.Row='0' Background='#0078D7' Padding='20'>
            <StackPanel Orientation="Horizontal" HorizontalAlignment="Center">
                <TextBlock Text="Devices Inactive Cleanup Tool"
                           Foreground="White"
                           FontSize="24"
                           FontWeight="Bold"
                           VerticalAlignment="Center"/>
            </StackPanel>
        </Border>

        <!-- Main Content Section -->
        <StackPanel Grid.Row="1" Margin="20" Orientation="Vertical" VerticalAlignment="Top">

            <!-- Search Box -->
            <Border BorderBrush="#D3D3D3" BorderThickness="0.5" Padding="5" Margin="0,5,0,5">
                <StackPanel Orientation="Horizontal" HorizontalAlignment="Center">
                    <TextBlock Text="Days Inactive:" 
                               FontSize="14" 
                               Height="30" 
                               FontWeight="Bold" 
                               Margin="5" 
                               ToolTip="Enter the number of days of inactivity"/>
                    <TextBox x:Name="DaysInactiveBox" 
                             Width="60" 
                             Height="30" 
                             Text="180" 
                             Margin="5"/>

                    <TextBlock Text="Search OU:" 
                               FontSize="14" 
                               Height="30" 
                               FontWeight="Bold" 
                               Margin="5" 
                               ToolTip="Select an OU or leave blank for entire domain"/>
                    <ComboBox x:Name="OUComboBox" 
                              Width="100" 
                              Height="30" 
                              Margin="5"/>

                    <Button x:Name="SearchButton" 
                            Content="Search" 
                            Width="100" 
                            Height="30" 
                            Background="#32CD32" 
                            Foreground="White" 
                            FontWeight="Bold" 
                            Margin="10"/>
                </StackPanel>
            </Border>

            <!-- Data Grid to display results -->
            <Border BorderBrush="#D3D3D3" BorderThickness="0.5" Padding="5" Margin="0,5,0,5">
                <DataGrid x:Name="ComputerGrid"
                          Background="White"
                          AutoGenerateColumns="False"
                          CanUserAddRows="False"
                          IsReadOnly="True"
                          SelectionMode="Extended"
                          Height="350">
                    <DataGrid.RowStyle>
                        <Style TargetType="DataGridRow">
                            <Style.Triggers>
                                <Trigger Property="IsSelected" Value="True">
                                    <Setter Property="Background" Value="Blue"/>
                                </Trigger>
                            </Style.Triggers>
                        </Style>
                    </DataGrid.RowStyle>
                    <DataGrid.Columns>
                        <DataGridTextColumn Header="Computer Name" Binding="{Binding ComputerName}" Width="140"/>
                        <DataGridTextColumn Header="Last Logon Date" Binding="{Binding LastLogonDate}" Width="140"/>
                        <DataGridTextColumn Header="Inactive Days" Binding="{Binding InactiveDays}" Width="100"/>
                        <DataGridTextColumn Header="Distinguished Name" Binding="{Binding DistinguishedName}" Width="300"/>
                    </DataGrid.Columns>
                </DataGrid>
            </Border>

            <!-- Progress Bar & Status Label -->
            <Border BorderBrush="#D3D3D3" BorderThickness="0.5" Padding="5" Margin="0,5,0,5">
                <StackPanel Orientation="Vertical" HorizontalAlignment="Center" Margin="5">
                    <ProgressBar x:Name="ProgressBar" 
                                 Width="650" 
                                 Height="20" 
                                 Visibility="Hidden"/>
                    <TextBlock x:Name="StatusLabel" 
                               Text="" 
                               FontSize="14" 
                               Height="20" 
                               Foreground="Black" 
                               Margin="5" 
                               TextAlignment="Center"/>
                </StackPanel>
            </Border>
            <!-- Action Buttons -->
            <Border BorderBrush="#D3D3D3" BorderThickness="0.5" Padding="5" Margin="0,5,0,5">
                <StackPanel Orientation="Horizontal" HorizontalAlignment="Center" Margin="5">
                    <Button x:Name="DisableButton" 
                            Content="Disable Selected" 
                            Width="150" 
                            Height="30" 
                            Margin="5" 
                            Background="#DC3545" 
                            Foreground="White" 
                            FontWeight="Bold" 
                            BorderThickness="0" 
                            Cursor="Hand"/>
                    <Button x:Name="DeleteButton" 
                            Content="Delete Selected" 
                            Width="150" 
                            Height="30" 
                            Margin="5" 
                            Background="#DC3545" 
                            Foreground="White" 
                            FontWeight="Bold" 
                            BorderThickness="0" 
                            Cursor="Hand"/>
                    <Button x:Name="GenerateReportButton" 
                            Content="Generate CSV Report" 
                            Width="160" 
                            Height="30" 
                            Margin="5" 
                            Background="#0078D7" 
                            Foreground="White" 
                            FontWeight="Bold" 
                            BorderThickness="0" 
                            Cursor="Hand"/>
                    <Button x:Name="ExitButton" 
                            Content="Exit" 
                            Width="100" 
                            Height="30" 
                            Margin="5" 
                            Background="#FFA500" 
                            Foreground="White" 
                            FontWeight="Bold" 
                            BorderThickness="0" 
                            Cursor="Hand"/>
                </StackPanel>
            </Border>
        </StackPanel>

        <!-- Footer Section -->
        <Border Grid.Row='2' Background='#D3D3D3' Padding='5'>
            <TextBlock Text='� 2025 M.omar (momar.tech) - All Rights Reserved'
                       Foreground='Black' 
                       FontSize='10' 
                       HorizontalAlignment='Center'/>
        </Border>
    </Grid>
</Window>
"@

$reader = New-Object System.Xml.XmlNodeReader($XAML)
$Window = [Windows.Markup.XamlReader]::Load($reader)

# Retrieve the named UI elements.
$DaysInactiveBox      = $Window.FindName("DaysInactiveBox")
$OUComboBox           = $Window.FindName("OUComboBox")
$SearchButton         = $Window.FindName("SearchButton")
$ComputerGrid         = $Window.FindName("ComputerGrid")
$ProgressBar          = $Window.FindName("ProgressBar")
$StatusLabel          = $Window.FindName("StatusLabel")
$ExitButton           = $Window.FindName("ExitButton")
$GenerateReportButton = $Window.FindName("GenerateReportButton")
$DisableButton        = $Window.FindName("DisableButton")
$DeleteButton         = $Window.FindName("DeleteButton")

#------------------------------------------------------------------------------
# FUNCTION: Populate-OUComboBox
#   - Populates the OU ComboBox with all OUs in the domain.
#------------------------------------------------------------------------------
function Populate-OUComboBox {
    try {
        Import-Module ActiveDirectory
        $domainDN = (Get-ADDomain).DistinguishedName
        $OUs = Get-ADObject -Filter "ObjectClass -eq 'organizationalUnit'" -SearchBase $domainDN -ResultPageSize 2000 | Select-Object -ExpandProperty DistinguishedName
        $OUs = @("Entire Domain") + $OUs
        # Manually sort the OU list alphabetically.
        $SortedOUs = $OUs | Sort-Object

        # Set ComboBox properties for usability and appearance.
        $OUComboBox.IsEditable = $true
        $OUComboBox.StaysOpenOnEdit = $true
        $OUComboBox.IsTextSearchEnabled = $false
        $OUComboBox.Width = 300
        $OUComboBox.MinWidth = 200
        $OUComboBox.MaxWidth = 400           # Set maximum width to 400.
        $OUComboBox.MaxDropDownHeight = 300  # Controls dropdown height.

        # Bind the sorted OU list to the ComboBox.
        $OUComboBox.ItemsSource = $SortedOUs

        # Limit each dropdown item to 400px width with horizontal scroll
# Add after setting ItemsSource
# Limit each dropdown item to 400px width with horizontal scroll
$styleXaml = @"
<Style xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation" TargetType="ComboBoxItem">
    <Setter Property="Width" Value="400"/>
    <Setter Property="HorizontalContentAlignment" Value="Stretch"/>
    <Setter Property="ToolTip" Value="{Binding DN}"/>
</Style>
"@

$reader = New-Object System.Xml.XmlNodeReader([xml]$styleXaml)
$style = [System.Windows.Markup.XamlReader]::Load($reader)
$OUComboBox.ItemContainerStyle = $style




        # Retrieve the editable TextBox part of the ComboBox for handling text change.
        $editableTextBox = $OUComboBox.Template.FindName("PART_EditableTextBox", $OUComboBox)
        if ($editableTextBox) {
            $editableTextBox.Add_TextChanged({
                $filterText = $OUComboBox.Text
                if ([string]::IsNullOrWhiteSpace($filterText)) {
                    $OUComboBox.ItemsSource = $SortedOUs
                }
                else {
                    $FilteredOUs = $SortedOUs | Where-Object { $_ -like "*$filterText*" }
                    $OUComboBox.ItemsSource = $FilteredOUs
                }
            })
        }
        $OUComboBox.SelectedIndex = 0
    }
    catch {
        Show-WPFMessage -Message "Failed to retrieve OUs: $($_.Exception.Message)" -Title "Error" -Color "Red"
        return
    }
}

# Populate the OU ComboBox on script start
Populate-OUComboBox


#------------------------------------------------------------------------------
# FUNCTION: Search-InactiveComputers
#   - Checks if ActiveDirectory module is installed.
#   - Checks if the Search OU value is valid (i.e. not left as default).
#   - Validates Days Inactive and spawns a background job to query AD.
#------------------------------------------------------------------------------
function Search-InactiveComputers {

    # Check if the ActiveDirectory module is installed.
    if (-not (Get-Module -ListAvailable -Name ActiveDirectory)) {
        $userChoice = Show-WPFConfirmation -Message "ActiveDirectory module is not installed on this system.`nWould you like to attempt to install it now?" -Title "Module Missing" -Color "Orange"
        if ($userChoice -eq $true) {
            try {
                if (Get-Command Install-WindowsFeature -ErrorAction SilentlyContinue) {
                    Show-WPFMessage -Message "Detected Install-WindowsFeature command.`nInstalling RSAT-AD-PowerShell..." -Title "Installation" -Color "Blue"
                    Install-WindowsFeature RSAT-AD-PowerShell -IncludeAllSubFeature -ErrorAction Stop
                }
                elseif (Get-Command Add-WindowsCapability -ErrorAction SilentlyContinue) {
                    Show-WPFMessage -Message "Detected Add-WindowsCapability command.`nInstalling RSAT ActiveDirectory DS-LDS Tools..." -Title "Installation" -Color "Blue"
                    Add-WindowsCapability -Online -Name "Rsat.ActiveDirectory.DS-LDS.Tools~~~~0.0.1.0" -ErrorAction Stop
                }
                else {
                    Show-WPFMessage -Message "No automated installation method available.`nPlease install the RSAT tools manually or run the script from a Domain Controller." -Title "Installation Error" -Color "Red"
                    return
                }
                Show-WPFMessage -Message "ActiveDirectory module installed successfully.`nPlease restart the script to continue." -Title "Installation Success" -Color "Green"
                return
            }
            catch {
                Show-WPFMessage -Message "Installation failed: $($_.Exception.Message)" -Title "Installation Error" -Color "Red"
                return
            }
        }
        else {
            Show-WPFMessage -Message "ActiveDirectory module is required to run this script.`nThe search will now be cancelled." -Title "Module Missing" -Color "Red"
            return
        }
    }

    # Check if a valid Search OU is selected.
    if ($OUComboBox.SelectedItem -eq "Entire Domain") {
        $SearchBaseOU = ""
    }
    else {
        $SearchBaseOU = $OUComboBox.SelectedItem
    }

    # Validate that 'Days Inactive' is a valid integer.
    if (-not [int]::TryParse($DaysInactiveBox.Text, [ref]$null)) {
        $StatusLabel.Text = "Invalid 'Days Inactive' value. Please enter a valid number."
        return
    }

    $DaysInactive  = [int]$DaysInactiveBox.Text
    $InactiveCutoff = (Get-Date).AddDays(-$DaysInactive)

    # Update UI to indicate search progress.
    $ProgressBar.Visibility = "Visible"
    $ProgressBar.Value = 0
    $StatusLabel.Text = "Searching inactive computers..."

    # Spawn a background job to query Active Directory.
    $Global:ScanJob = Start-Job -ScriptBlock {
        param ($DaysInactive, $SearchBaseOU, $InactiveCutoff)

        Import-Module ActiveDirectory
        $Results = @()
        try {
            $AllComputers = if ($SearchBaseOU) {
                Get-ADComputer -Filter * -SearchBase $SearchBaseOU -Property Name, LastLogonDate, DistinguishedName
            } else {
                Get-ADComputer -Filter * -Property Name, LastLogonDate, DistinguishedName
            }
            foreach ($Computer in $AllComputers) {
                $LastLogonDate = if ($Computer.LastLogonDate) { $Computer.LastLogonDate } else { "No Logon Information" }
                $InactiveDays  = if ($LastLogonDate -eq "No Logon Information") { "N/A" } else { (New-TimeSpan -Start $LastLogonDate -End (Get-Date)).Days }
                if ($LastLogonDate -eq "No Logon Information" -or ([DateTime]$LastLogonDate -lt $InactiveCutoff)) {
                    $Results += [PSCustomObject]@{
                        ComputerName      = $Computer.Name
                        LastLogonDate     = $LastLogonDate
                        InactiveDays      = $InactiveDays
                        DistinguishedName = $Computer.DistinguishedName
                    }
                }
            }
            return $Results
        }
        catch {
            return "ERROR: $_"
        }
    } -ArgumentList $DaysInactive, $SearchBaseOU, $InactiveCutoff

    # Use a DispatcherTimer to poll the background job status.
    $Global:ScanTimer = New-Object System.Windows.Threading.DispatcherTimer
    $Global:ScanTimer.Interval = [TimeSpan]::FromMilliseconds(500)
    $Global:ScanTimer.Add_Tick({
        if ($Global:ScanJob.State -eq "Completed") {
            $Global:ScanTimer.Stop()
            $Data = Receive-Job -Job $Global:ScanJob -Keep
            if ($Data -is [string] -and $Data.StartsWith("ERROR")) {
                $StatusLabel.Text = $Data
            }
            else {
                if (-not ($Data -is [System.Collections.IEnumerable])) { $Data = @($Data) }
                $ComputerGrid.ItemsSource = $Data
                $StatusLabel.Text = "Scan Completed. $($Data.Count) inactive computer(s) found."
            }
            $ProgressBar.Visibility = "Hidden"
        }
    })
    $Global:ScanTimer.Start()
}

#------------------------------------------------------------------------------
# EVENT HANDLERS
#------------------------------------------------------------------------------

# When Search button is clicked, run the enhanced search function.
$SearchButton.Add_Click({ Search-InactiveComputers })

# Exit button: Closes the application.
$ExitButton.Add_Click({ $Window.Close() })

# Generate CSV Report: Exports the grid data to a CSV file.
$GenerateReportButton.Add_Click({
    $Data = $ComputerGrid.ItemsSource
    if ($Data -and $Data.Count -gt 0) {
        $dlg = New-Object Microsoft.Win32.SaveFileDialog
        $dlg.FileName   = "InactiveComputersReport"
        $dlg.DefaultExt = ".csv"
        $dlg.Filter     = "CSV files (*.csv)|*.csv"
        if ($dlg.ShowDialog() -eq $true) {
            $FileName = $dlg.FileName
            $ColumnsToExport = $Data | Select-Object ComputerName, LastLogonDate, InactiveDays, DistinguishedName
            $ColumnsToExport | Export-Csv -Path $FileName -NoTypeInformation
            $StatusLabel.Text = "CSV report generated successfully: $FileName"
        }
    }
    else {
        $StatusLabel.Text = "No data available to generate report."
    }
})

# Disable Selected Computers: Disables the selected AD computer accounts.
$DisableButton.Add_Click({
    $selectedItems = $ComputerGrid.SelectedItems
    if ($selectedItems.Count -eq 0) {
        $StatusLabel.Text = "No computer selected to disable."
        return
    }
    $confirm = Show-WPFConfirmation -Message "Are you sure you want to disable the selected computer(s)?" -Title "Confirm Disable" -Color "Blue"
    if ($confirm -eq $true) {
        Import-Module ActiveDirectory
        foreach ($item in $selectedItems) {
            try {
                Disable-ADAccount -Identity $item.DistinguishedName -ErrorAction Stop
                $StatusLabel.Text = "Disabled: $($item.ComputerName)"
            }
            catch {
                $StatusLabel.Text = "Error disabling $($item.ComputerName): $_"
            }
        }
    }
})

# Delete Selected Computers: Deletes the selected AD computer accounts.
$DeleteButton.Add_Click({
    $selectedItems = $ComputerGrid.SelectedItems
    if ($selectedItems.Count -eq 0) {
        $StatusLabel.Text = "No computer selected to delete."
        return
    }
    $confirm = Show-WPFConfirmation -Message "Are you sure you want to delete the selected computer(s)? This action cannot be undone." -Title "Confirm Delete" -Color "Red"
    if ($confirm -eq $true) {
        Import-Module ActiveDirectory
        foreach ($item in $selectedItems) {
            try {
                Remove-ADComputer -Identity $item.DistinguishedName -Confirm:$false -ErrorAction Stop
                $StatusLabel.Text = "Deleted: $($item.ComputerName)"
            }
            catch {
                $StatusLabel.Text = "Error deleting $($item.ComputerName): $_"
            }
        }
        $updatedList = New-Object System.Collections.ObjectModel.ObservableCollection[PSObject]
        foreach ($comp in $ComputerGrid.ItemsSource) {
            if ($selectedItems -notcontains $comp) { $updatedList.Add($comp) }
        }
        $ComputerGrid.ItemsSource = $updatedList
    }
})

#------------------------------------------------------------------------------
# Finally, show the Window.
#------------------------------------------------------------------------------
$Window.ShowDialog()
