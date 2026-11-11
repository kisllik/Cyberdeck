#Requires -Version 5.1
<#
    Night City OS - autorun setup
      .\Install-NightCityShell.ps1              enable autostart
      .\Install-NightCityShell.ps1 -Uninstall   disable autostart
      .\Install-NightCityShell.ps1 -Run         start right now
#>
[CmdletBinding()]
param(
    [switch]$Uninstall,
    [switch]$Run
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$shellScript = Join-Path $root 'NightCityShell.ps1'
$vbs = Join-Path $root 'NightCityShell.vbs'
$runKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'
$runName = 'NightCityShell'
$ieKey = 'HKCU:\Software\Microsoft\Internet Explorer\Main\FeatureControl\FEATURE_BROWSER_EMULATION'

if ($Run) {
    if (-not (Test-Path $shellScript)) { throw "Not found: $shellScript" }
    $args = @('-NoLogo', '-NoProfile', '-STA', '-ExecutionPolicy', 'Bypass', '-WindowStyle', 'Hidden', '-File', ('"' + $shellScript + '"'), '-Shell')
    Start-Process -FilePath 'powershell.exe' -ArgumentList $args
    Write-Host 'Night City OS launched.' -ForegroundColor Green
    return
}

if ($Uninstall) {
    Remove-ItemProperty -Path $runKey -Name $runName -ErrorAction SilentlyContinue
    try { Set-ItemProperty -Path 'HKCU:\Software\NightCityOS' -Name 'ReplaceDesktop' -Value 0 -Type DWord } catch {}
    if (-not (Get-Process -Name explorer -ErrorAction SilentlyContinue)) { Start-Process explorer.exe }
    foreach ($exe in @('powershell.exe', 'pwsh.exe')) {
        Remove-ItemProperty -Path $ieKey -Name $exe -ErrorAction SilentlyContinue
    }
    Write-Host 'Autostart disabled. explorer.exe was never replaced, nothing to restore.' -ForegroundColor Yellow
    Write-Host ('Files are still in ' + $root)
    return
}

if (-not (Test-Path $shellScript)) { throw "Not found: $shellScript" }
if (-not (Test-Path $vbs)) { throw "Not found: $vbs" }

if (-not (Test-Path $ieKey)) { New-Item -Path $ieKey -Force | Out-Null }
foreach ($exe in @('powershell.exe', 'pwsh.exe')) {
    Set-ItemProperty -Path $ieKey -Name $exe -Value 11001 -Type DWord
}

if (-not (Test-Path $runKey)) { New-Item -Path $runKey -Force | Out-Null }
$value = 'wscript.exe //B "' + $vbs + '"'
New-ItemProperty -Path $runKey -Name $runName -Value $value -PropertyType String -Force | Out-Null

try {
    if (-not (Test-Path 'HKCU:\Software\NightCityOS')) { New-Item -Path 'HKCU:\Software\NightCityOS' -Force | Out-Null }
    Set-ItemProperty -Path 'HKCU:\Software\NightCityOS' -Name 'ReplaceDesktop' -Value 1 -Type DWord
} catch {}

Write-Host ''
Write-Host '  NIGHT CITY OS // INSTALLED' -ForegroundColor Red
Write-Host ('  autostart : HKCU\...\Run\' + $runName) -ForegroundColor DarkGray
Write-Host ('  launcher  : ' + $vbs) -ForegroundColor DarkGray
Write-Host ''
Write-Host '  Start now :' -ForegroundColor Gray
Write-Host '    .\NightCityShell.cmd' -ForegroundColor White
Write-Host '  Disable   :' -ForegroundColor Gray
Write-Host '    .\Install-NightCityShell.ps1 -Uninstall' -ForegroundColor White
Write-Host '  Panic key : Ctrl+Shift+Q' -ForegroundColor Gray
Write-Host ''
