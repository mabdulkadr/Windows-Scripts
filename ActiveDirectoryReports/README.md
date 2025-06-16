# Active Directory Reports

![License](https://img.shields.io/badge/license-MIT-blue.svg)
![PowerShell](https://img.shields.io/badge/powershell-5.1%2B-blue.svg)
![Version](https://img.shields.io/badge/version-1.0-green.svg)

## Overview

This project provides a unified, modern, and responsive PowerShell script to generate **comprehensive HTML reports** for your Active Directory environment. All reports are saved in a timestamped and styled format, providing a clean overview of computer objects, domain controllers, workstations, servers, and more.

- **Modern HTML output:** Responsive, mobile-friendly, card-based reports with sticky headers.
- **Multiple built-in reports:** Generate detailed reports for computers, servers, workstations, domain controllers, and more.
- **Menu-driven interface:** Console menu (works in classic PowerShell and ISE).
- **No dependencies beyond RSAT/AD module.**

---

## Requirements

- Windows Server or Client with **PowerShell 5.1+**
- **RSAT tools** (Remote Server Administration Tools) with the **Active Directory PowerShell module** enabled.
- Run the script as a user with **read permissions on the AD** (Domain Admin recommended for full info).

---

## Features

- **Complete Computer Object Report:**  
  Get a full list of all computers in your AD with OS, IP, last logon, OU, and more.

- **Domain Controllers Report:**  
  Detailed information about all domain controllers, including site, OS, roles, last logon, and status.

- **Workstations Report:**  
  Focus on non-server Windows devices in your domain (desktops, laptops).

- **Servers Report:**  
  Detailed view of all Windows Server objects.

- **Computer Account Status Report:**  
  View enabled/disabled status, last logon, and password/account expiration.

- **OS-Based Report:**  
  Group computers by operating system, with device details under each.

---

## How to Use

1. **Download the script** (e.g., `ActiveDirectoryReports.ps1`) to your machine.
2. **Open PowerShell as Administrator.**
3. **Run the script:**
    ```powershell
    C:\ADReports\ActiveDirectoryReports.ps1
    ```
4. **Choose a report from the menu** (type its number), or select “Run ALL Reports”.

5. **After report generation,** you can open the HTML output from the menu prompt or browse to the `C:\ADReports` folder.

---

## Scripts Included

- **ActiveDirectoryReports.ps1**
  - Unified menu-driven script for all reporting features below.

---

## Script Details

### 1. Complete Computer Object Report

#### Purpose
Lists all computer objects in AD with their OS, IP, OU, creation date, last logon, password info, and more.

#### How to Run
Choose `1` from the main menu.

#### Output
- HTML report: `AD_CompleteComputerReport_<date>.html`

---

### 2. Domain Controllers Report

#### Purpose
Shows all domain controllers, their site, OS, GC/RODC roles, managed by, creation, and status.

#### How to Run
Choose `2` from the main menu.

#### Output
- HTML report: `AD_DomainControllersReport_<date>.html`

---

### 3. Workstations Report

#### Purpose
Shows all non-server computers (workstations/laptops), with extra details.

#### How to Run
Choose `3` from the main menu.

#### Output
- HTML report: `AD_WorkstationsReport_<date>.html`

---

### 4. Servers Report

#### Purpose
Shows all Windows Server-class computers with key AD attributes.

#### How to Run
Choose `4` from the main menu.

#### Output
- HTML report: `AD_ServersReport_<date>.html`

---

### 5. Computer Account Status Report

#### Purpose
Shows enabled/disabled status, last logon, password and account expiration for all computers.

#### How to Run
Choose `5` from the main menu.

#### Output
- HTML report: `AD_ComputerAccountStatusReport_<date>.html`

---

### 6. OS Based Reports

#### Purpose
Groups computers by their operating system, displaying details under each OS.

#### How to Run
Choose `6` from the main menu.

#### Output
- HTML report: `AD_OSBasedReport_<date>.html`

---

## Notes

- All reports are saved to: `C:\ADReports`
- Reports are timestamped, so multiple runs are preserved.
- Script works in both PowerShell ISE and classic PowerShell consoles.
- You can add your organization logo to the report by editing the `$CSS` and `Build-HtmlReport` section.

## License

This project is licensed under the [MIT License](https://opensource.org/licenses/MIT).

---

**Disclaimer:**  
These scripts are provided as-is. Test in a lab before production use. The author is not responsible for any unintended outcomes resulting from their use.

