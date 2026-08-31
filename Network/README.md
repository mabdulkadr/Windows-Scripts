<div align="center">

# 📂 Network
$110 tools**

Part of **Windows-Scripts** enterprise toolkit — `Windows-Scripts/Network/`

[![Mode](https://img.shields.io/badge/Mode-CLI-334155?style=for-the-badge)](#-core-features)
[![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-5391FE?style=for-the-badge&logo=powershell&logoColor=white)](https://learn.microsoft.com/en-us/powershell/)
[![Platform](https://img.shields.io/badge/Platform-Windows%2010%2F11-0F172A?style=for-the-badge)](#%EF%B8%8F-requirements)
[![License](https://img.shields.io/badge/License-MIT-F59E0B?style=for-the-badge)](#-license)
[![Version](https://img.shields.io/badge/Version-2.1.0-334155?style=for-the-badge)](#-overview)

[Overview](#-overview) • [Features](#-core-features) • [Tools](#-tools) • [Usage](#-usage) • [Requirements](#%EF%B8%8F-requirements) • [License](#-license)

</div>

---

# 📖 Overview

**Network** contains **11 PowerShell CLI tools** for network — dns, firewall, tls, ports & connectivity.

**Category:** `Network`
**Path:** `Network/`

> **Structure:** `Windows-Scripts/Network/<ScriptName>/<ScriptName>.ps1 + README.md` — each tool is isolated with its own README.

---

# ✨ Core Features

* **9 Isolated Tools** — each in `Network/ScriptName/` with `README.md`
* **Verb-Noun PascalCase** — no spaces, no typos, no double extensions
* **CLI-First** — pure PowerShell 5.1, no GUI dependencies
* **Canonical logging** — `Initialize-Log` / `Write-Banner` / `Write-Log` / `Finish-Script`
* **Intune-Ready** — exit codes 0/1/2, SYSTEM context support

---

# 🧰 Tools (11)

| Tool | Script | Path |
|------|--------|------|
| Clear-DnsCache | Clear-DnsCache.ps1 | [Clear-DnsCache](./Clear-DnsCache/) |
| Disable-IPv6 | Disable-IPv6.ps1 | [Disable-IPv6](./Disable-IPv6/) |
| Disable-WindowsFirewall | Disable-WindowsFirewall.ps1 | [Disable-WindowsFirewall](./Disable-WindowsFirewall/) |
| Get-OpenPorts | Get-OpenPorts.ps1 | [Get-OpenPorts](./Get-OpenPorts/) |
| Get-TLSConfiguration | Get-TLSConfiguration.ps1 | [Get-TLSConfiguration](./Get-TLSConfiguration/) |
| Get-WiFiPassword | Get-WiFiPassword.ps1 | [Get-WiFiPassword](./Get-WiFiPassword/) |
| Reset-WindowsFirewall | Reset-WindowsFirewall.ps1 | [Reset-WindowsFirewall](./Reset-WindowsFirewall/) |
| Reset-Winsock | Reset-Winsock.ps1 | [Reset-Winsock](./Reset-Winsock/) |
| Resolve-DeviceIP | Resolve-DeviceIP.ps1 | [Resolve-DeviceIP](./Resolve-DeviceIP/) |
| Test-InternetConnectivity | Test-InternetConnectivity.ps1 | [Test-InternetConnectivity](./Test-InternetConnectivity/) |
| Test-NetworkLatency | Test-NetworkLatency.ps1 | [Test-NetworkLatency](./Test-NetworkLatency/) |

---

# 📂 Project Structure

```text
Network/
├── Clear-DnsCache/
│   ├── Clear-DnsCache.ps1
│   └── README.md
├── Disable-IPv6/
│   ├── Disable-IPv6.ps1
│   └── README.md
└── ... (7 more)
```

---

# 🚀 Usage

```powershell
# Run any tool in this category
.\Network\Clear-DnsCache\Clear-DnsCache.ps1
.\Network\Clear-DnsCache\Clear-DnsCache.ps1 -WhatIf

# Help
Get-Help .\Network\Clear-DnsCache\Clear-DnsCache.ps1 -Full
```

---

# ⚙️ Requirements

* **OS:** Windows 10/11/Server 2019+
* **PowerShell:** 5.1 or later (`#Requires -Version 5.1`)
* **Permissions:** See per-tool README for specific requirements
* **Modules:** None — uses built-in cmdlets only (AD tools require `ActiveDirectory` module)

---

# 🛡 Operational Notes

* Always test with `-WhatIf` first in a staging environment before production rollout.
* Elevation is detected at runtime via `Test-IsElevated`; the script logs a warning and degrades gracefully when not elevated.
* Each per-tool result is returned as a structured `PSCustomObject` with `Target / Success / Skipped / Error` fields, aggregated in MAIN.
* Log files are written to `C:\ProgramData\WindowsScripts\Logs\<yyyyMMdd>.log` (TSV-like `[time] [Level] message` lines).
* Re-running any tool is **idempotent** — it produces the same end state.

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







