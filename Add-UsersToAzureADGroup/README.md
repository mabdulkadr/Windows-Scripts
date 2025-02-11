
# Add Users to Azure AD Security Group

![License](https://img.shields.io/badge/license-MIT-blue.svg)
![PowerShell](https://img.shields.io/badge/powershell-5.1%2B-blue.svg)
![Version](https://img.shields.io/badge/version-1.0-green.svg)

## Overview
This PowerShell script automates the process of adding users to an **Azure AD Security Group** from a CSV file. It checks if each user exists, ensures they are not already members, and adds them if necessary.

---

## Features
- ✅ **Reads users from a CSV file**
- ✅ **Checks if users exist in Azure AD before adding them**
- ✅ **Prevents duplicate additions**
- ✅ **Uses error handling to manage failures**
- ✅ **Includes rate-limiting to avoid API throttling**

---

## Requirements
- Windows PowerShell 5.1 or later
- **AzureAD PowerShell Module**  
  Install it using:
  ```powershell
  Install-Module -Name AzureAD -Force
  ```
- **Admin privileges** to manage Azure AD groups

---

## Scripts Details

### **1. `Add-UsersToAzureADGroup.ps1`**

#### **Purpose**
This script:
- Connects to Azure AD
- Reads a CSV file containing a list of user UPNs
- Checks if the users exist in Azure AD
- Adds users to the specified **Security Group** if they are not already members

#### **How to Run**
1. Open **PowerShell as Administrator**.
2. Run the script with:
   ```powershell
   .\Add-UsersToAzureADGroup.ps1
   ```

---

## **CSV File Format**
The CSV file should have a **header column `UPN`**, followed by user principal names:

```
UPN
user1@domain.com
user2@domain.com
user3@domain.com
```

---

## **Customization**
- **Change the Security Group ID** in the script:
  ```powershell
  $GroupID = "your-group-id"
  ```
- **Change the CSV file path**:
  ```powershell
  $CSVFilePath = "C:\path\to\your\file.csv"
  ```

---

## **Error Handling**
The script includes **detailed error messages** to handle:
1. **User Not Found** → `"User does not exist in Azure AD"`
2. **User Already in Group** → `"UPN is already a member of the security group"`
3. **General Errors** → `"Error adding UPN: <Error Message>"`

---

## **License**
This project is licensed under the [MIT License](https://opensource.org/licenses/MIT).

---

## **Disclaimer**
This script is provided **as-is**. Please test in a staging environment before deploying to production.
```
