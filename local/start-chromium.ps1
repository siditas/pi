# Launches Chromium with a CDP debug port on a persistent profile. Idempotent.
param([int]$Port = 9222, [string]$Url = "https://www.instagram.com/")
$ErrorActionPreference = "Stop"
$Profile = "$env:LOCALAPPDATA\pi-ig-profile"
$Root    = "$env:LOCALAPPDATA\pi-chromium"

function PortOpen { try { (Invoke-WebRequest "http://127.0.0.1:$Port/json/version" -UseBasicParsing -TimeoutSec 2) | Out-Null; $true } catch { $false } }
function RelayOpen { try { (New-Object Net.Sockets.TcpClient('127.0.0.1', $Port + 1)).Close(); $true } catch { $false } }
if (-not (RelayOpen)) {
  Start-Process powershell -WindowStyle Hidden -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSScriptRoot\cdp-relay.ps1`" -Listen $($Port + 1) -Target $Port"
  Write-Host "Started CDP relay on $($Port + 1)"
}
if (PortOpen) { Write-Host "Chromium already listening on $Port"; exit 0 }

function FindChromium {
  $c = @(
    (Get-ChildItem "$Root\chrome-win\chrome.exe" -ErrorAction SilentlyContinue),
    (Get-ChildItem "$env:LOCALAPPDATA\ms-playwright\chromium-*\chrome-win*\chrome.exe" -ErrorAction SilentlyContinue)
  ) | Where-Object { $_ } | Select-Object -First 1
  if ($c) { $c.FullName }
}

$exe = FindChromium
if (-not $exe) {
  Write-Host "Downloading Chromium snapshot (official, no Node needed)..."
  New-Item -ItemType Directory -Force $Root | Out-Null
  $zip = "$Root\chromium.zip"
  [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
  Invoke-WebRequest "https://download-chromium.appspot.com/dl/Win_x64?type=snapshots" -OutFile $zip -UseBasicParsing
  Expand-Archive $zip -DestinationPath $Root -Force
  Remove-Item $zip
  $exe = FindChromium
}
if (-not $exe) { throw "Chromium not found after download" }

New-Item -ItemType Directory -Force $Profile | Out-Null
Start-Process $exe -ArgumentList @(
  "--remote-debugging-port=$Port",
  "--remote-debugging-address=0.0.0.0",
  "--user-data-dir=$Profile",
  "--no-first-run", "--no-default-browser-check",
  $Url
)
foreach ($i in 1..30) { if (PortOpen) { Write-Host "Chromium ready on $Port ($exe)"; exit 0 }; Start-Sleep -Seconds 1 }
throw "Chromium did not open port $Port"
