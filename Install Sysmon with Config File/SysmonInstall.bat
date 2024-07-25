
@echo off
REM Change directory to the location of the script
cd /d "%~dp0"

REM Install Sysmon with the specified configuration file silently
Sysmon64.exe -accepteula -i sysmonconfig.xml 

exit
