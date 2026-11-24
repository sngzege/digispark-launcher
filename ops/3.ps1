# ops/3 - Log / Diagnostics (Windows). Collects a system summary, recent event
# log entries, and systeminfo into a single report file for IT to review. Writes
# only that one report file; changes nothing else on the system.

$ErrorActionPreference = 'SilentlyContinue'

$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$desktop = [Environment]::GetFolderPath('Desktop')
$dir = if ($desktop -and (Test-Path $desktop)) { $desktop } else { $env:TEMP }
$report = Join-Path $dir ("digispark-report-{0}.txt" -f $stamp)

$lines = New-Object System.Collections.Generic.List[string]
function Add-Line($s) { $lines.Add([string]$s) }
function Add-Section($t) { Add-Line ""; Add-Line ("== {0} ==" -f $t) }

Write-Host "== Log / Diagnostics ==" -ForegroundColor Green
Write-Host "Collecting diagnostics..."

Add-Line ("Digispark diagnostics report - {0}" -f (Get-Date))
Add-Line ("Host: {0}   User: {1}" -f $env:COMPUTERNAME, $env:USERNAME)

$os = Get-CimInstance Win32_OperatingSystem
Add-Section "System"
Add-Line ("OS: {0} (build {1})" -f $os.Caption, $os.BuildNumber)
if ($os.LastBootUpTime) {
  $up = (Get-Date) - $os.LastBootUpTime
  Add-Line ("Uptime: {0}d {1}h {2}m (last boot {3})" -f $up.Days, $up.Hours, $up.Minutes, $os.LastBootUpTime)
}
$totalRam = $os.TotalVisibleMemorySize * 1KB
$freeRam  = $os.FreePhysicalMemory * 1KB
Add-Line ("RAM: {0:N1} GB used / {1:N1} GB total" -f (($totalRam-$freeRam)/1GB), ($totalRam/1GB))

Add-Section "Drives"
Get-CimInstance Win32_LogicalDisk -Filter "DriveType=3" | ForEach-Object {
  if ($_.Size) { Add-Line ("{0} {1:N1} GB free / {2:N1} GB total" -f $_.DeviceID, ($_.FreeSpace/1GB), ($_.Size/1GB)) }
}

Add-Section "Recent events (last 24h: Critical/Error/Warning)"
$since = (Get-Date).AddHours(-24)
$events = @()
foreach ($log in 'System','Application') {
  $events += Get-WinEvent -FilterHashtable @{LogName=$log; Level=1,2,3; StartTime=$since} -MaxEvents 40 -ErrorAction SilentlyContinue |
             Select-Object TimeCreated, LevelDisplayName, LogName, ProviderName, Id, Message
}
if ($events) {
  $events | Sort-Object TimeCreated -Descending | ForEach-Object {
    $msg = ($_.Message -split "`r?`n")[0]
    Add-Line ("{0:yyyy-MM-dd HH:mm} [{1}] {2}/{3} id {4}: {5}" -f $_.TimeCreated, $_.LevelDisplayName, $_.LogName, $_.ProviderName, $_.Id, $msg)
  }
} else {
  Add-Line "none"
}

Add-Section "systeminfo"
try { Add-Line ((& systeminfo 2>$null) -join "`r`n") } catch { Add-Line "systeminfo unavailable" }

$lines | Set-Content -LiteralPath $report -Encoding UTF8
Write-Host ("[+] Report written to: {0}" -f $report) -ForegroundColor Green
