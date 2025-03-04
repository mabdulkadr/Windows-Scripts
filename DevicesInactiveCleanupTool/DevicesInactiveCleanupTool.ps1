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

# Check if the ActiveDirectory module is installed
if (-not (Get-Module -ListAvailable -Name ActiveDirectory)) {
    Write-Error "ActiveDirectory module is not installed. Please install the RSAT tools or the module and try again."
    exit
}

# Load .NET PresentationFramework (WPF) for the GUI
Add-Type -AssemblyName PresentationFramework

###############################################################################
# Define the XAML for the GUI layout
###############################################################################
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
                               ToolTip="Enter the OU path in AD (e.g., OU=Computers,DC=Domain,DC=local)"/>
                    <TextBox x:Name="OUBox" 
                             Width="300" 
                             Height="30" 
                             Text="OU=Computers,DC=company,DC=local" 
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
                    <!-- Highlight selected rows in blue -->
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
                <StackPanel Orientation="Horizontal" HorizontalAlignment="Center">
                    <Button x:Name="DisableButton" 
                            Content="Disable Selected" 
                            Width="150" 
                            Height="30" 
                            Background="#FFA500" 
                            Foreground="White" 
                            FontWeight="Bold" 
                            Margin="5"/>
                    <Button x:Name="DeleteButton" 
                            Content="Delete Selected" 
                            Width="150" 
                            Height="30" 
                            Background="#FF6347" 
                            Foreground="White" 
                            FontWeight="Bold" 
                            Margin="5"/>
                    <Button x:Name="GenerateReportButton" 
                            Content="Generate CSV Report" 
                            Width="180" 
                            Height="30" 
                            Background="#0078D7" 
                            Foreground="White" 
                            FontWeight="Bold" 
                            Margin="5"/>
                    <Button x:Name="ExitButton" 
                            Content="Exit" 
                            Width="100" 
                            Height="30" 
                            Background="#808080" 
                            Foreground="White" 
                            FontWeight="Bold" 
                            Margin="5"/>
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

###############################################################################
# Parse the XAML to generate the WPF Window object
###############################################################################
$reader = New-Object System.Xml.XmlNodeReader($XAML)
$Window = [Windows.Markup.XamlReader]::Load($reader)

###############################################################################
# Retrieve the named UI elements
###############################################################################
$DaysInactiveBox      = $Window.FindName("DaysInactiveBox")
$OUBox                = $Window.FindName("OUBox")
$SearchButton         = $Window.FindName("SearchButton")
$ComputerGrid         = $Window.FindName("ComputerGrid")
$ProgressBar          = $Window.FindName("ProgressBar")
$StatusLabel          = $Window.FindName("StatusLabel")
$ExitButton           = $Window.FindName("ExitButton")
$GenerateReportButton = $Window.FindName("GenerateReportButton")
$DisableButton        = $Window.FindName("DisableButton")
$DeleteButton         = $Window.FindName("DeleteButton")

###############################################################################
# Global Variables for the Background Job and Timer
###############################################################################
$Global:ScanJob           = $null
$Global:ScanTimer         = $null
$Global:InactiveComputers = New-Object System.Collections.ObjectModel.ObservableCollection[PSObject]

###############################################################################
# FUNCTION: Search-InactiveComputers
#   - Validates input
#   - Spawns a background job to query AD
#   - Updates the UI with results once the job completes
###############################################################################
function Search-InactiveComputers {

    # Ensure DaysInactiveBox is a valid integer
    if (-not [int]::TryParse($DaysInactiveBox.Text, [ref]$null)) {
        $StatusLabel.Text = "Invalid 'Days Inactive' value. Please enter a valid number."
        return
    }

    $DaysInactive  = [int]$DaysInactiveBox.Text
    $SearchBaseOU  = $OUBox.Text
    $InactiveCutoff = (Get-Date).AddDays(-$DaysInactive)  # date minus X days

    # Update UI to reflect ongoing work
    $ProgressBar.Visibility = "Visible"
    $ProgressBar.Value = 0
    $StatusLabel.Text = "Searching inactive computers..."

    # Start a background job to prevent blocking the UI
    $Global:ScanJob = Start-Job -ScriptBlock {
        param ($DaysInactive, $SearchBaseOU, $InactiveCutoff)

        Import-Module ActiveDirectory
        $Results = @()

        try {
            # Query all computers in the specified OU
            $AllComputers = Get-ADComputer -Filter * -SearchBase $SearchBaseOU -Property Name, LastLogonDate, DistinguishedName

            foreach ($Computer in $AllComputers) {
                $LastLogonDate = if ($Computer.LastLogonDate) { 
                                    $Computer.LastLogonDate 
                                 } else { 
                                    "No Logon Information" 
                                 }

                $InactiveDays  = if ($LastLogonDate -eq "No Logon Information") {
                                    "N/A"
                                 } else {
                                    (New-TimeSpan -Start $LastLogonDate -End (Get-Date)).Days
                                 }

                # If computer is missing logon info or it's older than cutoff
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

    # Use a DispatcherTimer to poll the background job state
    $Global:ScanTimer = New-Object System.Windows.Threading.DispatcherTimer
    $Global:ScanTimer.Interval = [TimeSpan]::FromMilliseconds(500)
    $Global:ScanTimer.Add_Tick({
        if ($Global:ScanJob.State -eq "Completed") {
            $Global:ScanTimer.Stop()

            # Retrieve the data from the completed job
            $Data = Receive-Job -Job $Global:ScanJob -Keep
            if ($Data -is [string] -and $Data.StartsWith("ERROR")) {
                # Error case
                $StatusLabel.Text = $Data
            }
            else {
                # IMPORTANT: Ensure $Data is a collection; if single item, wrap it
                if (-not ($Data -is [System.Collections.IEnumerable])) {
                    $Data = @($Data) 
                }

                # Bind the results to the DataGrid
                $ComputerGrid.ItemsSource = $Data
                $StatusLabel.Text = "Scan Completed. $($Data.Count) inactive computer(s) found."
            }
            # Hide the progress bar after the job finishes
            $ProgressBar.Visibility = "Hidden"
        }
    })
    $Global:ScanTimer.Start()
}

###############################################################################
# EVENT HANDLERS
###############################################################################

# 1) Search Button
$SearchButton.Add_Click({
    Search-InactiveComputers
})

# 2) Exit Button
$ExitButton.Add_Click({
    $Window.Close()
})

# 3) Generate CSV Report
#    - Exports ONLY: ComputerName, LastLogonDate, InactiveDays, DistinguishedName
$GenerateReportButton.Add_Click({
    # Get current grid data
    $Data = $ComputerGrid.ItemsSource

    # Ensure we have some data to export
    if ($Data -and $Data.Count -gt 0) {
        # Prompt user for save location
        $dlg = New-Object Microsoft.Win32.SaveFileDialog
        $dlg.FileName   = "InactiveComputersReport"
        $dlg.DefaultExt = ".csv"
        $dlg.Filter     = "CSV files (*.csv)|*.csv"

        if ($dlg.ShowDialog() -eq $true) {
            $FileName = $dlg.FileName

            # Select ONLY the 4 columns before exporting
            $ColumnsToExport = $Data | Select-Object ComputerName, LastLogonDate, InactiveDays, DistinguishedName
            $ColumnsToExport | Export-Csv -Path $FileName -NoTypeInformation

            $StatusLabel.Text = "CSV report generated successfully: $FileName"
        }
    }
    else {
        $StatusLabel.Text = "No data available to generate report."
    }
})

# 4) Disable Selected Computers
$DisableButton.Add_Click({
    $selectedItems = $ComputerGrid.SelectedItems
    if ($selectedItems.Count -eq 0) {
        $StatusLabel.Text = "No computer selected to disable."
        return
    }

    # Ask for confirmation
    $confirm = [System.Windows.MessageBox]::Show(
        "Are you sure you want to disable the selected computer(s)?",
        "Confirm Disable",
        [System.Windows.MessageBoxButton]::YesNo,
        [System.Windows.MessageBoxImage]::Question
    )

    if ($confirm -eq [System.Windows.MessageBoxResult]::Yes) {
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

# 5) Delete Selected Computers
$DeleteButton.Add_Click({
    $selectedItems = $ComputerGrid.SelectedItems
    if ($selectedItems.Count -eq 0) {
        $StatusLabel.Text = "No computer selected to delete."
        return
    }

    # Confirm deletion
    $confirm = [System.Windows.MessageBox]::Show(
        "Are you sure you want to delete the selected computer(s)? This action cannot be undone.",
        "Confirm Delete",
        [System.Windows.MessageBoxButton]::YesNo,
        [System.Windows.MessageBoxImage]::Warning
    )

    if ($confirm -eq [System.Windows.MessageBoxResult]::Yes) {
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

        # Refresh the data grid by removing deleted items
        $updatedList = New-Object System.Collections.ObjectModel.ObservableCollection[PSObject]
        foreach ($comp in $ComputerGrid.ItemsSource) {
            if ($selectedItems -notcontains $comp) {
                $updatedList.Add($comp)
            }
        }
        $ComputerGrid.ItemsSource = $updatedList
    }
})

###############################################################################
# Finally, show the Window
###############################################################################
$Window.ShowDialog()
