# ops/1 (Windows) — Güvenli ama detaylı disk temizliği.
# Amaç: diskte yer açmak. SADECE güvenli geçici/önbellek/çöp alanlarını temizler.
# ASLA dokunmaz: Belgeler, İndirilenler, Masaüstü, Program Files, kayıt defteri,
# Windows.old. Kilitli/kullanımdaki dosyaları atlar (silmeye zorlamaz).

$ErrorActionPreference = 'SilentlyContinue'

# --- Yönetici değilse UAC ile kendini yeniden başlat (derin temizlik için) ---
$self = 'https://raw.githubusercontent.com/sngzege/digispark-launcher/main/ops/1.ps1'
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
          ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
  Write-Host "Derin temizlik icin yonetici izni isteniyor (UAC penceresine Evet de)..." -ForegroundColor Yellow
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

function Clear-DirContents($path, $label) {
  if (-not (Test-Path -LiteralPath $path)) { return }
  $n = 0
  Get-ChildItem -LiteralPath $path -Force -ErrorAction SilentlyContinue | ForEach-Object {
    try { Remove-Item -LiteralPath $_.FullName -Recurse -Force -ErrorAction Stop; $n++ } catch {}
  }
  Write-Host ("  [+] {0}: {1} oge temizlendi (kilitliler atlandi)" -f $label, $n)
}

Write-Host "== Disk temizligi basliyor ==" -ForegroundColor Cyan
$before = (Get-PSDrive C).Free
Write-Host ("Baslangic bos alan (C:): {0}" -f (Format-GB $before))

# 1) Kullanici geçici dosyaları
Clear-DirContents $env:TEMP                                   "Kullanici TEMP"
Clear-DirContents (Join-Path $env:LOCALAPPDATA 'Temp')        "LocalAppData Temp"
Clear-DirContents (Join-Path $env:LOCALAPPDATA 'Microsoft\Windows\INetCache') "IE/Edge INetCache"
Clear-DirContents (Join-Path $env:LOCALAPPDATA 'CrashDumps')  "Crash Dumps"

# 2) Küçük resim / ikon önbelleği
Clear-DirContents (Join-Path $env:LOCALAPPDATA 'Microsoft\Windows\Explorer') "Thumbnail/Icon cache"

# 3) Geri Dönüşüm Kutusu
try { Clear-RecycleBin -Force -ErrorAction Stop; Write-Host "  [+] Geri Donusum Kutusu bosaltildi" } catch {}

if ($isAdmin) {
  # 4) Sistem geçici dosyaları
  Clear-DirContents 'C:\Windows\Temp' "Windows\Temp"

  # 5) Prefetch (Windows yeniden olusturur)
  Clear-DirContents 'C:\Windows\Prefetch' "Prefetch"

  # 6) Windows Update indirme önbelleği
  Write-Host "  [*] Windows Update onbellegi temizleniyor..."
  Stop-Service wuauserv,bits -Force -ErrorAction SilentlyContinue
  Clear-DirContents 'C:\Windows\SoftwareDistribution\Download' "WU Download cache"
  Start-Service wuauserv,bits -ErrorAction SilentlyContinue

  # 7) Delivery Optimization önbelleği
  try { Delete-DeliveryOptimizationCache -Force -ErrorAction Stop; Write-Host "  [+] Delivery Optimization onbellegi temizlendi" } catch {
    Clear-DirContents 'C:\Windows\SoftwareDistribution\DeliveryOptimization' "Delivery Optimization"
  }

  # 8) Eski bellek/dump kayıtları ve hata raporları
  Clear-DirContents 'C:\Windows\Minidump' "Minidump"
  if (Test-Path 'C:\Windows\MEMORY.DMP') { Remove-Item 'C:\Windows\MEMORY.DMP' -Force; Write-Host "  [+] MEMORY.DMP silindi" }
  Clear-DirContents (Join-Path $env:ProgramData 'Microsoft\Windows\WER\ReportQueue')   "WER rapor kuyrugu"
  Clear-DirContents (Join-Path $env:ProgramData 'Microsoft\Windows\WER\ReportArchive') "WER rapor arsivi"

  # 9) WinSxS bileşen temizliği (güvenli, kalıcı yer kazandirir)
  Write-Host "  [*] WinSxS bilesen temizligi (DISM, biraz surebilir)..."
  Dism.exe /Online /Cleanup-Image /StartComponentCleanup /Quiet | Out-Null
  Write-Host "  [+] DISM bilesen temizligi bitti"
} else {
  Write-Host "  [!] Yonetici degil: Windows\Temp, Prefetch, Windows Update, DISM atlandi."
}

Start-Sleep -Seconds 2
$after = (Get-PSDrive C).Free
$freed = $after - $before
Write-Host ("Bitis bos alan (C:): {0}" -f (Format-GB $after))
Write-Host ("ACILAN YER: {0}" -f (Format-GB ([math]::Max(0,$freed)))) -ForegroundColor Green
Write-Host "Not: standby/RAM onbellegi yerlesik araci gerektirir (RAMMap); eklenmedi."
