<#
.SYNOPSIS
    Comprehensive PowerShell script to optimize Windows performance, privacy, and user experience.

.DESCRIPTION
    This script performs a series of advanced system modifications to improve Windows behavior in enterprise or personal setups.

    Key features include:
    - Creating a system restore point for safety
    - Deleting temporary and junk files
    - Disabling Windows telemetry and feedback features
    - Blocking consumer-oriented and advertising components
    - Disabling unnecessary background services and features like GameDVR, Recall, and Storage Sense
    - Modifying scheduled tasks, registry entries, and service startup types
    - Debloating Microsoft Edge by adjusting policy-based settings
    - Optionally re-enabling hibernation on laptops with optimized power plans

.EXAMPLE
    .\Optimize-Windows.ps1

.NOTES
    Author  : Mohammad Abdelkader
    Website : momar.tech
    Date    : 2025-06-22
    Version : 1.0
#>


# ------------------- Create System Restore Point -------------------
try {
    # Ensure System Restore is enabled
    Enable-ComputerRestore -Drive "$env:SystemDrive"

    # Allow multiple restore points per day
    $exists = Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SystemRestore" -Name "SystemRestorePointCreationFrequency" -ErrorAction SilentlyContinue
    if ($null -eq $exists) {
        Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SystemRestore" -Name "SystemRestorePointCreationFrequency" -Value 0 -Type DWord -Force
    }

    # Load required module and check for existing restore point today
    Import-Module Microsoft.PowerShell.Management -ErrorAction Stop
    $existingRestorePoints = Get-ComputerRestorePoint | Where-Object { $_.CreationTime.Date -eq (Get-Date).Date }

    # Create restore point if none exist today
    if ($existingRestorePoints.Count -eq 0) {
        Checkpoint-Computer -Description "System Restore Point created by Winutil" -RestorePointType MODIFY_SETTINGS
        Write-Host "System Restore Point Created Successfully" -ForegroundColor Green
    }
} catch {
    Write-Host "Failed to create restore point: $_" -ForegroundColor Red
}

# ------------------- Delete Temporary Files -------------------
# Remove Windows and User temp files
Get-ChildItem -Path "C:\Windows\Temp" -Recurse -Force -ErrorAction SilentlyContinue | Remove-Item -Force -Recurse -ErrorAction SilentlyContinue
Get-ChildItem -Path $env:TEMP -Recurse -Force -ErrorAction SilentlyContinue | Remove-Item -Force -Recurse -ErrorAction SilentlyContinue

# ------------------- Disable Consumer Features -------------------
$regPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent"
if (-not (Test-Path $regPath)) { New-Item -Path $regPath -Force | Out-Null }
New-ItemProperty -Path $regPath -Name "DisableWindowsConsumerFeatures" -Value 1 -PropertyType DWord -Force
Write-Host "✅ 'DisableWindowsConsumerFeatures' has been set." -ForegroundColor Green

# ------------------- Disable Scheduled Tasks (Telemetry & Feedback) -------------------
$ScheduledTasks = @(
    "Microsoft\Windows\Application Experience\Microsoft Compatibility Appraiser",
    "Microsoft\Windows\Application Experience\ProgramDataUpdater",
    "Microsoft\Windows\Autochk\Proxy",
    "Microsoft\Windows\Customer Experience Improvement Program\Consolidator",
    "Microsoft\Windows\Customer Experience Improvement Program\UsbCeip",
    "Microsoft\Windows\DiskDiagnostic\Microsoft-Windows-DiskDiagnosticDataCollector",
    "Microsoft\Windows\Feedback\Siuf\DmClient",
    "Microsoft\Windows\Feedback\Siuf\DmClientOnScenarioDownload",
    "Microsoft\Windows\Windows Error Reporting\QueueReporting",
    "Microsoft\Windows\Application Experience\MareBackup",
    "Microsoft\Windows\Application Experience\StartupAppTask",
    "Microsoft\Windows\Application Experience\PcaPatchDbTask",
    "Microsoft\Windows\Maps\MapsUpdateTask"
)
foreach ($task in $ScheduledTasks) {
    try {
        Disable-ScheduledTask -TaskName ($task.Split('\')[-1]) -TaskPath ('\' + ($task -replace '\\[^\\]+$','')) -ErrorAction SilentlyContinue
        Write-Host "✅ Disabled: $task" -ForegroundColor Green
    } catch {
        Write-Host "⚠️ Failed to disable: $task" -ForegroundColor Yellow
    }
}

# ------------------- Disable GameDVR -------------------
$GameDVRSettings = @(
    @{ Path = "HKCU:\System\GameConfigStore"; Name = "GameDVR_FSEBehavior"; Value = 2 },
    @{ Path = "HKCU:\System\GameConfigStore"; Name = "GameDVR_Enabled"; Value = 0 },
    @{ Path = "HKCU:\System\GameConfigStore"; Name = "GameDVR_HonorUserFSEBehaviorMode"; Value = 1 },
    @{ Path = "HKCU:\System\GameConfigStore"; Name = "GameDVR_EFSEFeatureFlags"; Value = 0 },
    @{ Path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\GameDVR"; Name = "AllowGameDVR"; Value = 0 }
)
foreach ($reg in $GameDVRSettings) {
    if (-not (Test-Path $reg.Path)) { New-Item -Path $reg.Path -Force | Out-Null }
    New-ItemProperty -Path $reg.Path -Name $reg.Name -Value $reg.Value -PropertyType DWord -Force | Out-Null
    Write-Host "✅ Set $($reg.Name) to $($reg.Value) in $($reg.Path)" -ForegroundColor Green
}

# ------------------- Disable Hibernation -------------------
$HibernationSettings = @(
    @{ Path = "HKLM:\System\CurrentControlSet\Control\Session Manager\Power"; Name = "HibernateEnabled"; Value = 0 },
    @{ Path = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\FlyoutMenuSettings"; Name = "ShowHibernateOption"; Value = 0 }
)
foreach ($reg in $HibernationSettings) {
    if (-not (Test-Path $reg.Path)) { New-Item -Path $reg.Path -Force | Out-Null }
    New-ItemProperty -Path $reg.Path -Name $reg.Name -Value $reg.Value -PropertyType DWord -Force | Out-Null
    Write-Host "✅ Set $($reg.Name) to $($reg.Value) in $($reg.Path)" -ForegroundColor Green
}
try {
    powercfg.exe /hibernate off
    Write-Host "💤 Hibernation disabled via powercfg." -ForegroundColor Cyan
} catch {
    Write-Host "❌ Failed to disable hibernation." -ForegroundColor Red
}

# ------------------- Disable HomeGroup Services -------------------
$HomeGroupServices = @("HomeGroupListener", "HomeGroupProvider")
foreach ($svc in $HomeGroupServices) {
    try {
        Set-Service -Name $svc -StartupType Manual -ErrorAction Stop
        Write-Host "✅ Set $svc to Manual startup" -ForegroundColor Green
    } catch {
        Write-Host "❌ Failed to modify $svc : $_" -ForegroundColor Red
    }
}

# ------------------- Disable Location Tracking -------------------
$LocationSettings = @(
    @{ Path = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\location"; Name = "Value"; Value = "Deny"; Type = "String" },
    @{ Path = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Sensor\Overrides\{BFA794E4-F964-4FDB-90F6-51056BFE4B44}"; Name = "SensorPermissionState"; Value = 0; Type = "DWord" },
    @{ Path = "HKLM:\SYSTEM\CurrentControlSet\Services\lfsvc\Service\Configuration"; Name = "Status"; Value = 0; Type = "DWord" },
    @{ Path = "HKLM:\SYSTEM\Maps"; Name = "AutoUpdateEnabled"; Value = 0; Type = "DWord" }
)
foreach ($reg in $LocationSettings) {
    if (-not (Test-Path $reg.Path)) { New-Item -Path $reg.Path -Force | Out-Null }
    New-ItemProperty -Path $reg.Path -Name $reg.Name -Value $reg.Value -PropertyType $reg.Type -Force | Out-Null
    Write-Host "📍 Set $($reg.Name) in $($reg.Path)" -ForegroundColor Cyan
}

# ------------------- Disable Storage Sense -------------------
$StorageSensePath = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\StorageSense\Parameters\StoragePolicy"
if (-not (Test-Path $StorageSensePath)) { New-Item -Path $StorageSensePath -Force | Out-Null }
Set-ItemProperty -Path $StorageSensePath -Name "01" -Value 0 -Type DWord -Force
Write-Host "🗑️ Storage Sense disabled" -ForegroundColor Yellow

# ------------------- Disable Wi-Fi Sense -------------------
$WiFiSenseSettings = @(
    @{ Path = "HKLM:\Software\Microsoft\PolicyManager\default\WiFi\AllowWiFiHotSpotReporting"; Name = "Value"; Value = 0 },
    @{ Path = "HKLM:\Software\Microsoft\PolicyManager\default\WiFi\AllowAutoConnectToWiFiSenseHotspots"; Name = "Value"; Value = 0 }
)
foreach ($reg in $WiFiSenseSettings) {
    if (-not (Test-Path $reg.Path)) { New-Item -Path $reg.Path -Force | Out-Null }
    Set-ItemProperty -Path $reg.Path -Name $reg.Name -Value $reg.Value -Type DWord -Force
    Write-Host "📡 Disabled $($reg.Name) in $($reg.Path)" -ForegroundColor Cyan
}

# ------------------- Enable End Task in Taskbar -------------------
$endTaskPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced\TaskbarDeveloperSettings"
if (-not (Test-Path $endTaskPath)) { New-Item -Path $endTaskPath -Force | Out-Null }
New-ItemProperty -Path $endTaskPath -Name "TaskbarEndTask" -PropertyType DWord -Value 1 -Force | Out-Null

# ------------------- Disable PowerShell Telemetry -------------------
[Environment]::SetEnvironmentVariable('POWERSHELL_TELEMETRY_OPTOUT', '1', 'Machine')

# ------------------- Disable Microsoft Recall -------------------
Write-Host "Disabling Microsoft Recall..."
DISM /Online /Disable-Feature /FeatureName:Recall

# ------------------- Re-Enable Hibernation (for Laptops) -------------------
Write-Host "Re-enabling Hibernation (for laptops)..."
Start-Process -FilePath powercfg -ArgumentList "/hibernate on" -NoNewWindow -Wait
Start-Process -FilePath powercfg -ArgumentList "/change standby-timeout-ac 60" -NoNewWindow -Wait
Start-Process -FilePath powercfg -ArgumentList "/change standby-timeout-dc 60" -NoNewWindow -Wait
Start-Process -FilePath powercfg -ArgumentList "/change monitor-timeout-ac 10" -NoNewWindow -Wait
Start-Process -FilePath powercfg -ArgumentList "/change monitor-timeout-dc 1" -NoNewWindow -Wait

# ------------------- Final Notice -------------------
Write-Host "✅ All selected system tweaks have been applied successfully." -ForegroundColor Cyan
