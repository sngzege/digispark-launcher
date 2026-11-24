# Digispark launcher - Windows dispatcher (PowerShell).
# Card fetches and runs this (into Win+R):
#   powershell -NoProfile -ExecutionPolicy Bypass -Command "iwr -useb https://raw.githubusercontent.com/sngzege/digispark-launcher/main/dispatch.ps1 | iex"
# Runs ops/0, then an interactive named menu (q = quit). Op logic lives in
# ops/<N>.ps1. Never put secrets here (public repo).

$ErrorActionPreference = 'Stop'
if (-not $BASE) { $BASE = 'https://raw.githubusercontent.com/sngzege/digispark-launcher/main/' }
$env:BASE = $BASE

function Get-Op([string]$path) {
  return (Invoke-WebRequest -UseBasicParsing -Uri ($BASE + $path)).Content
}

# Export KEY=VALUE lines from .env into the process environment. Runs no code.
function Import-Env([string]$text) {
  foreach ($line in ($text -split "`r?`n")) {
    if ($line -match '^\s*(#.*)?$') { continue }
    if ($line -match '^([A-Za-z_][A-Za-z0-9_]*)=(.*)$') {
      [Environment]::SetEnvironmentVariable($Matches[1], $Matches[2], 'Process')
    }
  }
}

# Rebuild BASE from GH_OWNER/GH_REPO/GH_BRANCH when all are set.
function Update-BaseFromEnv {
  if ($env:GH_OWNER -and $env:GH_REPO -and $env:GH_BRANCH) {
    $script:BASE = "https://raw.githubusercontent.com/$($env:GH_OWNER)/$($env:GH_REPO)/$($env:GH_BRANCH)/"
    $env:BASE = $BASE
  }
}

# Render an ops/menu manifest ('N=Label' lines) as a human menu.
function Show-Menu([string]$text) {
  $shown = $false
  if ($text) {
    foreach ($line in ($text -split "`r?`n")) {
      if ($line -match '^\s*(#.*)?$') { continue }
      if ($line -match '^([1-9])=(.*)$') {
        Write-Host ("  {0} - {1}" -f $Matches[1], $Matches[2].Trim())
        $shown = $true
      }
    }
  }
  if (-not $shown) { Write-Host "  1  2  3  4" }
}

# Validate choice: 1-4 -> itself, q -> 'quit', anything else -> ''.
function Read-Choice([string]$in) {
  switch -Regex ($in) {
    '^[1-4]$' { return $in }
    '^[qQ]$'  { return 'quit' }
    default   { return '' }
  }
}

# Fetch and run ops/<N>.ps1. On fetch failure, print an error and return $false.
function Invoke-Op([string]$n) {
  try { $script = Get-Op "ops/$n.ps1" }
  catch { Write-Host "error: could not fetch ops/$n.ps1 (network/access?)" -ForegroundColor Red; return $false }
  Invoke-Expression $script | Out-Host
  return $true
}

function Main {
  Write-Host "== Digispark launcher =="
  try { Import-Env (Get-Op '.env'); Update-BaseFromEnv } catch {}
  if (-not (Invoke-Op '0')) { Write-Host "(op 0 failed)" }
  $menu = ''
  try { $menu = Get-Op 'ops/menu' } catch {}
  while ($true) {
    Write-Host "`nSelect an operation:"
    Show-Menu $menu
    Write-Host "  q - Quit"
    $sel = Read-Host '>'
    $choice = Read-Choice $sel
    if ($choice -eq 'quit') { Write-Host "bye."; break }
    elseif ($choice -eq '') { Write-Host "invalid input; choose a listed number or q." }
    else { if (-not (Invoke-Op $choice)) { Write-Host "(op $choice failed)" } }
  }
}

Main
