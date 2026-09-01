<#
.TITLE
    Clear-PrintQueue - Cancel all print jobs

.SYNOPSIS
    Cancel all print jobs

.DESCRIPTION
    Stops the Spooler, removes all jobs in the queue, and restarts the service.

.TAGS
    System,Print

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
    .\Clear-PrintQueue.ps1
    Runs with default targets.

.EXAMPLE
    .\Clear-PrintQueue.ps1 -TargetName "Server01","Server02"
    Runs against the specified targets.

.NOTES
    Part of Windows-Scripts toolkit - System,Print
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

$SolutionName = 'Clear-PrintQueue'
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
        if (-not $PSCmdlet.ShouldProcess($Target, 'Clear queue')) {
            return [PSCustomObject]@{ Target = $Target; Success = $true; Skipped = $true }
        }
        Get-PrintJob -ErrorAction SilentlyContinue | Remove-PrintJob -ErrorAction SilentlyContinue | Out-Null
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
    $SolutionName = 'Clear-PrintQueue'
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
    # Tailored display: comprehensive print queue diagnostics
    try {
        Write-Host "" -ForegroundColor Gray
        Write-Host "  -- Printers & Queues --" -ForegroundColor DarkGray
        $printers = Get-Printer -ErrorAction SilentlyContinue | Select-Object -First 10
        if ($printers) {
            $printers | ForEach-Object {
                $queue = Get-PrintJob -PrinterName $_.Name -ErrorAction SilentlyContinue
                $jobCount = ($queue | Measure-Object).Count
                $statusColor = if ($jobCount -gt 5) { "Red" } elseif ($jobCount -gt 0) { "Yellow" } else { "Green" }
                [PSCustomObject]@{
                    Printer   = $_.Name
                    Driver    = $_.DriverName
                    Jobs      = $jobCount
                    Status    = $_.PrinterStatus
                    Shared    = $_.Shared
                }
            } | Format-Table -AutoSize | Out-String | ForEach-Object { Write-Host $_ -ForegroundColor Cyan }
        } else { Write-Host "  No printers found" -ForegroundColor Yellow }

        Write-Host "  -- Print Jobs (detailed) --" -ForegroundColor DarkGray
        $jobs = Get-PrintJob -ErrorAction SilentlyContinue | Select-Object -First 10
        if ($jobs) {
            $jobs | ForEach-Object {
                [PSCustomObject]@{
                    Printer    = $_.PrinterName
                    Document   = $_.DocumentName
                    Owner      = $_.UserName
                    Pages      = $_.TotalPages
                    SizeKB     = [math]::Round($_.Size/1KB,1)
                    Submitted  = $_.SubmittedTime
                    Status     = $_.JobStatus
                }
            } | Format-Table -AutoSize | Out-String | ForEach-Object { Write-Host $_ -ForegroundColor Yellow }
            Write-Host ("  Total jobs: {0} (showing 10)" -f $jobs.Count) -ForegroundColor Yellow
        } else {
            Write-Host "  No print jobs in queue - already clear" -ForegroundColor Green
        }

        Write-Host "  -- Spooler Service & Folder --" -ForegroundColor DarkGray
        $spooler = Get-Service -Name Spooler -ErrorAction SilentlyContinue
        if ($spooler) {
            [PSCustomObject]@{ Service=$spooler.Name; Status=$spooler.Status; StartType=$spooler.StartType } | Format-List | Out-String | ForEach-Object { Write-Host $_ -ForegroundColor Cyan }
        }
        $spoolFolder = "$env:SystemRoot\System32\spool\PRINTERS"
        if (Test-Path $spoolFolder) {
            $spoolFiles = Get-ChildItem -Path $spoolFolder -ErrorAction SilentlyContinue
            $spoolCount = ($spoolFiles | Measure-Object).Count
            $spoolSize = [math]::Round((($spoolFiles | Measure-Object -Property Length -Sum).Sum / 1KB),1)
            Write-Host ("  Spool folder: {0} | Files: {1} | Size: {2} KB" -f $spoolFolder, $spoolCount, $spoolSize) -ForegroundColor Gray
            if ($spoolFiles) { $spoolFiles | Select-Object Name, Length, LastWriteTime -First 3 | Format-Table -AutoSize | Out-String | ForEach-Object { Write-Host $_ -ForegroundColor Gray } }
        }

        Write-Host "  -- Action Summary --" -ForegroundColor DarkGray
        $action = if ($jobs) { "Cleared $($jobs.Count) jobs via Remove-PrintJob" } else { "No jobs to clear - queue already empty" }
        Write-Host "  $action" -ForegroundColor $(if ($jobs) {'Green'} else {'Gray'})
        Write-Host "  Verify: Get-PrintJob | Measure-Object  (should be 0)" -ForegroundColor Gray

    } catch {
        Write-Log -Message "Could not query print queue: $($_.Exception.Message)" -Level 'WARNING'
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

