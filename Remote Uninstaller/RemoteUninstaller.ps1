<#
.SYNOPSIS
    Remote EXE/MSI Uninstaller with refined Start Menu cleanup (removes only matched folders/shortcuts).
.DESCRIPTION
    - Displays a WPF GUI with header and footer.
    - Lists registry-based EXE/MSI apps on a remote machine.
    - Runs a background job for uninstall so the GUI won't freeze.
    - Stops processes, forces MSI from /I to /x, ensures silent for EXE.
    - Removes leftover registry keys, leftover folders in Program Files.
    - Cleans Start Menu shortcuts/folders that match the app name (not the entire "Programs" folder).
    - Optionally searches each user's AppData for leftover .exe or .lnk with the app name (refined approach).
.NOTES
    - Requires PS Remoting on the remote machine.
    - Must run as admin to remove items from Program Files / other user profiles.
    - WinGet is optional on the remote if you want fallback if registry uninstall fails.
#>

[System.Reflection.Assembly]::LoadWithPartialName('presentationframework') | Out-Null

#region [ WPF UI with Header & Footer ]
$XAML = @"
<Window
    xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
    xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
    Title="Remote EXE/MSI Uninstaller"
    Height="800" Width="1000"
    Background="LightBlue"
    Foreground="Black"
    WindowStartupLocation="CenterScreen">

    <Grid>
        <!-- 3 rows: Header, Main Content, Footer -->
        <Grid.RowDefinitions>
            <RowDefinition Height="Auto" />
            <RowDefinition Height="*" />
            <RowDefinition Height="Auto" />
        </Grid.RowDefinitions>

        <!-- HEADER -->
        <Border Grid.Row="0" Background="#2F4F4F" Height="60">
            <TextBlock Text="🛠️ Remote EXE/MSI Uninstaller"
                       Foreground="White"
                       VerticalAlignment="Center"
                       HorizontalAlignment="Center"
                       FontSize="20"
                       FontWeight="Bold" />
        </Border>

        <!-- MAIN CONTENT -->
        <Grid Grid.Row="1" Margin="10">
            <Grid.RowDefinitions>
                <RowDefinition Height="50"/>
                <RowDefinition Height="50"/>
                <RowDefinition Height="*"/>
                <RowDefinition Height="70"/>
                <RowDefinition Height="150"/>
            </Grid.RowDefinitions>

            <!-- Row 0: Sub-header instructions -->
            <TextBlock Text="Select a Remote PC and Load the Installed Apps"
                       Grid.Row="0"
                       FontWeight="Bold"
                       FontSize="14"
                       Foreground="DarkBlue"
                       VerticalAlignment="Center"
                       HorizontalAlignment="Center" />

            <!-- Row 1: Label + TextBox + Buttons -->
            <StackPanel Grid.Row="1" Orientation="Horizontal" HorizontalAlignment="Center" Margin="5">
                <TextBlock Text="Remote PC Name or IP:"
                           Width="160"
                           VerticalAlignment="Center"
                           HorizontalAlignment="Right"
                           FontWeight="Bold"
                           Margin="5"
                           Foreground="Black"/>
                <TextBox x:Name="PCNameBox"
                         Width="250" Height="30" Margin="5"
                         Background="White" Foreground="Black" FontSize="14"
                         Text="" />
                <Button x:Name="LoadAppsButton" Content="📂 Load Apps"
                        Width="140" Height="30" Margin="5"
                        Background="DarkGreen" Foreground="White"/>
                <Button x:Name="RefreshButton" Content="🔄 Refresh"
                        Width="120" Height="30" Margin="5"
                        Background="Orange" Foreground="White"/>
            </StackPanel>

            <!-- Row 2: ListView of Applications -->
            <ListView x:Name="AppListView"
                      Grid.Row="2"
                      Margin="10"
                      SelectionMode="Extended"
                      Background="White"
                      Foreground="Black">
                <ListView.View>
                    <GridView>
                        <GridViewColumn Header="📦 Name" Width="250" DisplayMemberBinding="{Binding Name}"/>
                        <GridViewColumn Header="🏢 Publisher" Width="200" DisplayMemberBinding="{Binding Publisher}"/>
                        <GridViewColumn Header="🔢 Version" Width="100" DisplayMemberBinding="{Binding Version}"/>
                        <GridViewColumn Header="📅 Install Date" Width="120" DisplayMemberBinding="{Binding InstallDate}"/>
                        <GridViewColumn Header="❌ Uninstall String" Width="250" DisplayMemberBinding="{Binding UninstallString}"/>
                    </GridView>
                </ListView.View>
            </ListView>

            <!-- Row 3: Buttons (Uninstall, Export) -->
            <StackPanel Grid.Row="3" Orientation="Horizontal" HorizontalAlignment="Center" Margin="5">
                <Button x:Name="UninstallButton" Content="🗑️ Uninstall Selected"
                        Width="180" Height="30" Margin="5"
                        Background="Red" Foreground="White"/>
                <Button x:Name="ExportButton" Content="📄 Export to CSV"
                        Width="180" Height="30" Margin="5"
                        Background="Blue" Foreground="White"/>
            </StackPanel>

            <!-- Row 4: Console-like Output -->
            <TextBox x:Name="OutputBox"
                     Grid.Row="4"
                     Margin="10"
                     Background="Black"
                     Foreground="White"
                     FontSize="12"
                     IsReadOnly="True"
                     TextWrapping="Wrap"
                     VerticalScrollBarVisibility="Auto"/>
        </Grid>

        <!-- FOOTER -->
        <Border Grid.Row="2" Background="#2F4F4F" Height="30">
            <TextBlock Text="© 2023 YourCompany. All Rights Reserved."
                       Foreground="White"
                       VerticalAlignment="Center"
                       HorizontalAlignment="Center"
                       FontSize="12" />
        </Border>

    </Grid>
</Window>
"@
#endregion

#region [ Parse & Load the XAML into a WPF Window ]
[xml]$xml = $XAML
$reader  = New-Object System.Xml.XmlNodeReader $xml
$Window  = [Windows.Markup.XamlReader]::Load($reader)

# Acquire references
$PCNameBox       = $Window.FindName('PCNameBox')
$LoadAppsButton  = $Window.FindName('LoadAppsButton')
$RefreshButton   = $Window.FindName('RefreshButton')
$AppListView     = $Window.FindName('AppListView')
$UninstallButton = $Window.FindName('UninstallButton')
$ExportButton    = $Window.FindName('ExportButton')
$OutputBox       = $Window.FindName('OutputBox')
#endregion

#region [ Update-Output: Helper to append text & auto-scroll in the console box ]
function Update-Output {
    param([string]$Message)
    $OutputBox.Dispatcher.Invoke([Action]{
        $OutputBox.AppendText("$Message`r`n")
        $OutputBox.ScrollToEnd()
    })
}
#endregion

#region [ Get-InstalledApps: Lists Registry-Based (EXE/MSI) Apps from Remote ]
function Get-InstalledApps {
    param([string]$ComputerName)

    Update-Output "🔄 Checking connectivity to '$ComputerName'..."
    if (-not (Test-Connection -ComputerName $ComputerName -Count 1 -Quiet)) {
        Update-Output "❌ Failed to connect to $ComputerName!"
        return @()
    }
    Update-Output "✅ Connected. Fetching registry-based apps..."

    $Apps = Invoke-Command -ComputerName $ComputerName -ScriptBlock {
        $AppList = @()
        $Keys = @(
            "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall",
            "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall"
        )
        foreach ($Key in $Keys) {
            $AppList += Get-ChildItem -Path $Key -ErrorAction SilentlyContinue | ForEach-Object {
                $dn = $_.GetValue("DisplayName")
                if ($dn) {
                    [PSCustomObject]@{
                        Name            = $dn
                        Publisher       = $_.GetValue("Publisher")
                        Version         = $_.GetValue("DisplayVersion")
                        InstallDate     = $_.GetValue("InstallDate")
                        UninstallString = $_.GetValue("UninstallString")
                    }
                }
            }
        }
        $AppList | Sort-Object Name
    }

    Update-Output "✅ Retrieved $($Apps.Count) applications from $ComputerName."
    return $Apps
}
#endregion

#region [ Uninstall ScriptBlock: Uninstall + Cleanup in a Background Job ]
$UninstallScriptBlock = {
    param([string]$ComputerName, [Object[]]$AppList)

    function Write-Log {
        param($msg)
        Write-Output $msg
    }

    function Remove-Application {
        param([string]$ComputerName, [PSObject]$AppObject)

        $AppName      = $AppObject.Name
        $UninstallCmd = $AppObject.UninstallString

        Write-Log "-----"
        Write-Log "🛑 Attempting to remove '$AppName' on $ComputerName..."

        # 1) Check connectivity
        if (-not (Test-Connection -ComputerName $ComputerName -Count 1 -Quiet)) {
            Write-Log "❌ Cannot reach $ComputerName. Skipping '$AppName'."
            return
        }

        # 2) Stop processes matching $AppName
        Write-Log "🔹 Stopping processes matching '$AppName'..."
        Invoke-Command -ComputerName $ComputerName -ScriptBlock {
            param ($AppName)
            $procs = Get-Process -ErrorAction SilentlyContinue | Where-Object {
                $_.ProcessName -match $AppName -or $_.Description -match $AppName
            }
            if ($procs) { $procs | Stop-Process -Force -ErrorAction SilentlyContinue }
        } -ArgumentList $AppName

        # 3) Adjust uninstall command for MSI or EXE to ensure silent
        if ($UninstallCmd) {
            if ($UninstallCmd -match '(?i)msiexec\.exe') {
                # Replace /I with /x
                $UninstallCmd = $UninstallCmd -replace '(?i)/I','/x'
                if ($UninstallCmd -notmatch '(?i)/x') {
                    $UninstallCmd = $UninstallCmd.Replace('msiexec.exe','msiexec.exe /x')
                }
                if ($UninstallCmd -notmatch '(?i)/quiet') {
                    $UninstallCmd += ' /quiet /norestart'
                }
            }
            elseif ($UninstallCmd -match '\.exe') {
                if ($UninstallCmd -notmatch '/S' -and
                    $UninstallCmd -notmatch '/quiet' -and
                    $UninstallCmd -notmatch '/silent') {
                    $UninstallCmd += ' /S'
                }
            }

            Write-Log "🔹 Running uninstall command: $UninstallCmd"
            Invoke-Command -ComputerName $ComputerName -ScriptBlock {
                param ($Cmd)
                Start-Process -FilePath "cmd.exe" -ArgumentList "/c $Cmd" -Wait -NoNewWindow
            } -ArgumentList $UninstallCmd -ErrorAction SilentlyContinue
        }
        else {
            Write-Log "⚠ No UninstallString found for '$AppName'."
        }

        # 4) Check if the app is still installed
        $StillInstalled = Invoke-Command -ComputerName $ComputerName -ScriptBlock {
            param ($AppName)
            $RegPaths = @(
                "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall",
                "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall"
            )
            foreach ($r in $RegPaths) {
                Get-ChildItem -Path $r -ErrorAction SilentlyContinue | ForEach-Object {
                    if ($_.GetValue("DisplayName") -eq $AppName) { return $true }
                }
            }
            return $false
        } -ArgumentList $AppName

        if ($StillInstalled) {
            Write-Log "❌ Traditional uninstall may have failed for '$AppName'. Checking WinGet..."

            # Check if WinGet is installed
            $WingetExists = $true
            try {
                Invoke-Command -ComputerName $ComputerName -ScriptBlock {
                    winget --version | Out-Null
                } | Out-Null
            }
            catch {
                $WingetExists = $false
            }

            if ($WingetExists) {
                Invoke-Command -ComputerName $ComputerName -ScriptBlock {
                    param($AppName)
                    $results = winget list --name "$AppName" 2>$null
                    if ($results) {
                        Start-Process "winget" -ArgumentList "uninstall --name `"$AppName`" --exact --accept-source-agreements --accept-package-agreements" -Wait -NoNewWindow
                    }
                } -ArgumentList $AppName

                # Check again
                $StillInstalled = Invoke-Command -ComputerName $ComputerName -ScriptBlock {
                    param ($AppName)
                    $RegPaths = @(
                        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall",
                        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall"
                    )
                    foreach ($r in $RegPaths) {
                        Get-ChildItem -Path $r -ErrorAction SilentlyContinue | ForEach-Object {
                            if ($_.GetValue("DisplayName") -eq $AppName) {
                                return $true
                            }
                        }
                    }
                    return $false
                } -ArgumentList $AppName

                if (-not $StillInstalled) {
                    Write-Log "✅ '$AppName' removed via WinGet fallback!"
                }
                else {
                    Write-Log "⚠ WinGet could not remove '$AppName'. Manual steps may be needed."
                }
            }
            else {
                Write-Log "⚠ WinGet not found on remote. Cannot remove '$AppName' via fallback."
            }
        }
        else {
            Write-Log "✅ '$AppName' removed via registry uninstall!"
        }

        # 5) Remove leftover registry keys & gather InstallLocation if present
        Write-Log "🔹 Cleaning leftover registry keys for '$AppName'..."
        $InstallLocation = $null
        Invoke-Command -ComputerName $ComputerName -ScriptBlock {
            param($AppName)
            $RegPaths = @(
                "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall",
                "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall"
            )
            foreach ($r in $RegPaths) {
                Get-ChildItem -Path $r -ErrorAction SilentlyContinue | ForEach-Object {
                    if ($_.GetValue("DisplayName") -eq $AppName) {
                        $loc = $_.GetValue("InstallLocation")
                        Remove-Item $_.PSPath -Recurse -Force -ErrorAction SilentlyContinue
                        if ($loc) { return $loc }
                    }
                }
            }
        } -ArgumentList $AppName -OutVariable locationFromReg | Out-Null

        if ($locationFromReg) {
            $InstallLocation = $locationFromReg[0]
        }

        if ($InstallLocation) {
            Write-Log "🔹 Found InstallLocation: $InstallLocation"
            Invoke-Command -ComputerName $ComputerName -ScriptBlock {
                param($p)
                if (Test-Path $p) {
                    Remove-Item -Path $p -Recurse -Force -ErrorAction SilentlyContinue
                }
            } -ArgumentList $InstallLocation
        }

        # 6) Remove leftover folders in Program Files
        Write-Log "🔹 Checking leftover folders in Program Files for '$AppName'..."
        Invoke-Command -ComputerName $ComputerName -ScriptBlock {
            param($AppName)
            $pfPaths = @("C:\Program Files","C:\Program Files (x86)")
            foreach ($pf in $pfPaths) {
                if (Test-Path $pf) {
                    Get-ChildItem -Path $pf -Directory -Force -ErrorAction SilentlyContinue |
                        Where-Object { $_.Name -match $AppName } |
                        ForEach-Object {
                            Remove-Item $_.FullName -Recurse -Force -ErrorAction SilentlyContinue
                        }
                }
            }
        } -ArgumentList $AppName

        # 7) Remove leftover Start Menu subfolders/shortcuts
        Write-Log "🔹 Removing matched Start Menu items for '$AppName'..."
        Invoke-Command -ComputerName $ComputerName -ScriptBlock {
            param($AppName)

            # Machine-wide (All Users) Start Menu
            $AllUsersSM = "C:\ProgramData\Microsoft\Windows\Start Menu\Programs"
            if (Test-Path $AllUsersSM) {
                # Subfolders that match app name
                Get-ChildItem -Path $AllUsersSM -Directory -Recurse -ErrorAction SilentlyContinue |
                    Where-Object { $_.Name -match $AppName } |
                    Remove-Item -Recurse -Force -ErrorAction SilentlyContinue

                # .lnk shortcuts that match app name
                Get-ChildItem -Path $AllUsersSM -Include *.lnk -Recurse -ErrorAction SilentlyContinue |
                    Where-Object { $_.Name -match $AppName } |
                    Remove-Item -Force -ErrorAction SilentlyContinue
            }

            # Each user's Start Menu
            $userDirs = Get-ChildItem "C:\Users" -Directory -ErrorAction SilentlyContinue
            foreach ($u in $userDirs) {
                $userSM = Join-Path $u.FullName "AppData\Roaming\Microsoft\Windows\Start Menu\Programs"
                if (Test-Path $userSM) {
                    # Subfolders that match
                    Get-ChildItem -Path $userSM -Directory -Recurse -ErrorAction SilentlyContinue |
                        Where-Object { $_.Name -match $AppName } |
                        Remove-Item -Recurse -Force -ErrorAction SilentlyContinue

                    # .lnk shortcuts that match
                    Get-ChildItem -Path $userSM -Include *.lnk -Recurse -ErrorAction SilentlyContinue |
                        Where-Object { $_.Name -match $AppName } |
                        Remove-Item -Force -ErrorAction SilentlyContinue
                }
            }
        } -ArgumentList $AppName

        # 8) Search user AppData for leftover .exe / .lnk or known subfolders
        Write-Log "🔹 Searching each user's 'AppData' for leftover .exe or .lnk matching '$AppName'..."
        Invoke-Command -ComputerName $ComputerName -ScriptBlock {
            param($AppName)
            $skipProfiles = @('Public','Default','All Users','Administrator')  # optional skip
            $userDirs = Get-ChildItem "C:\Users" -Directory -ErrorAction SilentlyContinue |
                        Where-Object { -not $skipProfiles.Contains($_.Name) }

            foreach ($u in $userDirs) {
                $AppDataPath = Join-Path $u.FullName "AppData"
                if (Test-Path $AppDataPath) {
                    # Remove .exe or .lnk that contain the app name
                    Get-ChildItem -Path $AppDataPath -Recurse -Force -ErrorAction SilentlyContinue |
                        Where-Object {
                            ($_.Name -match $AppName) -and
                            (($_.Extension -eq '.exe') -or ($_.Extension -eq '.lnk'))
                        } |
                        Remove-Item -Recurse -Force -ErrorAction SilentlyContinue

                    # Remove known leftover subfolders that match the app name
                    Get-ChildItem -Path $AppDataPath -Directory -Recurse -Force -ErrorAction SilentlyContinue |
                        Where-Object { $_.Name -match $AppName } |
                        Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
                }
            }
        } -ArgumentList $AppName
    }

    Write-Log "===== Starting batch uninstall on $ComputerName for $($AppList.Count) app(s)... ====="

    foreach ($app in $AppList) {
        Remove-Application -ComputerName $ComputerName -AppObject $app
    }

    Write-Log "===== Uninstallation completed for $($AppList.Count) app(s) on $ComputerName. ====="
}
#endregion

#region [ Start-Job + DispatcherTimer for Non-Blocking UI ]
$Global:UninstallJob = $null
$PollTimer = New-Object System.Windows.Threading.DispatcherTimer
$PollTimer.Interval = [TimeSpan]::FromMilliseconds(500)

$PollTimer.Add_Tick({
    if ($Global:UninstallJob) {
        # Retrieve new lines from the job
        $lines = Receive-Job -Job $Global:UninstallJob -Keep
        foreach ($l in $lines) {
            Update-Output $l
        }

        # Check if the job ended
        if ($Global:UninstallJob.State -in @('Completed','Failed','Stopped')) {
            $PollTimer.Stop()

            $left = Receive-Job -Job $Global:UninstallJob -ErrorAction SilentlyContinue
            foreach ($r in $left) {
                Update-Output $r
            }

            Update-Output "🔔 Job ended. State: $($Global:UninstallJob.State)."
            Remove-Job -Job $Global:UninstallJob -Force | Out-Null
            $Global:UninstallJob = $null

            # Refresh the app list
            $c = $PCNameBox.Text
            if ($c) {
                $AppListView.ItemsSource = Get-InstalledApps -ComputerName $c
            }
        }
    }
})
$PollTimer.Start()
#endregion

#region [ Button Handlers: Load, Refresh, Uninstall, Export ]
# Load Apps
$LoadAppsButton.Add_Click({
    $ComputerName = $PCNameBox.Text
    if (-not $ComputerName) {
        Update-Output "⚠ Please enter a valid PC name or IP!"
        return
    }
    $AppListView.ItemsSource = Get-InstalledApps -ComputerName $ComputerName
})

# Refresh Apps
$RefreshButton.Add_Click({
    $ComputerName = $PCNameBox.Text
    if ($ComputerName) {
        $AppListView.ItemsSource = Get-InstalledApps -ComputerName $ComputerName
    }
    else {
        Update-Output "⚠ No computer name specified!"
    }
})

# Uninstall Selected Apps
$UninstallButton.Add_Click({
    # If a job is active, see if it ended
    if ($Global:UninstallJob) {
        if ($Global:UninstallJob.State -in @('Completed','Failed','Stopped')) {
            $lines = Receive-Job -Job $Global:UninstallJob -Keep
            foreach ($line in $lines) {
                Update-Output $line
            }
            Update-Output "🔔 Old job ended (State: $($Global:UninstallJob.State)). Cleaning up..."
            Remove-Job -Job $Global:UninstallJob -Force | Out-Null
            $Global:UninstallJob = $null
        }
        else {
            Update-Output "⚠ Another uninstall job is currently running. Please wait..."
            return
        }
    }

    $SelectedApps = $AppListView.SelectedItems
    if (-not $SelectedApps -or $SelectedApps.Count -eq 0) {
        Update-Output "⚠ No applications selected!"
        return
    }

    $ComputerName = $PCNameBox.Text
    if (-not $ComputerName) {
        Update-Output "⚠ Please specify a remote machine!"
        return
    }

    Update-Output "⚙ Launching uninstall job for $($SelectedApps.Count) app(s) on $ComputerName..."
    $Global:UninstallJob = Start-Job -ScriptBlock $UninstallScriptBlock -ArgumentList $ComputerName, @($SelectedApps)
})

# Export to CSV
$ExportButton.Add_Click({
    $AllApps = $AppListView.ItemsSource
    if (-not $AllApps -or $AllApps.Count -eq 0) {
        Update-Output "⚠ No applications loaded to export!"
        return
    }
    Add-Type -AssemblyName System.Windows.Forms
    $SaveDialog = New-Object System.Windows.Forms.SaveFileDialog
    $SaveDialog.Filter = "CSV files (*.csv)|*.csv"
    if ($SaveDialog.ShowDialog() -eq 'OK') {
        $FilePath = $SaveDialog.FileName
        $AllApps | Export-Csv -Path $FilePath -NoTypeInformation
        Update-Output "✅ Exported $($AllApps.Count) apps to '$FilePath'"
    }
})
#endregion

# Show the WPF Window
$Window.ShowDialog()
