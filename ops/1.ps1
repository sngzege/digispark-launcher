# ops/1 (Windows) — KAPSAMLI ve güvenli disk temizliği.
# GUI "Disk Temizleme"den daha ileri; terminal bilmeyen birinin elle
# yapamayacağı sistem/çoklu-kullanıcı/tarayıcı artıklarını da temizler.
#
# GÜVENLİK KURALI: ASLA kullanıcı verisine (Belgeler/İndirilenler/Masaüstü),
# Program Files'a, kayıt defterine, çerez/şifre/geçmişe dokunmaz. Yalnız
# önbellek/geçici/log/çöp ve yükseltme artıklarını siler. Kilitli dosyalar atlanır.
#
# Dışarıda bırakılanlar (istenirse eklenir):
#   - hiberfil.sys (Hızlı Başlatma'yı kapatır)   - Sistem Geri Yükleme noktaları
#   - standby/RAM önbelleği (yerleşik araç yok)

$ErrorActionPreference = 'SilentlyContinue'

# --- Yönetici değilse UAC ile kendini yeniden başlat (derin temizlik için) ---
$self = 'https://raw.githubusercontent.com/sngzege/digispark-launcher/main/ops/1.ps1'
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
          ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
  Write-Host "Derin temizlik icin yonetici izni isteniyor (UAC'ye Evet de)..." -ForegroundColor Yellow
  try {
    Start-Process powershell -Verb RunAs -ArgumentList @(
      '-NoProfile','-ExecutionPolicy','Bypass','-Command',
      "iwr -useb '$self' | iex; Read-Host 'Temizlik bitti. Kapatmak icin Enter'"
    ) -ErrorAction Stop
    Write-Host "Yonetici penceresi acildi; temizlik orada calisiyor."
    return
  } catch {
    Write-Host "Yonetici izni alinamadi; yalnizca kullanici duzeyi temizlik yapilacak." -ForegroundColor Yellow
  }
}

function Format-GB($bytes) { "{0:N2} GB" -f ($bytes / 1GB) }

# Bir klasörün İÇİNİ temizler (klasörün kendisini bırakır).
function Clear-DirContents($path, $label) {
  if (-not (Test-Path -LiteralPath $path)) { return }
  $n = 0
  Get-ChildItem -LiteralPath $path -Force -ErrorAction SilentlyContinue | ForEach-Object {
    try { Remove-Item -LiteralPath $_.FullName -Recurse -Force -ErrorAction Stop; $n++ } catch {}
  }
  if ($n -gt 0) { Write-Host ("  [+] {0}: {1} oge" -f $label, $n) }
}

# İnatçı sistem klasörünü (Windows.old gibi) sahiplik alıp siler.
function Remove-Stubborn($path, $label) {
  if (-not (Test-Path -LiteralPath $path)) { return }
  Write-Host ("  [*] {0} siliniyor (sahiplik aliniyor, surebilir)..." -f $label)
  # SID tabanli (dilden bagimsiz, sormaz): *S-1-5-32-544 = Administrators
  cmd /c "icacls `"$path`" /setowner *S-1-5-32-544 /t /c"  >$null 2>&1
  cmd /c "icacls `"$path`" /grant *S-1-5-32-544:F /t /c"   >$null 2>&1
  cmd /c "rd /s /q `"$path`""                              >$null 2>&1
  if (Test-Path -LiteralPath $path) {
    Write-Host ("  [!] {0} tamamen silinemedi (bazilari kilitli)." -f $label) -ForegroundColor Yellow
  } else {
    Write-Host ("  [+] {0} silindi." -f $label)
  }
}

# Verilen bir LocalAppData altında tüm tarayıcı ÖNBELLEKLERİNİ temizler (yalnız cache).
function Clear-BrowserCaches($local) {
  if (-not (Test-Path -LiteralPath $local)) { return }
  # Chromium tabanlılar: her profil altinda cache klasorleri
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
        Clear-DirContents (Join-Path $_.FullName $sub) ("Tarayici cache: " + $_.Name + "\" + $sub)
      }
    }
    # Profil kokunde de olabilecek cache
    foreach ($sub in $chromiumSub) { Clear-DirContents (Join-Path $root $sub) ("Tarayici cache: " + $sub) }
  }
  # Firefox: profiller altinda cache2
  $ffRoot = "$local\Mozilla\Firefox\Profiles"
  if (Test-Path -LiteralPath $ffRoot) {
    Get-ChildItem -LiteralPath $ffRoot -Directory -Force -ErrorAction SilentlyContinue | ForEach-Object {
      Clear-DirContents (Join-Path $_.FullName 'cache2') ("Firefox cache: " + $_.Name)
    }
  }
}

Write-Host "== KAPSAMLI disk temizligi basliyor ==" -ForegroundColor Cyan
$before = (Get-PSDrive C).Free
Write-Host ("Baslangic bos alan (C:): {0}" -f (Format-GB $before))

# ---------- Her zaman (kullanici duzeyi) ----------
Clear-DirContents $env:TEMP                                   "Kullanici TEMP"
Clear-DirContents (Join-Path $env:LOCALAPPDATA 'Temp')        "LocalAppData Temp"
Clear-DirContents (Join-Path $env:LOCALAPPDATA 'Microsoft\Windows\INetCache') "INetCache"
Clear-DirContents (Join-Path $env:LOCALAPPDATA 'CrashDumps')  "Crash Dumps"
Clear-DirContents (Join-Path $env:LOCALAPPDATA 'Microsoft\Windows\Explorer') "Thumbnail/Icon cache"
Clear-BrowserCaches $env:LOCALAPPDATA
try { Clear-RecycleBin -Force -ErrorAction Stop; Write-Host "  [+] Geri Donusum Kutusu bosaltildi" } catch {}

if ($isAdmin) {
  # ---------- Tum kullanicilar: temp + tarayici cache ----------
  Get-ChildItem 'C:\Users' -Directory -Force -ErrorAction SilentlyContinue | ForEach-Object {
    $u = $_.FullName
    Clear-DirContents (Join-Path $u 'AppData\Local\Temp')     ("Kullanici Temp: " + $_.Name)
    Clear-BrowserCaches (Join-Path $u 'AppData\Local')
  }

  # ---------- Sistem gecici / onbellek ----------
  Clear-DirContents 'C:\Windows\Temp'      "Windows\Temp"
  Clear-DirContents 'C:\Windows\Prefetch'  "Prefetch"
  Clear-DirContents 'C:\Windows\Downloaded Program Files' "Downloaded Program Files"

  # ---------- Windows Update + Delivery Optimization ----------
  Write-Host "  [*] Windows Update onbellegi..."
  Stop-Service wuauserv,bits -Force -ErrorAction SilentlyContinue
  Clear-DirContents 'C:\Windows\SoftwareDistribution\Download' "WU Download cache"
  Start-Service wuauserv,bits -ErrorAction SilentlyContinue
  try { Delete-DeliveryOptimizationCache -Force -ErrorAction Stop; Write-Host "  [+] Delivery Optimization onbellegi" } catch {}

  # ---------- Dump / hata raporu / loglar ----------
  Clear-DirContents 'C:\Windows\Minidump' "Minidump"
  if (Test-Path 'C:\Windows\MEMORY.DMP') { Remove-Item 'C:\Windows\MEMORY.DMP' -Force; Write-Host "  [+] MEMORY.DMP" }
  Clear-DirContents (Join-Path $env:ProgramData 'Microsoft\Windows\WER\ReportQueue')   "WER kuyruk"
  Clear-DirContents (Join-Path $env:ProgramData 'Microsoft\Windows\WER\ReportArchive') "WER arsiv"
  Clear-DirContents 'C:\Windows\Logs\CBS'  "CBS loglari"
  Clear-DirContents 'C:\Windows\Panther'   "Panther (kurulum log)"

  # ---------- Yukseltme artiklari (buyuk yer) ----------
  Remove-Stubborn 'C:\Windows.old'     'Windows.old (eski Windows)'
  Remove-Stubborn 'C:\$Windows.~BT'    'Yukseltme: $Windows.~BT'
  Remove-Stubborn 'C:\$Windows.~WS'    'Yukseltme: $Windows.~WS'
  Remove-Stubborn 'C:\$GetCurrent'     'Yukseltme: $GetCurrent'
  Remove-Stubborn 'C:\$WinREAgent'     'Yukseltme: $WinREAgent'

  # ---------- WinSxS bilesen deposu (derin) ----------
  Write-Host "  [*] WinSxS derin bilesen temizligi (DISM /ResetBase, surebilir)..."
  Dism.exe /Online /Cleanup-Image /StartComponentCleanup /ResetBase /Quiet | Out-Null
  Write-Host "  [+] DISM bilesen temizligi bitti"
} else {
  Write-Host "  [!] Yonetici degil: sistem/coklu-kullanici/Windows.old/DISM atlandi." -ForegroundColor Yellow
}

Start-Sleep -Seconds 2
$after = (Get-PSDrive C).Free
$freed = [math]::Max(0, $after - $before)
Write-Host ("Bitis bos alan (C:): {0}" -f (Format-GB $after))
Write-Host ("ACILAN YER: {0}" -f (Format-GB $freed)) -ForegroundColor Green
