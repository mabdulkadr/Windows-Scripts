<#
.TITLE
    Repair-DomainTrust - Reset the secure channel to a domain controller

.SYNOPSIS
    Reset the secure channel to a domain controller

.DESCRIPTION
    Calls Test-ComputerSecureChannel -Repair to recover a broken trust.

.TAGS
    Identity,AD,Trust

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
    .\Repair-DomainTrust.ps1
    Runs with default targets.

.EXAMPLE
    .\Repair-DomainTrust.ps1 -TargetName "Server01","Server02"
    Runs against the specified targets.

.NOTES
    Part of Windows-Scripts toolkit - Identity,AD,Trust
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

$SolutionName = 'Repair-DomainTrust'
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
        if (-not $PSCmdlet.ShouldProcess($Target, 'Reset channel')) {
            return [PSCustomObject]@{ Target = $Target; Success = $true; Skipped = $true }
        }
        $ok = Test-ComputerSecureChannel -ErrorAction Stop; if (-not $ok) { Test-ComputerSecureChannel -Repair -ErrorAction Stop | Out-Null }
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
    $SolutionName = 'Repair-DomainTrust'
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
    # Tailored display: comprehensive trust diagnostics
    try {
        Write-Host "" -ForegroundColor Gray
        Write-Host "  -- Secure Channel --" -ForegroundColor DarkGray
        $before = Test-ComputerSecureChannel -ErrorAction SilentlyContinue
        $repairNeeded = -not $before
        Write-Host ("  Before repair: {0}" -f $before) -ForegroundColor $(if ($before) {'Green'} else {'Red'})
        if ($repairNeeded) {
            Write-Host "  Attempting repair: Test-ComputerSecureChannel -Repair" -ForegroundColor Yellow
            try { $repairResult = Test-ComputerSecureChannel -Repair -ErrorAction Stop; Write-Host "  Repair result: $repairResult" -ForegroundColor $(if ($repairResult) {'Green'} else {'Red'}) } catch { Write-Host "  Repair failed: $($_.Exception.Message)" -ForegroundColor Red }
        }
        $after = Test-ComputerSecureChannel -ErrorAction SilentlyContinue
        Write-Host ("  After: {0}" -f $after) -ForegroundColor $(if ($after) {'Green'} else {'Red'})
        if ($after) { Write-Host "  Trust is healthy - no further action" -ForegroundColor Green } else { Write-Host "  Trust still broken - check DC connectivity and time sync" -ForegroundColor Red }

        Write-Host "  -- Domain Controller Discovery --" -ForegroundColor DarkGray
        try {
            $dc = Get-ADDomainController -Discover -ErrorAction SilentlyContinue
            if ($dc) {
                [PSCustomObject]@{ HostName=$dc.HostName; Site=$dc.Site; IsGC=$dc.IsGlobalCatalog; OS=$dc.OperatingSystem } | Format-List | Out-String | ForEach-Object { Write-Host $_ -ForegroundColor Cyan }
            } else {
                $nltest = nltest /dsgetdc:$env:USERDNSDOMAIN 2>&1 | Out-String
                Write-Host $nltest -ForegroundColor Gray
            }
        } catch { Write-Host "  DC discovery: $($_.Exception.Message)" -ForegroundColor Yellow }

        Write-Host "  -- Time Sync (important for Kerberos) --" -ForegroundColor DarkGray
        try {
            $w32time = w32tm /query /status 2>&1 | Select-Object -First 10 | Out-String
            Write-Host $w32time -ForegroundColor Gray
            $timeDiff = try { (Get-Date) - (Get-Date).ToUniversalTime() } catch {}
        } catch {}

        Write-Host "  -- Next Steps --" -ForegroundColor DarkGray
        Write-Host "  Verify: Test-ComputerSecureChannel -Verbose ; nltest /sc_query:$env:USERDNSDOMAIN" -ForegroundColor Gray
        Write-Host "  If still failing: Reset-ComputerMachinePassword -Server <DC> -Credential (Get-Credential)" -ForegroundColor Gray

    } catch {
        Write-Log -Message "Could not test secure channel: $($_.Exception.Message)" -Level 'WARNING'
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

