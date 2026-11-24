# Digispark baslatici - Windows dagitici (PowerShell).
# Kart bunu ceker ve calistirir (Win+R icine):
#   powershell -NoProfile -ExecutionPolicy Bypass -Command "iwr -useb https://raw.githubusercontent.com/sngzege/digispark-launcher/main/dispatch.ps1 | iex"
#
# Once ops/0 calisir, sonra 1-2-3 dongusu (q = cikis).
# Islem mantigi ops/<N>.ps1 icinde; buraya sir YAZMA (depo public).

$ErrorActionPreference = 'Stop'
if (-not $BASE) { $BASE = 'https://raw.githubusercontent.com/sngzege/digispark-launcher/main/' }
$env:BASE = $BASE

# Verilen goreli yolu cekip icerigini dondurur.
function Get-Op([string]$path) {
  return (Invoke-WebRequest -UseBasicParsing -Uri ($BASE + $path)).Content
}

# .env icindeki KEY=VALUE satirlarini surecin ortamina aktarir (yorum/bos satir
# atlanir). Yalniz gecerli degisken adlarini kabul eder; rastgele kod calistirmaz.
function Import-Env([string]$text) {
  foreach ($line in ($text -split "`r?`n")) {
    if ($line -match '^\s*(#.*)?$') { continue }
    if ($line -match '^([A-Za-z_][A-Za-z0-9_]*)=(.*)$') {
      [Environment]::SetEnvironmentVariable($Matches[1], $Matches[2], 'Process')
    }
  }
}

# .env'den GH_OWNER/GH_REPO/GH_BRANCH geldiyse BASE'i onlardan yeniden kurar.
function Update-BaseFromEnv {
  if ($env:GH_OWNER -and $env:GH_REPO -and $env:GH_BRANCH) {
    $script:BASE = "https://raw.githubusercontent.com/$($env:GH_OWNER)/$($env:GH_REPO)/$($env:GH_BRANCH)/"
    $env:BASE = $BASE
  }
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
  try { Import-Env (Get-Op '.env'); Update-BaseFromEnv } catch {}
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
