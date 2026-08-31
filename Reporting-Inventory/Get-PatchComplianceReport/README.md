<div align="center">

# 💻 Get-PatchComplianceReport

**Generate Windows patch compliance CSV**

Mode-CLI Windows-Scripts toolkit for endpoint management, helpdesk, and IT operations.

[![Mode](https://img.shields.io/badge/Mode-CLI-334155?style=for-the-badge)](#-usage)
[![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-5391FE?style=for-the-badge&logo=powershell&logoColor=white)](https://learn.microsoft.com/en-us/powershell/)
[![Platform](https://img.shields.io/badge/Platform-Windows%2010%2F11-0F172A?style=for-the-badge)](#%EF%B8%8F-requirements)
[![License](https://img.shields.io/badge/License-MIT-F59E0B?style=for-the-badge)](#-license)
[![Version](https://img.shields.io/badge/Version-2.1.0-334155?style=for-the-badge)](#-overview)

[Overview](#-overview) • [Features](#-core-features) • [Usage](#-usage) • [Parameters](#%EF%B8%8F-parameters) • [Requirements](#%EF%B8%8F-requirements) • [License](#-license)

</div>

---

# 📖 Overview

**Get-PatchComplianceReport** is a PowerShell CLI tool in the **Reporting-Inventory** category of the **Windows-Scripts** enterprise toolkit. Exports Get-HotFix results sorted by InstalledOn to Reports/PatchCompliance_<ts>.csv.

**Category:** `Reporting-Inventory`
**Script:** `Get-PatchComplianceReport.ps1`
**Path:** `Reporting-Inventory\Get-PatchComplianceReport\Get-PatchComplianceReport.ps1`

---

# ✨ Features

* Generate Windows patch compliance CSV
* **Canonical logging** — dot-sources `scripts/Write-Log.ps1` (single source of truth: `Initialize-Log`, `Write-Banner`, `Write-Log`, `Finish-Script`)
* **Graceful elevation** — detects privilege level at runtime via `Test-IsElevated` and degrades with a WARNING log instead of hard-failing
* **Structured per-target results** — every action returns a `PSCustomObject` with `Target / Success / Skipped / Error` fields so MAIN can aggregate with `Measure-Object`
* **Supports `-WhatIf`** via `[CmdletBinding(SupportsShouldProcess = True)]`
* **Canonical exit codes** — `0 = success / 1 = failure / 2 = script error` (Intune-compliant)
* **Per-script README** documenting parameters, exit codes, and operational notes

---

# 📂 Project Structure

```text
Reporting-Inventory/
└── Get-PatchComplianceReport/
    ├── Get-PatchComplianceReport.ps1
    └── README.md
```

---

# 🚀 Usage

### Basic

```powershell
.\Get-PatchComplianceReport.ps1
```

### Help

```powershell
Get-Help .\Get-PatchComplianceReport.ps1 -Full
Get-Help .\Get-PatchComplianceReport.ps1 -Examples
```

### Dry Run

```powershell
.\Get-PatchComplianceReport.ps1 -WhatIf
```



---

# ⚙️ Parameters

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| — | — | — | — | Run `Get-Help .\Get-PatchComplianceReport.ps1 -Full` for parameter documentation |

### Exit Codes

| Code | Meaning |
|------|---------|
| 0 | Success — all targets completed |
| 1 | Failure — one or more targets failed |
| 2 | Script error — exception in MAIN |

---

# ⚙️ Requirements

* **OS:** Windows 10/11/Server 2019+
* **PowerShell:** 5.1 or later (`#Requires -Version 5.1`)
* **Permissions:** Standard user
* **Modules:** None — uses built-in cmdlets only
* **Logging:** Dot-sources `scripts/Write-Log.ps1` (5 levels: DEBUG / INFO / SUCCESS / WARNING / ERROR)

---

# 🛡 Operational Notes

* Always test with `-WhatIf` first in a staging environment before production rollout.
* Elevation is detected at runtime via `Test-IsElevated`; the script logs a warning and degrades gracefully when not elevated.
* Each per-target result is returned as a structured `PSCustomObject` with `Target / Success / Skipped / Error` fields, aggregated in MAIN.
* Log files are written to `C:\ProgramData\WindowsScripts\Logs\<yyyyMMdd>.log` (TSV-like `[time] [Level] message` lines).
* Re-running the script is **idempotent** — it produces the same end state.

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

⭐ **If this toolkit saves you time, star the repo — it helps others find it.**

[Report an Issue](../../issues) · [momar.tech](https://momar.tech)

[![Buy Me A Coffee](https://img.shields.io/badge/Buy%20Me%20A%20Coffee-FFDD00?style=for-the-badge&logo=buy-me-a-coffee&logoColor=black)](https://www.buymeacoffee.com/mabdulkadrx)

Built with [**PowerShell Enterprise Admin**](https://github.com/mabdulkadr/powershell-enterprise-admin-skill)

</div>

