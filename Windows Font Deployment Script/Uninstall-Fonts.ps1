<#
.SYNOPSIS
    Force-uninstalls all .TTF and .OTF fonts listed in a shared network folder.

.DESCRIPTION
    This script removes font files from the Windows Fonts directory (`C:\Windows\Fonts`)
    and deletes their corresponding registry entries under:
    HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts

    The script:
    - Uses the filenames in the shared folder as uninstall targets
    - Forces deletion of font files and registry entries
    - Displays color-coded output for success/failure tracking

.NOTES
    Author  : Mohammad Abdulkader Omar
    Website : https://momar.tech
    Date    : 2025-04-30
#>

# Define the shared folder containing font references
$FontDirectory = "\\Fonts"

# Define output colors
$Green = "Green"
$Yellow = "Yellow"
$Red = "Red"

Write-Host "=== Font Uninstallation Script ===" -ForegroundColor Cyan
Write-Host "Source: $FontDirectory" -ForegroundColor Gray

# Check if the shared folder exists
if (-Not (Test-Path -Path $FontDirectory)) {
    Write-Host "ERROR: Fonts folder not found." -ForegroundColor Red
    exit 1
}

# Collect all .ttf and .otf font files to determine uninstall targets
$Fonts = Get-ChildItem -Path $FontDirectory -Include *.ttf, *.otf -File -Recurse -ErrorAction SilentlyContinue

if (-Not $Fonts) {
    Write-Host "WARNING: No font files found in the directory." -ForegroundColor Yellow
    exit 0
}

# Uninstall each font
foreach ($Font in $Fonts) {
    try {
        $FontName = $Font.Name
        $DestFontPath = Join-Path "$env:windir\Fonts" $FontName

        # Remove font file from system Fonts folder
        if (Test-Path $DestFontPath) {
            Remove-Item -Path $DestFontPath -Force
            Write-Host "Removed font file: $FontName" -ForegroundColor $Green
        }

        # Prepare registry-friendly name
        $RegFontName = [System.IO.Path]::GetFileNameWithoutExtension($FontName)
        $RegistryName = "$RegFontName (TrueType)"

        # Remove registry entry if it exists
        if (Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts" -Name $RegistryName -ErrorAction SilentlyContinue) {
            Remove-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts" -Name $RegistryName -Force
            Write-Host "Removed registry entry: $RegistryName" -ForegroundColor $Green
        }

    } catch {
        Write-Host "Failed to remove $FontName - $_" -ForegroundColor $Red
    }
}

Write-Host "`nFont uninstallation completed successfully." -ForegroundColor Cyan
