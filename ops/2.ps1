# ops/2 - System Health Report (Windows). Read-only: collects and prints a
# summary (OS, CPU, RAM, drives, battery, key services, recent critical events,
# pending reboot). Changes nothing. Works without admin (reports less).

$ErrorActionPreference = 'SilentlyContinue'

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
          ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

function Format-GB($bytes) { "{0:N1} GB" -f ($bytes / 1GB) }
function Section($t) { Write-Host ("`n== {0} ==" -f $t) -ForegroundColor Cyan }

Write-Host "== System Health Report ==" -ForegroundColor Green
if (-not $isAdmin) { Write-Host "[!] Not admin: some details (event log, services) may be limited." -ForegroundColor Yellow }

$os = Get-CimInstance Win32_OperatingSystem
Section "System"
Write-Host ("  OS       : {0} (build {1})" -f $os.Caption, $os.BuildNumber)
Write-Host ("  Host     : {0}" -f $env:COMPUTERNAME)
if ($os.LastBootUpTime) {
  $up = (Get-Date) - $os.LastBootUpTime
  Write-Host ("  Uptime   : {0}d {1}h {2}m" -f $up.Days, $up.Hours, $up.Minutes)
}

Section "CPU / Memory"
$cpu = Get-CimInstance Win32_Processor | Select-Object -First 1
Write-Host ("  CPU      : {0}" -f $cpu.Name.Trim())
Write-Host ("  CPU load : {0}%" -f $cpu.LoadPercentage)
$totalRam = $os.TotalVisibleMemorySize * 1KB
$freeRam  = $os.FreePhysicalMemory * 1KB
$usedRam  = $totalRam - $freeRam
$ramPct   = if ($totalRam) { [math]::Round($usedRam / $totalRam * 100) } else { 0 }
Write-Host ("  RAM      : {0} / {1} used ({2}%)" -f (Format-GB $usedRam), (Format-GB $totalRam), $ramPct)

Section "Drives"
Get-CimInstance Win32_LogicalDisk -Filter "DriveType=3" | ForEach-Object {
  if ($_.Size) {
    $pct = [math]::Round($_.FreeSpace / $_.Size * 100)
    Write-Host ("  {0} {1} free / {2} total ({3}% free)" -f $_.DeviceID, (Format-GB $_.FreeSpace), (Format-GB $_.Size), $pct)
  }
}

$bat = Get-CimInstance Win32_Battery
if ($bat) {
  Section "Battery"
  foreach ($b in $bat) {
    Write-Host ("  Charge   : {0}%  (status code {1})" -f $b.EstimatedChargeRemaining, $b.BatteryStatus)
  }
}

Section "Key services"
foreach ($svc in 'wuauserv','WinDefend','Spooler','LanmanServer','Dnscache') {
  $s = Get-Service -Name $svc -ErrorAction SilentlyContinue
  if ($s) { Write-Host ("  {0,-14} {1}" -f $s.Name, $s.Status) }
}

Section "Recent critical events (last 24h)"
$since = (Get-Date).AddHours(-24)
$events = @()
foreach ($log in 'System','Application') {
  $events += Get-WinEvent -FilterHashtable @{LogName=$log; Level=1,2; StartTime=$since} -MaxEvents 10 -ErrorAction SilentlyContinue |
             Select-Object TimeCreated, LevelDisplayName, ProviderName, Id
}
if ($events) {
  $events | Sort-Object TimeCreated -Descending | Select-Object -First 10 | ForEach-Object {
    Write-Host ("  {0:yyyy-MM-dd HH:mm} [{1}] {2} (id {3})" -f $_.TimeCreated, $_.LevelDisplayName, $_.ProviderName, $_.Id)
  }
} else {
  Write-Host "  none"
}

Section "Pending reboot"
$pending = $false
if (Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending') { $pending = $true }
if (Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired') { $pending = $true }
$pfro = (Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager' -Name PendingFileRenameOperations -ErrorAction SilentlyContinue)
if ($pfro) { $pending = $true }
Write-Host ("  {0}" -f $(if ($pending) { "YES - a reboot is pending" } else { "no" }))

Write-Host "`n== Report complete ==" -ForegroundColor Green
