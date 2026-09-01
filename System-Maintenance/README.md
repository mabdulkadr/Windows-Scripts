<div align="center">

# 📂 System-Maintenance
**System Maintenance - repair, cleanup, optimization and services - 19 tools**

Part of **Windows-Scripts** enterprise toolkit - `Windows-Scripts/System-Maintenance/`

[![Mode](https://img.shields.io/badge/Mode-CLI-334155?style=for-the-badge)](#-core-features)
[![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-5391FE?style=for-the-badge&logo=powershell&logoColor=white)](https://learn.microsoft.com/en-us/powershell/)
[![Platform](https://img.shields.io/badge/Platform-Windows%2010%2F11-0F172A?style=for-the-badge)](#%EF%B8%8F-requirements)
[![License](https://img.shields.io/badge/License-MIT-F59E0B?style=for-the-badge)](#-license)
[![Version](https://img.shields.io/badge/Version-2.1.0-334155?style=for-the-badge)](#-overview)

[Overview](#-overview) | [Features](#-core-features) | [Tools](#-tools) | [Usage](#-usage) | [Requirements](#%EF%B8%8F-requirements) | [License](#-license)

</div>

---

# 📖 Overview

**System-Maintenance** contains **19 PowerShell CLI tools** for System Maintenance - repair, cleanup, optimization and services.

**Category:** `System-Maintenance`
**Path:** `System-Maintenance/`

> **Structure:** `Windows-Scripts/System-Maintenance/<ScriptName>/<ScriptName>.ps1 + README.md` - each tool is isolated with its own README.

---

# ✨ Core Features

* **19 Isolated Tools** - each in `System-Maintenance/ScriptName/` with `README.md`
* **Verb-Noun PascalCase** - no spaces, no typos, no double extensions
* **CLI-First** - pure PowerShell 5.1, no GUI dependencies
* **Canonical logging** - `Initialize-Log` / `Write-Banner` / `Write-Log` / `Finish-Script`
* **Intune-Ready** - exit codes 0/1/2, SYSTEM context support

---

# 🧰 Tools (19)

| Tool | Script | Path |
|------|--------|------|
| Clear-PrintQueue | Clear-PrintQueue.ps1 | [Clear-PrintQueue](./Clear-PrintQueue/) |
| Clear-TempCache | Clear-TempCache.ps1 | [Clear-TempCache](./Clear-TempCache/) |
| Disable-FastStartup | Disable-FastStartup.ps1 | [Disable-FastStartup](./Disable-FastStartup/) |
| Enable-FastStartup | Enable-FastStartup.ps1 | [Enable-FastStartup](./Enable-FastStartup/) |
| Enable-SystemRestore | Enable-SystemRestore.ps1 | [Enable-SystemRestore](./Enable-SystemRestore/) |
| Get-USBDeviceHistory | Get-USBDeviceHistory.ps1 | [Get-USBDeviceHistory](./Get-USBDeviceHistory/) |
| Invoke-PCMaintenance | Invoke-PCMaintenance.ps1 | [Invoke-PCMaintenance](./Invoke-PCMaintenance/) |
| Invoke-SystemCleanup | Invoke-SystemCleanup.ps1 | [Invoke-SystemCleanup](./Invoke-SystemCleanup/) |
| Invoke-WindowsUpdate | Invoke-WindowsUpdate.ps1 | [Invoke-WindowsUpdate](./Invoke-WindowsUpdate/) |
| Optimize-WindowsSettings | Optimize-WindowsSettings.ps1 | [Optimize-WindowsSettings](./Optimize-WindowsSettings/) |
| Remove-WindowsBloatware | Remove-WindowsBloatware.ps1 | [Remove-WindowsBloatware](./Remove-WindowsBloatware/) |
| Repair-TimeService | Repair-TimeService.ps1 | [Repair-TimeService](./Repair-TimeService/) |
| Repair-WindowsImage | Repair-WindowsImage.ps1 | [Repair-WindowsImage](./Repair-WindowsImage/) |
| Repair-WindowsStore | Repair-WindowsStore.ps1 | [Repair-WindowsStore](./Repair-WindowsStore/) |
| Repair-WindowsUpdate | Repair-WindowsUpdate.ps1 | [Repair-WindowsUpdate](./Repair-WindowsUpdate/) |
| Reset-NetworkStack | Reset-NetworkStack.ps1 | [Reset-NetworkStack](./Reset-NetworkStack/) |
| Reset-PrintSpooler | Reset-PrintSpooler.ps1 | [Reset-PrintSpooler](./Reset-PrintSpooler/) |
| Restart-Explorer | Restart-Explorer.ps1 | [Restart-Explorer](./Restart-Explorer/) |
| Watch-DiskSpace | Watch-DiskSpace.ps1 | [Watch-DiskSpace](./Watch-DiskSpace/) |

---

# 📂 Project Structure

```text
System-Maintenance/
├── Clear-PrintQueue/
│   ├── Clear-PrintQueue.ps1
│   └── README.md
├── Clear-TempCache/
│   ├── Clear-TempCache.ps1
│   └── README.md
├── Disable-FastStartup/
│   ├── Disable-FastStartup.ps1
│   └── README.md
├── Enable-FastStartup/
│   ├── Enable-FastStartup.ps1
│   └── README.md
├── Enable-SystemRestore/
│   ├── Enable-SystemRestore.ps1
│   └── README.md
├── Get-USBDeviceHistory/
│   ├── Get-USBDeviceHistory.ps1
│   └── README.md
├── Invoke-PCMaintenance/
│   ├── Invoke-PCMaintenance.ps1
│   └── README.md
├── Invoke-SystemCleanup/
│   ├── Invoke-SystemCleanup.ps1
│   └── README.md
├── Invoke-WindowsUpdate/
│   ├── Invoke-WindowsUpdate.ps1
│   └── README.md
├── Optimize-WindowsSettings/
│   ├── Optimize-WindowsSettings.ps1
│   └── README.md
├── Remove-WindowsBloatware/
│   ├── Remove-WindowsBloatware.ps1
│   └── README.md
├── Repair-TimeService/
│   ├── Repair-TimeService.ps1
│   └── README.md
├── Repair-WindowsImage/
│   ├── Repair-WindowsImage.ps1
│   └── README.md
├── Repair-WindowsStore/
│   ├── Repair-WindowsStore.ps1
│   └── README.md
├── Repair-WindowsUpdate/
│   ├── Repair-WindowsUpdate.ps1
│   └── README.md
├── Reset-NetworkStack/
│   ├── Reset-NetworkStack.ps1
│   └── README.md
├── Reset-PrintSpooler/
│   ├── Reset-PrintSpooler.ps1
│   └── README.md
├── Restart-Explorer/
│   ├── Restart-Explorer.ps1
│   └── README.md
├── Watch-DiskSpace/
│   ├── Watch-DiskSpace.ps1
│   └── README.md
```

---

# 🚀 Usage

```powershell
# Run any tool in this category
.\System-Maintenance\Clear-PrintQueue\Clear-PrintQueue.ps1
.\System-Maintenance\Clear-PrintQueue\Clear-PrintQueue.ps1 -WhatIf

# Help
Get-Help .\System-Maintenance\Clear-PrintQueue\Clear-PrintQueue.ps1 -Full
```

---

# ⚙️ Requirements

* **OS:** Windows 10/11/Server 2019+
* **PowerShell:** 5.1 or later (`#Requires -Version 5.1`)
* **Permissions:** See per-tool README for specific requirements
* **Modules:** None - uses built-in cmdlets only (AD tools require `ActiveDirectory` module)

---

# 🛡 Operational Notes

* Always test with `-WhatIf` first in a staging environment before production rollout.
* Elevation is detected at runtime via `Test-IsElevated`; the script logs a warning and degrades gracefully when not elevated.
* Each per-tool result is returned as a structured `PSCustomObject` with `Target / Success / Skipped / Error` fields, aggregated in MAIN.
* Log files are written to `C:\ProgramData\WindowsScripts\Logs\<yyyyMMdd>.log` (TSV-like `[time] [Level] message` lines).
* Re-running any tool is **idempotent** - it produces the same end state.

---

## 👤 Author
**Mohammad Abdelkader Omar**
GitHub: [@mabdulkadr](https://github.com/mabdulkadr)
Website: [momar.tech](https://momar.tech)
## 📜 License

This project is licensed under the [MIT License](https://opensource.org/licenses/MIT).

---

## ⚠ Disclaimer

This skill and every script it generates are provided as-is with no warranty of any kind. Test generated tools in a staging environment before deploying to production. The authors assume no liability for any damage or data loss resulting from their use.

---
<div align="center">

If this toolkit saves you time, star the repo - it helps others find it.

[Report an Issue](../../issues) | [momar.tech](https://momar.tech)

[![Buy Me A Coffee](https://img.shields.io/badge/Buy%20Me%20A%20Coffee-FFDD00?style=for-the-badge&logo=buy-me-a-coffee&logoColor=black)](https://www.buymeacoffee.com/mabdulkadrx)

Built with [**PowerShell Enterprise Admin**](https://github.com/mabdulkadr/powershell-enterprise-admin-skill)

</div>