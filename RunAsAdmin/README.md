
# RunAsAdmin.bat

![License](https://img.shields.io/badge/license-MIT-blue.svg)
![Version](https://img.shields.io/badge/version-1.0.0-green.svg)

## Description
The `RunAsAdmin.bat` script is a simple yet effective tool designed to run a specified program (`example.exe`) with administrative privileges using the `RUNASINVOKER` compatibility layer. This ensures the program executes without triggering a UAC (User Account Control) prompt, leveraging the current user's permissions.

---

## Features
- **Compatibility Layer**: Uses the `RUNASINVOKER` compatibility layer to ensure the program runs with the invoking user's context.
- **Automatic Directory Handling**: Dynamically adjusts the working directory to the script's location for seamless execution.
- **Lightweight and Customizable**: Simple structure for quick modifications and straightforward use.

---

## How It Works
1. **Directory Adjustment**: The script changes the current working directory to the script's location.
2. **Compatibility Layer**: Sets the `__COMPAT_LAYER=RUNASINVOKER` environment variable to bypass UAC prompts.
3. **Program Execution**: Launches the specified program (`example.exe`) using the compatibility layer.

---

## Prerequisites
- The program to be executed (`example.exe`) should be in the same directory as the script, or you must provide the absolute path to the program in the script.

---

## Usage
1. Place the script (`RunAsAdmin.bat`) and the program (`example.exe`) in the same folder.
2. Run the script by double-clicking it or executing it from the command line:
   ```cmd
   RunAsAdmin.bat
   ```
3. The script will automatically:
   - Change to the directory containing the script.
   - Use the `RUNASINVOKER` compatibility layer to execute the program.

---

## Customization
- Replace `example.exe` in the script with the name of the program you wish to run.
- If the program is located in another folder, update the script with the program's full path:
   ```batch
   start "" "C:\Path\To\YourProgram.exe"
   ```

---

## Troubleshooting
- **Program Doesn't Start**:
  - Ensure `example.exe` exists in the same directory as the script.
  - Verify the program's name and path in the script.
- **Unexpected Errors**:
  - Check that the `cmd.exe` and `RUNASINVOKER` layer are supported on your Windows version.
- **Permission Issues**:
  - This script does not override permission-related access issues for files or system resources.

---

## Example Script
The script executes as follows:
```batch
@echo off
REM Change directory to the location of the script
cd /d "%~dp0"

REM Run the program with RUNASINVOKER compatibility layer
C:\Windows\System32\cmd.exe /min /C "set __COMPAT_LAYER=RUNASINVOKER && start "" "example.exe""
```

---

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Disclaimer

These scripts are provided "as is" without warranty of any kind. Use them at your own risk. Always test scripts in a controlled environment before deploying them in a production environment.
