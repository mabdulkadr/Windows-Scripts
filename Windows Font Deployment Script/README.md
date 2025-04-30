
# Windows Font Deployment Scripts

![PowerShell](httpsimg.shields.iobadgepowershell-5.1%2B-blue.svg)
![License](httpsimg.shields.iobadgelicense-MIT-green.svg)
![Status](httpsimg.shields.iobadgestatus-production-ready-brightgreen)

## Overview

This project includes two PowerShell scripts to install and uninstall TrueType (.TTF) and OpenType (.OTF) fonts on Windows systems from a shared network folder.

These scripts are designed for use in enterprise environments where fonts need to be deployed or removed from multiple machines — for example, via Microsoft Intune, Group Policy, or SCCM.

## Scripts Included

1. Install-Fonts.ps1
   - Installs all `.ttf` and `.otf` fonts from a shared folder to `CWindowsFonts`.
   - Automatically registers fonts in the system registry.
   - Uses force overwrite and includes color-coded output.

2. Uninstall-Fonts.ps1
   - Uninstalls fonts based on file names in the same shared folder.
   - Removes font files and cleans up associated registry entries.
   - Also includes force execution and color-coded output.

---

## Scripts Details

### 1. Install-Fonts.ps1

#### Purpose
Installs all fonts from shared folder to the system fonts directory and registers them under the Windows registry.

#### How to Run
```powershell
powershell -ExecutionPolicy Bypass -File .Install-Fonts.ps1
```

#### Features
- Auto-detects `.ttf` and `.otf` files
- Forces overwrite if fonts already exist
- Registers fonts with the correct registry key  
  `HKLMSOFTWAREMicrosoftWindows NTCurrentVersionFonts`

---

### 2. Uninstall-Fonts.ps1

#### Purpose
Removes fonts that match the filenames in the shared folder from `CWindowsFonts` and deletes their associated registry entries.

#### How to Run
```powershell
powershell -ExecutionPolicy Bypass -File .Uninstall-Fonts.ps1
```

#### Features
- Matches based on files in the shared folder
- Force-removes fonts even if they already exist
- Deletes corresponding registry entries

---

## Notes

- Run both scripts as Administrator.
- Ensure the shared folder (`\\Fonts`) is accessible from the executing machine.
- Only `.ttf` and `.otf` font types are supported.
- These scripts use color-coded console output (Green = success, Red = failure, Yellow = warning).

---

## License

This project is licensed under the [MIT License](https\\:opensource.org\licensesMIT).

---

Disclaimer Use these scripts at your own risk. Always test in a staging environment before deploying in production.
