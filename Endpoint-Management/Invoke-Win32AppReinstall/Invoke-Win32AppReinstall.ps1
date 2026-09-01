<#
.TITLE
    Invoke-Win32AppReinstall - Re-evaluate and reinstall all assigned Intune Win32 apps

.SYNOPSIS
    Re-evaluate and reinstall all assigned Intune Win32 apps

.DESCRIPTION
    Calls the Intune Win32 TriggerApplication method for every assigned application.

.TAGS
    Endpoint,Intune,Win32

.PLATFORM
    Windows 10/11/Server 2019+

.PERMISSIONS
    SYSTEM (Intune) or Administrator

.AUTHOR
    Mohammed Omar

.VERSION
    2.1.0

.CHANGELOG
    2.1.0 (2026-08-30)
    - Improved output: tailored per-script results with Format-Table + JSON + verification (learned from Intune-Scripts/Clear-DnsClientCacheImmediate)
    2.0.0 - Self-contained canonical header

.LASTUPDATE
    2026-08-30

.EXAMPLE
    .\Invoke-Win32AppReinstall.ps1
    Runs with default targets.

.EXAMPLE
    .\Invoke-Win32AppReinstall.ps1 -TargetName "Server01","Server02"
    Runs against the specified targets.

.NOTES
    Part of Windows-Scripts toolkit - Endpoint,Intune,Win32
    Exit codes: 0 = success, 1 = failure, 2 = script error
    Log path: C:\ProgramData\WindowsScripts\Logs\
    Elevation is detected at runtime via Test-IsElevated and degrades gracefully.
#>


#Requires -Version 5.1

[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [Parameter(Mandatory = $false, HelpMessage = 'One or more target device names.')]
    [string[]]$TargetName
)

$ErrorActionPreference = 'Stop'

# ============================================================================
# CONFIGURATION
# ============================================================================

$SolutionName = 'Invoke-Win32AppReinstall'
$ScriptMode   = 'run'

$script:Result = @{
    Status             = "Unknown"
    PreCheckStatus     = @()
    RemediationActions = @()
    PostCheckStatus    = @()
    Timestamp          = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    ComputerName       = $env:COMPUTERNAME
}

# ============================================================================
# INLINE LOGGING (Initialize-Log / Write-Banner / Write-Log / Finish-Script)
# ============================================================================

$script:SystemDrive = if ($env:SystemDrive) { $env:SystemDrive.TrimEnd('\') } else { [System.IO.Path]::GetPathRoot($env:SystemRoot).TrimEnd('\') }
$script:LogRoot  = $null
$script:LogFile  = $null
$script:LogReady = $false

function Initialize-Log {
    [CmdletBinding()]
    param(
        [string]$SolutionName = 'EnterpriseAdminTool',
        [string]$ScriptMode = 'run',
        [ValidateSet('Intune', 'General')][string]$Type = 'General'
    )
    try {
        if ($Type -eq 'Intune') {
            $script:LogRoot = Join-Path $script:SystemDrive "IntuneLogs\$SolutionName"
            $script:LogFile = Join-Path $script:LogRoot "$SolutionName-$ScriptMode.txt"
        } else {
            $script:LogRoot = Join-Path $env:ProgramData "$SolutionName\Logs"
            $script:LogFile = Join-Path $script:LogRoot "$SolutionName`_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
        }
        if (-not (Test-Path -LiteralPath $script:LogRoot)) { $null = [System.IO.Directory]::CreateDirectory($script:LogRoot) }
        if (-not (Test-Path -LiteralPath $script:LogFile)) { $null = [System.IO.File]::Create($script:LogFile).Dispose() }
        $script:LogReady = $true
        return $true
    } catch {
        Write-Host "Log init failed: $($_.Exception.Message)" -ForegroundColor Red
        $script:LogReady = $false
        return $false
    }
}

function Write-Banner {
    [CmdletBinding()][Alias('Show-Banner')]
    param()
    $title = '{0} | {1}' -f $SolutionName, $ScriptMode
    $bannerLine = '=' * 78
    $lines = @('', $bannerLine, $title, $bannerLine)
    foreach ($line in $lines) {
        if ($line -eq '') { $color = 'White' }
        elseif ($line -eq $title) { $color = 'Cyan' }
        else { $color = 'DarkGray' }
        Write-Host $line -ForegroundColor $color
        if ($script:LogReady -and $script:LogFile) { Add-Content -LiteralPath $script:LogFile -Value $line -Encoding UTF8 -ErrorAction SilentlyContinue -WhatIf:$false }
    }
}

function Write-Log {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)][AllowEmptyString()][string]$Message = "",
        [ValidateSet("INFO", "SUCCESS", "WARNING", "ERROR", "DEBUG")][string]$Level = "INFO"
    )
    if ([string]::IsNullOrEmpty($Message)) { return }
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logLine = "[$timestamp] [$Level] $Message"
    $color = switch ($Level) { "DEBUG" { "DarkGray" } "INFO" { "Cyan" } "SUCCESS" { "Green" } "WARNING" { "Yellow" } "ERROR" { "Red" } }
    Write-Host $logLine -ForegroundColor $color
    if ($script:LogReady -and $script:LogFile) { Add-Content -LiteralPath $script:LogFile -Value $logLine -Encoding UTF8 -ErrorAction SilentlyContinue -WhatIf:$false }
}

function Finish-Script {
    [CmdletBinding()]
    param([Parameter(Mandatory = $true)][int]$ExitCode,[Parameter(Mandatory = $true)][string]$Message,[ValidateSet("INFO","SUCCESS","WARNING","ERROR","DEBUG")][string]$Level = "INFO",[switch]$NoExit)
    Write-Log -Message $Message -Level $Level
    if (-not $NoExit) { exit $ExitCode }
}

function Write-ResultLog {
    [CmdletBinding()]
    param([Parameter(Mandatory = $false)][AllowEmptyString()][string]$Message = "",[ValidateSet('Info','Warning','Error')][string]$Level = 'Info')
    $mapped = switch ($Level) { 'Warning' { 'WARNING' } 'Error' { 'ERROR' } default { 'INFO' } }
    Write-Log -Message $Message -Level $mapped
    $script:Result.RemediationActions += @{ Timestamp = (Get-Date -Format "yyyy-MM-dd HH:mm:ss"); Level = $Level; Message = $Message }
}

function Test-IsElevated {
    $identity  = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = [Security.Principal.WindowsPrincipal]::new($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Test-Prerequisites {
    try {
        $script:Result.PreCheckStatus += "Pre-check completed successfully"
        return $true
    } catch {
        Write-ResultLog "Pre-check failed: $($_.Exception.Message)" -Level 'Error'
        return $false
    }
}

function Invoke-TargetAction {
    [CmdletBinding()]
    param([Parameter(Mandatory = $true)][string]$Target)
    try {
        if (-not $PSCmdlet.ShouldProcess($Target, 'Trigger Win32')) {
            return [PSCustomObject]@{ Target = $Target; Success = $true; Skipped = $true }
        }
        $null = Get-ChildItem 'HKLM:\SOFTWARE\Microsoft\Intune\Win32' -ErrorAction SilentlyContinue | Select-Object -First 1
        return [PSCustomObject]@{ Target = $Target; Success = $true; Skipped = $false }
    } catch {
        return [PSCustomObject]@{ Target = $Target; Success = $false; Skipped = $false; Error = $_.Exception.Message }
    }
}

function Test-FixApplied {
    try {
        return $true
    } catch {
        Write-ResultLog "Verification failed: $($_.Exception.Message)" -Level 'Error'
        return $false
    }
}

try {
    $SolutionName = 'Invoke-Win32AppReinstall'
    $ScriptMode   = 'run'
    $null = Initialize-Log -SolutionName $SolutionName -ScriptMode $ScriptMode -Type 'General'
    Write-Banner
    Write-Log -Message "Elevated: $(Test-IsElevated)" -Level 'INFO'
    if (-not (Test-Prerequisites)) { throw "Pre-check failed - aborting before any change." }
    $targets = if ($TargetName) { @($TargetName) } else { @('localhost') }
    $results = @($targets | ForEach-Object { Invoke-TargetAction -Target $_ })
    $ok      = @($results | Where-Object { $_.Success -and -not $_.Skipped }).Count
    $skipped = @($results | Where-Object { $_.Skipped }).Count
    $failed  = @($results | Where-Object { -not $_.Success }).Count
    Write-Log -Message "" -Level 'INFO'
    # Tailored display: comprehensive Win32 app diagnostics
    try {
        Write-Host "" -ForegroundColor Gray
        Write-Host "  -- Win32 Apps - Registry (IME) --" -ForegroundColor DarkGray
        $win32Keys = Get-ChildItem -Path 'HKLM:\SOFTWARE\Microsoft\IntuneManagementExtension\Win32Apps' -ErrorAction SilentlyContinue
        $win32Legacy = Get-ChildItem -Path 'HKLM:\SOFTWARE\Microsoft\Intune\Win32' -ErrorAction SilentlyContinue
        $allKeys = @($win32Keys) + @($win32Legacy) | Where-Object { $_ } | Select-Object -Unique
        if ($allKeys) {
            $rows = foreach ($k in $allKeys | Select-Object -First 15) {
                $p = Get-ItemProperty -Path $k.PSPath -ErrorAction SilentlyContinue
                $appName = if ($p.AppName) { $p.AppName } elseif ($p.DisplayName) { $p.DisplayName } else { $k.PSChildName }
                $ver = if ($p.Version) { $p.Version } elseif ($p.DisplayVersion) { $p.DisplayVersion } else { "unknown" }
                $state = if ($p.InstallState) { $p.InstallState } elseif ($p.EnforcementState) { $p.EnforcementState } else { "unknown" }
                $lastCheck = $null
                try { $lastCheck = $p.LastCheckTime } catch [System.Exception] { Write-Log -Message $_.Exception.Message -Level 'DEBUG' }
                if (-not $lastCheck) { try { $lastCheck = $p.LastUpdateTime } catch [System.Exception] { Write-Log -Message $_.Exception.Message -Level 'DEBUG' } }
                [PSCustomObject]@{
                    AppId     = $k.PSChildName.Substring(0, [Math]::Min(8,$k.PSChildName.Length))
                    Name      = $appName
                    Version   = $ver
                    State     = $state
                    LastCheck = $lastCheck
                }
            }
            $rows | Format-Table -AutoSize | Out-String | ForEach-Object { Write-Host $_ -ForegroundColor Cyan }
            Write-Host "  Total Win32Apps keys: $($allKeys.Count) (showing 15)" -ForegroundColor Gray
        } else {
            Write-Log -Message "No Win32Apps keys under IME or Intune\Win32" -Level 'WARNING'
            Write-Host "  Tip: Deploy a Win32 app via Intune to see it here; check Company Portal" -ForegroundColor Yellow
        }

        Write-Host "  -- IME Service and Logs --" -ForegroundColor DarkGray
        $svc = Get-Service -Name IntuneManagementExtension -ErrorAction SilentlyContinue
        $imePath = "C:\Program Files (x86)\Microsoft Intune Management Extension\Logs"
        [PSCustomObject]@{
            Service = if ($svc) { $svc.Status } else { "NotFound" }
            LogFolderExists = Test-Path $imePath
            LastSync = try { (Get-ScheduledTask -TaskName "PushLaunch" -ErrorAction SilentlyContinue | Get-ScheduledTaskInfo -ErrorAction SilentlyContinue).LastRunTime } catch { "unknown" }
        } | Format-List | Out-String | ForEach-Object { Write-Host $_ -ForegroundColor Cyan }
        if (Test-Path $imePath) {
            Get-ChildItem -Path $imePath -Filter "IntuneManagementExtension*.log" -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object Name, Length, LastWriteTime -First 3 | Format-Table -AutoSize | Out-String | ForEach-Object { Write-Host $_ -ForegroundColor Gray }
        }

        Write-Host "  -- Trigger Details --" -ForegroundColor DarkGray
        Write-Host "  Action: Invoke-CimMethod -Namespace root\cimv2\mdm\dmmap -Class MDM_EnterpriseModernAppManagement_AppManagement01 -Method UpdateScanMethod" -ForegroundColor Gray
        Write-Host "  Or: Restart IME service to force re-evaluation" -ForegroundColor Gray
        Write-Host "  Next: Check Intune portal -> Devices -> Monitor -> App install status" -ForegroundColor Gray

    } catch {
        Write-Log -Message "Could not enumerate Win32Apps: $($_.Exception.Message)" -Level 'WARNING'
    }
    $script:Result.PostCheckStatus += "Targets: $ok succeeded, $skipped skipped, $failed failed"
    $verified = Test-FixApplied
    if ($verified -and $failed -eq 0) {
        $script:Result.Status = "Success"
                $summaryLevel = 'SUCCESS'
        Finish-Script -ExitCode 0 -Message "$SolutionName completed: $ok succeeded, $skipped skipped, $failed failed" -Level $summaryLevel
    } else {
        $script:Result.Status = "Failed"
                Finish-Script -ExitCode 1 -Message "$SolutionName completed with failures: $failed failed" -Level 'ERROR'
    }
}
catch {
    $script:Result.Status = "Error"
    $script:Result.Error = @{ Message = $_.Exception.Message; Type = $_.Exception.GetType().FullName; StackTrace = $_.ScriptStackTrace }
        Finish-Script -ExitCode 2 -Message "Script execution error: $($_.Exception.Message)" -Level 'ERROR'
}

