<#
.SYNOPSIS
    Scans and removes revoked root certificates with formatted table-style logging.

.DESCRIPTION
    This script checks the revocation status of certificates in the LocalMachine Trusted Root store.
    Revoked certificates are removed automatically, and a formatted log is saved to C:\Intune.

.NOTES
    Author  : Mohammed Omar
    Date    : 2025-05-27
    Run As  : Administrator
#>

# ------------------- Initial Setup -------------------
$LogFolder = "C:\Intune"
$LogFile = "RevokedRootCerts-$(Get-Date -Format 'yyyyMMdd-HHmmss').log"
$LogPath = Join-Path $LogFolder $LogFile

# Ensure log folder exists
if (-not (Test-Path $LogFolder)) {
    New-Item -Path $LogFolder -ItemType Directory -Force | Out-Null
}

# Start log with header
$timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
$header = @"
========================================================================================
 Trusted Root Certificate Revocation Cleanup Log
 Date: $timestamp
========================================================================================
| Time                | Status   | Subject                                  | Thumbprint                         | Details                            |
|---------------------|----------|------------------------------------------|------------------------------------|------------------------------------|
"@
$header | Out-File -FilePath $LogPath -Encoding UTF8

# ------------------- Certificate Processing -------------------
$store = New-Object System.Security.Cryptography.X509Certificates.X509Store("Root", "LocalMachine")
$store.Open("ReadWrite")

[int]$countOK = 0
[int]$countRevoked = 0
[int]$countInvalid = 0
[int]$countError = 0

foreach ($cert in $store.Certificates) {
    $time = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $subject = ($cert.Subject -replace '^CN=', '')
    $subjectShort = if ($subject.Length -gt 40) { $subject.Substring(0, 38) + "..." } else { $subject }
    $thumb = $cert.Thumbprint
    $status = ""
    $details = ""

    $chain = New-Object System.Security.Cryptography.X509Certificates.X509Chain
    $chain.ChainPolicy.RevocationMode = "Online"
    $chain.ChainPolicy.RevocationFlag = "EntireChain"
    $chain.ChainPolicy.UrlRetrievalTimeout = New-TimeSpan -Seconds 10

    try {
        $isValid = $chain.Build($cert)
        if (-not $isValid) {
            $revoked = $false
            foreach ($s in $chain.ChainStatus) {
                if ($s.Status -eq "Revoked") { $revoked = $true }
                $details += "$($s.Status); "
            }

            if ($revoked) {
                $store.Remove($cert)
                $status = "Revoked"
                $countRevoked++
            } else {
                $status = "Invalid"
                $countInvalid++
            }
        } else {
            $status = "OK"
            $details = "Valid"
            $countOK++
        }
    } catch {
        $status = "Error"
        $details = $_.Exception.Message
        $countError++
    }

    if ($details.Length -gt 30) {
        $details = $details.Substring(0, 28) + "..."
    }

    $line = "| {0,-19} | {1,-8} | {2,-40} | {3,-34} | {4,-32} |" -f $time, $status, $subjectShort, $thumb, $details
    $line | Out-File -Append $LogPath -Encoding UTF8
}

$store.Close()

# ------------------- Summary -------------------
$footer = @"
========================================================================================
 Summary:
 - Total Certificates Checked : $($countOK + $countRevoked + $countInvalid + $countError)
 - Valid Certificates         : $countOK
 - Revoked Certificates       : $countRevoked
 - Invalid (non-revoked)      : $countInvalid
 - Errors                     : $countError
 Log Path: $LogPath
========================================================================================
"@
$footer | Out-File -Append $LogPath -Encoding UTF8

# Console Output
Write-Host "`n✅ Revocation check complete. Log saved to:`n$LogPath" -ForegroundColor Cyan
