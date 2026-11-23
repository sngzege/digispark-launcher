# Digispark başlatıcı — Windows dağıtıcı (PowerShell).
# Kart bunu çeker ve çalıştırır (Win+R içine):
#   powershell -NoProfile -ExecutionPolicy Bypass -Command "iwr -useb https://raw.githubusercontent.com/sngzege/digispark-launcher/main/dispatch.ps1 | iex"
#
# Önce ops/0 çalışır, sonra 1-2-3 döngüsü (q = çıkış).
# İşlem mantığı ops/<N>.ps1 içinde; buraya sır YAZMA (depo public).

$ErrorActionPreference = 'Stop'
if (-not $BASE) { $BASE = 'https://raw.githubusercontent.com/sngzege/digispark-launcher/main/' }

# Verilen göreli yolu çekip içeriğini döndürür.
function Get-Op([string]$path) {
  return (Invoke-WebRequest -UseBasicParsing -Uri ($BASE + $path)).Content
}

# Girdiyi doğrular: 1|2|3 → aynısı, q → 'quit', aksi → ''.
function Read-Choice([string]$in) {
  switch -Regex ($in) {
    '^[123]$' { return $in }
    '^[qQ]$'  { return 'quit' }
    default   { return '' }
  }
}

# ops/<N>.ps1'i çekip çalıştırır. Çekilemezse hata yazıp $false döner.
function Invoke-Op([string]$n) {
  try {
    $script = Get-Op "ops/$n.ps1"
  } catch {
    Write-Host "hata: ops/$n.ps1 çekilemedi (ağ/erişim?)" -ForegroundColor Red
    return $false
  }
  Invoke-Expression $script | Out-Host
  return $true
}

function Main {
  Write-Host "== Digispark başlatıcı =="
  if (-not (Invoke-Op '0')) { Write-Host "(işlem 0 çalıştırılamadı)" }
  while ($true) {
    $sel = Read-Host "`nİşlem seç [1-2-3, q=çıkış]"
    $choice = Read-Choice $sel
    if ($choice -eq 'quit') { Write-Host "çıkılıyor."; break }
    elseif ($choice -eq '') { Write-Host "geçersiz girdi; 1, 2, 3 veya q." }
    else { if (-not (Invoke-Op $choice)) { Write-Host "(işlem $choice çalıştırılamadı)" } }
  }
}

Main
