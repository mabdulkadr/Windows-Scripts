<div align="center">

# 🛠️ Windows-Scripts

**Enterprise Windows Administration Toolkit — 70 Tools in 9 Categories**

Modern PowerShell toolkit for Helpdesk & SysAdmins — System, Endpoint, GroupPolicy, Network, Identity, Reporting, Security, Deployment, Utilities.

[![Mode](https://img.shields.io/badge/Mode-CLI%20Tools-334155?style=for-the-badge)](#-usage)
[![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-5391FE?style=for-the-badge&logo=powershell&logoColor=white)](https://learn.microsoft.com/en-us/powershell/)
[![Platform](https://img.shields.io/badge/Platform-Windows%2010%2F11-0F172A?style=for-the-badge)](#%EF%B8%8F-requirements)
[![License](https://img.shields.io/badge/License-MIT-F59E0B?style=for-the-badge)](#-license)
[![Version](https://img.shields.io/badge/Version-2.1.0-334155?style=for-the-badge)](#-overview)
[![Scripts](https://img.shields.io/badge/Scripts-70-10B981?style=for-the-badge)](#-project-structure)

[Overview](#-overview) • [Features](#-core-features) • [Structure](#-project-structure) • [Usage](#-usage) • [Requirements](#%EF%B8%8F-requirements) • [License](#-license)

</div>

---

# 📖 Overview

**Windows-Scripts** is a production-grade Windows administration toolkit with **70 PowerShell tools** organized into **9 categories** — each script lives in **its own folder with a dedicated README.md** for isolated documentation and deployment.

> **v2.1 Structure:** `Windows-Scripts/<Category>/<ScriptName>/<ScriptName>.ps1 + README.md` — no numeric prefixes, no spaces, per-script isolation.

Built for **Helpdesk, Endpoint Management, and IT Operations** managing Intune / SCCM / Active Directory / M365 fleets.

---

# ✨ Core Features

* **9 Categories** — System-Maintenance (19), Endpoint-Management (8), GroupPolicy (6), Network (8), Identity-Access (4), Reporting-Inventory (10), Security-Compliance (7), Software-Deployment (3), Utilities-Tools (5)
* **70 Isolated Tools** — each in `Category/ScriptName/` with `README.md`
* **Verb-Noun PascalCase** — no spaces, no typos, no double extensions
* **CLI-First** — pure PowerShell 5.1, no GUI dependencies, STA not required
* **Intune-Ready** — exit codes 0/1/2, SYSTEM context support

---

# 📂 Project Structure

```text
Windows-Scripts/
│
├── README.md
├── LICENSE
│
├── System-Maintenance/            # 19 tools
│   ├── Clear-PrintQueue/
│   ├── Clear-TempCache/
│   ├── Disable-FastStartup/
│   ├── Enable-FastStartup/
│   ├── Enable-SystemRestore/
│   ├── Get-USBDeviceHistory/
│   ├── Invoke-PCMaintenance/
│   ├── Invoke-SystemCleanup/
│   ├── Invoke-WindowsUpdate/
│   ├── Optimize-WindowsSettings/
│   ├── Remove-WindowsBloatware/
│   ├── Repair-TimeService/
│   ├── Repair-WindowsImage/
│   ├── Repair-WindowsStore/
│   ├── Repair-WindowsUpdate/
│   ├── Reset-NetworkStack/
│   ├── Reset-PrintSpooler/
│   ├── Restart-Explorer/
│   └── Watch-DiskSpace/
│
├── Endpoint-Management/            # 8 tools
│   ├── Get-EnrollmentStatus/
│   ├── Get-IntuneDeviceDiagnostics/
│   ├── Invoke-IntuneReenrollment/
│   ├── Invoke-SCCMActions/
│   ├── Invoke-Win32AppReinstall/
│   ├── Repair-IntuneManagementExtension/
│   ├── Restart-ConfigMgrService/
│   └── Restart-IntuneService/
│
├── GroupPolicy/                    # 6 tools
│   ├── Backup-LocalGPO/
│   ├── Export-GPResult/
│   ├── Get-AppliedGPO/
│   ├── Invoke-RegistryPolicyAudit/
│   ├── Reset-LocalGPO/
│   └── Restore-LocalGPO/
│
├── Network/                        # 8 tools
│   ├── Clear-DnsCache/
│   ├── Disable-IPv6/
│   ├── Disable-WindowsFirewall/
│   ├── Get-OpenPorts/
│   ├── Get-TLSConfiguration/
│   ├── Reset-WindowsFirewall/
│   ├── Reset-Winsock/
│   └── Test-NetworkLatency/
│
├── Identity-Access/                # 4 tools
│   ├── Disable-InactiveComputers/
│   ├── New-LocalUserBulk/
│   ├── Repair-DomainTrust/
│   └── Repair-DomainTrustStandalone/
│
├── Reporting-Inventory/            # 10 tools
│   ├── Export-InstalledApplications/
│   ├── Get-BatteryHealth/
│   ├── Get-BrowserExtensionInventory/
│   ├── Get-CertificateHealthReport/
│   ├── Get-CertificateSummary/
│   ├── Get-ComplianceReport/
│   ├── Get-LocalUsersAndGroups/
│   ├── Get-PatchComplianceReport/
│   ├── Get-StartupTasks/
│   └── Get-SystemInventory/
│
├── Security-Compliance/            # 7 tools
│   ├── Enable-BitLocker/
│   ├── Get-BitLockerStatus/
│   ├── Get-DefenderHealth/
│   ├── Get-LAPSStatus/
│   ├── Install-Sysmon/  (+ Config/sysmonconfig.xml)
│   ├── Remove-RevokedRootCertificate/
│   └── Test-SecureBoot/
│
├── Software-Deployment/            # 3 tools
│   ├── Get-StoreAppInventory/
│   ├── Install-Fonts/
│   └── Uninstall-Fonts/
│
└── Utilities-Tools/                # 5 tools
    ├── Find-LargeFiles/
    ├── Get-LocalAdminReport/
    ├── Get-ScheduledTaskReport/
    ├── Invoke-RemoteCommand/
    └── Invoke-RunAsAdmin/
```

**Rule:** every script folder contains **exactly** `<ScriptName>.ps1` + `README.md` (+ bundled assets where needed). No loose files at category level.

---

# 🚀 Usage

### Run a single tool

```powershell
# System
.\System-Maintenance\Repair-WindowsImage\Repair-WindowsImage.ps1

# Network
.\Network\Clear-DnsCache\Clear-DnsCache.ps1
.\Network\Test-NetworkLatency\Test-NetworkLatency.ps1 -Target "8.8.8.8"

# Identity
.\Identity-Access\New-LocalUserBulk\New-LocalUserBulk.ps1 -CsvPath ".\users.csv" -WhatIf

# Endpoint
.\Endpoint-Management\Invoke-SCCMActions\Invoke-SCCMActions.ps1
```

### Help per script

```powershell
Get-Help .\System-Maintenance\Clear-TempCache\Clear-TempCache.ps1 -Full
Get-Content .\Network\Clear-DnsCache\README.md
```

---

# ⚙️ Requirements

- **OS:** Windows 10 21H2+ / Windows 11 22H2–24H2 / Server 2019+
- **PowerShell:** 5.1+ (7.4+ recommended)
- **Permissions:** Standard user for inventory/reporting; Administrator for system/GPO/firewall/deployment
- **Modules:** `ActiveDirectory` (AD tools), `Microsoft.Graph` (M365 report) — see per-script README

---

# 🛡 Operational Notes

- Test with `-WhatIf` in staging OU before production.
- Per-script README documents parameters, exit codes, and bundled assets.
- Sysmon deployment requires reboot to activate driver.

---

## 👤 Author
**Mohammad Abdelkader Omar**  
GitHub: [@mabdulkadr](https://github.com/mabdulkadr)  
Website: [momar.tech](https://momar.tech)
## 📜 License

This project is licensed under the [MIT License](https://opensource.org/licenses/MIT).

---

## ⚠ Disclaimer

This toolkit and every script it contains are provided as-is with no warranty of any kind. Test generated tools in a staging environment before deploying to production. The authors assume no liability for any damage or data loss resulting from their use.

---
<div align="center">

⭐ **If this toolkit saves you time, star the repo — it helps others find it.**

[Report an Issue](../../issues) · [momar.tech](https://momar.tech)

[![Buy Me A Coffee](https://img.shields.io/badge/Buy%20Me%20A%20Coffee-FFDD00?style=for-the-badge&logo=buy-me-a-coffee&logoColor=black)](https://www.buymeacoffee.com/mabdulkadrx)

Built with [**PowerShell Enterprise Admin**](https://github.com/mabdulkadr/powershell-enterprise-admin-skill)

</div>




