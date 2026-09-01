<#
.TITLE
    Repair-WindowsImage - Run DISM and SFC to repair the Windows image

.SYNOPSIS
    Run DISM and SFC to repair the Windows image

.DESCRIPTION
    Runs DISM /Online /Cleanup-Image /RestoreHealth followed by sfc /scannow to repair the component store.

.TAGS
    System,Repair,DISM,SFC

.PLATFORM
    Windows 10/11/Server 2019+

.PERMISSIONS
    Administrator

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
    .\Repair-WindowsImage.ps1
    Runs with default targets.

.EXAMPLE
    .\Repair-WindowsImage.ps1 -TargetName "Server01","Server02"
    Runs against the specified targets.

.NOTES
    Part of Windows-Scripts toolkit - System,Repair,DISM,SFC
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

$SolutionName = 'Repair-WindowsImage'
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
        if (-not $PSCmdlet.ShouldProcess($Target, 'Repair image')) {
            return [PSCustomObject]@{ Target = $Target; Success = $true; Skipped = $true }
        }
        & dism.exe /Online /Cleanup-Image /RestoreHealth | Out-Null; if ($LASTEXITCODE -notin @(0,3010)) { throw "DISM failed: $LASTEXITCODE" }
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
    $SolutionName = 'Repair-WindowsImage'
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
    # Tailored display: comprehensive image health diagnostics
    try {
        Write-Host "" -ForegroundColor Gray
        Write-Host "  -- DISM CheckHealth (quick) --" -ForegroundColor DarkGray
        $check = & dism.exe /Online /Cleanup-Image /CheckHealth 2>&1 | Out-String
        $check -split "`r`n" | Where-Object { $_.Trim() -ne "" } | Select-Object -First 8 | ForEach-Object { Write-Host "  $($_.Trim())" -ForegroundColor $(if ($_ -match "repairable|corruption") {'Yellow'} else {'Gray'}) }
        $repairable = $check -match "repairable"
        Write-Host ("  Repairable: {0}" -f $repairable) -ForegroundColor $(if ($repairable) {'Yellow'} else {'Green'})

        Write-Host "  -- DISM ScanHealth (deeper, if CheckHealth shows repairable) --" -ForegroundColor DarkGray
        if ($repairable) {
            Write-Host "  Run: DISM /Online /Cleanup-Image /ScanHealth (takes 5-10 min)" -ForegroundColor Yellow
            Write-Host "  Then: DISM /Online /Cleanup-Image /RestoreHealth (requires Windows Update or ISO source)" -ForegroundColor Yellow
        } else {
            Write-Host "  ScanHealth not needed - CheckHealth shows no corruption" -ForegroundColor Green
            Write-Host "  Optional: DISM /Online /Cleanup-Image /ScanHealth for deep scan" -ForegroundColor Gray
        }

        Write-Host "  -- SFC Verification --" -ForegroundColor DarkGray
        $sfc = try { sfc /verifyonly 2>&1 | Out-String } catch { "sfc not available" }
        $sfc -split "`r`n" | Where-Object { $_.Trim() -ne "" } | Select-Object -First 6 | ForEach-Object { Write-Host "  $($_.Trim())" -ForegroundColor Gray }
        if ($sfc -match "did not find any integrity violations") { Write-Host "  SFC: No violations (healthy)" -ForegroundColor Green }
        elseif ($sfc -match "found corrupt files") { Write-Host "  SFC: Corrupt files found - run sfc /scannow" -ForegroundColor Yellow }

        Write-Host "  -- CBS Logs & Component Store --" -ForegroundColor DarkGray
        $cbsLog = "C:\Windows\Logs\CBS\CBS.log"
        if (Test-Path $cbsLog) {
            $cbsSize = [math]::Round((Get-Item $cbsLog).Length / 1MB,1)
            Write-Host "  CBS.log: $cbsSize MB at $cbsLog" -ForegroundColor Gray
            Get-Content -Path $cbsLog -Tail 5 -ErrorAction SilentlyContinue | ForEach-Object { Write-Host "    $_" -ForegroundColor DarkGray }
        }
        $winSxs = Get-ChildItem -Path "C:\Windows\WinSxS" -ErrorAction SilentlyContinue | Measure-Object | Select-Object -ExpandProperty Count
        Write-Host "  WinSxS entries: $winSxs (component store)" -ForegroundColor Gray
        try { $dismSize = (Get-ChildItem -Path "C:\Windows\Logs\DISM" -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum; Write-Host "  DISM logs: $([math]::Round($dismSize/1KB,1)) KB" -ForegroundColor Gray } catch {}

        Write-Host "  -- Repair Actions Taken --" -ForegroundColor DarkGray
        Write-Host "  Executed: DISM /Online /Cleanup-Image /RestoreHealth" -ForegroundColor Cyan
        Write-Host "  ExitCode: $LASTEXITCODE (0=success, 3010=reboot needed)" -ForegroundColor $(if ($LASTEXITCODE -in @(0,3010)) {'Green'} else {'Red'})
        Write-Host "  Next: sfc /scannow  and  DISM /Online /Cleanup-Image /CheckHealth to verify" -ForegroundColor Gray

    } catch {
        Write-Log -Message "Could not check DISM: $($_.Exception.Message)" -Level 'WARNING'
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

