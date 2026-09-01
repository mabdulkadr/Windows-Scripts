<div align="center">

# 📂 Software-Deployment
**Software Deployment - Store apps and font management - 3 tools**

Part of **Windows-Scripts** enterprise toolkit - `Windows-Scripts/Software-Deployment/`

[![Mode](https://img.shields.io/badge/Mode-CLI-334155?style=for-the-badge)](#-core-features)
[![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-5391FE?style=for-the-badge&logo=powershell&logoColor=white)](https://learn.microsoft.com/en-us/powershell/)
[![Platform](https://img.shields.io/badge/Platform-Windows%2010%2F11-0F172A?style=for-the-badge)](#%EF%B8%8F-requirements)
[![License](https://img.shields.io/badge/License-MIT-F59E0B?style=for-the-badge)](#-license)
[![Version](https://img.shields.io/badge/Version-2.1.0-334155?style=for-the-badge)](#-overview)

[Overview](#-overview) | [Features](#-core-features) | [Tools](#-tools) | [Usage](#-usage) | [Requirements](#%EF%B8%8F-requirements) | [License](#-license)

</div>

---

# 📖 Overview

**Software-Deployment** contains **3 PowerShell CLI tools** for Software Deployment - Store apps and font management.

**Category:** `Software-Deployment`
**Path:** `Software-Deployment/`

> **Structure:** `Windows-Scripts/Software-Deployment/<ScriptName>/<ScriptName>.ps1 + README.md` - each tool is isolated with its own README.

---

# ✨ Core Features

* **3 Isolated Tools** - each in `Software-Deployment/ScriptName/` with `README.md`
* **Verb-Noun PascalCase** - no spaces, no typos, no double extensions
* **CLI-First** - pure PowerShell 5.1, no GUI dependencies
* **Canonical logging** - `Initialize-Log` / `Write-Banner` / `Write-Log` / `Finish-Script`
* **Intune-Ready** - exit codes 0/1/2, SYSTEM context support

---

# 🧰 Tools (3)

| Tool | Script | Path |
|------|--------|------|
| Get-StoreAppInventory | Get-StoreAppInventory.ps1 | [Get-StoreAppInventory](./Get-StoreAppInventory/) |
| Install-Fonts | Install-Fonts.ps1 | [Install-Fonts](./Install-Fonts/) |
| Uninstall-Fonts | Uninstall-Fonts.ps1 | [Uninstall-Fonts](./Uninstall-Fonts/) |

---

# 📂 Project Structure

```text
Software-Deployment/
├── Get-StoreAppInventory/
│   ├── Get-StoreAppInventory.ps1
│   └── README.md
├── Install-Fonts/
│   ├── Install-Fonts.ps1
│   └── README.md
├── Uninstall-Fonts/
│   ├── Uninstall-Fonts.ps1
│   └── README.md
```

---

# 🚀 Usage

```powershell
# Run any tool in this category
.\Software-Deployment\Get-StoreAppInventory\Get-StoreAppInventory.ps1
.\Software-Deployment\Get-StoreAppInventory\Get-StoreAppInventory.ps1 -WhatIf

# Help
Get-Help .\Software-Deployment\Get-StoreAppInventory\Get-StoreAppInventory.ps1 -Full
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