# AD Computer Mover Script

![License](https://img.shields.io/badge/license-MIT-blue.svg)
![PowerShell](https://img.shields.io/badge/powershell-5.1%2B-blue.svg)
![Version](https://img.shields.io/badge/version-1.0.0-green.svg)

## Overview
This PowerShell script automates the process of moving computers in Active Directory (AD) to the appropriate Organizational Units (OUs) based on a naming convention. The script extracts the prefix from the computer name (e.g., `BACKUP` from `BACKUP-01` or `backup2`) and matches it with OU names using flexible matching logic.

### Key Features:
- Extracts the prefix from computer names for matching.
- Matches only when the prefix is at the beginning of the computer name to avoid false positives.
- Supports flexible partial matching (e.g., `backup-01` and `backup2` matching `backup1` OU).
- Provides detailed logging and error handling.

## Prerequisites
- Active Directory PowerShell module (`ActiveDirectory`) must be installed.
- The script should be run by a user with appropriate permissions to read and move computer objects in Active Directory.

## Setup and Installation
1. Ensure that you have the `Active Directory` module installed. Run the following command to check:
   ```powershell
   Get-Module -ListAvailable -Name ActiveDirectory
   ```
   If not installed, refer to the [Microsoft documentation](https://docs.microsoft.com/en-us/powershell/module/activedirectory/?view=windowsserver2022-ps) for installation instructions.

2. Save the `AD-ComputerMover.ps1` script file to your desired location.

3. Open PowerShell with **administrative privileges**.

4. Navigate to the directory where the script is located:
   ```powershell
   cd "C:\Path\To\Your\Script"
   ```

## Usage
1. Run the script by executing:
   ```powershell
   .\AD-ComputerMover.ps1
   ```

2. The script will:
   - Scan the specified OU (`$ComputersOU`) for computer objects.
   - Extract the prefix from each computer name.
   - Match the prefix with available OUs and move the computer if a match is found.
   - Log the process in the PowerShell console.

## Script Details
### How the Script Works:
- **Prefix Extraction**: The script splits the computer name using delimiters (`-`, `_`, and digits) and extracts the first part as the prefix.
- **Matching Logic**: The script matches the prefix with the OU name only if the prefix appears at the start of the computer name or matches the OU name exactly.
- **Logging**: Outputs messages to the console to show progress, matches, and any errors encountered.

### Example Scenarios:
- **Computer Name**: `backup-01` ➔ **Extracted Prefix**: `BACKUP` ➔ **Matches OU**: `backup1`, `backup-team`
- **Computer Name**: `backup2` ➔ **Extracted Prefix**: `BACKUP` ➔ **Matches OU**: `backup1`
- **Computer Name**: `quality-01` ➔ **Extracted Prefix**: `QUALITY` ➔ **Does Not Match** an OU named `IT`

## Customization
- **Change Base OU**: Modify the `$ComputersOU` variable to reflect your environment's base OU:
  ```powershell
  $ComputersOU = "OU=Computers,OU=YourOrg,DC=yourdomain,DC=com"
  ```
- **Adjust Delimiters**: Modify the `-split '[-_0-9]'` operation if your naming conventions use different delimiters.

## Troubleshooting
- Ensure the user running the script has sufficient permissions in AD.
- Run the script in a test environment before using it in production.
- If the script fails to move objects, check for potential issues such as:
  - Insufficient permissions.
  - Incorrect `DistinguishedName` for the target OUs.

## License

This project is licensed under the [MIT License](LICENSE).


---

**Disclaimer**: Use these scripts at your own risk. Ensure you understand their impact before running them in a production environment. Always review and test scripts thoroughly.
