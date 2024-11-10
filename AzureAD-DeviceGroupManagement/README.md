
# Azure AD Static Device Group Management Script
![License](https://img.shields.io/badge/license-MIT-blue.svg)
![PowerShell](https://img.shields.io/badge/powershell-5.1%2B-blue.svg)
![Version](https://img.shields.io/badge/version-1.0.0-green.svg)

## Overview

The **Azure AD Static Device Group Management** PowerShell script automates the creation and management of static Azure Active Directory (Azure AD) groups by integrating with Microsoft Intune and Microsoft Graph. This ensures efficient organization of Windows devices within Azure AD, adhering to membership limits and facilitating streamlined device management.

## Features

- **Automated Group Management**: Identifies existing static groups with a specified prefix and creates new groups as needed to accommodate all devices.
- **Device Assignment**: Retrieves Windows devices from Intune and assigns them to appropriate Azure AD groups without exceeding the defined member limit per group.
- **Batch Processing**: Handles large numbers of devices by processing them in configurable batches.
- **Logging**: Optionally logs all operations to a specified file for auditing and troubleshooting.
- **Modular Integration**: Utilizes Microsoft Graph and Azure AD modules for seamless integration and management.

## Prerequisites

- **PowerShell 5.1** or later (recommended PowerShell 7+)
- **AzureAD Module**: Ensure the `AzureAD` PowerShell module is installed.
- **Microsoft Graph Modules**: The script will automatically install the required Microsoft Graph modules if they are not already present on the system.
- **Permissions**: 
  - Administrative access to Azure AD.
  - Permissions to create and manage groups and group memberships.
- **Intune Access**: Access to Microsoft Intune to retrieve device information.


## Usage

### Running the Script

Execute the script using PowerShell:

```powershell
.\AzureAD-DeviceGroupManagement.ps1
```

### Parameters

The script accepts the following parameters to customize its behavior:

- `-BatchSize` *(int)*: Specifies the maximum number of devices per group. Default is `500`.

  ```powershell
  -BatchSize 300
  ```

- `-GroupNamePrefix` *(string)*: Defines the prefix for the Azure AD group names. Default is `"Devices-group"`.

  ```powershell
  -GroupNamePrefix "CorporateDevices-"
  ```

- `-NamePadding` *(int)*: Determines the number of digits in the group numbering. Default is `2` (e.g., `01`, `02`, etc.).

  ```powershell
  -NamePadding 3
  ```

- `-EnableLogging` *(switch)*: Enables logging of script operations to a file.

  ```powershell
  -EnableLogging
  ```

- `-LogFilePath` *(string)*: Specifies the path to the log file. Default is `"C:\CreateStaticGroup\GroupCreationLog.txt"`.

  ```powershell
  -LogFilePath "D:\Logs\AzureADGroupManagement.log"
  ```

### Example

```powershell
.\AzureAD-DeviceGroupManagement.ps1 -BatchSize 300 -GroupNamePrefix "CorporateDevices-" -NamePadding 3 -EnableLogging -LogFilePath "D:\Logs\AzureADGroupManagement.log"
```

This command will:

- Create groups with the prefix `CorporateDevices-` (e.g., `CorporateDevices-001`, `CorporateDevices-002`, etc.).
- Assign up to `300` devices per group.
- Use `3` digits for group numbering.
- Enable logging and save logs to `D:\Logs\AzureADGroupManagement.log`.

## Logging

When the `-EnableLogging` switch is used, the script logs all operations, including successes, warnings, and errors, to the specified log file. This is useful for auditing purposes and troubleshooting any issues that arise during execution.

**Log File Structure:**

```
[2024-11-10 14:23:45] [INFO] Retrieving all Windows PC devices from Microsoft Graph...
[2024-11-10 14:23:50] [SUCCESS] Total devices retrieved: 1500
[2024-11-10 14:23:50] [INFO] Retrieving existing groups with prefix 'Devices-group'...
[2024-11-10 14:23:55] [INFO] Next group number to create: 3
...
```

## Notes

- **Permissions**: Ensure the script is executed with appropriate permissions to access Microsoft Graph and Azure AD. This typically requires administrative privileges.
- **Static Groups**: This script manages static group memberships exclusively and does not handle dynamic group rules or memberships.
- **Security**: Store the App Secret and other sensitive information securely. Avoid hardcoding sensitive data directly within scripts.
- **Modules**: The script automatically installs required Microsoft Graph modules if they are not already present on the system.
- **Error Handling**: The script includes robust error handling to capture and log issues during execution, such as failures in group creation or device assignment.
- **Module Installation**: If the required Microsoft Graph modules are not present, the script will attempt to install them automatically. Ensure that the executing user has the necessary permissions to install PowerShell modules.


## License

This project is licensed under the [MIT License](LICENSE).


---

**Disclaimer**: Use these scripts at your own risk. Ensure you understand their impact before running them in a production environment. Always review and test scripts thoroughly.
