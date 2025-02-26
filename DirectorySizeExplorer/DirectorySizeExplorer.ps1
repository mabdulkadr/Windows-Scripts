<#
.SYNOPSIS
    Directory Size Explorer GUI Tool (Fully Recursive, Asynchronous Incremental Scanning)

.DESCRIPTION
    This script creates a WPF-based GUI tool for scanning a specified directory 
    (or a folder selected in the grid) and displaying the fully recursive size 
    of each top-level item. The scan is performed in a background job and results 
    are streamed incrementally to the DataGrid via a DispatcherTimer, so that 
    items appear as they’re discovered. The grid is read-only; folders are shown 
    with a light yellow background and files with light gray.
    
    The "Size" column is bound to a human-readable property ("PrettySize") but 
    uses the numeric "Size" property (explicitly cast as [long]) for sorting.
    
.NOTES
    Author  : Mohammad Abdulkader Omar
    Website : https://momar.tech
    Date    : 2025-02-26
#>

Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase
[System.Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms") | Out-Null

# Global variables
$Global:CurrentFolder = $null
$Global:GridData      = New-Object System.Collections.ObjectModel.ObservableCollection[System.Object]
$Global:ScanJob       = $null
$Global:ScanTimer     = $null

# XAML Layout (7 rows: Header, Directory Selection, Scan Status, DataGrid, Progress Bar, Buttons, Footer)
$XAML = @"
<Window
    xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
    xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
    WindowStartupLocation="CenterScreen"
    Title="Directory Size Explorer" 
    Height="650" Width="800"
    Background="#1E1E1E" 
    Foreground="White" 
    FontFamily="Segoe UI">
  <Grid>
    <Grid.RowDefinitions>
      <RowDefinition Height="Auto" />    <!-- Header -->
      <RowDefinition Height="Auto" />    <!-- Directory Selection -->
      <RowDefinition Height="Auto" />    <!-- Scan Status -->
      <RowDefinition Height="*" />       <!-- DataGrid -->
      <RowDefinition Height="Auto" />    <!-- Progress Bar -->
      <RowDefinition Height="Auto" />    <!-- Buttons -->
      <RowDefinition Height="Auto" />    <!-- Footer -->
    </Grid.RowDefinitions>

    <!-- HEADER -->
    <Border Grid.Row="0" Background="#0078D7" Padding="15">
      <StackPanel Orientation="Horizontal" HorizontalAlignment="Center">
        <TextBlock Text="Directory Size Explorer"
                   Foreground="White"
                   FontSize="24"
                   FontWeight="Bold"
                   VerticalAlignment="Center"/>
      </StackPanel>
    </Border>

    <!-- Directory Selection -->
    <StackPanel Grid.Row="1" Orientation="Horizontal" Margin="10">
      <Label Content="Select Directory:" Foreground="White" FontSize="14" Height="30"/>
      <TextBox Name="DirectoryPath" Width="500" Height="30" Background="#333333" Foreground="White" Margin="5"/>
      <Button Name="BrowseButton" Content="Browse" Width="100" Height="30" Background="#007ACC" Foreground="White"/>
    </StackPanel>

    <!-- Scan Status Message -->
    <Label Grid.Row="2" Name="ScanMessage" Content="" Background="#333333" Foreground="Yellow" Margin="10" />

    <!-- Results DataGrid (ReadOnly) -->
    <DataGrid Grid.Row="3" Name="ResultsGrid" Margin="10"
              Background="White" Foreground="Black"
              HeadersVisibility="Column" AutoGenerateColumns="False"
              ItemsSource="{Binding}" SelectionMode="Single" SelectionUnit="FullRow"
              CanUserSortColumns="True" IsReadOnly="True">
      <!-- RowStyle: Files in LightGray, Folders in LightYellow -->
      <DataGrid.RowStyle>
        <Style TargetType="DataGridRow">
          <Setter Property="Background" Value="LightGray" />
          <Style.Triggers>
            <DataTrigger Binding="{Binding Icon}" Value="📁">
              <Setter Property="Background" Value="LightYellow" />
            </DataTrigger>
          </Style.Triggers>
        </Style>
      </DataGrid.RowStyle>
      <DataGrid.ContextMenu>
        <ContextMenu>
          <MenuItem Header="Open in Explorer" Name="MenuOpenExplorer"/>
          <MenuItem Header="Scan Folder" Name="MenuScanSingle"/>
          <MenuItem Header="Properties" Name="MenuProperties"/>
        </ContextMenu>
      </DataGrid.ContextMenu>
      <DataGrid.Columns>
        <DataGridTextColumn Header="Type" Binding="{Binding Icon}" Width="50" />
        <DataGridTextColumn Header="Path" Binding="{Binding Path}" Width="*" />
        <!-- The Size column displays PrettySize but sorts using numeric "Size" -->
        <DataGridTextColumn Header="Size" Binding="{Binding PrettySize}" Width="120" SortMemberPath="Size" />
        <DataGridTextColumn Header="Modified" Binding="{Binding Modified}" Width="150" />
      </DataGrid.Columns>
    </DataGrid>

    <!-- Progress Bar -->
    <ProgressBar Grid.Row="4" Name="ProgressBar" Height="20" Margin="10" Visibility="Collapsed" />

    <!-- Buttons -->
    <StackPanel Grid.Row="5" Orientation="Horizontal" HorizontalAlignment="Center" Margin="10">
      <Button Name="ScanButton" Content="Scan" Width="100" Height="30" Background="#28A745" Foreground="White" Margin="5"/>
      <Button Name="GoBackButton" Content="Go Back" Width="100" Height="30" Background="#FFD700" Foreground="Black" Margin="5"/>
      <Button Name="DeleteButton" Content="Delete" Width="100" Height="30" Background="#C0392B" Foreground="White" Margin="5"/>
      <Button Name="ExitButton" Content="Exit" Width="100" Height="30" Background="#DC3545" Foreground="White" Margin="5"/>
    </StackPanel>

    <!-- FOOTER -->
    <Border Grid.Row="6" Background="#D3D3D3" Padding="5">
      <TextBlock Text="© 2025 M.omar (momar.tech) - All Rights Reserved"
                 Foreground="Black" FontSize="10" HorizontalAlignment="Center"/>
    </Border>
  </Grid>
</Window>
"@

# Parse the XAML.
try {
    [xml]$XAMLWindow = $XAML
} catch {
    Write-Host "Error parsing XAML: $($_.Exception.Message)"
    return
}
$Reader = New-Object System.Xml.XmlNodeReader($XAMLWindow)
$Form = [Windows.Markup.XamlReader]::Load($Reader)

# Capture UI elements.
$DirectoryPath    = $Form.FindName("DirectoryPath")
$BrowseButton     = $Form.FindName("BrowseButton")
$ScanMessage      = $Form.FindName("ScanMessage")
$ResultsGrid      = $Form.FindName("ResultsGrid")
$ProgressBar      = $Form.FindName("ProgressBar")
$ScanButton       = $Form.FindName("ScanButton")
$GoBackButton     = $Form.FindName("GoBackButton")
$DeleteButton     = $Form.FindName("DeleteButton")
$ExitButton       = $Form.FindName("ExitButton")
$MenuOpenExplorer = $Form.FindName("MenuOpenExplorer")
$MenuScanSingle   = $Form.FindName("MenuScanSingle")
$MenuProperties   = $Form.FindName("MenuProperties")

# Bind the DataGrid's ItemsSource.
$ResultsGrid.DataContext = $Global:GridData

# --- Helper: Clear any existing scan job.
function Clear-OldJob {
    if ($Global:ScanJob -and ($Global:ScanJob.State -in @('Completed','Failed','Stopped'))) {
        Receive-Job -Job $Global:ScanJob -ErrorAction SilentlyContinue | Out-Null
        Remove-Job -Job $Global:ScanJob -Force | Out-Null
        $Global:ScanJob = $null
    }
}

# --- Start-FolderScan: Launch a background job to scan folder and stream results.
function Start-FolderScan {
    param([string]$Path)
    Clear-OldJob
    $Global:GridData.Clear()
    $Form.Dispatcher.Invoke({
        $ScanMessage.Content = "Scanning folder: $Path"
        $ProgressBar.Visibility = "Visible"
        $ProgressBar.Value = 0
    })
    $Global:ScanJob = Start-Job -ScriptBlock {
        param($scanPath)
        # Define helper functions in the job scope.
        function Convert-SizeToHumanReadable {
            param([long]$Size)
            switch ($Size) {
                { $_ -lt 1MB } { return ("{0:N2} KB" -f ([long]($Size / 1KB))) }
                { $_ -lt 1GB } { return ("{0:N2} MB" -f ([long]($Size / 1MB))) }
                default { return ("{0:N2} GB" -f ([long]($Size / 1MB))) }
            }
        }
        function Get-FolderSizeRecursive {
            param([string]$FolderPath)
            try {
                (Get-ChildItem -Path $FolderPath -Recurse -File -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum
            }
            catch { 0 }
        }
        $items = Get-ChildItem -Path $scanPath -ErrorAction SilentlyContinue
        if ($items) {
            foreach ($item in $items) {
                if ($item.PSIsContainer) {
                    $icon = "📁"
                    $size = [long](Get-FolderSizeRecursive -FolderPath $item.FullName)
                }
                else {
                    $icon = "📄"
                    $size = [long]$item.Length
                }
                $obj = [PSCustomObject]@{
                    Icon       = $icon
                    Path       = $item.FullName
                    Size       = $size
                    PrettySize = Convert-SizeToHumanReadable -Size $size
                    Modified   = $item.LastWriteTime
                }
                Write-Output $obj
            }
        }
    } -ArgumentList $Path

    # Create a global DispatcherTimer to poll the job.
    $Global:ScanTimer = New-Object System.Windows.Threading.DispatcherTimer
    $Global:ScanTimer.Interval = [TimeSpan]::FromMilliseconds(500)
    $Global:ScanTimer.Add_Tick({
        if ($Global:ScanJob) {
            $newItems = Receive-Job -Job $Global:ScanJob -Keep -ErrorAction SilentlyContinue
            if ($newItems) {
                foreach ($obj in $newItems) {
                    $Global:GridData.Add($obj)
                    $Form.Dispatcher.Invoke({ $ProgressBar.Value++ })
                }
            }
            if ($Global:ScanJob.State -in @('Completed','Failed','Stopped')) {
                if ($Global:ScanTimer -ne $null) {
                    try { 
                        $Global:ScanTimer.Stop() 
                    } catch { }
                }
                $ScanMessage.Content = "Scan completed."
                $Form.Dispatcher.Invoke({ $ProgressBar.Visibility = "Collapsed" })
                Clear-OldJob
            }
        }
    })
    $Global:ScanTimer.Start()
}

# --- Event Handlers ---

# Browse Button: Open FolderBrowserDialog.
$BrowseButton.Add_Click({
    [System.Windows.Forms.Application]::EnableVisualStyles()
    $FolderDialog = New-Object System.Windows.Forms.FolderBrowserDialog
    $FolderDialog.Description = "Select a Directory"
    $FolderDialog.ShowNewFolderButton = $false
    $result = $FolderDialog.ShowDialog()
    if ($result -eq [System.Windows.Forms.DialogResult]::OK) {
        $DirectoryPath.Text = $FolderDialog.SelectedPath
        $Global:CurrentFolder = $FolderDialog.SelectedPath
    }
})

# Go Back Button: Navigate to parent folder.
$GoBackButton.Add_Click({
    if (-not $Global:CurrentFolder) {
        [System.Windows.MessageBox]::Show("No current folder to go back from.","Info","OK","Information") | Out-Null
        return
    }
    $parent = Split-Path $Global:CurrentFolder -Parent
    if ($parent) {
        $Global:CurrentFolder = $parent
        $DirectoryPath.Text = $parent
        Start-FolderScan -Path $parent
    }
    else {
        [System.Windows.MessageBox]::Show("No parent directory found.","Info","OK","Information") | Out-Null
    }
})

# Scan Button: Scan folder (if a folder row is selected, use that; otherwise, use DirectoryPath).
$ScanButton.Add_Click({
    $selected = $ResultsGrid.SelectedItem
    if ($selected -and (Test-Path $selected.Path) -and ((Get-Item $selected.Path).PSIsContainer)) {
        $folderToScan = $selected.Path
    }
    else {
        $folderToScan = $DirectoryPath.Text
    }
    if (-not (Test-Path $folderToScan)) {
        [System.Windows.MessageBox]::Show("Please select a valid directory.","Error","OK","Error") | Out-Null
        return
    }
    if (-not (Get-Item $folderToScan).PSIsContainer) {
        [System.Windows.MessageBox]::Show("The specified path is a file and cannot be scanned.","Error","OK","Error") | Out-Null
        return
    }
    $Global:CurrentFolder = $folderToScan
    Start-FolderScan -Path $folderToScan
})

# Delete Button: Delete selected item.
$DeleteButton.Add_Click({
    $selected = $ResultsGrid.SelectedItem
    if (-not $selected) {
        [System.Windows.MessageBox]::Show("No item selected. Please highlight a folder or file first.","Warning","OK","Warning") | Out-Null
        return
    }
    $confirm = [System.Windows.MessageBox]::Show("Are you sure you want to delete the following?`n$($selected.Path)","Confirm Delete","YesNo","Warning")
    if ($confirm -eq "Yes") {
        try {
            Remove-Item -LiteralPath $selected.Path -Recurse -Force
            [System.Windows.MessageBox]::Show("Deleted successfully.","Info","OK","Information") | Out-Null
            $Global:GridData.Remove($selected) | Out-Null
        }
        catch {
            [System.Windows.MessageBox]::Show("Failed to delete.`n$($_.Exception.Message)","Error","OK","Error") | Out-Null
        }
    }
})

# Context Menu: Open in Explorer.
$MenuOpenExplorer.Add_Click({
    $selected = $ResultsGrid.SelectedItem
    if ($selected -and (Test-Path $selected.Path)) {
        Start-Process explorer.exe $selected.Path
    }
    else {
        [System.Windows.MessageBox]::Show("No valid path selected.","Info","OK","Information") | Out-Null
    }
})

# Context Menu: Scan Single (behaves same as Scan button).
$MenuScanSingle.Add_Click({
    $selected = $ResultsGrid.SelectedItem
    if ($selected -and (Test-Path $selected.Path) -and ((Get-Item $selected.Path).PSIsContainer)) {
        $folderToScan = $selected.Path
    }
    else {
        $folderToScan = $DirectoryPath.Text
    }
    if (-not (Test-Path $folderToScan)) {
        [System.Windows.MessageBox]::Show("Please select a valid directory.","Error","OK","Error") | Out-Null
        return
    }
    if (-not (Get-Item $folderToScan).PSIsContainer) {
        [System.Windows.MessageBox]::Show("The specified path is a file and cannot be scanned.","Error","OK","Error") | Out-Null
        return
    }
    $Global:CurrentFolder = $folderToScan
    Start-FolderScan -Path $folderToScan
})

# Context Menu: Properties.
$MenuProperties.Add_Click({
    $selected = $ResultsGrid.SelectedItem
    if (-not $selected) {
        [System.Windows.MessageBox]::Show("No item selected.","Warning","OK","Warning") | Out-Null
        return
    }
    if (-not (Test-Path $selected.Path)) {
        [System.Windows.MessageBox]::Show("Invalid path.","Error","OK","Error") | Out-Null
        return
    }
    $itemObj = Get-Item $selected.Path
    $type = if ($itemObj.PSIsContainer) { "Folder" } else { "File" }
    $details = "Path: $($itemObj.FullName)`n"
    $details += "Type: $type`n"
    $details += "Size: $($selected.PrettySize)`n"
    $details += "Created: $($itemObj.CreationTime)`n"
    $details += "Modified: $($itemObj.LastWriteTime)"
    [System.Windows.MessageBox]::Show($details,"Properties","OK","Information") | Out-Null
})

# Double-click on a row: Do nothing.
$ResultsGrid.Add_MouseDoubleClick({
    # Intentionally left blank.
})

# Exit Button: Close the GUI.
$ExitButton.Add_Click({
    $Form.Close()
})

# Show the GUI.
$Form.ShowDialog() | Out-Null
