<#
.SYNOPSIS
    Enables the Fast Startup feature in Windows.

.DESCRIPTION
    This script sets the `HiberbootEnabled` registry value to `1`, which enables the Fast Startup feature.
    Fast Startup helps reduce boot time by saving system state to a hibernation file. It requires that Hibernation is enabled on the system.

.EXAMPLE
    .\Enable_Fast_Startup.ps1
#>

# Set the registry key to enable Fast Startup
$RegistryPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power"
$PropertyName = "HiberbootEnabled"
$PropertyValue = 1

# Apply the registry change
Set-ItemProperty -Path $RegistryPath -Name $PropertyName -Value $PropertyValue -Type DWORD -Force -Confirm:$False
