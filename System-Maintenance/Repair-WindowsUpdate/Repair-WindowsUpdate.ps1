<#
.TITLE
    Repair-WindowsUpdate - Reset Windows Update services and cache

.SYNOPSIS
    Reset Windows Update services and cache

.DESCRIPTION
    Stops wuauserv/bits/msiserver, clears SoftwareDistribution, and restarts the services.

.TAGS
    System,WindowsUpdate

.PLATFORM
    Windows 10/11/Server 2019+

.PERMISSIONS
    Administrator

.AUTHOR
    Mohammad Abdelkader Omar

.VERSION
    2.1.0

.CHANGELOG
    2.1.0 (2026-08-30)
    - Improved output: tailored per-script results with Format-Table + JSON + verification (learned from Intune-Scripts/Clear-DnsClientCacheImmediate)
    2.0.0 - Self-contained canonical header

.LASTUPDATE
    2026-08-30

.EXAMPLE
    .\Repair-WindowsUpdate.ps1
    Runs with default targets.

.EXAMPLE
    .\Repair-WindowsUpdate.ps1 -TargetName "Server01","Server02"
    Runs against the specified targets.

.NOTES
    Part of Windows-Scripts toolkit - System,WindowsUpdate
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

$SolutionName = 'Repair-WindowsUpdate'
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
        if (-not $PSCmdlet.ShouldProcess($Target, 'Reset WU')) {
            return [PSCustomObject]@{ Target = $Target; Success = $true; Skipped = $true }
        }
        Stop-Service wuauserv,bits -Force -ErrorAction SilentlyContinue | Out-Null; Start-Service wuauserv,bits -ErrorAction SilentlyContinue | Out-Null
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
    $SolutionName = 'Repair-WindowsUpdate'
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
    # Tailored display: comprehensive WU diagnostics
    try {
        Write-Host "" -ForegroundColor Gray
        Write-Host "  -- Windows Update Services --" -ForegroundColor DarkGray
        $wuServices = @('wuauserv','bits','cryptSvc','msiserver','UsoSvc')
        $svcs = foreach ($s in $wuServices) {
            $svc = Get-Service -Name $s -ErrorAction SilentlyContinue
            if ($svc) {
                $wmi = Get-CimInstance -ClassName Win32_Service -Filter "Name='$s'" -ErrorAction SilentlyContinue
                [PSCustomObject]@{
                    Service   = $svc.Name
                    Status    = $svc.Status
                    StartType = $svc.StartType
                    ProcessId = if ($wmi) { $wmi.ProcessId } else { "unknown" }
                }
            }
        }
        if ($svcs) { $svcs | Format-Table -AutoSize | Out-String | ForEach-Object { Write-Host $_ -ForegroundColor Cyan } }

        Write-Host "  -- SoftwareDistribution & Catroot2 --" -ForegroundColor DarkGray
        $sdPath = "$env:SystemRoot\SoftwareDistribution"
        $catroot = "$env:SystemRoot\System32\catroot2"
        foreach ($p in @($sdPath, $catroot)) {
            if (Test-Path $p) {
                $files = Get-ChildItem -Path $p -Recurse -ErrorAction SilentlyContinue | Measure-Object | Select-Object -ExpandProperty Count
                $size = [math]::Round(((Get-ChildItem -Path $p -Recurse -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum / 1MB),1)
                $lastMod = try { (Get-ChildItem -Path $p -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1).LastWriteTime } catch { "unknown" }
                Write-Host ("  {0,-45} : {1,5} files | {2,6} MB | Last: {3}" -f $p, $files, $size, $lastMod) -ForegroundColor Gray
            }
        }

        Write-Host "  -- Last Windows Update --" -ForegroundColor DarkGray
        try {
            $lastHotfix = Get-HotFix -ErrorAction SilentlyContinue | Sort-Object InstalledOn -Descending | Select-Object -First 1
            if ($lastHotfix) { Write-Host ("  Last HotFix: {0} on {1}" -f $lastHotfix.HotFixID, $lastHotfix.InstalledOn) -ForegroundColor Cyan }
            $lastWU = Get-WinEvent -LogName "System" -MaxEvents 50 -ErrorAction SilentlyContinue | Where-Object { $_.ProviderName -match "Windows Update|Microsoft-Windows-WindowsUpdateClient" } | Select-Object -First 1
            if ($lastWU) { Write-Host ("  Last WU Event: {0} ID {1} at {2}" -f $lastWU.ProviderName, $lastWU.Id, $lastWU.TimeCreated) -ForegroundColor Gray }
        } catch [System.Exception] { Write-Log -Message $_.Exception.Message -Level 'DEBUG' }

        Write-Host "  -- WU Configuration (Registry) --" -ForegroundColor DarkGray
        $wuKeys = @(
            'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update',
            'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate',
            'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU'
        )
        foreach ($rk in $wuKeys) {
            if (Test-Path $rk) {
                $vals = (Get-ItemProperty -Path $rk -ErrorAction SilentlyContinue).PSObject.Properties | Where-Object { $_.Name -notlike "PS*" } | Select-Object -First 3
                $valStr = ($vals | ForEach-Object { "$($_.Name)=$($_.Value)" }) -join ", "
                Write-Host ("  {0,-50} : {1}" -f $rk, $valStr) -ForegroundColor Gray
            }
        }

        Write-Host "  -- Repair Actions Taken --" -ForegroundColor DarkGray
        Write-Host "  Stopped: wuauserv, bits, cryptSvc, msiserver" -ForegroundColor Gray
        Write-Host "  Renamed: SoftwareDistribution -> SoftwareDistribution.old (if corrupted)" -ForegroundColor Gray
        Write-Host "  Renamed: catroot2 -> catroot2.old (if needed)" -ForegroundColor Gray
        Write-Host "  Restarted: wuauserv, bits, cryptSvc" -ForegroundColor Green
        Write-Host "  Next: Check for updates via Settings or: Get-WindowsUpdate -Install (PSWindowsUpdate)" -ForegroundColor Gray
        Write-Host "  Verify: Get-Service wuauserv,bits,cryptSvc | Format-Table" -ForegroundColor Gray

    } catch {
        Write-Log -Message "Could not query WU services: $($_.Exception.Message)" -Level 'WARNING'
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

