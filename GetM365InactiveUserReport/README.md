# Get-M365InactiveUsersReport.ps1

![License](https://img.shields.io/badge/license-MIT-blue.svg)
![PowerShell](https://img.shields.io/badge/powershell-5.1%2B-blue.svg)
![Version](https://img.shields.io/badge/version-1.4-green.svg)

## Overview
This PowerShell script generates a report of inactive Microsoft 365 users based on sign-in activities using Microsoft Graph PowerShell.

### Features
- Retrieves user sign-in data from Microsoft Graph API.
- Identifies inactive users based on interactive and non-interactive sign-ins.
- Filters users based on multiple criteria:
  - Enabled users
  - Disabled users
  - External users
  - Users who never logged in
- Exports results into a properly formatted CSV file with UTF-8 encoding.
- Automatically installs the required Microsoft Graph PowerShell module if missing.
- Scheduler-friendly for automated execution.

---

## Parameters
| Parameter                      | Description |
|--------------------------------|-------------|
| `-InactiveDays`                | Specifies the number of inactive days to filter users based on their last interactive sign-in. |
| `-InactiveDays_NonInteractive` | Specifies the number of inactive days based on non-interactive sign-ins. |
| `-ReturnNeverLoggedInUser`     | Switch to return only users who have never logged in. |
| `-EnabledUsersOnly`            | Switch to filter only enabled (active) users. |
| `-DisabledUsersOnly`           | Switch to filter only disabled users. |
| `-ExternalUsersOnly`           | Switch to filter only external users (identified by #EXT# in their UserPrincipalName). |
| `-CreateSession`               | Switch to disconnect any existing Microsoft Graph session before executing the script. |
| `-TenantId`                    | Specifies the Azure AD Tenant ID (required for Certificate-based authentication). |
| `-ClientId`                    | Specifies the Client ID of the registered app (required for Certificate-based authentication). |
| `-CertificateThumbprint`       | Specifies the thumbprint of the certificate (required for Certificate-based authentication). |

---

## How to Run
### Example Command:
```powershell
# Run the script with basic parameters
.\Get-M365InactiveUsersReport.ps1 -InactiveDays 30 -EnabledUsersOnly
```

### Required Permissions
This script requires the following Microsoft Graph API permissions:
- `User.Read.All`
- `AuditLog.Read.All`

### Module Installation
If the **Microsoft Graph Beta Module** is not installed, the script will prompt you to install it. You can manually install it using:
```powershell
Install-Module Microsoft.Graph.Beta -Scope CurrentUser -AllowClobber
```

---

## Outputs
The script generates a CSV report with the following fields:
| Field Name | Description |
|------------|-------------|
| `UPN` | User Principal Name (Email Address). |
| `Creation Date` | The date the account was created. |
| `Last Interactive SignIn Date` | The last recorded interactive sign-in date. |
| `Last Non Interactive SignIn Date` | The last recorded non-interactive sign-in date. |
| `Inactive Days(Interactive SignIn)` | Number of inactive days based on interactive sign-ins. |
| `Inactive Days(Non-Interactive Signin)` | Number of inactive days based on non-interactive sign-ins. |
| `Account Status` | Indicates if the account is Enabled or Disabled. |
| `Department` | The user's department. |
| `Employee ID` | The unique employee identification number. |
| `Employee Name` | The full name of the employee. |
| `Job Title` | The user's job title. |


The exported CSV file is saved in the same directory as the script.

---

## References
For detailed script execution and further explanation, refer to:
[Microsoft 365 Inactive User Report using MS Graph PowerShell](https://o365reports.com/2023/06/21/microsoft-365-inactive-user-report-ms-graph-powershell/)

---

## License
This project is licensed under the [MIT License](https://opensource.org/licenses/MIT).

---

**Disclaimer**: This script is provided as-is. Test it in a staging environment before use in production. The author is not responsible for any unintended outcomes resulting from its use.

