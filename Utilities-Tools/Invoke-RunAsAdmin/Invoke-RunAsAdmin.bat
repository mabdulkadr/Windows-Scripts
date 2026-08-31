@echo off
REM -------------------------------------------------------------------
REM Script: RunAsAdmin.bat
REM Purpose:
REM This script changes the working directory to the location of the 
REM script and executes the specified program ('example.exe') with 
REM administrative privileges using the `RUNASINVOKER` compatibility 
REM layer.
REM -------------------------------------------------------------------

REM Step 1: Change the working directory to the script's location
REM Ensures the script operates from its own directory
cd /d "%~dp0"

REM Step 2: Execute the program with RUNASINVOKER compatibility layer
REM - __COMPAT_LAYER=RUNASINVOKER: Forces the program to use the user's 
REM   permissions as invoked, bypassing UAC prompts.
REM - start: Launches the program in a separate process.
REM - Replace "example.exe" with your desired executable's name or path.
C:\Windows\System32\cmd.exe /min /C "set __COMPAT_LAYER=RUNASINVOKER && start "" "example.exe"""

REM Step 3: Exit the script gracefully
exit /b 0
