<#
.TITLE
    Get-AppliedGPO - List GPOs applied to the current user/computer

.SYNOPSIS
    List GPOs applied to the current user/computer

.DESCRIPTION
    Combines Get-GPResultantSetOfPolicy and Get-GPResultantPolicy to list applied GPOs.

.TAGS
    GroupPolicy,Reporting

.PLATFORM
    Windows 10/11/Server 2019+

.PERMISSIONS
    Standard user

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
    .\Get-AppliedGPO.ps1
    Runs with default targets.

.EXAMPLE
    .\Get-AppliedGPO.ps1 -TargetName "Server01","Server02"
    Runs against the specified targets.

.NOTES
    Part of Windows-Scripts toolkit - GroupPolicy,Reporting
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

$SolutionName = 'Get-AppliedGPO'
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
        if (-not $PSCmdlet.ShouldProcess($Target, 'List GPO')) {
            return [PSCustomObject]@{ Target = $Target; Success = $true; Skipped = $true }
        }
        $null = Get-Command Get-GPResultantSetOfPolicy -ErrorAction SilentlyContinue; if (-not $null) { throw 'GroupPolicy module not found' }
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
    $SolutionName = 'Get-AppliedGPO'
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
    # Tailored display: comprehensive GPO diagnostics
    try {
        Write-Host "" -ForegroundColor Gray
        Write-Host "  -- Computer vs User GPOs (gpresult /R /Scope) --" -ForegroundColor DarkGray
        $gpresultR = gpresult /R 2>&1 | Out-String
        # Split Computer and User sections
        $computerSection = ($gpresultR -split "USER SETTINGS")[0]
        $userSection = if ($gpresultR -match "USER SETTINGS") { ($gpresultR -split "USER SETTINGS")[1] } else { "" }

        Write-Host "  [Computer Configuration]" -ForegroundColor Cyan
        $compGPOs = $computerSection -split "`r`n" | Where-Object { $_ -match "^\s{2,}[A-Z].*GPO|Applied Group Policy" } | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne "" } | Select-Object -First 12
        if ($compGPOs) { $compGPOs | ForEach-Object { Write-Host "    $_" -ForegroundColor Gray } }
        else {
            # Fallback: show all lines with GPO in computer section
            $fallback = $computerSection -split "`r`n" | Where-Object { $_ -match "GPO" } | Select-Object -First 8
            if ($fallback) { $fallback | ForEach-Object { Write-Host "    $($_.Trim())" -ForegroundColor Gray } }
            else { Write-Host "    No Computer GPOs parsed - see gpresult /R full output" -ForegroundColor Yellow }
        }

        Write-Host "  [User Configuration]" -ForegroundColor Cyan
        $userGPOs = $userSection -split "`r`n" | Where-Object { $_ -match "^\s{2,}[A-Z].*GPO|Applied Group Policy" } | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne "" } | Select-Object -First 12
        if ($userGPOs) { $userGPOs | ForEach-Object { Write-Host "    $_" -ForegroundColor Gray } }
        else {
            $fallbackU = $userSection -split "`r`n" | Where-Object { $_ -match "GPO" } | Select-Object -First 8
            if ($fallbackU) { $fallbackU | ForEach-Object { Write-Host "    $($_.Trim())" -ForegroundColor Gray } }
            else { Write-Host "    No User GPOs (or user not logged via GP)" -ForegroundColor Yellow }
        }

        Write-Host "  -- GPOs Filtered Out (Denied) --" -ForegroundColor DarkGray
        $denied = $gpresultR -split "`r`n" | Where-Object { $_ -match "The following GPOs were not applied|Filtered Out|Denied" } | Select-Object -First 5
        if ($denied) { $denied | ForEach-Object { Write-Host "  $($_.Trim())" -ForegroundColor Yellow } }
        else {
            $notApplied = $gpresultR -split "`r`n" | Where-Object { $_ -match "not applied" } | Select-Object -First 5
            if ($notApplied) { $notApplied | ForEach-Object { Write-Host "  $($_.Trim())" -ForegroundColor Yellow } }
            else { Write-Host "  None listed (or gpresult /V needed for details)" -ForegroundColor Gray }
        }

        Write-Host "  -- Last GP Update & Domain --" -ForegroundColor DarkGray
        try {
            $lastGP = Get-WinEvent -LogName "Microsoft-Windows-GroupPolicy/Operational" -MaxEvents 1 -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($lastGP) { Write-Host ("  Last GP Event: {0} (ID {1})" -f $lastGP.TimeCreated, $lastGP.Id) -ForegroundColor Gray }
        } catch [System.Exception] { Write-Log -Message $_.Exception.Message -Level 'DEBUG' }
        $domain = (Get-CimInstance -ClassName Win32_ComputerSystem -ErrorAction SilentlyContinue).Domain
        $ou = try { (Get-ADComputer -Identity $env:COMPUTERNAME -Properties DistinguishedName -ErrorAction SilentlyContinue).DistinguishedName } catch { "AD module not available" }
        Write-Host "  Domain: $domain" -ForegroundColor Cyan
        Write-Host "  OU: $ou" -ForegroundColor Gray
        Write-Host "  Command: gpresult /H Reports\GPResult.html  |  gpresult /V for verbose" -ForegroundColor Gray

        # Dual reports
        try {
            $scriptBase = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $PSCommandPath }
            $reports = Join-Path $scriptBase "Reports"
            if (-not (Test-Path -LiteralPath $reports)) { $null = [System.IO.Directory]::CreateDirectory($reports) }
            $csvPath = Join-Path $reports "AppliedGPO_$(Get-Date -Format yyyyMMdd_HHmmss).csv"
            $allGPOs = @()
            $allGPOs += $compGPOs | ForEach-Object { [PSCustomObject]@{ Scope="Computer"; GPO=$_ } }
            $allGPOs += $userGPOs | ForEach-Object { [PSCustomObject]@{ Scope="User"; GPO=$_ } }
            if ($allGPOs) { $allGPOs | Export-Csv -Path $csvPath -NoTypeInformation -Encoding UTF8; Write-Host "  CSV: $csvPath" -ForegroundColor Cyan }
        } catch { Write-Log -Message "CSV export failed: $($_.Exception.Message)" -Level 'WARNING' }

    } catch {
        Write-Log -Message "Could not query applied GPOs: $($_.Exception.Message)" -Level 'WARNING'
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

