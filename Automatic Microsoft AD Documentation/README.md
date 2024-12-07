
# Microsoft Active Directory AsBuilt Report Automation Script

![License](https://img.shields.io/badge/license-MIT-blue.svg)
![PowerShell](https://img.shields.io/badge/powershell-5.1%2B-blue.svg)
![Version](https://img.shields.io/badge/version-1.0.0-green.svg)

## Overview

This PowerShell script automates the generation of an **As Built Report** for **Microsoft Active Directory**. It streamlines the process by:

- Automatically detecting the domain controller and logged-in user.
- Ensuring all required modules and tools are installed.
- Enabling PowerShell remoting securely on the domain controller.
- Managing configuration and output directories.
- Generating reports in multiple formats (e.g., Word, HTML).

This script leverages the [Microsoft AD As Built Report](https://github.com/AsBuiltReport/AsBuiltReport.Microsoft.AD#readme) for data collection and Word document generation.

---

## Features

- **Automatic Detection**: Identifies the primary domain controller (PDC) and logged-in user.
- **Secure PowerShell Remoting**: Configures and verifies PowerShell remoting on the domain controller.
- **Module Management**: Checks for and installs required PowerShell modules.
- **RSAT Tools Setup**: Installs necessary RSAT features based on the system type (Windows Server or Windows 10+).
- **Comprehensive Report Generation**: Creates detailed AD reports in the desired formats.

---

## Requirements

### System Requirements

- **Operating System**:
  - Windows Server 2012 R2 or later
  - Windows 10 or later
- **PowerShell Version**: PowerShell 5.1 or later
- **Privileges**: Must be run with administrative privileges (Domain Administrator).

### Dependencies

- **PowerShell Modules**:
  - [`PSPKI`](https://www.powershellgallery.com/packages/PSPKI)
  - [`AsBuiltReport.Microsoft.AD`](https://github.com/AsBuiltReport/AsBuiltReport.Microsoft.AD)
- **RSAT Tools**:
  - Active Directory Module
  - Group Policy Management
  - Certificate Services Management
  - DNS Server Management

## Installation

1. **Install Required PowerShell Modules**:

   ```powershell
   Install-Module -Name PSPKI, AsBuiltReport.Microsoft.AD -Force
   ```

2. **Install RSAT Tools**:

   - **For Windows Server**:

     ```powershell
     Install-WindowsFeature -Name RSAT-AD-PowerShell, RSAT-ADCS, RSAT-ADCS-Mgmt, RSAT-DNS-Server, GPMC -IncludeAllSubFeature
     ```

   - **For Windows 10**:

     ```powershell
     Add-WindowsCapability -Online -Name 'Rsat.ActiveDirectory.DS-LDS.Tools~~~~0.0.1.0'
     Add-WindowsCapability -Online -Name 'Rsat.CertificateServices.Tools~~~~0.0.1.0'
     Add-WindowsCapability -Online -Name 'Rsat.GroupPolicy.Management.Tools~~~~0.0.1.0'
     Add-WindowsCapability -Online -Name 'Rsat.Dns.Tools~~~~0.0.1.0'
     ```

---

## Usage

1. **Clone or Download the Script**:

   Save the script to your local machine as `MicrosoftActiveDirectoryReport.ps1`.

2. **Run the Script**:

   Run the script with administrative privileges:

   ```powershell
   .\MicrosoftActiveDirectoryReport.ps1
   ```

3. **Output**:

   - **Configuration Directory**: The script creates a configuration file in `C:\Reports\Config` (default).
   - **Generated Reports**: Reports are saved in `C:\Reports` (default) in the specified formats.

### Parameters

| Parameter      | Description                                         | Default Value |
|----------------|-----------------------------------------------------|---------------|
| `OutputPath`   | Directory to store configuration files and reports. | `C:\Reports` |
| `ReportFormat` | Formats for the report: Word, HTML, or Text.        | `Word,HTML`  |

### Example

To generate a report in Word format and save it in a custom directory:

```powershell
.\MicrosoftActiveDirectoryReport.ps1 -OutputPath "D:\CustomReports" -ReportFormat "Word"
```

---

## Script Workflow

1. **Detect Domain Controller and User**: Identifies the primary DC and logged-in user credentials.
2. **Enable PowerShell Remoting**:
   - Configures remoting on the domain controller.
   - Verifies and updates firewall rules.
3. **Install Required Modules**: Checks and installs missing PowerShell modules.
4. **Install RSAT Tools**: Ensures required RSAT tools are installed based on the OS type.
5. **Manage Configuration**:
   - Creates output and configuration directories.
   - Overwrites existing configuration files when necessary.
6. **Generate the Report**:
   - Uses `New-AsBuiltReport` to create the AD report.
   - Saves the report in the specified format(s).

---

## Troubleshooting

- **Failed to detect domain controller**:
  - Ensure RSAT tools are installed and the system is domain-joined.
  - Verify connectivity to the domain controller.
- **Module installation errors**:
  - Run `Update-Module` to ensure the latest versions of `PSPKI` and `AsBuiltReport.Microsoft.AD`.
  - Manually install modules if necessary.
- **Firewall issues for PSRemoting**:
  - Check and configure firewall rules manually for Windows Remote Management (WinRM).

---

## Security Considerations

- **Access Control**: Restrict PSRemoting to trusted administrators.
- **Secure Communication**: Consider configuring HTTPS for PSRemoting.
- **Auditing**: Monitor remote sessions via the Event Viewer (`Applications and Services Logs > PowerShell > 

---

## References
- [Microsoft AD As Built Report](https://github.com/AsBuiltReport/AsBuiltReport.Microsoft.AD#readme)

---

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Disclaimer

These scripts are provided "as is" without warranty of any kind. Use them at your own risk. Always test scripts in a controlled environment before deploying them in a production environment.
