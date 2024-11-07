
# Azure AD Static Device Group Management Script
![License](https://img.shields.io/badge/license-MIT-blue.svg)
![PowerShell](https://img.shields.io/badge/powershell-5.1%2B-blue.svg)
![Version](https://img.shields.io/badge/version-1.0.0-green.svg)

## Overview

The **Azure AD Static Device Group Management Script** is a PowerShell tool designed to automate the creation and management of static Azure Active Directory (Azure AD) groups. It integrates seamlessly with Microsoft Intune to retrieve Windows devices, distribute them across Azure AD groups, and handle dynamic changes such as device additions or deletions. This ensures efficient group management without exceeding predefined member limits.

## Features

- **Automated Microsoft Graph Connection**: Automatically connects to Microsoft Graph using app-based authentication with specified `TenantID`, `AppID`, and `AppSecret`.
- **Manual Azure AD Connection**: Allows users to manually connect to Azure AD using user-based authentication.
- **Automated Group Creation**: Automatically creates static Azure AD groups with a specified prefix and numbering.
- **Device Assignment**: Distributes devices across existing groups with fewer than 500 members or creates new groups as needed.
- **Static Group Management**: Manages static groups, ensuring that groups do not exceed the maximum member limit.
- **Logging**: Provides detailed logs with timestamps and message types for monitoring and troubleshooting.
- **User-Friendly**: Simple setup and execution with customizable parameters.
- **Error Handling**: Robust error handling to ensure smooth execution and clear feedback on issues.

## Prerequisites

Before using the script, ensure the following prerequisites are met:

- **PowerShell Version**: PowerShell 5.1 or higher.
- **Modules**:
  - [AzureAD](https://www.powershellgallery.com/packages/AzureAD)
  - [Microsoft.Graph](https://www.powershellgallery.com/packages/Microsoft.Graph)
- **Permissions**:
  - Sufficient Azure AD permissions to create groups and manage group memberships.
  - Access to Microsoft Intune to retrieve device information.
  - App registration in Azure AD with the necessary permissions for Microsoft Graph.

## Configuration

Before running the script, you need to set up app-based authentication for Microsoft Graph:

1. **App Registration in Azure AD**

   - Register an application in Azure AD and obtain the following:
     - **Tenant ID**: The Azure AD tenant ID.
     - **Client ID (AppID)**: The application (client) ID.
     - **Client Secret (AppSecret)**: The secret associated with the application.

   > **Security Note**: Ensure that the `AppSecret` is stored securely and not exposed in source control or logs.

2. **Customize Parameters**

   You can customize the script parameters directly in the script or pass them as arguments when executing the script:

   - **BatchSize**: Number of devices per group (default is 500).
   - **GroupNamePrefix**: Prefix for the group names (default is "Devices-group").
   - **NamePadding**: Number of digits in group numbering (default is 2).
   - **EnableLogging**: Enable or disable logging to a file.
   - **LogFilePath**: Path to the log file (default is `C:\CreateStaticGroup\GroupCreationLog.txt`).

## Usage

1. **Run the Script**

   ```powershell
   .\AzureAD-DeviceGroupManagement.ps1
   ```

2. **Using Parameters**

   You can customize the script execution by providing parameters:

   ```powershell
   .\AzureAD-DeviceGroupManagement.ps1 -BatchSize 300 -GroupNamePrefix "IntuneGroup" -NamePadding 3 -EnableLogging -LogFilePath "C:\Logs\GroupCreationLog.txt"
   ```

## Parameters

| Parameter          | Description                                              | Default Value                                   |
|--------------------|----------------------------------------------------------|-------------------------------------------------|
| `-BatchSize`       | Number of devices per group                              | `500`                                           |
| `-GroupNamePrefix` | Prefix for the group names                               | `"Devices-group"`                               |
| `-NamePadding`     | Number of digits in group numbering                      | `2`                                             |
| `-EnableLogging`   | Enable logging to a file                                 | `False`                                         |
| `-LogFilePath`     | Path to the log file                                     | `"C:\CreateStaticGroup\GroupCreationLog.txt"`   |

## Script Workflow

1. **Module Installation and Import**: Ensures required PowerShell modules (`AzureAD` and `Microsoft.Graph`) are installed and imported.
2. **Authentication**:
   - **Automatic Connection to Microsoft Graph**: Automatically connects to Microsoft Graph using app-based authentication with the specified `TenantID`, `AppID`, and `AppSecret`.
   - **Manual Connection to Azure AD**: Prompts the user to manually connect to Azure AD using user-based authentication.
3. **Device Retrieval**: Fetches all Windows PC devices from Microsoft Intune via Microsoft Graph.
4. **Group Retrieval and Creation**:
   - Retrieves existing Azure AD groups with the specified prefix.
   - Determines the next group number based on existing groups.
   - Creates new static groups if necessary.
5. **Device Assignment**:
   - Adds devices to existing static groups with available space (fewer than 500 members).
   - Creates new static groups and assigns devices if no existing groups have available space.
6. **Logging**: Records all actions and errors to the console and optionally to a log file.

## Logging

- **Console Logging**: Outputs log messages with timestamps and message types (INFO, SUCCESS, WARNING, ERROR) in different colors for easy readability.
- **File Logging**: If `-EnableLogging` is specified, logs are saved to the path defined by `-LogFilePath`.

## Troubleshooting

- **Module Not Found Errors**: Ensure that the `AzureAD` and `Microsoft.Graph` modules are installed and imported correctly.
- **Authentication Issues**: Verify that you have the necessary permissions to access Microsoft Graph and Azure AD.
- **Group Creation Failures**: Check if the group name prefix is unique and adheres to Azure AD naming conventions.
- **Device Addition Failures**: Ensure devices exist in Intune and you have the rights to modify group memberships.

## License

This project is licensed under the [MIT License](LICENSE).


---

**Disclaimer**: Use these scripts at your own risk. Ensure you understand their impact before running them in a production environment. Always review and test scripts thoroughly.