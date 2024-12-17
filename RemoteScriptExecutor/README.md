
# Remote Script Executor

![License](https://img.shields.io/badge/license-MIT-blue.svg)
![PowerShell](https://img.shields.io/badge/powershell-5.1%2B-blue.svg)
![Version](https://img.shields.io/badge/version-1.0.0-green.svg)


## Introduction

The **Remote Script Executor** is a versatile PowerShell tool designed to automate the execution of scripts and commands across multiple remote computers. Tailored for IT administrators and professionals, it streamlines routine tasks, enhances productivity, and ensures consistency across your network infrastructure.

Whether you prefer the speed and flexibility of a **Command-Line Interface (CLI)** or the intuitive experience of a **Graphical User Interface (GUI)**, Remote Script Executor has you covered.

---

## Features

### CLI Version

- **Select Target PCs:**
  - **Import from CSV:** Easily import PC names or IP addresses from a structured CSV file.
  - **Manual Entry:** Directly input PC names or IPs for quick operations.

- **Script/Command Selection:**
  - **Browse and Select Scripts:** Choose PowerShell scripts (`.ps1`) to execute remotely.
  - **Custom Commands:** Enter one or multiple PowerShell commands to run on target PCs.

- **Execution:**
  - **Bulk Operations:** Execute scripts and commands across all specified PCs simultaneously.
  - **Progress Indicators:** Real-time feedback on execution status and progress.
  - **Error Handling:** Comprehensive logging of successes and failures for easy troubleshooting.

- **Reporting:**
  - **Export Options:** Generate detailed reports in **CSV**, **HTML**, or both formats.
  - **File Browsing Dialogs:** Navigate your file system graphically to select save locations and filenames.

- **Logging:**
  - **Detailed Logs:** Maintain logs capturing execution details, errors, and timestamps for auditing purposes.

### GUI Version

- **User-Friendly Interface:**
  - **WPF-Based GUI:** Intuitive and visually appealing interface for managing remote script executions.
  - **Drag and Drop:** Easily upload scripts and input device information.

- **Select Target PCs:**
  - **Import from CSV:** Browse and select a CSV file containing PC names or IP addresses.
  - **Manual Entry:** Input PC names or IPs directly into the GUI.

- **Script/Command Selection:**
  - **Browse and Select Scripts:** Use the "Select Script" button to choose a PowerShell script (`.ps1`) to execute.
  - **Custom Commands:** Enter custom PowerShell commands in the designated text area.

- **Execution Controls:**
  - **Run Scripts:** Initiate the execution of selected scripts and commands on all specified PCs.
  - **Cancel Execution:** Option to cancel ongoing executions (Note: Cancellation is currently not supported and will be implemented in future updates).

- **Real-Time Output:**
  - **RichTextBox Display:** View execution outputs and statuses in real-time within the GUI.
  - **Progress Bar:** Visual representation of the execution progress.

- **Logging and Reporting:**
  - **Detailed Output Logs:** Comprehensive logs displayed within the GUI for immediate reference.
  - **Export Options:** Future enhancements will include exporting logs and reports directly from the GUI.

> **Note:** The GUI version is under continuous development. Future updates will introduce additional features such as cancellation support and enhanced reporting capabilities.

---

## Prerequisites

Before using the Remote Script Executor, ensure the following:

- **Operating System:** Windows 10 or later.
- **PowerShell Version:** PowerShell 5.1 or later.
- **Permissions:** Administrative privileges on both the local and remote machines.
- **WinRM Configuration:**
  - **Enable PowerShell Remoting:** WinRM must be enabled and properly configured on all target machines.
    ```powershell
    Enable-PSRemoting -Force
    ```
  - **Firewall Settings:** Ensure that firewall rules allow PowerShell remoting.
- **Network:** Verify that there are no network restrictions or firewall rules blocking communication between the local and remote machines.

---

## Installation

### Download

1. **Clone the Repository:**
   ```powershell
   git clone https://github.com/mabdulkadr/Scripts/RemoteScriptExecutor.git
   ```

2. **Or Download as ZIP:**
   - Visit the [GitHub Repository](https://github.com/mabdulkadr/Scripts/RemoteScriptExecutor).
   - Click on the **"Code"** button and select **"Download ZIP"**.
   - Extract the ZIP file to your desired location, e.g., `C:\Scripts\RemoteScriptExecutor\`.

### Setup

1. **Navigate to the Script Directory:**
   ```powershell
   cd "C:\Scripts\RemoteScriptExecutor\"
   ```

2. **Set Execution Policy (if not already set):**
   To allow the execution of PowerShell scripts, you may need to adjust the execution policy:
   ```powershell
   Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
   ```
   *Choose **Yes** when prompted.*

3. **Verify Prerequisites:**
   Ensure that all prerequisites mentioned above are met, especially PowerShell remoting configurations on target machines.

---

## Usage

### CLI Version Usage

1. **Open PowerShell as Administrator:**
   - Right-click on the **PowerShell** icon and select **"Run as Administrator"**.

2. **Navigate to the Script Directory:**
   ```powershell
   cd "C:\Scripts\RemoteScriptExecutor\"
   ```

3. **Execute the Script:**
   ```powershell
   .\RemoteScriptExecutor.ps1
   ```

4. **Follow the On-Screen Prompts:**
   - **Step 1:** Select PCs by importing from a CSV file or entering manually.
   - **Step 2:** Select a PowerShell script to execute or enter custom commands.
   - **Step 3:** Execute the scripts/commands on all specified PCs.
   - **Step 4:** Export the execution results to CSV and/or HTML.
   - **Step 5:** Exit the executor.

> **Example:**
>
> - **CSV File Format:**
>   ```csv
>   PC1
>   PC2
>   192.168.1.10
>   ```
> - **Custom Command Example:**
>   ```
>   Get-Service; Get-Process
>   ```

### GUI Version Usage

1. **Open PowerShell as Administrator:**
   - Right-click on the **PowerShell** icon and select **"Run as Administrator"**.

2. **Navigate to the Script Directory:**
   ```powershell
   cd "C:\Scripts\RemoteScriptExecutor\"
   ```

3. **Execute the GUI Script:**
   ```powershell
   .\RemoteScriptExecutorGUI.ps1
   ```

4. **Interact with the GUI:**
   - **Target Devices:**
     - **Enter Device Names/IPs:** Input PC names or IP addresses separated by commas.
     - **Import from CSV:** Click the **"Import from File"** button to browse and select a CSV file containing device names or IPs.
   - **Custom Command:**
     - **Enter Commands:** Input custom PowerShell commands directly into the text area.
   - **Script Upload:**
     - **Browse Script:** Click the **"Select Script"** button to browse and select a `.ps1` PowerShell script for execution.
   - **Execution Controls:**
     - **Run Scripts:** Click the **"Run Scripts"** button to initiate execution.
     - **Cancel Execution:** Click the **"Cancel Execution"** button to attempt to cancel ongoing executions (Note: Cancellation is not currently supported and will be implemented in future updates).
   - **Execution Output:**
     - **View Output:** Monitor real-time execution outputs and statuses in the **"Execution Output"** section.
   - **Progress Bar & Footer:**
     - **Progress Indicator:** Observe the progress of script executions through the progress bar.
     - **Footer:** View footer information including author credits.

> **Note:** The GUI version is under continuous development. Future updates will introduce additional features such as cancellation support and enhanced reporting capabilities.

---

## Exporting Reports

After executing scripts/commands on remote PCs, you can export the results for auditing and reporting purposes.

### CLI Version

1. **Choose Export Format:**
   - **CSV:** Suitable for data analysis in spreadsheet applications like Microsoft Excel.
   - **HTML:** Provides a formatted, easily readable report in web browsers.
   - **Both:** Generate both CSV and HTML reports simultaneously.

2. **Select Save Location:**
   - Use the file browsing dialogs to navigate to your desired save location and specify the filename.

3. **Access the Reports:**
   - Navigate to the chosen directory to view your reports.

> **Sample Export Process:**
>
> - **Exporting to CSV:**
>   1. Choose the **CSV** option.
>   2. In the dialog, navigate to `C:\Reports\` and name the file `ExecutionResults.csv`.
>   3. Click **Save** to generate the report.
>
> - **Exporting to HTML:**
>   1. Choose the **HTML** option.
>   2. In the dialog, navigate to `C:\Reports\` and name the file `ExecutionReport.html`.
>   3. Click **Save** to generate the report.

### GUI Version

*Coming Soon!*

> **Note:** Future updates will include the ability to export execution results directly from the GUI. Stay tuned for an integrated reporting feature.

---

## Logging

The Remote Script Executor maintains detailed logs to help you track activities, successes, and errors.

### CLI Version

- **Log File Location:**
  - By default, logs are saved in the script directory with a timestamp, e.g.,
    ```
    RemoteScriptExecutorCLI_Log_20241212_123456.txt
    ```

- **Log Contents:**
  - Execution timestamps.
  - Status messages (INFO, WARNING, ERROR).
  - Detailed error messages for troubleshooting.

> **Sample Log Entry:**
>
> ```
> 2024-12-12 12:34:56 [INFO] - Imported 3 valid devices from CSV: C:\Scripts\RemoteScriptExecutor\devices.csv
> 2024-12-12 12:35:10 [INFO] - Processing PC: PC1
> 2024-12-12 12:35:12 [INFO] - PC1 is ONLINE.
> 2024-12-12 12:35:15 [INFO] - Executing script on PC1.
> 2024-12-12 12:35:20 [INFO] - Script Output on PC1:
> <script output here>
> ```

### GUI Version

*Coming Soon!*

> **Note:** Future updates will include comprehensive logging features within the GUI for real-time monitoring and post-execution analysis.

---

## Troubleshooting

Encountering issues? Here are some common problems and their solutions:

### CLI Version

- **WinRM Not Enabled on Remote Machines:**
  - **Solution:** Run the following command on each remote machine to enable PowerShell remoting:
    ```powershell
    Enable-PSRemoting -Force
    ```

- **Firewall Blocking Remoting:**
  - **Solution:** Ensure that the firewall on both local and remote machines allows PowerShell remoting. You can configure this using Group Policy or manually via the firewall settings.

- **Authentication Errors:**
  - **Solution:** Verify that you have administrative privileges on the remote machines and that the credentials used are correct.

- **Script Execution Fails on Remote PCs:**
  - **Solution:** Check the script syntax, ensure all necessary modules are available on remote machines, and review the detailed logs for specific error messages.

- **Exporting Reports Fails:**
  - **Solution:** Ensure you have write permissions to the selected save location and that the filenames are valid.

> **Advanced Troubleshooting:**
>
> - **Enable Verbose Logging:** Modify the script to include verbose output for more detailed logs.
> - **Check Network Connectivity:** Use `Test-Connection` to verify connectivity to remote PCs.
> - **Review Event Logs:** Inspect the Windows Event Viewer on remote machines for related error entries.

### GUI Version

*Coming Soon!*

> **Note:** As the GUI version is under development, detailed troubleshooting steps will be provided in future updates.

---

## License

This project is licensed under the [MIT License](https://opensource.org/licenses/MIT).

---

**Disclaimer**: These scripts are provided as-is. Test them in a staging environment before use in production. The author is not responsible for any unintended outcomes resulting from their use.

