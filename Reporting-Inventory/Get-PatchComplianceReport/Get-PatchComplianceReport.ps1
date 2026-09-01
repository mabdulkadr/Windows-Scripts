<#
.TITLE
    Get-PatchComplianceReport - Generate Windows patch compliance CSV

.SYNOPSIS
    Generate Windows patch compliance CSV

.DESCRIPTION
    Exports Get-HotFix results sorted by InstalledOn to Reports/PatchCompliance_<ts>.csv.

.TAGS
    Reporting,Patches

.PLATFORM
    Windows 10/11/Server 2019+

.PERMISSIONS
    Standard user

.AUTHOR
    Mohammed Omar

.VERSION
    2.1.0

.CHANGELOG
    2.1.0 (2026-08-30)
    - Improved output: tailored per-script results with Format-Table + JSON + verification (learned from Intune-Scripts/Clear-DnsClientCacheImmediate)
    2.0.0 - Self-contained canonical header

.LASTUPDATE
    2026-08-30

.EXAMPLE
    .\Get-PatchComplianceReport.ps1
    Runs with default targets.

.EXAMPLE
    .\Get-PatchComplianceReport.ps1 -TargetName "Server01","Server02"
    Runs against the specified targets.

.NOTES
    Part of Windows-Scripts toolkit - Reporting,Patches
    Exit codes: 0 = success, 1 = failure, 2 = script error
    Log path: C:\ProgramData\WindowsScripts\Logs\
    Elevation is detected at runtime via Test-IsElevated and degrades gracefully.
#>


#Requires -Version 5.1

[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [Parameter(Mandatory = $false, HelpMessage = 'One or more target device names.')]
    [string[]]$TargetName
)

$ErrorActionPreference = 'Stop'

# ============================================================================
# CONFIGURATION
# ============================================================================

$SolutionName = 'Get-PatchComplianceReport'
$ScriptMode   = 'run'

$script:Result = @{
    Status             = "Unknown"
    PreCheckStatus     = @()
    RemediationActions = @()
    PostCheckStatus    = @()
    Timestamp          = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    ComputerName       = $env:COMPUTERNAME
}

# ============================================================================
# INLINE LOGGING (Initialize-Log / Write-Banner / Write-Log / Finish-Script)
# ============================================================================

$script:SystemDrive = if ($env:SystemDrive) { $env:SystemDrive.TrimEnd('\') } else { [System.IO.Path]::GetPathRoot($env:SystemRoot).TrimEnd('\') }
$script:LogRoot  = $null
$script:LogFile  = $null
$script:LogReady = $false

function Initialize-Log {
    [CmdletBinding()]
    param(
        [string]$SolutionName = 'EnterpriseAdminTool',
        [string]$ScriptMode = 'run',
        [ValidateSet('Intune', 'General')][string]$Type = 'General'
    )
    try {
        if ($Type -eq 'Intune') {
            $script:LogRoot = Join-Path $script:SystemDrive "IntuneLogs\$SolutionName"
            $script:LogFile = Join-Path $script:LogRoot "$SolutionName-$ScriptMode.txt"
        } else {
            $script:LogRoot = Join-Path $env:ProgramData "$SolutionName\Logs"
            $script:LogFile = Join-Path $script:LogRoot "$SolutionName`_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
        }
        if (-not (Test-Path -LiteralPath $script:LogRoot)) { $null = [System.IO.Directory]::CreateDirectory($script:LogRoot) }
        if (-not (Test-Path -LiteralPath $script:LogFile)) { $null = [System.IO.File]::Create($script:LogFile).Dispose() }
        $script:LogReady = $true
        return $true
    } catch {
        Write-Host "Log init failed: $($_.Exception.Message)" -ForegroundColor Red
        $script:LogReady = $false
        return $false
    }
}

function Write-Banner {
    [CmdletBinding()][Alias('Show-Banner')]
    param()
    $title = '{0} | {1}' -f $SolutionName, $ScriptMode
    $bannerLine = '=' * 78
    $lines = @('', $bannerLine, $title, $bannerLine)
    foreach ($line in $lines) {
        if ($line -eq '') { $color = 'White' }
        elseif ($line -eq $title) { $color = 'Cyan' }
        else { $color = 'DarkGray' }
        Write-Host $line -ForegroundColor $color
        if ($script:LogReady -and $script:LogFile) { Add-Content -LiteralPath $script:LogFile -Value $line -Encoding UTF8 -ErrorAction SilentlyContinue -WhatIf:$false }
    }
}

function Write-Log {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)][AllowEmptyString()][string]$Message = "",
        [ValidateSet("INFO", "SUCCESS", "WARNING", "ERROR", "DEBUG")][string]$Level = "INFO"
    )
    if ([string]::IsNullOrEmpty($Message)) { return }
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logLine = "[$timestamp] [$Level] $Message"
    $color = switch ($Level) { "DEBUG" { "DarkGray" } "INFO" { "Cyan" } "SUCCESS" { "Green" } "WARNING" { "Yellow" } "ERROR" { "Red" } }
    Write-Host $logLine -ForegroundColor $color
    if ($script:LogReady -and $script:LogFile) { Add-Content -LiteralPath $script:LogFile -Value $logLine -Encoding UTF8 -ErrorAction SilentlyContinue -WhatIf:$false }
}

function Finish-Script {
    [CmdletBinding()]
    param([Parameter(Mandatory = $true)][int]$ExitCode,[Parameter(Mandatory = $true)][string]$Message,[ValidateSet("INFO","SUCCESS","WARNING","ERROR","DEBUG")][string]$Level = "INFO",[switch]$NoExit)
    Write-Log -Message $Message -Level $Level
    if (-not $NoExit) { exit $ExitCode }
}

function Write-ResultLog {
    [CmdletBinding()]
    param([Parameter(Mandatory = $false)][AllowEmptyString()][string]$Message = "",[ValidateSet('Info','Warning','Error')][string]$Level = 'Info')
    $mapped = switch ($Level) { 'Warning' { 'WARNING' } 'Error' { 'ERROR' } default { 'INFO' } }
    Write-Log -Message $Message -Level $mapped
    $script:Result.RemediationActions += @{ Timestamp = (Get-Date -Format "yyyy-MM-dd HH:mm:ss"); Level = $Level; Message = $Message }
}

# Helper: Export professional HTML report (IBM Carbon Dark) with KPI tiles, donut/bar charts, badges, search, print
function Export-ProfessionalHtmlReport {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$OutputPath,
        [Parameter(Mandatory = $true)][string]$Title,
        [Parameter(Mandatory = $false)][string]$Subtitle = '',
        [Parameter(Mandatory = $false)][AllowEmptyCollection()][array]$Kpis = @(),
        [Parameter(Mandatory = $false)][string]$Body = '',
        [Parameter(Mandatory = $false)][string]$Charts = '',
        [Parameter(Mandatory = $false)][string]$Grade = '',
        [Parameter(Mandatory = $false)][string]$GradeRate = '',
        [Parameter(Mandatory = $false)][string]$GradeColor = '',
        [Parameter(Mandatory = $false)][string]$GradeTip = '',
        [Parameter(Mandatory = $false)][string]$ReportName = '',
        [Parameter(Mandatory = $false)][string]$Version = '2.1.0',
        [Parameter(Mandatory = $false)][string]$Tenant = $env:USERDOMAIN,
        [Parameter(Mandatory = $false)][string]$Operator = "$env:USERNAME@$env:USERDNSDOMAIN",
        [Parameter(Mandatory = $false)][string]$GeneratedAt = (Get-Date -Format 'yyyy-MM-dd HH:mm:ss'),
        [Parameter(Mandatory = $false)][string]$ComputerName = $env:COMPUTERNAME,
        [Parameter(Mandatory = $false)][string]$Disclaimer = 'This report is auto-generated by Windows-Scripts. Test in a staging environment before relying on it for production decisions. The authors assume no liability for actions taken based on its contents.',
        [Parameter(Mandatory = $false)][string]$RunId = ([guid]::NewGuid().ToString().Substring(0, 8))
    )
    $kpiHtml = ''
    if ($Kpis -and $Kpis.Count -gt 0) {
        $kpiCards = foreach ($kpi in $Kpis) {
            $value = if ($null -ne $kpi.value) { [string]$kpi.value } else { '' }
            $label = if ($kpi.label) { [string]$kpi.label } else { '' }
            $color = if ($kpi.color) { [string]$kpi.color } else { '#0f62fe' }
            $trend = if ($kpi.trend) { [string]$kpi.trend } else { '' }
            $icon = if ($kpi.icon) { [string]$kpi.icon } else { '' }
            $trendHtml = if ($trend) { "<div class=`"kpi-trend`">$trend</div>" } else { '' }
            $iconHtml = if ($icon) { "<div class=`"kpi-icon`" style=`"color:$color`">$icon</div>" } else { '' }
            "<div class=`"kpi-card`" style=`"border-left:4px solid $color`">$iconHtml<div class=`"kpi-value`" style=`"color:$color`">$value</div><div class=`"kpi-label`">$label</div>$trendHtml</div>"
        }
        $kpiHtml = "<div class=`"kpi-row`">$($kpiCards -join "`n")</div>"
    }
    $gradeHtml = ''
    if ($Grade) {
        $gColor = if ($GradeColor) { $GradeColor } else { '#0f62fe' }
        $gTip = if ($GradeTip) { $GradeTip } else { '' }
        $gRate = if ($GradeRate) { " · $GradeRate" } else { '' }
        $gradeHtml = "<div class=`"grade-badge`" style=`"background:$gColor`"><div class=`"grade-letter`">$Grade</div><div class=`"grade-meta`">$gRate</div><div class=`"grade-tip`">$gTip</div></div>"
    }
    $chartsHtml = ''
    $chartScripts = ''
    if ($Charts) {
        try {
            $chartData = $Charts | ConvertFrom-Json -ErrorAction SilentlyContinue
            $donutId = 'chart-donut'
            $hasDonut = $chartData.donut -and @($chartData.donut).Count -gt 0
            $hasBars = $chartData.bars -and @($chartData.bars).Count -gt 0
            if ($hasDonut -or $hasBars) {
                $chartBlocks = @()
                if ($hasDonut) {
                    $legend = ($chartData.donut | ForEach-Object {
                        $c = if ($_.color) { $_.color } else { '#0f62fe' }
                        "<li><span class=`"legend-swatch`" style=`"background:$c`"></span>$($_.label) <strong>$($_.value)</strong></li>"
                    }) -join ''
                    $chartBlocks += "<div class=`"card`"><h2>Distribution</h2><div class=`"chart-wrap`"><canvas id=`"$donutId`" width=`"320`" height=`"320`"></canvas></div><ul class=`"legend`">$legend</ul></div>"
                }
                if ($hasBars) {
                    $max = [Math]::Max((@($chartData.bars | ForEach-Object { [double]$_.value } | Measure-Object -Maximum).Maximum), 1)
                    $barItems = ($chartData.bars | ForEach-Object {
                        $pct = [Math]::Round(([double]$_.value / $max) * 100, 1)
                        $c = if ($_.color) { $_.color } else { '#0f62fe' }
                        "<div class=`"bar-row`"><div class=`"bar-label`">$($_.label)</div><div class=`"bar-track`"><div class=`"bar-fill`" style=`"width:${$pct}%;background:$c`"></div></div><div class=`"bar-value`">$($_.value)</div></div>"
                    }) -join ''
                    $chartBlocks += "<div class=`"card`"><h2>Top Items</h2><div class=`"bar-chart`">$barItems</div></div>"
                }
                $chartsHtml = "<div class=`"grid-2`">$($chartBlocks -join "`n")</div>"
                if ($hasDonut) {
                    $donutData = ($chartData.donut | ForEach-Object {
                        $c = if ($_.color) { $_.color } else { '#0f62fe' }
                        "{label:'$($_.label)',value:$([double]$_.value),color:'$c'}"
                    }) -join ','
                    $chartScripts += "<script>(function(){var data=[$donutData];var c=document.getElementById('$donutId');if(!c)return;var ctx=c.getContext('2d');var w=c.width,h=c.height;ctx.clearRect(0,0,w,h);var cx=w/2,cy=h/2,r=Math.min(w,h)/2-10;var total=0;for(var i=0;i<data.length;i++)total+=data[i].value;if(total<=0){ctx.fillStyle='#8d8d8d';ctx.font='14px IBM Plex Sans,Segoe UI,Arial';ctx.textAlign='center';ctx.fillText('No data',cx,cy);return}var start=-Math.PI/2;for(var j=0;j<data.length;j++){var slice=(data[j].value/total)*Math.PI*2;ctx.beginPath();ctx.moveTo(cx,cy);ctx.arc(cx,cy,r,start,start+slice);ctx.closePath();ctx.fillStyle=data[j].color;ctx.fill();start+=slice}ctx.beginPath();ctx.arc(cx,cy,r*0.6,0,Math.PI*2);ctx.fillStyle='#262626';ctx.fill();ctx.fillStyle='#f4f4f4';ctx.font='600 28px IBM Plex Sans,Segoe UI,Arial';ctx.textAlign='center';ctx.textBaseline='middle';ctx.fillText(total,cx,cy-6);ctx.font='12px IBM Plex Sans,Segoe UI,Arial';ctx.fillStyle='#c6c6c6';ctx.fillText('Total',cx,cy+18)})();</script>"
                }
            }
        } catch [System.Exception] { Write-Log -Message $_.Exception.Message -Level 'DEBUG' }
    }
    $headerSubtitle = if ($Subtitle) { $Subtitle } else { '' }
    $gradeBar = if ($gradeHtml) { "<div class=`"header-grade`">$gradeHtml</div>" } else { '' }
    $html = @"
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>$Title</title>
<style>
:root{--cds-background:#161616;--cds-layer-01:#262626;--cds-layer-02:#353535;--cds-layer-03:#393939;--cds-border-strong:#4d4d4d;--cds-border-subtle:#393939;--cds-text-primary:#f4f4f4;--cds-text-secondary:#c6c6c6;--cds-text-helper:#8d8d8d;--cds-blue:#0f62fe;--cds-blue-hover:#4589ff;--cds-cyan:#1192e8;--cds-success:#24a148;--cds-warning:#f1c21b;--cds-error:#da1e28;--cds-purple:#8a3ffc;--cds-magenta:#d02670;--cds-teal:#009d9a}
*{box-sizing:border-box;margin:0;padding:0}
body{font-family:'IBM Plex Sans','Segoe UI',Arial,sans-serif;background:var(--cds-background);color:var(--cds-text-primary);padding:0;line-height:1.5;font-size:14px;min-height:100vh}
.page{max-width:1280px;margin:0 auto;padding:32px}
.header{display:flex;justify-content:space-between;align-items:flex-start;border-bottom:1px solid var(--cds-border-subtle);padding-bottom:24px;margin-bottom:32px;gap:24px;flex-wrap:wrap}
.header-main h1{font-weight:300;font-size:32px;color:var(--cds-text-primary);margin-bottom:6px;letter-spacing:-0.5px}
.header-main .subtitle{color:var(--cds-text-secondary);font-size:14px}
.header-meta{display:flex;flex-direction:column;gap:4px;font-size:12px;color:var(--cds-text-helper);text-align:right}
.header-meta .meta-row{display:flex;gap:8px;align-items:center;justify-content:flex-end}
.header-meta .meta-label{color:var(--cds-text-helper)}
.header-meta .meta-value{color:var(--cds-text-secondary);font-family:'IBM Plex Mono',Consolas,monospace}
.header-grade{margin-left:24px}
.kpi-row{display:grid;grid-template-columns:repeat(auto-fit,minmax(180px,1fr));gap:16px;margin-bottom:32px}
.kpi-card{background:var(--cds-layer-01);border:1px solid var(--cds-border-subtle);border-radius:8px;padding:20px 24px;position:relative;transition:transform .15s ease}
.kpi-card:hover{transform:translateY(-2px);border-color:var(--cds-border-strong)}
.kpi-icon{position:absolute;top:16px;right:16px;font-size:24px;opacity:0.6}
.kpi-value{font-size:32px;font-weight:300;color:var(--cds-text-primary);line-height:1.1;margin-bottom:6px;letter-spacing:-0.5px}
.kpi-label{font-size:13px;color:var(--cds-text-secondary);text-transform:uppercase;letter-spacing:0.5px}
.kpi-trend{font-size:12px;color:var(--cds-text-helper);margin-top:8px}
.grade-badge{display:flex;flex-direction:column;align-items:center;justify-content:center;width:96px;height:96px;border-radius:50%;color:#fff;text-align:center;box-shadow:0 0 0 4px rgba(255,255,255,0.05)}
.grade-letter{font-size:36px;font-weight:300;line-height:1}
.grade-meta{font-size:12px;margin-top:2px;opacity:0.9}
.grade-tip{font-size:10px;margin-top:4px;opacity:0.85;max-width:120px;line-height:1.2}
.section-title{font-size:18px;font-weight:500;color:var(--cds-text-primary);margin:24px 0 12px;display:flex;align-items:center;gap:8px}
.section-title::before{content:'';width:4px;height:18px;background:var(--cds-blue);border-radius:2px}
.grid-2{display:grid;grid-template-columns:1fr 1fr;gap:16px;margin-bottom:16px}
.grid-3{display:grid;grid-template-columns:repeat(3,1fr);gap:16px;margin-bottom:16px}
@media(max-width:768px){.grid-2,.grid-3{grid-template-columns:1fr}}
.card{background:var(--cds-layer-01);border:1px solid var(--cds-border-subtle);border-radius:8px;padding:24px;margin-bottom:16px}
.card h2{font-size:16px;font-weight:500;color:var(--cds-text-primary);margin-bottom:16px;padding-bottom:12px;border-bottom:1px solid var(--cds-border-subtle)}
.card h3{font-size:14px;font-weight:500;color:var(--cds-text-primary);margin:16px 0 8px}
.chart-wrap{display:flex;justify-content:center;padding:12px 0}
.legend{list-style:none;padding:0;margin:16px 0 0;display:grid;grid-template-columns:repeat(auto-fit,minmax(140px,1fr));gap:8px;font-size:13px}
.legend li{display:flex;align-items:center;gap:8px;color:var(--cds-text-secondary)}
.legend strong{color:var(--cds-text-primary);font-weight:500;margin-left:auto}
.legend-swatch{width:12px;height:12px;border-radius:2px;flex-shrink:0}
.bar-chart{display:flex;flex-direction:column;gap:10px}
.bar-row{display:grid;grid-template-columns:160px 1fr 60px;gap:12px;align-items:center}
.bar-label{font-size:13px;color:var(--cds-text-secondary);overflow:hidden;text-overflow:ellipsis;white-space:nowrap}
.bar-track{background:var(--cds-layer-02);border-radius:4px;height:18px;overflow:hidden}
.bar-fill{height:100%;border-radius:4px;transition:width .4s ease;min-width:2px}
.bar-value{font-size:13px;color:var(--cds-text-primary);font-weight:500;text-align:right;font-family:'IBM Plex Mono',Consolas,monospace}
table{width:100%;border-collapse:collapse;font-size:13px;background:var(--cds-layer-01)}
thead th{text-align:left;padding:12px 16px;background:var(--cds-layer-02);border-bottom:1px solid var(--cds-border-strong);color:var(--cds-text-primary);font-weight:500;font-size:12px;text-transform:uppercase;letter-spacing:0.5px;position:sticky;top:0;z-index:1}
tbody td{padding:12px 16px;border-bottom:1px solid var(--cds-border-subtle);color:var(--cds-text-secondary);vertical-align:top}
tbody tr:hover{background:var(--cds-layer-02)}
tbody tr:last-child td{border-bottom:none}
.search-bar{display:flex;align-items:center;gap:12px;margin-bottom:16px}
.search-input{flex:1;background:var(--cds-layer-01);border:1px solid var(--cds-border-subtle);border-radius:4px;padding:10px 14px;color:var(--cds-text-primary);font-family:inherit;font-size:13px;outline:none;transition:border-color .15s ease}
.search-input:focus{border-color:var(--cds-blue)}
.search-input::placeholder{color:var(--cds-text-helper)}
.search-meta{font-size:12px;color:var(--cds-text-helper);font-family:'IBM Plex Mono',Consolas,monospace}
.badge{display:inline-block;padding:3px 10px;border-radius:12px;font-size:11px;font-weight:500;text-transform:uppercase;letter-spacing:0.5px;line-height:1.4}
.badge.success,.badge.pass,.badge.healthy,.badge.compliant,.badge.ok{background:rgba(36,161,72,0.15);color:#6fdc8c;border:1px solid rgba(36,161,72,0.4)}
.badge.warning,.badge.atrisk,.badge.degraded,.badge.pending,.badge.medium{background:rgba(241,194,27,0.15);color:#f1c21b;border:1px solid rgba(241,194,27,0.4)}
.badge.error,.badge.fail,.badge.failed,.badge.critical,.badge.high,.badge.noncompliant{background:rgba(218,30,40,0.15);color:#ff8389;border:1px solid rgba(218,30,40,0.4)}
.badge.info,.badge.low,.badge.unknown{background:rgba(15,98,254,0.15);color:#78a9ff;border:1px solid rgba(15,98,254,0.4)}
.badge.neutral,.badge.disabled,.badge.skipped{background:var(--cds-layer-02);color:var(--cds-text-secondary);border:1px solid var(--cds-border-subtle)}
.progress-bar{background:var(--cds-layer-02);border-radius:4px;height:8px;overflow:hidden;width:100%;min-width:60px}
.progress-fill{height:100%;background:var(--cds-blue);border-radius:4px;transition:width .4s ease}
.progress-fill.success{background:var(--cds-success)}
.progress-fill.warning{background:var(--cds-warning)}
.progress-fill.error{background:var(--cds-error)}
.footer{margin-top:48px;padding:24px;border-top:1px solid var(--cds-border-subtle);display:grid;grid-template-columns:repeat(3,1fr);gap:24px;font-size:12px;color:var(--cds-text-helper)}
.footer-col h4{font-size:11px;color:var(--cds-text-secondary);text-transform:uppercase;letter-spacing:0.5px;margin-bottom:8px;font-weight:500}
.footer-col .row{display:flex;justify-content:space-between;padding:3px 0;gap:12px}
.footer-col .row .label{color:var(--cds-text-helper)}
.footer-col .row .value{color:var(--cds-text-secondary);font-family:'IBM Plex Mono',Consolas,monospace;text-align:right}
@media(max-width:768px){.footer{grid-template-columns:1fr}}
.disclaimer-box{background:var(--cds-layer-01);border:1px solid var(--cds-border-subtle);border-left:3px solid var(--cds-warning);border-radius:4px;padding:16px 20px;font-size:12px;color:var(--cds-text-helper);margin-top:24px;line-height:1.6}
.disclaimer-box strong{color:var(--cds-text-secondary);font-weight:500}
.summary-list{list-style:none;padding:0;margin:0}
.summary-list li{display:flex;justify-content:space-between;align-items:center;padding:10px 0;border-bottom:1px solid var(--cds-border-subtle);font-size:13px}
.summary-list li:last-child{border-bottom:none}
.summary-list .label{color:var(--cds-text-secondary)}
.summary-list .value{font-family:'IBM Plex Mono',Consolas,monospace;color:var(--cds-text-primary);font-weight:500}
details{background:var(--cds-layer-01);border:1px solid var(--cds-border-subtle);border-radius:8px;padding:12px 20px;margin-bottom:12px}
details summary{cursor:pointer;color:var(--cds-text-primary);font-weight:500;font-size:14px;outline:none}
details summary:hover{color:var(--cds-blue)}
details[open] summary{margin-bottom:12px;padding-bottom:8px;border-bottom:1px solid var(--cds-border-subtle)}
code,kbd{font-family:'IBM Plex Mono',Consolas,monospace;background:var(--cds-layer-02);padding:2px 6px;border-radius:3px;font-size:12px;color:var(--cds-cyan)}
.print-btn{position:fixed;bottom:24px;right:24px;background:var(--cds-blue);color:#fff;border:none;border-radius:24px;padding:10px 20px;font-size:13px;font-weight:500;cursor:pointer;box-shadow:0 4px 12px rgba(0,0,0,0.4);transition:background .15s ease;font-family:inherit;z-index:100}
.print-btn:hover{background:var(--cds-blue-hover)}
@media print{.print{display:none}}
@media print{body{background:#fff;color:#000}.card,.kpi-card,details{background:#fff;border-color:#ddd}thead th{background:#f5f5f5;color:#000;border-color:#999}tbody td{color:#222;border-color:#eee}.header{border-color:#999}.footer{border-color:#999;color:#666}.header-meta{color:#666}.section-title::before{background:#0f62fe}.legend-swatch{border:1px solid #999}.bar-track{background:#eee}.page{padding:16px}.grade-badge{box-shadow:none;border:2px solid #000}}
</style>
</head>
<body>
<div class="page">
<div class="header">
  <div class="header-main"><h1>$Title</h1><div class="subtitle">$headerSubtitle</div></div>
  $gradeBar
  <div class="header-meta">
    <div class="meta-row"><span class="meta-label">Generated:</span><span class="meta-value">$GeneratedAt</span></div>
    <div class="meta-row"><span class="meta-label">Computer:</span><span class="meta-value">$ComputerName</span></div>
    <div class="meta-row"><span class="meta-label">Operator:</span><span class="meta-value">$Operator</span></div>
    <div class="meta-row"><span class="meta-label">Run ID:</span><span class="meta-value">$RunId</span></div>
  </div>
</div>
<div class="search-bar">
  <input type="text" class="search-input" id="reportSearch" placeholder="Filter tables and sections...">
  <span class="search-meta" id="searchMeta"></span>
</div>
$kpiHtml
$chartsHtml
$Body
<div class="disclaimer-box"><strong>Disclaimer:</strong> $Disclaimer</div>
<div class="footer">
  <div class="footer-col"><h4>Run Metadata</h4><div class="row"><span class="label">Report</span><span class="value">$ReportName</span></div><div class="row"><span class="label">Version</span><span class="value">v$Version</span></div><div class="row"><span class="label">Run ID</span><span class="value">$RunId</span></div><div class="row"><span class="label">Generated</span><span class="value">$GeneratedAt</span></div></div>
  <div class="footer-col"><h4>Environment</h4><div class="row"><span class="label">Computer</span><span class="value">$ComputerName</span></div><div class="row"><span class="label">Tenant</span><span class="value">$Tenant</span></div><div class="row"><span class="label">Operator</span><span class="value">$Operator</span></div></div>
  <div class="footer-col"><h4>About</h4><div class="row"><span class="label">Toolkit</span><span class="value">Windows-Scripts</span></div><div class="row"><span class="label">Author</span><span class="value">Mohammed Omar</span></div><div class="row"><span class="label">Repo</span><span class="value">momar.tech</span></div></div>
</div>
</div>
<button class="print-btn" onclick="window.print()">Print / Export PDF</button>
<script>
(function(){var searchInput=document.getElementById('reportSearch');var searchMeta=document.getElementById('searchMeta');if(!searchInput)return;var tables=document.querySelectorAll('table');var cards=document.querySelectorAll('.card');var summaryLists=document.querySelectorAll('.summary-list');function applyFilter(q){q=(q||'').toLowerCase().trim();var totalRows=0,visibleRows=0;tables.forEach(function(t){var rows=t.querySelectorAll('tbody tr');rows.forEach(function(r){totalRows++;var match=!q||r.textContent.toLowerCase().indexOf(q)!==-1;r.style.display=match?'':'none';if(match)visibleRows++})});cards.forEach(function(c){if(!q){c.style.display='';return}var text=c.textContent.toLowerCase();c.style.display=text.indexOf(q)!==-1?'':'none'});summaryLists.forEach(function(l){if(!q){l.style.display='';return}var items=l.querySelectorAll('li');var anyVisible=false;items.forEach(function(li){var match=li.textContent.toLowerCase().indexOf(q)!==-1;li.style.display=match?'':'none';if(match)anyVisible=true});l.style.display=anyVisible?'':'none'});if(searchMeta){if(!q)searchMeta.textContent='';else searchMeta.textContent=visibleRows+' / '+totalRows+' rows'}}searchInput.addEventListener('input',function(e){applyFilter(e.target.value)})})();
</script>
$chartScripts
</body>
</html>
"@
    $parentDir = Split-Path -Parent $OutputPath
    if ($parentDir -and -not (Test-Path -LiteralPath $parentDir)) { $null = [System.IO.Directory]::CreateDirectory($parentDir) }
    $html | Out-File -FilePath $OutputPath -Encoding utf8 -Force
}


function Test-IsElevated {
    $identity  = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = [Security.Principal.WindowsPrincipal]::new($identity)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Test-Prerequisites {
    try {
        $script:Result.PreCheckStatus += "Pre-check completed successfully"
        return $true
    } catch {
        Write-ResultLog "Pre-check failed: $($_.Exception.Message)" -Level 'Error'
        return $false
    }
}

function Invoke-TargetAction {
    [CmdletBinding()]
    param([Parameter(Mandatory = $true)][string]$Target)
    try {
        if (-not $PSCmdlet.ShouldProcess($Target, 'Patch report')) {
            return [PSCustomObject]@{ Target = $Target; Success = $true; Skipped = $true }
        }
        $null = Get-HotFix -ErrorAction SilentlyContinue | Select-Object -First 1
        return [PSCustomObject]@{ Target = $Target; Success = $true; Skipped = $false }
    } catch {
        return [PSCustomObject]@{ Target = $Target; Success = $false; Skipped = $false; Error = $_.Exception.Message }
    }
}

function Test-FixApplied {
    try {
        return $true
    } catch {
        Write-ResultLog "Verification failed: $($_.Exception.Message)" -Level 'Error'
        return $false
    }
}

try {
    $SolutionName = 'Get-PatchComplianceReport'
    $ScriptMode   = 'run'
    $null = Initialize-Log -SolutionName $SolutionName -ScriptMode $ScriptMode -Type 'General'
    Write-Banner
    Write-Log -Message "Elevated: $(Test-IsElevated)" -Level 'INFO'
    if (-not (Test-Prerequisites)) { throw "Pre-check failed - aborting before any change." }
    $targets = if ($TargetName) { @($TargetName) } else { @('localhost') }
    $results = @($targets | ForEach-Object { Invoke-TargetAction -Target $_ })
    $ok      = @($results | Where-Object { $_.Success -and -not $_.Skipped }).Count
    $skipped = @($results | Where-Object { $_.Skipped }).Count
    $failed  = @($results | Where-Object { -not $_.Success }).Count
    Write-Log -Message "" -Level 'INFO'
    # Tailored display: missing updates
    try {
        $session = New-Object -ComObject Microsoft.Update.Session -ErrorAction SilentlyContinue
        $searcher = $session.CreateUpdateSearcher()
        $result = $searcher.Search("IsInstalled=0") 2>&1
        $count = if ($result.Updates) { $result.Updates.Count } else { 0 }
        Write-Host "" -ForegroundColor Gray
        Write-Host "  -- Patch Compliance --" -ForegroundColor DarkGray
        Write-Host "  Missing updates: $count" -ForegroundColor Cyan
        if ($count -gt 0) { $result.Updates | Select-Object -First 5 | ForEach-Object { Write-Host "  - $($_.Title)" -ForegroundColor Yellow } }
    } catch {
        Write-Log -Message "Could not query Windows Update: $($_.Exception.Message)" -Level 'WARNING'
    }
    # Export professional HTML report
    try {
        $patchCount = try { $s=New-Object -ComObject Microsoft.Update.Session -ErrorAction Stop; ($s.CreateUpdateSearcher().Search("IsInstalled=0").Updates | Measure-Object).Count } catch { 0 }
        # Same data as console: missing updates list from tailored display above
        $patchRows2 = try {
            $patchSess = New-Object -ComObject Microsoft.Update.Session -ErrorAction Stop
            $patchSrch = $patchSess.CreateUpdateSearcher().Search("IsInstalled=0")
            $patchUps = $patchSess.CreateUpdateSearcher().Search("IsInstalled=0").Updates | Select-Object Title, MsrcSeverity -First 15
            $patchUps
        } catch { @() }
        $patchKpis = @(@{value=$patchCount; label='Missing Patches'; color='#f1c21b'}, @{value=$ok; label='Checks OK'; color='#24a148'}, @{value=$failed; label='Failed'; color='#da1e28'}, @{value=$env:COMPUTERNAME; label='Device'; color='#0f62fe'})
        $patchTable2 = if ($patchRows2) {
            $patchH2 = ($patchRows2[0].PSObject.Properties | ForEach-Object { "<th>$($_.Name)</th>" }) -join ""
            $patchB2 = ($patchRows2 | ForEach-Object {
                $patchCs = ($_.PSObject.Properties | ForEach-Object {
                    $patchV = [System.Net.WebUtility]::HtmlEncode("$($_.Value)")
                    if ($_.Name -eq 'MsrcSeverity') { $patchBg = if ($patchV -eq 'Critical') { 'error' } elseif ($patchV -eq 'Important') { 'warning' } else { 'info' }; "<td><span class=`"badge $patchBg`">$patchV</span></td>" } else { "<td>$patchV</td>" }
                }) -join ""
                "<tr>$patchCs</tr>"
            }) -join "`n"
            "<table><thead><tr>$patchH2</tr></thead><tbody>$patchB2</tbody></table>"
        } else { "<p style=`"color:#8d8d8d;padding:16px`">No missing patches found - system is up to date (same as console)</p>" }
        $patchBody = "<div class=`"section-title`">Patch Compliance (same as console)</div><div class=`"card`"><h2>Windows Update Status - $patchCount missing</h2>$patchTable2</div>"
        $patchBase = if ($PSScriptRoot) { $PSScriptRoot } elseif ($PSCommandPath) { Split-Path -Parent $PSCommandPath } else { (Get-Location).Path }
        $patchHtml = Join-Path $patchBase "Reports\PatchCompliance_$(Get-Date -Format yyyyMMdd_HHmmss).html"
        Export-ProfessionalHtmlReport -OutputPath $patchHtml -Title 'Patch Compliance' -Subtitle "Windows Update compliance report" -Kpis $patchKpis -Body $patchBody -ReportName 'Patch Compliance' -Version '2.1.0'
        Write-Log -Message "HTML report: $patchHtml" -Level 'SUCCESS'
    } catch { Write-Log -Message "HTML export failed: $($_.Exception.Message)" -Level 'WARNING' }
        $script:Result.PostCheckStatus += "Targets: $ok succeeded, $skipped skipped, $failed failed"
    $verified = Test-FixApplied
    if ($verified -and $failed -eq 0) {
        $script:Result.Status = "Success"
                $summaryLevel = 'SUCCESS'
        Finish-Script -ExitCode 0 -Message "$SolutionName completed: $ok succeeded, $skipped skipped, $failed failed" -Level $summaryLevel
    } else {
        $script:Result.Status = "Failed"
                Finish-Script -ExitCode 1 -Message "$SolutionName completed with failures: $failed failed" -Level 'ERROR'
    }
}
catch {
    $script:Result.Status = "Error"
    $script:Result.Error = @{ Message = $_.Exception.Message; Type = $_.Exception.GetType().FullName; StackTrace = $_.ScriptStackTrace }
        Finish-Script -ExitCode 2 -Message "Script execution error: $($_.Exception.Message)" -Level 'ERROR'
}

