# Update WMI Quota Configuration Script

![License](https://img.shields.io/badge/license-MIT-blue.svg)
![PowerShell](https://img.shields.io/badge/powershell-5.1%2B-blue.svg)
![Version](https://img.shields.io/badge/version-1.0.0-green.svg)

## Overview
This PowerShell script is designed to modify the WMI (Windows Management Instrumentation) Provider Host Quota Configuration settings. It increases memory and handle limits to improve system performance and prevent issues related to quota exhaustion, as outlined in the [Microsoft Tech Community blog](https://techcommunity.microsoft.com/blog/askperf/wmi-how-to-troubleshoot-wmi-high-handle-count/375500).

## Features
- Sets WMI `MemoryPerHost` to **1 GB** (1073741824 bytes).
- Configures WMI `HandlesPerHost` to **8192**, if supported by the system.
- Displays current settings before and after applying changes.
- Includes robust error handling and detailed output for easy troubleshooting.

## Prerequisites
1. **Administrative Privileges**: Run the script with elevated permissions.
2. **PowerShell Environment**: Ensure PowerShell 5.1 or later is installed.
3. **Supported Properties**: Verify that the target system supports the `MemoryPerHost` and `HandlesPerHost` properties.

## Script Details
The script interacts with the `__ProviderHostQuotaConfiguration` class in the `root` WMI namespace. It adjusts the following properties:
- **MemoryPerHost**: The maximum memory allocated per host.
- **HandlesPerHost**: The maximum number of handles allowed per host (if available).

Other properties such as `MemoryAllHosts` and `ProcessLimitAllHosts` remain unchanged unless explicitly modified in the script.

## How to Use
### Step 1: Download the Script
Save the script as `UpdateWMIQuotaEnhanced.ps1`.

### Step 2: Execute the Script
1. Open PowerShell with administrative privileges.
2. Navigate to the directory containing the script.
3. Run the script:
   ```powershell
   .\UpdateWMIQuotaEnhanced.ps1
   ```

### Step 3: Verify the Changes
To confirm the updated settings, run the following command:
```powershell
Get-WmiObject -Namespace "root" -Class "__ProviderHostQuotaConfiguration" | Select-Object MemoryPerHost, MemoryAllHosts, ProcessLimitAllHosts
```

Alternatively, use the **WBEMTest** tool to inspect the `__ProviderHostQuotaConfiguration` class.

## Script Output
- **Before Update**: Displays the current WMI quota settings.
- **After Update**: Shows the updated settings.
- **Error Messages**: Provides detailed information if any errors occur during execution.

## References
For more details on troubleshooting WMI high handle count issues, refer to the [Microsoft Tech Community blog](https://techcommunity.microsoft.com/blog/askperf/wmi-how-to-troubleshoot-wmi-high-handle-count/375500).

---

## License

This project is licensed under the [MIT License](https://opensource.org/licenses/MIT).

---

**Disclaimer**: These scripts are provided as-is. Test them in a staging environment before use in production. The author is not responsible for any unintended outcomes resulting from their use.

