<#
.SYNOPSIS
Generates detailed documentation for Microsoft 365 components, supporting dynamic section inclusion and exclusion.

.DESCRIPTION
This script provides a menu-driven interface to select components and optionally specify sections to include or exclude. It dynamically validates inputs to ensure compatibility with the `Get-M365Doc` cmdlet.

.NOTES
Ensure the Azure AD application has appropriate permissions for the Microsoft Graph API.

.NOTES
    Author  : Mohammad Abdulkader Omar
    Website : momar.tech
    Date    : 2024-12-03
#>

# Define credentials

$TenantId		 = '<Your-Tenant-ID>'
$ClientId		 = '<Your-App-ID>'
$ClientSecret		 = '<Your-App-Secret>'
$OutputDirectory	 = "C:\Temp"

# Install required modules
Write-Host "Installing required PowerShell modules..." -ForegroundColor Yellow
$modules = @('MSAL.PS', 'PSWriteOffice', 'M365Documentation')
foreach ($module in $modules) {
    if (-not (Get-Module -Name $module -ListAvailable)) {
        Write-Host "Installing module: $module..." -ForegroundColor Cyan
        Install-Module -Name $module -Force -ErrorAction Stop
    } else {
        Write-Host "Module $module is already installed." -ForegroundColor Green
    }
}

# Validate output directory
if (-not (Test-Path -Path $OutputDirectory)) {
    Write-Host "Creating output directory: $OutputDirectory..." -ForegroundColor Yellow
    New-Item -ItemType Directory -Path $OutputDirectory -Force
}

# Convert ClientSecret to SecureString
$SecureClientSecret = ConvertTo-SecureString $ClientSecret -AsPlainText -Force

# Connect to the M365 tenant
try {
    Write-Host "Connecting to Microsoft 365 tenant..." -ForegroundColor Yellow
    Connect-M365Doc -ClientId $ClientId -ClientSecret $SecureClientSecret -TenantId $TenantId
    Write-Host "Successfully connected to the Microsoft 365 tenant." -ForegroundColor Green
} catch {
    Write-Error "Failed to connect to Microsoft 365 tenant. Please verify credentials and try again."
    exit
}

# Menu for selecting components
$componentsMenu = @{
    "1" = "Intune"
    "2" = "AzureAD"
}
Write-Host "Select the component to document:" -ForegroundColor Cyan
$componentsMenu.Keys | Sort-Object | ForEach-Object { Write-Host "$_ - $($componentsMenu[$_])" }

# Capture user choice
$componentChoice = Read-Host "Enter your choice (1-5)"
$selectedComponent = $componentsMenu[$componentChoice]

# Validate choice
if (-not $selectedComponent) {
    Write-Error "Invalid choice. Exiting script."
    exit
}

# Collect optional section information
Write-Host "You selected: $selectedComponent" -ForegroundColor Cyan
$includeSections = Read-Host "Enter sections to include (comma-separated, leave blank for all)"
$excludeSections = Read-Host "Enter sections to exclude (comma-separated, leave blank for none)"

# Process Include and Exclude Sections
$includeSectionsArray = if ($includeSections -ne "") { $includeSections -split ",\s*" } else { $null }
$excludeSectionsArray = if ($excludeSections -ne "") { $excludeSections -split ",\s*" } else { $null }

try {
    Write-Host "Collecting $selectedComponent documentation..." -ForegroundColor Yellow
    
    # Collect documentation, only pass IncludeSections or ExcludeSections if they are not null
    if ($includeSectionsArray -and $excludeSectionsArray) {
        $doc = Get-M365Doc -Components $selectedComponent `
            -IncludeSections $includeSectionsArray `
            -ExcludeSections $excludeSectionsArray
    } elseif ($includeSectionsArray) {
        $doc = Get-M365Doc -Components $selectedComponent `
            -IncludeSections $includeSectionsArray
    } elseif ($excludeSectionsArray) {
        $doc = Get-M365Doc -Components $selectedComponent `
            -ExcludeSections $excludeSectionsArray
    } else {
        $doc = Get-M365Doc -Components $selectedComponent
    }

    # Define output file path with timestamp
    $timestamp = (Get-Date).ToString("yyyyMMddHHmm")
    $OutputFile = Join-Path -Path $OutputDirectory -ChildPath "$timestamp-$selectedComponent-Documentation.docx"

    # Output documentation to Word file
    Write-Host "Writing documentation to: $OutputFile..." -ForegroundColor Yellow
    $doc | Write-M365DocWord -FullDocumentationPath $OutputFile
    Write-Host "Documentation for $selectedComponent successfully generated at $OutputFile." -ForegroundColor Green
} catch {
    Write-Error "An error occurred while generating documentation. Error: $_"
    exit
}

# Completion message
Write-Host "Script completed successfully!" -ForegroundColor Green
