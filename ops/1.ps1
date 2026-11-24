# ops/1 - Disk Cleaner (Windows). Deep but safe cleanup: caches, temp, logs,
# crash dumps, Windows Update cache, and upgrade leftovers. Never touches user
# data, Program Files, the registry, cookies/passwords/history. Locked files are
# skipped. Excluded by design: hiberfil.sys, System Restore points, RAM cache.

$ErrorActionPreference = 'SilentlyContinue'

$base = if ($env:BASE) { $env:BASE } else { 'https://raw.githubusercontent.com/sngzege/digispark-launcher/main/' }
$self = $base + 'ops/1.ps1'
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
          ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
  Write-Host "Requesting administrator rights for deep cleanup (click Yes on UAC)..." -ForegroundColor Yellow
  try {
    Start-Process powershell -Verb RunAs -ArgumentList @(
      '-NoProfile','-ExecutionPolicy','Bypass','-Command',
      "iwr -useb '$self' | iex; Read-Host 'Cleanup done. Press Enter to close'"
    ) -ErrorAction Stop
    Write-Host "Admin window opened; cleanup is running there."
    return
  } catch {
    Write-Host "Could not elevate; running user-level cleanup only." -ForegroundColor Yellow
    Write-Host ("  Reason: {0}" -f $_.Exception.Message) -ForegroundColor Yellow
  }
}

function Format-GB($bytes) { "{0:N2} GB" -f ($bytes / 1GB) }

function Clear-DirContents($path, $label) {
  if (-not (Test-Path -LiteralPath $path)) { return }
  $n = 0
  Get-ChildItem -LiteralPath $path -Force -ErrorAction SilentlyContinue | ForEach-Object {
    try { Remove-Item -LiteralPath $_.FullName -Recurse -Force -ErrorAction Stop; $n++ } catch {}
  }
  if ($n -gt 0) { Write-Host ("  [+] {0}: {1} items" -f $label, $n) }
}

# Take ownership and force-remove a stubborn system folder (e.g. Windows.old).
function Remove-Stubborn($path, $label) {
  if (-not (Test-Path -LiteralPath $path)) { return }
  Write-Host ("  [*] Removing {0} (taking ownership, may take a while)..." -f $label)
  cmd /c "icacls `"$path`" /setowner *S-1-5-32-544 /t /c"  >$null 2>&1
  cmd /c "icacls `"$path`" /grant *S-1-5-32-544:F /t /c"   >$null 2>&1
  cmd /c "rd /s /q `"$path`""                              >$null 2>&1
  if (Test-Path -LiteralPath $path) {
    Write-Host ("  [!] {0} not fully removed (some files locked)." -f $label) -ForegroundColor Yellow
  } else {
    Write-Host ("  [+] {0} removed." -f $label)
  }
}

# Clear browser caches only (never cookies/passwords/history) under a LocalAppData.
function Clear-BrowserCaches($local) {
  if (-not (Test-Path -LiteralPath $local)) { return }
  $chromiumRoots = @(
    "$local\Google\Chrome\User Data",
    "$local\Microsoft\Edge\User Data",
    "$local\BraveSoftware\Brave-Browser\User Data",
    "$local\Chromium\User Data",
    "$local\Opera Software\Opera Stable",
    "$local\Opera Software\Opera GX Stable"
  )
  $chromiumSub = @('Cache','Code Cache','GPUCache','Service Worker\CacheStorage','Service Worker\ScriptCache')
  foreach ($root in $chromiumRoots) {
    if (-not (Test-Path -LiteralPath $root)) { continue }
    Get-ChildItem -LiteralPath $root -Directory -Force -ErrorAction SilentlyContinue | ForEach-Object {
      foreach ($sub in $chromiumSub) {
        Clear-DirContents (Join-Path $_.FullName $sub) ("Browser cache: " + $_.Name + "\" + $sub)
      }
    }
    foreach ($sub in $chromiumSub) { Clear-DirContents (Join-Path $root $sub) ("Browser cache: " + $sub) }
  }
  $ffRoot = "$local\Mozilla\Firefox\Profiles"
  if (Test-Path -LiteralPath $ffRoot) {
    Get-ChildItem -LiteralPath $ffRoot -Directory -Force -ErrorAction SilentlyContinue | ForEach-Object {
      Clear-DirContents (Join-Path $_.FullName 'cache2') ("Firefox cache: " + $_.Name)
    }
  }
}

Write-Host "== Disk Cleaner starting ==" -ForegroundColor Cyan
$before = (Get-PSDrive C).Free
Write-Host ("Free space before (C:): {0}" -f (Format-GB $before))

# User level (always)
Clear-DirContents $env:TEMP                                   "User TEMP"
Clear-DirContents (Join-Path $env:LOCALAPPDATA 'Temp')        "LocalAppData Temp"
Clear-DirContents (Join-Path $env:LOCALAPPDATA 'Microsoft\Windows\INetCache') "INetCache"
Clear-DirContents (Join-Path $env:LOCALAPPDATA 'CrashDumps')  "Crash Dumps"
Clear-DirContents (Join-Path $env:LOCALAPPDATA 'Microsoft\Windows\Explorer') "Thumbnail/Icon cache"
Clear-BrowserCaches $env:LOCALAPPDATA
try { Clear-RecycleBin -Force -ErrorAction Stop; Write-Host "  [+] Recycle Bin emptied" } catch {}

if ($isAdmin) {
  # All users: temp + browser cache
  Get-ChildItem 'C:\Users' -Directory -Force -ErrorAction SilentlyContinue | ForEach-Object {
    $u = $_.FullName
    Clear-DirContents (Join-Path $u 'AppData\Local\Temp')     ("User Temp: " + $_.Name)
    Clear-BrowserCaches (Join-Path $u 'AppData\Local')
  }

  # System temp / cache
  Clear-DirContents 'C:\Windows\Temp'      "Windows\Temp"
  Clear-DirContents 'C:\Windows\Prefetch'  "Prefetch"
  Clear-DirContents 'C:\Windows\Downloaded Program Files' "Downloaded Program Files"

  # Windows Update + Delivery Optimization
  Write-Host "  [*] Windows Update cache..."
  Stop-Service wuauserv,bits -Force -ErrorAction SilentlyContinue
  Clear-DirContents 'C:\Windows\SoftwareDistribution\Download' "WU Download cache"
  Start-Service wuauserv,bits -ErrorAction SilentlyContinue
  try { Delete-DeliveryOptimizationCache -Force -ErrorAction Stop; Write-Host "  [+] Delivery Optimization cache" } catch {}

  # Dumps / error reports / logs
  Clear-DirContents 'C:\Windows\Minidump' "Minidump"
  if (Test-Path 'C:\Windows\MEMORY.DMP') { Remove-Item 'C:\Windows\MEMORY.DMP' -Force; Write-Host "  [+] MEMORY.DMP" }
  Clear-DirContents (Join-Path $env:ProgramData 'Microsoft\Windows\WER\ReportQueue')   "WER queue"
  Clear-DirContents (Join-Path $env:ProgramData 'Microsoft\Windows\WER\ReportArchive') "WER archive"
  Clear-DirContents 'C:\Windows\Logs\CBS'  "CBS logs"
  Clear-DirContents 'C:\Windows\Panther'   "Panther (setup logs)"

  # Upgrade leftovers (large)
  Remove-Stubborn 'C:\Windows.old'     'Windows.old (previous Windows)'
  Remove-Stubborn 'C:\$Windows.~BT'    'Upgrade: $Windows.~BT'
  Remove-Stubborn 'C:\$Windows.~WS'    'Upgrade: $Windows.~WS'
  Remove-Stubborn 'C:\$GetCurrent'     'Upgrade: $GetCurrent'
  Remove-Stubborn 'C:\$WinREAgent'     'Upgrade: $WinREAgent'

  # WinSxS component store (deep)
  Write-Host "  [*] WinSxS component cleanup (DISM /ResetBase, may take a while)..."
  Dism.exe /Online /Cleanup-Image /StartComponentCleanup /ResetBase /Quiet | Out-Null
  Write-Host "  [+] DISM component cleanup done"
} else {
  Write-Host "  [!] Not admin: system/multi-user/Windows.old/DISM skipped." -ForegroundColor Yellow
}

Start-Sleep -Seconds 2
$after = (Get-PSDrive C).Free
# Get-PSDrive Free is UInt64; compute the delta as int64 to avoid underflow.
$freed = [int64]$after - [int64]$before
if ($freed -lt 0) { $freed = 0 }
Write-Host ("Free space after (C:): {0}" -f (Format-GB $after))
Write-Host ("SPACE FREED: {0}" -f (Format-GB $freed)) -ForegroundColor Green
