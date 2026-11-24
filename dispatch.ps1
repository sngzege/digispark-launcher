# Digispark baslatici - Windows dagitici (PowerShell).
# Kart bunu ceker ve calistirir (Win+R icine):
#   powershell -NoProfile -ExecutionPolicy Bypass -Command "iwr -useb https://raw.githubusercontent.com/sngzege/digispark-launcher/main/dispatch.ps1 | iex"
#
# Once ops/0 calisir, sonra 1-2-3 dongusu (q = cikis).
# Islem mantigi ops/<N>.ps1 icinde; buraya sir YAZMA (depo public).

$ErrorActionPreference = 'Stop'
if (-not $BASE) { $BASE = 'https://raw.githubusercontent.com/sngzege/digispark-launcher/main/' }

# Verilen goreli yolu cekip icerigini dondurur.
function Get-Op([string]$path) {
  return (Invoke-WebRequest -UseBasicParsing -Uri ($BASE + $path)).Content
}

# Girdiyi dogrular: 1|2|3 -> aynisi, q -> 'quit', aksi -> ''.
function Read-Choice([string]$in) {
  switch -Regex ($in) {
    '^[123]$' { return $in }
    '^[qQ]$'  { return 'quit' }
    default   { return '' }
  }
}

# ops/<N>.ps1'i cekip calistirir. Cekilemezse hata yazip $false doner.
function Invoke-Op([string]$n) {
  try {
    $script = Get-Op "ops/$n.ps1"
  } catch {
    Write-Host "hata: ops/$n.ps1 cekilemedi (ag/erisim?)" -ForegroundColor Red
    return $false
  }
  Invoke-Expression $script | Out-Host
  return $true
}

function Main {
  Write-Host "== Digispark baslatici =="
  if (-not (Invoke-Op '0')) { Write-Host "(islem 0 calistirilamadi)" }
  while ($true) {
    $sel = Read-Host "`nIslem sec [1-2-3, q=cikis]"
    $choice = Read-Choice $sel
    if ($choice -eq 'quit') { Write-Host "cikiliyor."; break }
    elseif ($choice -eq '') { Write-Host "gecersiz girdi; 1, 2, 3 veya q." }
    else { if (-not (Invoke-Op $choice)) { Write-Host "(islem $choice calistirilamadi)" } }
  }
}

Main
