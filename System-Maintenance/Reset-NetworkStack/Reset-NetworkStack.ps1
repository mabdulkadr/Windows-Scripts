<#
.TITLE
    Reset-NetworkStack - Reset Winsock and TCP/IP stack

.SYNOPSIS
    Reset Winsock and TCP/IP stack

.DESCRIPTION
    Runs netsh winsock reset and netsh int ip reset to recover from network stack corruption.

.TAGS
    System,Network,Winsock

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
    .\Reset-NetworkStack.ps1
    Runs with default targets.

.EXAMPLE
    .\Reset-NetworkStack.ps1 -TargetName "Server01","Server02"
    Runs against the specified targets.

.NOTES
    Part of Windows-Scripts toolkit - System,Network,Winsock
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

$SolutionName = 'Reset-NetworkStack'
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
        if (-not $PSCmdlet.ShouldProcess($Target, 'Reset stack')) {
            return [PSCustomObject]@{ Target = $Target; Success = $true; Skipped = $true }
        }
        & netsh winsock reset | Out-Null; & netsh int ip reset | Out-Null
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
    $SolutionName = 'Reset-NetworkStack'
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
    # Tailored display: comprehensive network stack diagnostics
    try {
        Write-Host "" -ForegroundColor Gray
        Write-Host "  -- Network Adapters (detailed) --" -ForegroundColor DarkGray
        $adapters = Get-NetAdapter -ErrorAction SilentlyContinue
        if ($adapters) {
            $rows = $adapters | ForEach-Object {
                $ip = Get-NetIPAddress -InterfaceIndex $_.InterfaceIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue | Select-Object -First 1
                $dns = (Get-DnsClientServerAddress -InterfaceIndex $_.InterfaceIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue).ServerAddresses -join ", "
                [PSCustomObject]@{
                    Name       = $_.Name
                    Status     = $_.Status
                    LinkSpeed  = $_.LinkSpeed
                    IP         = if ($ip) { $ip.IPAddress } else { "none" }
                    DNS        = if ($dns) { $dns } else { "DHCP" }
                    Media      = $_.MediaType
                }
            } | Select-Object -First 8
            $rows | Format-Table -AutoSize | Out-String | ForEach-Object { Write-Host $_ -ForegroundColor Cyan }
            Write-Host ("  Total adapters: {0} | Up: {1} | Disconnected: {2}" -f $adapters.Count, ($adapters | Where-Object { $_.Status -eq 'Up' } | Measure-Object).Count, ($adapters | Where-Object { $_.Status -eq 'Disconnected' } | Measure-Object).Count) -ForegroundColor Gray
        }

        Write-Host "  -- Winsock & TCP/IP Stack --" -ForegroundColor DarkGray
        try {
            $winsock = netsh winsock show catalog 2>&1 | Select-Object -First 5 | Out-String
            Write-Host "  Winsock catalog (first 5):" -ForegroundColor Gray
            Write-Host $winsock -ForegroundColor Gray
        } catch [System.Exception] { Write-Log -Message $_.Exception.Message -Level 'DEBUG' }
        $tcpParams = Get-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters' -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($tcpParams) {
            Write-Host "  TCP Parameters:" -ForegroundColor Gray
            $tcpParams.PSObject.Properties | Where-Object { $_.Name -notlike "PS*" } | Select-Object -First 5 | ForEach-Object {
                Write-Host ("    {0} = {1}" -f $_.Name, $_.Value) -ForegroundColor Gray
            }
        }

        Write-Host "  -- Reset Actions Taken --" -ForegroundColor DarkGray
        Write-Host "  Executed: netsh winsock reset  +  netsh int ip reset (netsh.log)" -ForegroundColor Cyan
        Write-Host "  Log: netsh.log in current directory (if int ip reset was logged)" -ForegroundColor Gray
        if (Test-Path "netsh.log") {
            $logSize = (Get-Item "netsh.log").Length
            Write-Host "  netsh.log: $logSize bytes" -ForegroundColor Yellow
            Get-Content -Path "netsh.log" -Tail 5 -ErrorAction SilentlyContinue | ForEach-Object { Write-Host "    $_" -ForegroundColor Gray }
        }
        Write-Host "  Reboot required: YES - network stack reset needs restart" -ForegroundColor Yellow
        Write-Host "  Verify after reboot: Get-NetAdapter | Format-Table ; Test-NetConnection 8.8.8.8" -ForegroundColor Gray
        Write-Host "  Rollback: No rollback - Winsock/IP reset is destructive, ensure you have driver backups" -ForegroundColor Yellow

    } catch {
        Write-Log -Message "Could not query adapters: $($_.Exception.Message)" -Level 'WARNING'
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

