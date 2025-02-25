
# Directory Size Explorer GUI Tool

![License](https://img.shields.io/badge/license-MIT-blue.svg)
![PowerShell](https://img.shields.io/badge/powershell-5.1%2B-blue.svg)
![Version](https://img.shields.io/badge/version-1.0.0-green.svg)

## Overview

**Directory Size Explorer** is a PowerShell-based GUI tool that allows you to scan a specified directory and display the sizes of files and folders recursively. The tool provides a clear visual distinction between folders and files through color coding and icons, and includes features for navigation, deletion, and detailed property viewing. A standard header and footer are included for branding consistency across GUI tools.

## Features

- **Recursive Folder Size Calculation:**  
  Accurately calculates the total size of each folder (including all subfolders).

- **DataGrid Display:**  
  Displays folder and file details (icon, path, size, and modified date) in a sortable WPF DataGrid.  
  - **Row Coloring:** Folders are highlighted with a light yellow background and files with a light gray background.
  - **Numeric Sorting:** The grid sorts by the underlying numeric size while displaying human-readable size strings.

- **Navigation:**  
  The **Go Back** button allows you to move up one folder level using the current scanned directory.

- **Context Menu Options:**  
  Right-clicking on a row brings up options to:
  - **Open in Explorer:** Launch the selected folder/file in Windows Explorer.
  - **Scan Single:** Display the size of the selected item (measured recursively for folders).
  - **Properties:** View detailed information about the selected item.

- **Standard Header and Footer:**  
  - **Header:** A blue banner with the text "Join / Unjoin Computer Tool".  
  - **Footer:** A light-gray section displaying "© 2025 M.omar (momar.tech) - All Rights Reserved".

## Requirements

- **Operating System:** Windows  
- **PowerShell Version:** PowerShell 5.1 or higher  
- **.NET Framework:** 4.5 or later

## Usage

1. **Launch PowerShell:**  
   Open PowerShell (preferably as Administrator if scanning system directories).

2. **Run the Script:**  
   Navigate to the directory containing `DirectorySizeExplorer.ps1` and execute:
   ```powershell
   .\DirectorySizeExplorer.ps1
   ```

3. **Select a Directory:**  
   - Enter the directory path manually or click the **Browse** button to choose a directory.

4. **Scan the Directory:**  
   - Click **Scan** to scan the directory.
   - If a folder is selected in the results grid, that folder will be scanned instead.
   - If a file is selected, a message is displayed indicating that files cannot be scanned.

5. **Navigate:**  
   - Use the **Go Back** button to move up one folder level from the current folder.

6. **Manage Items:**  
   - **Delete:** Select an item in the grid and click **Delete** to remove it from disk.
   - **Context Menu:** Right-click an item for additional options:
     - **Open in Explorer**
     - **Scan Single** (display the size of just that item)
     - **Properties** (view detailed item information)

7. **Exit the Application:**  
   Click the **Exit** button to close the GUI.

## Customization

- **Header/Footer:**  
  Modify the header and footer text in the XAML section to fit your branding.

- **Appearance:**  
  Adjust the colors, fonts, and layout by editing the XAML.  
  For example, you can change the row colors by modifying the DataGrid.RowStyle.

## Troubleshooting

- **Slow Performance:**  
  Recursive scanning may take time for large directories. Consider scanning smaller directories or optimizing the script for performance if needed.

- **Permissions Issues:**  
  Ensure you have sufficient permissions to access the directories and files you want to scan.

- **Sorting Anomalies:**  
  The grid sorts on the numeric `Size` property while displaying the human-readable `PrettySize`. Ensure your data items maintain consistent property types for correct sorting.

## License

This project is licensed under the [MIT License](https://opensource.org/licenses/MIT).


**Disclaimer**: These scripts are provided as-is. Test them in a staging environment before use in production. The author is not responsible for any unintended outcomes resulting from their use.