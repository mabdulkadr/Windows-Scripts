# Shadow Group 

![License](https://img.shields.io/badge/license-MIT-blue.svg)
![PowerShell](https://img.shields.io/badge/powershell-5.1%2B-blue.svg)
![Version](https://img.shields.io/badge/version-3.0-green.svg)

## Overview
**ShadowGroup.ps1** is a PowerShell script designed to ensure that a specific Active Directory (AD) group (Shadow Group) contains all users from one or more Organizational Units (OUs). It also removes users who no longer belong to the specified OUs, ensuring accurate membership management.

This script is useful for enforcing group-based policies, such as Fine-Grained Password Policies (FGPP), and maintaining accurate group membership without manual intervention.

---

## Features
- Synchronizes an AD group with users from multiple OUs.
- Supports **enabled users only** (optional filter).
- Includes/excludes **child OUs** based on configuration.
- Performs **dry-run mode** (logs actions without modifying AD if enabled).
- Generates detailed **logs** for tracking changes.
- Limits bulk modifications per execution to prevent excessive AD operations.
- Can be scheduled as a **Windows Task** to automate execution from a Domain Controller.

---

## Prerequisites
- **PowerShell 5.1+**
- **Active Directory Module for Windows PowerShell**
- **Domain Controller (DC) with Active Directory Web Services (ADWS)**
- Proper permissions to manage group membership in AD

---

## Configuration
All script parameters are defined in the **PARAMETERS** section at the beginning of the script:

- **$Server** → Domain Controller handling AD queries.
- **$LogFile** → Path for storing execution logs.
- **$Update** → Enable or disable actual modifications (`$true` applies changes, `$false` logs only).
- **$EnabledOnly** → Include only enabled users in the shadow group.
- **$OUDNs** → Array of OUs to monitor.
- **$ChildOUs** → Whether to include child OUs.
- **$GroupDN** → Distinguished Name (DN) of the shadow group.
- **$MaxChanges** → Limits maximum users added/removed per execution.

---

## How to Run
### 1. Test Run (No Changes Applied)
```powershell
.\ShadowGroup.ps1
```
This will **log actions** without modifying group membership.

### 2. Apply Changes
To enable modifications, ensure `$Update = $true` in the script, then run:
```powershell
.\ShadowGroup.ps1
```

### 3. Run with Elevated Privileges
Make sure to run PowerShell as **Administrator** for proper execution.

---

## Automating with a Scheduled Task
To run the script automatically on a **Domain Controller**, create a scheduled task:

### Step 1: Open Task Scheduler
1. Open **Task Scheduler** (`taskschd.msc`).
2. Click **Create Basic Task**.

### Step 2: Define the Task
1. Name: **Shadow Group Sync**
2. Description: **Ensures shadow group is synchronized with AD OUs.**
3. Click **Next**.

### Step 3: Set Trigger
1. Choose **Daily** or **Hourly** based on your preference.
2. Click **Next** and set the desired schedule.

### Step 4: Set Action
1. Select **Start a Program**.
2. Program/script: `powershell.exe`
3. Add arguments:
   ```powershell
   -ExecutionPolicy Bypass -File "C:\Path\To\ShadowGroup.ps1"
   ```
4. Click **Next**.

### Step 5: Set Security Options
1. Check **Run whether user is logged on or not**.
2. Select **Run with highest privileges**.
3. Click **Finish** and enter domain admin credentials when prompted.

Now, the script will run automatically based on the schedule you set.

---

## Logging
Execution logs are stored in the specified log file (default: `C:\ShadowGroups\ShadowGroup.log`). Logs include:
- Users added/removed.
- Timestamp of execution.
- Any encountered errors or warnings.

---

## Example Output
```plaintext
--- Script Execution Start: 2025-02-02 14:00:00 ---
Users Removed: 12
Users Added: 25
--- Script Execution End: 2025-02-02 14:01:00 ---
```

---

## Notes
- If the shadow group does not exist, the script will **exit with an error**.
- The script ensures **group membership consistency** with AD OUs.
- If `$MaxChanges` is exceeded, the script will **require multiple runs** to complete synchronization.

---

## License 
This project is licensed under the [MIT License](https://opensource.org/licenses/MIT).

---

**Disclaimer**: This script is provided as-is. Test in a staging environment before deploying in production. The author is not responsible for any unintended consequences.
