<div align="center">

# 📦 Sysmon Config Pack

**Bundled Sysmon binaries and a community-curated baseline configuration for the Install-Sysmon script.**

Supports the parent Install-Sysmon tool by shipping the payload locally so deployment runs out of the box.

[![Tools](https://img.shields.io/badge/Tools-3%20Files-10B981?style=for-the-badge)](#-scripts-included)
[![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-5391FE?style=for-the-badge&logo=powershell&logoColor=white)](https://learn.microsoft.com/en-us/powershell/)
[![Platform](https://img.shields.io/badge/Platform-Windows%2010%2F11-0F172A?style=for-the-badge)](#%EF%B8%8F-requirements)
[![License](https://img.shields.io/badge/License-MIT-F59E0B?style=for-the-badge)](#-license)
[![Version](https://img.shields.io/badge/Version-1.0.0-334155?style=for-the-badge)](#-overview)

[Overview](#-overview) • [Features](#-core-features) • [Structure](#-project-structure) • [Scripts](#-scripts-included) • [License](#-license)

</div>

---

# 📖 Overview

**Sysmon Config Pack** bundles the Sysmon driver binaries and the SwiftOnSecurity sysmon-config.xml baseline used by the parent **Install-Sysmon** script. The files are intentionally tracked in the repository so the Install-Sysmon tool runs out of the box without a separate download step.

---

# ✨ Core Features

### 🔹 Sysmon Binaries
* `Sysmon.exe` / `Sysmon64.exe` — Sysmon driver binaries from the Mark Russinovich / SwiftOnSecurity fork.

### 🔹 Baseline Config
* `sysmonconfig.xml` — SwiftOnSecurity sysmon-config.xml community-curated baseline.

### 🔹 Dependency-First Delivery
* Payload shipped alongside the installer — no network dependency during deployment.

---

# 📂 Project Structure

```text
Config\
├── Sysmon.exe
├── Sysmon64.exe
├── sysmonconfig.xml
└── README.md
```

---

# 🚀 Scripts Included

## 🔎 Install-Sysmon (CLI)

**Consumer**
```powershell
Install-Sysmon.ps1
```

### Purpose
* Consumes the bundled binaries and configuration at `Config\`.
* Replaces the payload with a download-based approach by removing the binaries and adjusting `.gitignore`.

---

# ⚙️ Requirements

### Operating System
* Windows 10 / Windows 11 / Windows Server 2016+

### PowerShell
* PowerShell **5.1 or later**

### Permissions
* Administrator privileges to install the driver.

---

# 🛡 Operational Notes

* Do not deploy the Sysmon binary from this folder unless you trust the fork origin — verify hashes before production rollout.
* Swapping to a download-based payload requires updating the parent script and the `.gitignore` entries.
* The configuration file is a baseline: review events and tune `sysmonconfig.xml` for your environment.

---

## 👤 Author

**Mohammad Abdelkader Omar**  
GitHub: [@mabdulkadr](https://github.com/mabdulkadr)  
Website: [momar.tech](https://momar.tech)

---

## 📜 License
This project is licensed under the [MIT License](https://opensource.org/licenses/MIT).

---

## ⚠ Disclaimer

This skill and every script it generates are provided as-is with no warranty of any kind. Test generated tools in a staging environment before deploying to production. The authors assume no liability for any damage or data loss resulting from their use.

---

<div align="center">

⭐ **If this skill saves you time, star the repo — it helps others find it.**

[Report an Issue](../../issues) · [momar.tech](https://momar.tech)

[![Buy Me A Coffee](https://img.shields.io/badge/Buy%20Me%20A%20Coffee-FFDD00?style=for-the-badge&logo=buy-me-a-coffee&logoColor=black)](https://www.buymeacoffee.com/mabdulkadrx)

Built with [**PowerShell Enterprise Admin**](https://github.com/mabdulkadr/powershell-enterprise-admin-skill)

</div>