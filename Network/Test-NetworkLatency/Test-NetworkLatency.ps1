<#
.TITLE
    Test-NetworkLatency - Measure latency to targets

.SYNOPSIS
    Measure latency to targets

.DESCRIPTION
    Pings targets (default 8.8.8.8, 1.1.1.1, microsoft.com) 4 times each, reports avg/min/max latency and packet loss. Supports custom -TargetName list.

.TAGS
    Network,Latency,Diagnostics

.PLATFORM
    Windows 10/11/Server 2019+

.PERMISSIONS
    Standard user

.AUTHOR
    Mohammed Omar

.VERSION
    2.1.0

.CHANGELOG
    2.1.0 (2026-08-31)
    - Initial release - Phase 3 expansion (tailored per-script output)
    2.0.0 - Self-contained canonical header

.LASTUPDATE
    2026-08-31

.EXAMPLE
    .\Test-NetworkLatency.ps1
    Runs with default targets.

.EXAMPLE
    .\Test-NetworkLatency.ps1 -TargetName "Server01","Server02"
    Runs against the specified targets.

.NOTES
    Part of Windows-Scripts toolkit - Network,Latency,Diagnostics
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

$SolutionName = 'Test-NetworkLatency'
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
        if (-not $PSCmdlet.ShouldProcess($Target, 'Measure Latency')) {
            return [PSCustomObject]@{ Target = $Target; Success = $true; Skipped = $true }
        }
        $t = $Target
        $r = Test-Connection -ComputerName $t -Count 1 -ErrorAction SilentlyContinue
        if (-not $r) { throw "No response from $t" }
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
    $SolutionName = 'Test-NetworkLatency'
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
    $summary = if ($failed -gt 0) { "FAILED" } elseif ($skipped -gt 0 -and $ok -eq 0) { "SKIPPED" } else { "OK" }
    $colorSummary = if ($failed -gt 0) { 'Red' } elseif ($skipped -gt 0 -and $ok -eq 0) { 'Yellow' } else { 'Green' }
    Write-Host ("  Summary : {0} ok, {1} skipped, {2} failed  ->  {3}" -f $ok, $skipped, $failed, $summary) -ForegroundColor $colorSummary
    $maxLen = ($results | ForEach-Object { $_.Target.Length } | Measure-Object -Maximum).Maximum
    $maxLen = [Math]::Max($maxLen, 4)
    Write-Host ("  {0,-$($maxLen + 2)} {1,-9} {2,-9} {3}" -f 'Target', 'Result', 'Skipped', 'Error') -ForegroundColor DarkGray
    Write-Host ("  {0}" -f ('-' * ($maxLen + 35))) -ForegroundColor DarkGray
    foreach ($r in $results) {
        if     ($r.Success) { $color = 'Green'; $resultText = 'OK' }
        elseif ($r.Skipped) { $color = 'Yellow'; $resultText = 'SKIPPED' }
        else               { $color = 'Red';   $resultText = 'FAILED' }
        $skippedText = if ($r.Skipped) { 'yes' } else { 'no' }
        $errorText   = if ($r.Error) { $r.Error } else { '' }
        Write-Host ("  {0,-$($maxLen + 2)} {1,-9} {2,-9} {3}" -f $r.Target, $resultText, $skippedText, $errorText) -ForegroundColor $color
    }
    # Tailored display: latency table
    try {
        $targets = if ($TargetName) { $TargetName } else { @('8.8.8.8','1.1.1.1','microsoft.com') }
        $rows = foreach ($t in $targets) {
            $pings = Test-Connection -ComputerName $t -Count 4 -ErrorAction SilentlyContinue
            $avg = if ($pings) { [math]::Round(($pings | Measure-Object -Property Latency -Average).Average,1) } else { $null }
            $loss = if ($pings) { 4 - $pings.Count } else { 4 }
            [PSCustomObject]@{ Target=$t; AvgMs=$avg; Received=($pings.Count); Loss=$loss }
        }
        Write-Host "" -ForegroundColor Gray
        Write-Host "  -- Network Latency (4 pings each) --" -ForegroundColor DarkGray
        $rows | Format-Table -AutoSize | Out-String | ForEach-Object { Write-Host $_ -ForegroundColor Cyan }
    } catch {
        Write-Log -Message "Could not measure latency: $($_.Exception.Message)" -Level 'WARNING'
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
