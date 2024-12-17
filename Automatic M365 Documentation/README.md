
# Microsoft 365 Documentation Script

![License](https://img.shields.io/badge/license-MIT-blue.svg)
![PowerShell](https://img.shields.io/badge/powershell-7-blue.svg)
![Version](https://img.shields.io/badge/version-1.0.0-green.svg)

## Overview
This PowerShell script generates detailed documentation for Microsoft 365 components, focusing on **Intune** and **AzureAD**. It allows dynamic selection of sections for inclusion or exclusion and outputs the results as a Word document.

This script leverages the [M365Documentation PowerShell Module](https://github.com/ThomasKur/M365Documentation) for data collection and Word document generation.

---

## Features
- Supports detailed documentation for:
  - **Intune** (configuration policies, compliance policies, applications, etc.).
  - **AzureAD** (domains, conditional access policies, authentication policies, etc.).
- Provides a menu-driven interface for selecting components and sections dynamically.
- Outputs documentation in Word format with a timestamped filename.

---

## Prerequisites

### **PowerShell Modules**
Ensure the following modules are installed:
- `MSAL.PS`  
  Install using:
  ```powershell
  Install-Module -Name MSAL.PS -Force
  ```
- `PSWriteOffice`  
  Install using:
  ```powershell
  Install-Module -Name PSWriteOffice -Force
  ```
- `M365Documentation`  
  Install using:
  ```powershell
  Install-Module -Name M365Documentation -Force
  ```

### **Azure AD App Registration**
1. **Create or use an existing app registration** in the Azure Portal.
2. Assign the following **Microsoft Graph API permissions**:
   - **Application Permissions**:
     - `Directory.Read.All`
     - `DeviceManagementApps.Read.All`
     - `DeviceManagementConfiguration.Read.All`
     - `DeviceManagementManagedDevices.Read.All`
     - `DeviceManagementRBAC.Read.All`
     - `DeviceManagementServiceConfig.Read.All`
     - `Domain.Read.All`
     - `Policy.Read.All`
     - `Policy.ReadWrite.AuthenticationMethod`
     - `Policy.ReadWrite.FeatureRollout`
     - `Organization.Read.All`
     - `User.Read`
   - Grant **admin consent** for the permissions in Azure AD.
3. Note down the **Client ID**, **Client Secret**, and **Tenant ID** for your app.

---

## Installation
1. Clone or download this repository.
2. Place the script (`document-M365-environment.ps1`) in your working directory.
3. Update the script with your Azure AD **Client ID**, **Client Secret**, and **Tenant ID**.

---

## Usage

### **Running the Script**
1. Open PowerShell with administrative privileges.
2. Run the script:
   ```powershell
   .\document-M365-environment.ps1
   ```
3. Follow the prompts to:
   - Select a component (**Intune** or **AzureAD**).
   - Optionally specify sections to include or exclude.
4. The script generates a Word document in the specified output directory.

---

## Supported Components and Sections

### **1. Intune**
- Configuration Policies
- Compliance Policies
- Device Enrollment Restrictions
- Applications (Only Assigned)
- Application Protection Policies
- AutoPilot Configuration
- Enrollment Page Configuration
- Apple Push Certificate
- Apple VPP
- Device Categories
- PowerShell Scripts
- Security Baseline
- Custom Roles

### **2. AzureAD**
- Domains
- Conditional Access Policies
- Authentication Policies
- Feature Rollout Policies
- Organizational Settings
- Subscriptions / SKU
- Administrative Units

---

## Example Output
The output file is saved in the following format:
```
C:\Temp\<timestamp>-<component>-Documentation.docx
```

---

## Troubleshooting
### **API Permission Errors**
If the script encounters errors related to API permissions:
1. Verify the app registration has the required permissions.
2. Re-grant admin consent in Azure AD if necessary.
3. Authenticate to Microsoft Graph manually before running the script:
   ```powershell
   Connect-MgGraph
   ```

### **Module Issues**
If modules are not installed or updated:
- Run the following commands:
  ```powershell
  Install-Module -Name MSAL.PS -Force
  Install-Module -Name PSWriteOffice -Force
  Install-Module -Name M365Documentation -Force
  ```

---

## References
- [M365Documentation PowerShell Module GitHub Repository](https://github.com/ThomasKur/M365Documentation)

---

## License

This project is licensed under the [MIT License](https://opensource.org/licenses/MIT).

---

**Disclaimer**: These scripts are provided as-is. Test them in a staging environment before use in production. The author is not responsible for any unintended outcomes resulting from their use.

