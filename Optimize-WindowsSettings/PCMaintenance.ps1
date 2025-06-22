<#
.SYNOPSIS
    Performs essential Windows PC maintenance tasks automatically.

.DESCRIPTION
    This script automates a set of routine Windows maintenance tasks to ensure system stability and performance.
    It performs the following actions:
    - Clears user temp files
    - Runs System File Checker (SFC)
    - Executes DISM for Windows image health check and repair
    - Flushes DNS cache
    - Removes old minidump crash files
    - Logs each step with timestamps and colored console output

    The script also saves the full log to a timestamped `.log` file in `C:\`, and displays clear success or error messages
    for each operation.

.EXAMPLE
    .\PCMaintenance.ps1
    Runs all maintenance tasks and logs results to `C:\PC_Maintenance_Log_*.log`

.NOTES
    Author  : Mohammad Abdelkader
    Website : momar.tech
    Date    : 2025-06-22
    Version : 1.0
#>

[CmdletBinding()]
param()

# Set up logging
$startTime = Get-Date
$logFile = "C:\PC_Maintenance_Log_$(Get-Date -Format 'yyyyMMdd_HHmm').log"

function Write-Log {
    param(
        [string]$Message,
        [ConsoleColor]$Color = "White"
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Write-Host "$Message" -ForegroundColor $Color
    Add-Content -Path $logFile -Value "$timestamp - $Message"
}

Write-Log "🧹 Starting PC Maintenance Tasks..." -Color Cyan

#--------------------------------------------------
# 1. Clear Temp Files
#--------------------------------------------------
Write-Log ""
Write-Log "🗑 Clearing temporary files..."
try {
    Remove-Item -Path $env:TEMP\* -Recurse -Force -ErrorAction Stop
    Write-Log "✅ Temporary files cleared successfully." -Color Green
} catch {
    Write-Log "❌ Failed to clear temp files: $_" -Color Red
}

#--------------------------------------------------
# 2. Run SFC Scan
#--------------------------------------------------
Write-Log ""
Write-Log "🔍 Running System File Checker (SFC) scan..."
try {
    Start-Process -FilePath "sfc" -ArgumentList "/scannow" -Wait -NoNewWindow
    Write-Log "✅ SFC scan completed." -Color Green
} catch {
    Write-Log "❌ Error running SFC scan: $_" -Color Red
}

#--------------------------------------------------
# 3. Run DISM Image Repair
#--------------------------------------------------
Write-Log ""
Write-Log "🔧 Running DISM to repair Windows image..."
try {
    Start-Process -FilePath "DISM" -ArgumentList "/Online /Cleanup-Image /RestoreHealth" -Wait -NoNewWindow
    Write-Log "✅ DISM completed." -Color Green
} catch {
    Write-Log "❌ Error running DISM: $_" -Color Red
}

#--------------------------------------------------
# 4. Flush DNS Cache
#--------------------------------------------------
Write-Log ""
Write-Log "🧼 Flushing DNS cache..."
try {
    ipconfig /flushdns | Out-Null
    Write-Log "✅ DNS cache flushed." -Color Green
} catch {
    Write-Log "❌ Failed to flush DNS: $_" -Color Red
}

#--------------------------------------------------
# 5. Clean Minidump Files
#--------------------------------------------------
Write-Log ""
$dumpPath = "$env:SystemRoot\Minidump"
if (Test-Path $dumpPath) {
    Write-Log "🗑 Removing minidump files..."
    try {
        Remove-Item -Path "$dumpPath\*" -Force -ErrorAction Stop
        Write-Log "✅ Minidump files removed." -Color Green
    } catch {
        Write-Log "❌ Failed to remove minidumps: $_" -Color Red
    }
} else {
    Write-Log "ℹ️ No minidump folder found. Skipping cleanup." -Color Yellow
}

#--------------------------------------------------
# 6. Final Summary
#--------------------------------------------------
Write-Log ""
Write-Log "🎉 PC Maintenance completed!" -Color Green
Write-Log "🕒 Total runtime: $((Get-Date) - $startTime)" -Color Cyan
Write-Log "📄 Log saved to: $logFile" -Color Cyan
Write-Log "👋 Maintenance complete. You may restart later if needed." -Color Cyan
