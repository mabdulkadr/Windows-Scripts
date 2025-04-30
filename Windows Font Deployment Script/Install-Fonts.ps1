<#
.SYNOPSIS
    Force-installs all .TTF and .OTF fonts from a shared network folder.

.DESCRIPTION
    This script copies all TrueType (.ttf) and OpenType (.otf) font files from a specified shared network directory 
    to the Windows Fonts directory (`C:\Windows\Fonts`). It also registers the fonts in the Windows Registry under:
    HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts

    The script:
    - Runs with forced overwrite
    - Displays color-coded output
    - Handles errors gracefully

.NOTES
    Author  : Mohammad Abdulkader Omar
    Website : https://momar.tech
    Date    : 2025-04-30
#>

# Define the shared folder containing fonts
$FontDirectory = "\\Fonts"

# Define output colors
$Green = "Green"
$Yellow = "Yellow"
$Red = "Red"

Write-Host "=== Font Installation Script ===" -ForegroundColor Cyan
Write-Host "Source: $FontDirectory" -ForegroundColor Gray

# Check if the shared folder exists
if (-Not (Test-Path -Path $FontDirectory)) {
    Write-Host "ERROR: Fonts folder not found." -ForegroundColor Red
    exit 1
}

# Collect all .ttf and .otf font files
$Fonts = Get-ChildItem -Path $FontDirectory -Include *.ttf, *.otf -File -Recurse -ErrorAction SilentlyContinue

if (-Not $Fonts) {
    Write-Host "WARNING: No font files found in the directory." -ForegroundColor Yellow
    exit 0
}

# Install each font
foreach ($Font in $Fonts) {
    try {
        $FontName = $Font.Name
        $FontPath = $Font.FullName
        $DestPath = Join-Path "$env:windir\Fonts" $FontName

        # Copy font to system Fonts folder with overwrite
        Copy-Item -Path $FontPath -Destination $DestPath -Force

        # Prepare registry-friendly name
        $RegFontName = [System.IO.Path]::GetFileNameWithoutExtension($FontName)
        $RegistryName = "$RegFontName (TrueType)"

        # Register the font in the registry
        New-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Fonts" `
                         -Name $RegistryName `
                         -PropertyType String `
                         -Value $FontName `
                         -Force

        Write-Host "Installed: $FontName" -ForegroundColor $Green
    } catch {
        Write-Host "Failed to install $FontName - $_" -ForegroundColor $Red
    }
}

Write-Host "`nFont installation completed successfully." -ForegroundColor Cyan
