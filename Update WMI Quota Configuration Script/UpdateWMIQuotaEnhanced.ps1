<#
.SYNOPSIS
   Updates WMI quota configuration to increase limits for better performance.

.DESCRIPTION
   This script modifies the WMI Provider Host Quota Configuration settings to increase
   the quotas for memory usage and handle limits. These settings are essential in 
   environments with high WMI activity to prevent errors due to quota exhaustion.

.PARAMETER MemoryPerHost
   The maximum memory allowed per host. Default is 1 GB (1073741824 bytes).

.PARAMETER HandlesPerHost
   The maximum number of handles allowed per host. Default is 8192.

.OUTPUTS
   Displays the updated WMI quota settings.

.NOTES
   - Ensure the script is run with administrative privileges.
   - This script applies changes to the root namespace (__ProviderHostQuotaConfiguration).
   - Compatible with Windows operating systems where these properties exist.
#>

# Define the target WMI namespace and class
$namespace = "root"
$providerHostQuotaClass = "__ProviderHostQuotaConfiguration"

try {
    # Retrieve the WMI quota configuration object
    Write-Host "Retrieving WMI quota configuration..." -ForegroundColor Cyan
    $quotaConfig = Get-WmiObject -Namespace $namespace -Class $providerHostQuotaClass

    # Display the current quota settings
    Write-Host "Current WMI Quota Settings:" -ForegroundColor Yellow
    $quotaConfig | Select-Object MemoryPerHost, MemoryAllHosts, ProcessLimitAllHosts | Format-Table -AutoSize

    # Update quota settings with specified values
    Write-Host "Updating WMI Quota Settings..." -ForegroundColor Cyan
    $quotaConfig.MemoryPerHost = 1073741824    # 1 GB
    $quotaConfig.MemoryAllHosts = 4294967296  # 4 GB (unchanged)
    $quotaConfig.ProcessLimitAllHosts = 20    # 20 processes for all hosts
    # Add HandlesPerHost property if it exists
    if ($quotaConfig.PSObject.Properties.Match("HandlesPerHost")) {
        $quotaConfig.HandlesPerHost = 8192      # 8192 handles per host
    }

    # Save the changes
    $quotaConfig.Put() | Out-Null
    Write-Host "WMI Quota settings have been updated successfully!" -ForegroundColor Green

    # Display the updated quota settings
    Write-Host "Updated WMI Quota Settings:" -ForegroundColor Yellow
    $quotaConfig | Select-Object MemoryPerHost, MemoryAllHosts, ProcessLimitAllHosts, HandlesPerHost | Format-Table -AutoSize

} catch {
    # Handle errors and display meaningful messages
    Write-Host "An error occurred while updating the WMI quota settings." -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
}

# End of script
