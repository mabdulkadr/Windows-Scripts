
# Devices Inactive Cleanup Tool (WPF GUI)

![License](https://img.shields.io/badge/license-MIT-blue.svg)
![PowerShell](https://img.shields.io/badge/powershell-5.1%2B-blue.svg)
![Version](https://img.shields.io/badge/version-1.0-green.svg)

## Overview
**Devices Inactive Cleanup Tool** is a **WPF-based PowerShell GUI tool** designed for **Active Directory administrators** to efficiently **identify, manage, and clean up inactive computers** in AD.  

This tool enables admins to:
- **Search** for computers that have been inactive for a specified number of days.
- **Export results** to a **CSV file** (with `ComputerName`, `LastLogonDate`, `InactiveDays`, `DistinguishedName`).
- **Disable selected computers** in bulk.
- **Delete selected computers** from AD.
- **Run asynchronously** using background jobs to keep the GUI responsive.

## Features
✅ **Graphical User Interface (GUI)** – Built with WPF for ease of use.  
✅ **Find inactive devices** by specifying inactivity days and an Organizational Unit (OU).  
✅ **Bulk Actions** – Disable or delete multiple devices at once.  
✅ **CSV Export** – Saves selected fields (`ComputerName`, `LastLogonDate`, `InactiveDays`, `DistinguishedName`).  
✅ **Runs in Background** – Uses PowerShell jobs to avoid UI freezing.  
✅ **Error Handling** – Displays warnings if a connection or query fails.  

---

## Prerequisites
Before running this script, ensure:
- **PowerShell 5.1+** is installed.
- **RSAT (Remote Server Administration Tools) – Active Directory Module** is installed.
- The **user has necessary permissions** to manage AD computers.
- The **PC has network access** to the Domain Controller (DC).

📌 **To check if RSAT is installed, run:**
```powershell
Get-Module -ListAvailable ActiveDirectory
```
📌 **If missing, install RSAT (for Windows 10/11):**
```powershell
Add-WindowsFeature -Name "RSAT-AD-PowerShell"
```

---

## Installation
1. **Download the script** from [GitHub](https://github.com/mabdulkadr/DevicesInactiveCleanup).
2. **Run PowerShell as Administrator**.
3. **Ensure execution policy allows scripts**:
   ```powershell
   Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
   ```
4. **Execute the script**:
   ```powershell
   .\DevicesInactiveCleanup.ps1
   ```

---

## How to Use
### **1️⃣ Search for Inactive Computers**
- Enter the **number of days inactive**.
- Specify the **Active Directory OU** (or use the default).
- Click **"Search"** to begin.

### **2️⃣ Perform Actions**
- **Disable**: Select computers and click **"Disable Selected"**.
- **Delete**: Select computers and click **"Delete Selected"**.

### **3️⃣ Export Results to CSV**
- Click **"Generate CSV Report"**.
- Select a location to save the file.

### **4️⃣ Exit the Tool**
- Click **"Exit"** to close the application.

---

## Troubleshooting
### ❌ **Error: "The operation returned because the timeout limit was exceeded."**
✅ **Cause:** Your PC cannot connect to the domain controller (DC).  
**Fix:**  
- Ensure your PC is on the **same network** as the DC.
- Test AD connectivity:
  ```powershell
  Test-NetConnection -ComputerName "YourDC.domain.local" -Port 389
  ```
- Manually set your **DNS server** to point to the **DC's IP**:
  ```powershell
  Set-DnsClientServerAddress -InterfaceIndex 2 -ServerAddresses ("192.168.1.10")
  ```
---

### ❌ **Error: "WARNING: Error initializing default drive"**
✅ **Cause:** The Active Directory module is missing or not loading correctly.  
**Fix:**
- Check if the module is installed:
  ```powershell
  Get-Module -ListAvailable ActiveDirectory
  ```
- Install RSAT (for Windows 10/11):
  ```powershell
  Get-WindowsCapability -Name RSAT* -Online | Where-Object Name -like "RSAT:ActiveDirectory*" | Add-WindowsCapability -Online
  ```

---

## Notes
- Ensure you have **domain admin** or equivalent permissions.
- Always **test changes** before applying them in production.
- If running from a **non-DC machine**, verify **network connectivity** and **RSAT installation**.

---

## License 
This project is licensed under the [MIT License](https://opensource.org/licenses/MIT).

---

**Disclaimer**: This script is provided **as-is**. Test in a **staging environment** before deploying in production. The author is **not responsible** for any unintended consequences.


