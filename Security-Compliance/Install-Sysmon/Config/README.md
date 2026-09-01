# Config

Bundled Sysmon binaries and configuration file for the Install-Sysmon script.

## Contents

- Sysmon.exe / Sysmon64.exe — Sysmon driver binary (Mark Russinovich / SwiftOnSecurity fork).
- sysmonconfig.xml — SwiftOnSecurity sysmon-config.xml baseline (community-curated).

These files are required by the parent Install-Sysmon.ps1 script. They are intentionally tracked in the repository so the script runs out-of-the-box; the .gitignore excludes the contents if you swap to a download-based payload.

