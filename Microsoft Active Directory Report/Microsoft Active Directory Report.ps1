<#
.SYNOPSIS
    Automates the creation of a Microsoft Active Directory As Built Report.

.DESCRIPTION
    - Detects the domain controller and current user automatically.
    - Ensures required PowerShell modules and RSAT tools are installed.
    - Configures PSRemoting on the domain controller securely.
    - Creates directories for configuration and output.
    - Handles existing configuration files by overwriting them if necessary.
    - Generates the report in specified formats (e.g., Word, HTML).

.NOTES
    - Run this script with administrative privileges.
    - Ensure the system is domain-joined and can access the domain controller.

.NOTES
    Author  : Mohammad Abdulkader Omar
    Website : momar.tech
    Date    : 2024-12-03
#>

# Define parameters for output directory and report format
param (
    [string]$OutputPath = "C:\Reports",      # Directory to store the generated report
    [string]$ReportFormat = "Word,HTML"     # Supported formats: Word, HTML, or Text
)

# Function to check and install required PowerShell modules
function Install-ModuleIfMissing {
    param (
        [string]$ModuleName
    )
    if (-not (Get-Module -ListAvailable -Name $ModuleName)) {
        Write-Host "Installing module: $ModuleName" -ForegroundColor Green
        Install-Module -Name $ModuleName -Force -ErrorAction Stop
    } else {
        Write-Host "Module $ModuleName is already installed." -ForegroundColor Cyan
    }
}

# Step 1: Detect Domain Controller and Logged-In User
Write-Host "Detecting domain controller and user..." -ForegroundColor Green
try {
    $DomainController = (Get-ADDomainController -Discover -Service "PrimaryDC").HostName
    Write-Host "Domain Controller detected: $DomainController" -ForegroundColor Cyan
} catch {
    Write-Host "Failed to detect domain controller. Ensure RSAT tools are installed and the system is domain-joined." -ForegroundColor Red
    exit
}

$Username = "$env:USERDOMAIN\$env:USERNAME"
Write-Host "Using logged-in user: $Username" -ForegroundColor Cyan

# Step 2: Enable PSRemoting on the Domain Controller
Write-Host "Enabling PSRemoting on the domain controller: $DomainController" -ForegroundColor Green
try {
    Enable-PSRemoting -Force -SkipNetworkProfileCheck
    Write-Host "PSRemoting enabled successfully." -ForegroundColor Green

    # Verify firewall rules
    Write-Host "Verifying firewall rules for PSRemoting..." -ForegroundColor Green
    $firewallRules = Get-NetFirewallRule -DisplayName "Windows Remote Management (HTTP-In)" | Where-Object { $_.Enabled -eq $true }
    if ($firewallRules) {
        Write-Host "Firewall rules for PSRemoting are configured correctly." -ForegroundColor Cyan
    } else {
        Write-Host "Firewall rules for PSRemoting are not enabled. Please verify manually." -ForegroundColor Red
    }
} catch {
    Write-Host "Failed to enable PSRemoting. Error: $_" -ForegroundColor Red
    exit
}

# Step 3: Install Required PowerShell Modules
Write-Host "Checking and installing required PowerShell modules..." -ForegroundColor Green
Install-ModuleIfMissing -ModuleName "PSPKI"
Install-ModuleIfMissing -ModuleName "AsBuiltReport.Microsoft.AD"

# Step 4: Install RSAT Features (Windows Server or Windows 10+)
Write-Host "Checking and installing required Windows features or capabilities..." -ForegroundColor Green
if ($env:OS -match "Windows_NT") {
    try {
        if ((Get-WindowsFeature -Name RSAT-AD-PowerShell).Installed -eq $false) {
            Write-Host "Installing RSAT features for Windows Server..." -ForegroundColor Green
            Install-WindowsFeature -Name RSAT-AD-PowerShell, RSAT-ADCS, RSAT-ADCS-Mgmt, RSAT-DNS-Server, GPMC -IncludeAllSubFeature -ErrorAction Stop
        } else {
            Write-Host "RSAT features are already installed." -ForegroundColor Cyan
        }
    } catch {
        Write-Host "Installing RSAT capabilities for Windows 10..." -ForegroundColor Green
        Add-WindowsCapability -Online -Name 'Rsat.ActiveDirectory.DS-LDS.Tools~~~~0.0.1.0'
        Add-WindowsCapability -Online -Name 'Rsat.CertificateServices.Tools~~~~0.0.1.0'
        Add-WindowsCapability -Online -Name 'Rsat.GroupPolicy.Management.Tools~~~~0.0.1.0'
        Add-WindowsCapability -Online -Name 'Rsat.Dns.Tools~~~~0.0.1.0'
    }
}

# Step 5: Ensure Output and Configuration Directories Exist
Write-Host "Checking output directory..." -ForegroundColor Green
if (-not (Test-Path -Path $OutputPath)) {
    New-Item -Path $OutputPath -ItemType Directory -Force | Out-Null
    Write-Host "Output directory created: $OutputPath" -ForegroundColor Green
} else {
    Write-Host "Output directory already exists: $OutputPath" -ForegroundColor Yellow
}

Write-Host "Setting up configuration directory..." -ForegroundColor Green
$ConfigPath = Join-Path -Path $OutputPath -ChildPath "Config"

if (-not (Test-Path -Path $ConfigPath)) {
    New-Item -Path $ConfigPath -ItemType Directory -Force | Out-Null
    Write-Host "Configuration directory created at: $ConfigPath" -ForegroundColor Green
} else {
    Write-Host "Configuration directory already exists: $ConfigPath" -ForegroundColor Yellow
}

# Step 6: Generate Configuration File
Write-Host "Generating report configuration file..." -ForegroundColor Green
$ConfigFile = Join-Path -Path $ConfigPath -ChildPath "MicrosoftADConfig.json"

if (Test-Path -Path $ConfigFile) {
    Write-Host "Configuration file already exists at: $ConfigFile" -ForegroundColor Yellow
    Write-Host "Overwriting the existing configuration file..." -ForegroundColor Green
    New-AsBuiltReportConfig -Report Microsoft.AD -FolderPath $ConfigPath -Filename "MicrosoftADConfig" -Force
} else {
    New-AsBuiltReportConfig -Report Microsoft.AD -FolderPath $ConfigPath -Filename "MicrosoftADConfig"
}

# Step 7: Generate the Microsoft AD As Built Report
Write-Host "Generating the Microsoft AD As Built Report..." -ForegroundColor Green
try {
    # Split formats into an array if multiple formats are specified
    $Formats = $ReportFormat -split ","
    foreach ($Format in $Formats) {
        New-AsBuiltReport -Report Microsoft.AD -Target $DomainController -Username $Username -Format $Format.Trim() -OutputFolderPath $OutputPath -Timestamp
        Write-Host "Report in $Format format generated successfully at $OutputPath" -ForegroundColor Green
    }
} catch {
    Write-Host "Error generating report: $_" -ForegroundColor Red
}
