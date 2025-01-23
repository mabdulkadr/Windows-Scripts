

# **Join/Unjoin Computer Tool**

![License](https://img.shields.io/badge/license-MIT-blue.svg)
![PowerShell](https://img.shields.io/badge/powershell-5.1%2B-blue.svg)
![Version](https://img.shields.io/badge/version-1.0.0-green.svg)

A **PowerShell-based GUI tool**, now available as a standalone `.exe`, to simplify the management of computer objects in Active Directory (AD). This tool allows administrators to join, disjoin, and delete computers from Active Directory with ease.

---

## **Features**

1. **Standalone Executable (`.exe`)**:
   - No need to configure PowerShell execution policies.
   - Launch directly by running the provided `.exe` file.

2. **Join Computers to a Domain**:
   - Specify the domain and optionally an Organizational Unit (OU) for placement.

3. **Disjoin Computers from a Domain**:
   - Safely remove computers from the domain and move them to a workgroup.

4. **Delete Computers from Active Directory**:
   - Clean up inactive or decommissioned computer objects.

5. **View Current Computer Information**:
   - Displays the computer name and domain/workgroup status in the GUI.

6. **Logs and Notifications**:
   - Operation results are logged in the GUI console.
   - Success/error notifications are displayed in Windows Message Boxes.

7. **Administrator Privileges Check**:
   - Ensures the tool runs with elevated privileges to perform sensitive operations.

---

## **Prerequisites**

1. **Operating System**: Windows (with .NET Framework support).
2. **Active Directory Access**:
   - The computer must have network access to the Active Directory environment.
   - Valid credentials are required for domain operations.
3. **Run as Administrator**:
   - Ensure the tool is launched with administrative privileges.

---

## **Installation and Usage**

### Option 1: Using the `.exe` File
1. Download the **`JoinUnjoinComputerTool.exe`** from this repository.
2. Right-click the file and select **"Run as Administrator"** to launch the tool.
3. Use the GUI to perform operations such as joining or disjoining a computer from the domain.

---

### Option 2: Using the PowerShell Script (`.ps1`)
1. Clone this repository or download the **`JoinUnjoinComputerTool.ps1`** script:
   ```bash
   git clone https://github.com/mabdulkadr/Scripts.git
   cd Scripts/JoinUnjoinComputerTool
   ```

2. Save the script to a local folder.

3. Open PowerShell **as Administrator**.

4. Temporarily relax the execution policy for the current session:
   ```powershell
   Set-ExecutionPolicy -Scope Process -ExecutionPolicy Unrestricted
   ```

5. Run the script:
   ```powershell
   .\JoinUnjoinComputerTool.ps1
   ```

---

## **How to Use**

1. **Domain Configuration**:
   - Enter the domain controller, domain name, and search base in the GUI.
2. **Join to a Domain**:
   - Use the **"Join to Domain + OU"** button to join a domain.
3. **Disjoin from a Domain**:
   - Use the **"Disjoin from Domain"** button to leave the current domain.
4. **Delete from AD**:
   - Use the **"Delete from AD"** button to remove a computer object.
5. **View Logs**:
   - Check the **"Output Console"** in the GUI for operation details.

---

## **Parameters**

| Parameter                 | Description                                      | Default Value                  |
|---------------------------|--------------------------------------------------|--------------------------------|
| `DefaultDomainController` | The Fully Qualified Domain Name (FQDN) of the Domain Controller. | `DC01.company.local`          |
| `DefaultDomainName`       | The name of the domain.                          | `company.local`               |
| `DefaultSearchBase`       | LDAP search base to filter Organizational Units. | `OU=Computers,DC=company,DC=local` |

---

## **Screenshot**

![Screenshot](Screenshot.png)

---

## **Troubleshooting**

1. **Error: "The server is not operational"**:
   - Ensure the provided domain controller is reachable and correct.
   - Check the computer’s network connection.

2. **Error: "Access Denied"**:
   - Run the tool as Administrator.
   - Provide valid credentials when prompted.

3. **Execution Policy Issues (for `.ps1`)**:
   - Ensure the execution policy is set to `Unrestricted` as described in the **Usage** section.

4. **Computer Not Found in AD**:
   - Double-check the search base (OU) and ensure the computer object exists in AD.

---


## **License** 
This project is licensed under the [MIT License](https://opensource.org/licenses/MIT).

---

**Disclaimer**: This script is provided as-is. Test it in a staging environment before deploying it to production. The author is not responsible for any unintended outcomes resulting from its use.
