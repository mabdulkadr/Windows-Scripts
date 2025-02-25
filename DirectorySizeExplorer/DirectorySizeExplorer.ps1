<#
.SYNOPSIS
   Directory Size Explorer GUI Tool (Fully Recursive Folder Sizes)

.DESCRIPTION
   This script creates a WPF-based GUI tool for scanning a specified directory 
   (or a folder selected in the grid) and displaying the *fully recursive* size 
   of each folder. Folders are colored light yellow and files light gray.  
   Includes a header, footer, "Go Back" functionality, and context menu options.

.NOTES
   - Header: "Join / Unjoin Computer Tool"
   - Footer: "© 2025 M.omar (momar.tech) - All Rights Reserved"
   - Recursive scanning can be slow for large directories.
#>

Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase

[System.Reflection.Assembly]::LoadWithPartialName("System.Drawing") | Out-Null
[System.Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms") | Out-Null

# Global variable to track the currently scanned folder
$Global:CurrentFolder = $null

# ObservableCollection for the DataGrid (dynamic binding)
$Global:GridData = New-Object System.Collections.ObjectModel.ObservableCollection[System.Object]

# XAML layout with header and footer
$XAML = @"
<Window
    xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
    xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
    Title="Directory Size Explorer" Height="650" Width="800"
    Background="#1E1E1E" Foreground="White" FontFamily="Segoe UI">
  <Grid>
    <!-- 7 rows: header, directory selection, status, grid, progress, buttons, footer -->
    <Grid.RowDefinitions>
      <RowDefinition Height="Auto" />    <!-- Header -->
      <RowDefinition Height="Auto" />    <!-- Directory Selection -->
      <RowDefinition Height="Auto" />    <!-- Scan Status Message -->
      <RowDefinition Height="*" />       <!-- Results DataGrid -->
      <RowDefinition Height="Auto" />    <!-- Progress Bar -->
      <RowDefinition Height="Auto" />    <!-- Buttons -->
      <RowDefinition Height="Auto" />    <!-- Footer -->
    </Grid.RowDefinitions>

    <!-- Header Section -->
    <Border Grid.Row="0" Background="#0078D7" Padding="15">
      <StackPanel Orientation="Horizontal" HorizontalAlignment="Center">
        <TextBlock Text="Join / Unjoin Computer Tool"
                   Foreground="White"
                   FontSize="24"
                   FontWeight="Bold"
                   VerticalAlignment="Center"/>
      </StackPanel>
    </Border>

    <!-- Directory Selection (Row 1) -->
    <StackPanel Grid.Row="1" Orientation="Horizontal" Margin="10">
      <Label Content="Select Directory:" Foreground="White" FontSize="14" Height="30"/>
      <TextBox Name="DirectoryPath" Width="500" Height="30" Background="#333333" Foreground="White" Margin="5"/>
      <Button Name="BrowseButton" Content="Browse" Width="100" Height="30" Background="#007ACC" Foreground="White"/>
    </StackPanel>

    <!-- Scan Status Message (Row 2) -->
    <Label Grid.Row="2" Name="ScanMessage" Content="" Background="#333333" Foreground="Yellow" Margin="10" />

    <!-- Results DataGrid (Row 3) -->
    <DataGrid Grid.Row="3" Name="ResultsGrid" Margin="10"
              Background="White" Foreground="Black"
              HeadersVisibility="Column" AutoGenerateColumns="False"
              ItemsSource="{Binding}" SelectionMode="Single" SelectionUnit="FullRow"
              CanUserSortColumns="True">
      <!-- RowStyle to color folders (light yellow) and files (light gray) -->
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
          <MenuItem Header="Scan Single" Name="MenuScanSingle"/>
          <MenuItem Header="Properties" Name="MenuProperties"/>
        </ContextMenu>
      </DataGrid.ContextMenu>
      <DataGrid.Columns>
        <DataGridTextColumn Header="Type" Binding="{Binding Icon}" Width="50" />
        <DataGridTextColumn Header="Path" Binding="{Binding Path}" Width="*" />
        <DataGridTextColumn Header="Size" Binding="{Binding PrettySize}" Width="120" />
        <DataGridTextColumn Header="Modified" Binding="{Binding Modified}" Width="150" />
        <DataGridTextColumn 
            Header="Size" 
            Binding="{Binding PrettySize}" 
            Width="120"
            SortMemberPath="Size" />
        </DataGrid.Columns>
        </DataGrid>

    <!-- Progress Bar (Row 4) -->
    <ProgressBar Grid.Row="4" Name="ProgressBar" Height="20" Margin="10" Visibility="Collapsed" />

    <!-- Buttons (Row 5) -->
    <StackPanel Grid.Row="5" Orientation="Horizontal" HorizontalAlignment="Center" Margin="10">
      <Button Name="ScanButton" Content="Scan" Width="100" Height="30" Background="#28A745" Foreground="White" Margin="5"/>
      <Button Name="GoBackButton" Content="Go Back" Width="100" Height="30" Background="#FFD700" Foreground="Black" Margin="5"/>
      <Button Name="DeleteButton" Content="Delete" Width="100" Height="30" Background="#C0392B" Foreground="White" Margin="5"/>
      <Button Name="ExitButton" Content="Exit" Width="100" Height="30" Background="#DC3545" Foreground="White" Margin="5"/>
    </StackPanel>

    <!-- Footer Section -->
    <Border Grid.Row="6" Background="#D3D3D3" Padding="5">
      <TextBlock Text="© 2025 M.omar (momar.tech) - All Rights Reserved"
                 Foreground="Black" 
                 FontSize="10" 
                 HorizontalAlignment="Center"/>
    </Border>
  </Grid>
</Window>
"@

try {
    [xml]$XAMLWindow = $XAML
} catch {
    Write-Host "Error parsing XAML: $($_.Exception.Message)"
    return
}

$Reader = New-Object System.Xml.XmlNodeReader($XAMLWindow)
$Form   = [Windows.Markup.XamlReader]::Load($Reader)

# Capture UI Elements
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

# Bind DataGrid to the global ObservableCollection
$ResultsGrid.DataContext = $Global:GridData

#------------------------------------------------------------------------------
# Utility Functions
#------------------------------------------------------------------------------

# Convert bytes to a human-readable string (KB, MB, GB, TB)
function Convert-SizeToHumanReadable {
    param([long]$Size)
    switch ($Size) {
        { $_ -lt 1MB } { return ("{0:N2} KB" -f ($Size / 1KB)) }
        { $_ -lt 1GB } { return ("{0:N2} MB" -f ($Size / 1MB)) }
        { $_ -lt 1TB } { return ("{0:N2} GB" -f ($Size / 1GB)) }
        default        { return ("{0:N2} TB" -f ($Size / 1TB)) }
    }
}

# Calculate folder size fully recursively
function Get-FolderSizeRecursive {
    param([string]$FolderPath)
    try {
        (Get-ChildItem -LiteralPath $FolderPath -File -Recurse -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum
    }
    catch {
        0
    }
}

# Get top-level items (files/folders) and measure folder sizes recursively
function Get-DirectoryTreeAllItems {
    param([string]$Path)

    $Form.Dispatcher.Invoke([System.Action]{
        $ProgressBar.Visibility = "Collapsed"
        $ScanMessage.Content    = "Scanning..."
    })

    $allItems = Get-ChildItem -LiteralPath $Path -ErrorAction SilentlyContinue
    if (-not $allItems) { return @() }

    # We'll just set the progress bar to the count of top-level items
    $Form.Dispatcher.Invoke([System.Action]{
        $ProgressBar.Minimum    = 0
        $ProgressBar.Maximum    = $allItems.Count
        $ProgressBar.Value      = 0
        $ProgressBar.Visibility = "Visible"
    })

    $results = New-Object System.Collections.Generic.List[System.Object]
    $count   = 0

    foreach ($item in $allItems) {
        if ($item.PSIsContainer) {
            # FOLDER: measure size recursively
            $icon = "📁"
            $size = Get-FolderSizeRecursive -FolderPath $item.FullName
        }
        else {
            # FILE: direct size
            $icon = "📄"
            $size = $item.Length
        }

        $results.Add(
            [PSCustomObject]@{
                Icon       = $icon
                Path       = $item.FullName
                Size       = $size
                PrettySize = Convert-SizeToHumanReadable $size
                Modified   = $item.LastWriteTime
            }
        ) | Out-Null

        $count++
        $Form.Dispatcher.Invoke([System.Action]{
            $ProgressBar.Value = $count
        })
    }

    # Hide progress bar
    $Form.Dispatcher.Invoke([System.Action]{
        $ProgressBar.Visibility = "Collapsed"
    })

    # Return sorted descending by size
    return $results | Sort-Object Size -Descending
}

#------------------------------------------------------------------------------
# Event Handlers
#------------------------------------------------------------------------------

# Browse Button
$BrowseButton.Add_Click({
    $FolderBrowser = New-Object -ComObject Shell.Application
    $Folder = $FolderBrowser.BrowseForFolder(0, "Select a Directory", 0)
    if ($Folder) {
        $DirectoryPath.Text = $Folder.Self.Path
        $Global:CurrentFolder = $Folder.Self.Path
    }
})

# Go Back Button
$GoBackButton.Add_Click({
    if (-not $Global:CurrentFolder) {
        [System.Windows.MessageBox]::Show("No current folder to go back from.", "Info", "OK", "Information") | Out-Null
        return
    }
    $parent = Split-Path $Global:CurrentFolder -Parent
    if ($parent) {
        $Global:CurrentFolder = $parent
        $DirectoryPath.Text   = $parent
        $ScanMessage.Content  = "Scanning folder: $parent"
        $Global:GridData.Clear()

        $Results = Get-DirectoryTreeAllItems -Path $parent
        foreach ($item in $Results) {
            $Global:GridData.Add($item)
        }
        $ScanMessage.Content = "Scan completed."
    }
    else {
        [System.Windows.MessageBox]::Show("No parent directory found.", "Info", "OK", "Information") | Out-Null
    }
})

# Scan Button
$ScanButton.Add_Click({
    # If a folder row is selected, use that folder; otherwise, use DirectoryPath
    $selected = $ResultsGrid.SelectedItem
    if ($selected -and (Test-Path $selected.Path) -and ((Get-Item $selected.Path).PSIsContainer)) {
        $folderToScan = $selected.Path
    }
    else {
        $folderToScan = $DirectoryPath.Text
    }

    $Global:GridData.Clear()
    if (-not (Test-Path $folderToScan)) {
        [System.Windows.MessageBox]::Show("Please select a valid directory.", "Error", "OK", "Error") | Out-Null
        return
    }
    if (-not (Get-Item $folderToScan).PSIsContainer) {
        [System.Windows.MessageBox]::Show("The specified path is a file and cannot be scanned.", "Error", "OK", "Error") | Out-Null
        return
    }

    $Global:CurrentFolder   = $folderToScan
    $ScanMessage.Content    = "Scanning folder: $folderToScan"
    $Results                = Get-DirectoryTreeAllItems -Path $folderToScan

    foreach ($item in $Results) {
        $Global:GridData.Add($item)
    }
    $ScanMessage.Content = "Scan completed."
})

# Delete Button
$DeleteButton.Add_Click({
    $selected = $ResultsGrid.SelectedItem
    if (-not $selected) {
        [System.Windows.MessageBox]::Show("No item selected. Please highlight a folder or file first.", "Warning", "OK", "Warning") | Out-Null
        return
    }
    $confirm = [System.Windows.MessageBox]::Show("Are you sure you want to delete the following?`n$($selected.Path)", "Confirm Delete", "YesNo", "Warning")
    if ($confirm -eq "Yes") {
        try {
            Remove-Item -LiteralPath $selected.Path -Recurse -Force
            [System.Windows.MessageBox]::Show("Deleted successfully.", "Info", "OK", "Information") | Out-Null
            $Global:GridData.Remove($selected) | Out-Null
        }
        catch {
            [System.Windows.MessageBox]::Show("Failed to delete.`n$($_.Exception.Message)", "Error", "OK", "Error") | Out-Null
        }
    }
})

# Context Menu: Open in Explorer
$MenuOpenExplorer.Add_Click({
    $selected = $ResultsGrid.SelectedItem
    if ($selected -and (Test-Path $selected.Path)) {
        Start-Process explorer.exe $selected.Path
    }
    else {
        [System.Windows.MessageBox]::Show("No valid path selected.", "Info", "OK", "Information") | Out-Null
    }
})

# Context Menu: Scan Single (just measure size for that folder/file)
$MenuScanSingle.Add_Click({
    $selected = $ResultsGrid.SelectedItem
    if (-not $selected) {
        [System.Windows.MessageBox]::Show("No item selected.", "Warning", "OK", "Warning") | Out-Null
        return
    }
    if (-not (Test-Path $selected.Path)) {
        [System.Windows.MessageBox]::Show("Invalid path.", "Error", "OK", "Error") | Out-Null
        return
    }

    if ((Get-Item $selected.Path).PSIsContainer) {
        # folder => measure recursively
        $size = Get-FolderSizeRecursive -FolderPath $selected.Path
    }
    else {
        # file => direct size
        $size = (Get-Item $selected.Path).Length
    }

    $pretty = Convert-SizeToHumanReadable $size
    [System.Windows.MessageBox]::Show("Path: $($selected.Path)`nSize: $pretty", "Scan Single", "OK", "Information") | Out-Null
})

# Context Menu: Properties
$MenuProperties.Add_Click({
    $selected = $ResultsGrid.SelectedItem
    if (-not $selected) {
        [System.Windows.MessageBox]::Show("No item selected.", "Warning", "OK", "Warning") | Out-Null
        return
    }
    if (-not (Test-Path $selected.Path)) {
        [System.Windows.MessageBox]::Show("Invalid path.", "Error", "OK", "Error") | Out-Null
        return
    }

    $itemObj = Get-Item $selected.Path
    $type = if ($itemObj.PSIsContainer) { "Folder" } else { "File" }

    $details  = "Path: $($itemObj.FullName)`n"
    $details += "Type: $type`n"
    $details += "Size: $($selected.PrettySize)`n"
    $details += "Created: $($itemObj.CreationTime)`n"
    $details += "Modified: $($itemObj.LastWriteTime)"

    [System.Windows.MessageBox]::Show($details, "Properties", "OK", "Information") | Out-Null
})

# Double-click row to open item in Explorer
$ResultsGrid.Add_MouseDoubleClick({
    $selected = $ResultsGrid.SelectedItem
    if ($selected -and (Test-Path $selected.Path)) {
        Start-Process explorer.exe $selected.Path
    }
})

# Exit Button
$ExitButton.Add_Click({
    $Form.Close()
})

# Show GUI
$Form.ShowDialog() | Out-Null
