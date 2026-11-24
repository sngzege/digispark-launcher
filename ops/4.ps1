# ops/4 - Network Map (Windows). Read-only: reports the connected network
# (adapters, IPv4/gateway/DNS, Wi-Fi) and maps local hosts via a quick async
# ping sweep of the /24 plus the ARP neighbor table. Changes nothing.

$ErrorActionPreference = 'SilentlyContinue'

function Section($t) { Write-Host ("`n== {0} ==" -f $t) -ForegroundColor Cyan }

Write-Host "== Network Map ==" -ForegroundColor Green

Section "Adapters / IP configuration"
$cfg = Get-NetIPConfiguration -ErrorAction SilentlyContinue | Where-Object { $_.IPv4Address }
if ($cfg) {
  foreach ($c in $cfg) {
    $ip = ($c.IPv4Address.IPAddress -join ', ')
    $gw = $c.IPv4DefaultGateway.NextHop
    $dns = ($c.DNSServer | Where-Object { $_.AddressFamily -eq 2 } | ForEach-Object { $_.ServerAddresses }) -join ', '
    Write-Host ("  {0}" -f $c.InterfaceAlias)
    Write-Host ("    IPv4   : {0}" -f $ip)
    Write-Host ("    Gateway: {0}" -f $gw)
    Write-Host ("    DNS    : {0}" -f $dns)
  }
} else {
  ipconfig /all
}

Section "Wi-Fi"
$wifi = netsh wlan show interfaces 2>$null
if ($wifi) {
  $wifi | Where-Object { $_ -match '^\s*(SSID|Signal|Radio type|Authentication|Channel|Receive rate|Transmit rate)\s*:' } |
    ForEach-Object { Write-Host ("  " + $_.Trim()) }
} else {
  Write-Host "  no wireless interface"
}

# Determine the primary IPv4 and its /24 prefix for the sweep.
$primary = (Get-NetIPConfiguration | Where-Object { $_.IPv4DefaultGateway } | Select-Object -First 1).IPv4Address.IPAddress
if ($primary -and $primary -match '^(\d+\.\d+\.\d+)\.\d+$') {
  $prefix = $Matches[1] + '.'
  Section ("Host sweep ({0}0/24)" -f $prefix)
  Write-Host "  Pinging subnet (async, ~a few seconds)..."
  $tasks = foreach ($i in 1..254) {
    [pscustomobject]@{ IP = "$prefix$i"; Task = (New-Object System.Net.NetworkInformation.Ping).SendPingAsync("$prefix$i", 400) }
  }
  try { [System.Threading.Tasks.Task]::WaitAll(($tasks.Task)) } catch {}
  $alive = $tasks | Where-Object { $_.Task.Status -eq 'RanToCompletion' -and $_.Task.Result.Status -eq 'Success' }
  if ($alive) {
    foreach ($h in ($alive | Sort-Object { [version]$_.IP })) {
      $mac = (Get-NetNeighbor -IPAddress $h.IP -ErrorAction SilentlyContinue | Select-Object -First 1).LinkLayerAddress
      $name = try { ([System.Net.Dns]::GetHostEntry($h.IP)).HostName } catch { '' }
      Write-Host ("  {0,-15} {1,-18} {2}" -f $h.IP, $mac, $name)
    }
    Write-Host ("  {0} host(s) responded." -f @($alive).Count)
  } else {
    Write-Host "  no hosts responded (ICMP may be blocked)."
  }
} else {
  Write-Host "`n[!] Could not determine primary IPv4; skipping sweep." -ForegroundColor Yellow
}

Section "ARP neighbor table"
Get-NetNeighbor -AddressFamily IPv4 -ErrorAction SilentlyContinue |
  Where-Object { $_.State -in 'Reachable','Stale','Permanent' -and $_.LinkLayerAddress } |
  Sort-Object { [version]$_.IPAddress } |
  ForEach-Object { Write-Host ("  {0,-15} {1}" -f $_.IPAddress, $_.LinkLayerAddress) }

Write-Host "`n== Network map complete ==" -ForegroundColor Green
