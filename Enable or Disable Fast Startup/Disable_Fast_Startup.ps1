<#
.SYNOPSIS
    Disables the Fast Startup feature in Windows.

.DESCRIPTION
    This script sets the `HiberbootEnabled` registry value to `0`, which disables the Fast Startup feature.
    Fast Startup combines elements of hibernation and shutdown to speed up boot time, but it can interfere with some updates or dual-boot setups.

.EXAMPLE
    .\Disable_Fast_Startup.ps1
#>

# Set the registry key to disable Fast Startup
$RegistryPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power"
$PropertyName = "HiberbootEnabled"
$PropertyValue = 0

# Apply the registry change
Set-ItemProperty -Path $RegistryPath -Name $PropertyName -Value $PropertyValue -Type DWORD -Force -Confirm:$False
