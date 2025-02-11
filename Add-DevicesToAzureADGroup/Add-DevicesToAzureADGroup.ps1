<#
    .Synopsis
        PowerShell script to add devices (from CSV file) to an Azure AD Group.
    
    .DESCRIPTION
        PowerShell script used to bulk add devices to a group in Azure AD, as the Azure AD bulk import functionality requires Device GUIDs rather than the Device Name. 
           This script looks up the device based on it's name and then adds the device to the specified group.
    
    .EXAMPLE
        .\Add-DevicesToAzureAdGroup.ps1 -GroupName "Device Test Group" -InputFile "C:\Scripts\DevicesToAdd.csv"
	   
    .NOTES
	        Author:  Andrew Silcock
	        Version: 1.0
          Created: 27-Sep-2022
          Updated: 27-Sep-2022
    
     .LINK
        https://github.com/andrewitdevlab/blog-content/Azure AD/Scripts/Add Devices to Group/Add-DevicesToAzureAdGroup.ps1
#>
param
(
    [parameter(Mandatory=$true)]
    [string] $GroupName,
    [parameter(Mandatory=$true)]
    [string] $InputFile

)

function Create-AzureADConnection
{
    # Helper function that runs a cmdlet, and if the exception relates to a connection being required to Azure AD call Connect-AzureAD
    try
    {
        Get-AzureADTenantDetail | Out-Null
    }
    catch [Microsoft.Open.Azure.AD.CommonLibrary.AadNeedAuthenticationException]
    {
        Connect-AzureAD
    }
    catch
    {
        Write-Error "An exception has occurred attepmting to connect to Azure AD"
        Exit -1
    }
}

Import-Module AzureAD
Create-AzureADConnection

# Get the group object from Azure AD
#
$AzureAdGroup = Get-AzureADGroup -Filter ("DisplayName eq '{0}'" -f $GroupName)
if (-not $AzureAdGroup)
{
    Write-Warning ("A group with the name '{0}' was not found.`n`tThe script is exiting with no actions performed" -f $GroupName)
    exit -1
}

# Get devices input file
#
$DeviceCsv = Import-Csv -Path $InputFile -ErrorAction Stop
if (-not $DeviceCsv)
{
    Write-Warning ("An error has occurred reading the device CSV file: '{0}'. The script is exiting with no actions performed" -f $InputFile)
    exit -1
}

# Add the devices the group retrieved from Azure AD
#
$counter = 1
foreach ($DeviceInfo in $DeviceCsv)
{
    "{0} of {1} - Processing the device '{2}'" -f $counter, $DeviceCsv.Count, $DeviceInfo.DeviceName
    
    # Get the device object (as we need the Object ID to add it to the group)
    $AzureAdDevices = Get-AzureADDevice -SearchString $DeviceInfo.DeviceName
    
    # If there are device(s) found in Azure AD - add them to the group
    #
    if ($AzureAdDevices)
    {
        # need to loop, as its possible multiple devices exist with the same name
        foreach ($Device in $AzureAdDevices)
        {
            "`tAdding the device with the device ID: {1})" -f $DeviceInfo.DeviceName, $Device.ObjectId
            try
            {
                Add-AzureADGroupMember -ObjectId $AzureAdGroup.ObjectId -RefObjectId $Device.ObjectId
            }
            catch
            {
                Write-Warning "An exception occurred adding the device to the group, it most likely already exists in the group"
            }
        }
    }
    else
    {
        Write-Warning "The device could not be found in Azure AD"
    }
    ""
    $counter++
}
