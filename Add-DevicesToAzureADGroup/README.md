
# Add Devices to Azure AD Group using PowerShell

![License](https://img.shields.io/badge/license-MIT-blue.svg)
![PowerShell](https://img.shields.io/badge/powershell-5.1%2B-blue.svg)
![Version](https://img.shields.io/badge/version-1.0-green.svg)


## Overview

This PowerShell script automates the process of **bulk adding devices** to an **Azure AD group** using their **device names**. Since Azure AD’s bulk import feature requires **Device Object IDs instead of Device Names**, this script **retrieves the device IDs dynamically** and adds them to the specified group.

### Features

- **Bulk Add Devices**: Processes a CSV file containing device names and adds them to an Azure AD group.
- **Automated Device Lookup**: Searches Azure AD for each device based on its name.
- **Handles Duplicate Names**: If multiple devices exist with the same name, all are added.
- **Error Handling**: Skips devices that cannot be found or already exist in the group.
- **Azure AD Authentication**: Ensures a valid Azure AD connection before running operations.

---

## Prerequisites

Before running the script, ensure you have:

1. **PowerShell 5.1+** installed.
2. **AzureAD PowerShell Module** installed:
   ```powershell
   Install-Module AzureAD -Scope CurrentUser
   ```
3. **Admin Permissions**: You must have the necessary permissions to read devices and modify Azure AD groups.
4. **Azure AD Application Permissions** (if running as a service):
   - `Group.ReadWrite.All`
   - `Device.Read.All`
   - `Directory.Read.All`
5. **A valid CSV file** containing device names.

---

## How to Run

### 1. Running the Script
Run the script with **group name** and **CSV file path** as parameters:
```powershell
.\Add-DevicesToAzureADGroup.ps1 -GroupName "Device Test Group" -InputFile "C:\Scripts\DevicesToAdd.csv"
```

### 2. CSV File Format
Ensure your CSV file follows this format:

```csv
DeviceName
Device-01
Device-02
Device-03
```

Each device name should match the exact name in Azure AD.

---

## Script Parameters

| Parameter   | Description |
|-------------|-------------|
| `-GroupName` | The **Azure AD group name** where devices will be added. |
| `-InputFile` | Path to the **CSV file** containing device names. |

---

## Output

The script provides real-time output, including:

- **Successfully added** devices.
- **Devices already in the group** (skipped).
- **Devices not found** in Azure AD.


---

## Notes

- The script **connects to Azure AD** automatically before execution.
- Ensure the device names in the CSV file **exactly match** those in Azure AD.
- Devices **already in the group** will be skipped.
- If **multiple devices share the same name**, all instances will be added.

---

## Reference

This script is sourced from Andrew IT Dev Lab's GitHub repository:
[**Add Devices to Group in Azure AD**](https://github.com/andrewitdevlab/blog-content/tree/main/Azure%20AD/Scripts/Add%20Devices%20to%20Group)

---

## License

This project is licensed under the [MIT License](https://opensource.org/licenses/MIT).

---

**Disclaimer**: This script is provided as-is. Ensure you test it in a non-production environment before using it on live systems.
