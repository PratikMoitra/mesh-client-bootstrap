param([switch]$DryRun)
$ErrorActionPreference = 'Stop'
# UNVERIFIED deployment candidates; override through environment variables.
$server = if ($env:HEADSCALE_LOGIN_SERVER) { $env:HEADSCALE_LOGIN_SERVER } else { 'https://mesh.psmhome.no' }
$proxy = if ($env:TELEPORT_PROXY) { $env:TELEPORT_PROXY } else { 'teleport.psmhome.no' }
$tsVersion = if ($env:TAILSCALE_VERSION) { $env:TAILSCALE_VERSION } else { '1.104.7' }
$tpVersion = if ($env:TELEPORT_VERSION) { $env:TELEPORT_VERSION } else { '18.11.10' }
$c = @{ HEADSCALE_LOGIN_SERVER=$server; TELEPORT_PROXY=$proxy }
$cpu = if ($env:PROCESSOR_ARCHITEW6432) { $env:PROCESSOR_ARCHITEW6432 } else { $env:PROCESSOR_ARCHITECTURE }
$arch = switch ($cpu) { 'AMD64' { 'amd64' }; 'ARM64' { 'arm64' }; default { throw 'Unsupported Windows CPU' } }
if ($server -notmatch '^https://[a-zA-Z0-9.-]+(:[0-9]+)?/?$' -or $proxy -notmatch '^[a-zA-Z0-9.-]+(:[0-9]+)?$') { throw 'Invalid endpoint' }
foreach ($v in @($tsVersion,$tpVersion)) { if ($v -notmatch '^[0-9]+\.[0-9]+\.[0-9]+$') { throw 'Invalid release version' } }
Write-Warning "UNVERIFIED endpoints (including overrides): $server; $proxy. Verify public port, Headscale 0.23.0 and client compatibility."
Write-Output "Windows/$arch"
if ($DryRun) { Write-Output 'DRY RUN: no downloads, installation or login.'; return }
if ($arch -eq 'arm64') { Write-Output 'Teleport publishes Windows amd64 client; ARM64 requires Windows x64 emulation. Pilot required.' }
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
function Fetch($url, $destination) {
 Invoke-WebRequest -Uri $url -OutFile $destination -UseBasicParsing
 $response = Invoke-WebRequest -Uri "$url.sha256" -UseBasicParsing
 $text = if ($response.Content -is [byte[]]) { [Text.Encoding]::UTF8.GetString($response.Content) } else { [string]$response.Content }
 $digest = ($text.Trim() -split '\s+')[0]
 if ($digest -notmatch '^[a-fA-F0-9]{64}$' -or (Get-FileHash -LiteralPath $destination -Algorithm SHA256).Hash -ne $digest) { throw 'Vendor SHA256 mismatch or invalid digest' }
}
$temp = Join-Path ([IO.Path]::GetTempPath()) ([guid]::NewGuid().ToString())
New-Item -ItemType Directory -Path $temp | Out-Null
try {
 $ts = Join-Path $env:ProgramFiles 'Tailscale/tailscale.exe'
 if (-not (Test-Path -LiteralPath $ts)) {
  $msi = Join-Path $temp 'tailscale.msi'
  Fetch "https://pkgs.tailscale.com/stable/tailscale-setup-$tsVersion-$arch.msi" $msi
  $sig = Get-AuthenticodeSignature -FilePath $msi
  if ($sig.Status -ne 'Valid') { throw 'Tailscale MSI signature invalid' }
  $proc = Start-Process msiexec.exe -ArgumentList @('/i', ('"' + $msi + '"'), '/passive', '/norestart') -Verb RunAs -Wait -PassThru
  if ($proc.ExitCode -notin @(0,3010)) { throw "MSI failed: $($proc.ExitCode)" }
  if ($proc.ExitCode -eq 3010) { Write-Warning 'Restart required; restart manually before connecting.'; return }
 }
 $bin = Join-Path $env:LOCALAPPDATA 'MeshBootstrap/bin'
 $tsh = Join-Path $bin 'tsh.exe'
 $existing = Get-Command tsh.exe -ErrorAction SilentlyContinue
 if ($existing) { $tsh = $existing.Source }
 elseif (-not (Test-Path -LiteralPath $tsh)) {
  $zip = Join-Path $temp 'teleport.zip'
  Fetch "https://cdn.teleport.dev/teleport-v$tpVersion-windows-amd64-bin.zip" $zip
  Expand-Archive -LiteralPath $zip -DestinationPath (Join-Path $temp 'teleport')
  $matches = @(Get-ChildItem (Join-Path $temp 'teleport') -Recurse -Filter tsh.exe -File)
  if ($matches.Count -ne 1) { throw 'Expected exactly one tsh.exe in official archive' }
  New-Item -ItemType Directory -Force -Path $bin | Out-Null
  Copy-Item -LiteralPath $matches[0].FullName -Destination $tsh
 }
 & $ts version
 if ($LASTEXITCODE -ne 0) { throw 'Tailscale version check failed' }
 & $tsh version
 if ($LASTEXITCODE -ne 0) { throw 'tsh version check failed' }
 Write-Output "Complete invite and MFA yourself; then run: & '$tsh' login --proxy=$($c.TELEPORT_PROXY)"
 & {
  New-Item -Path "HKLM:\SOFTWARE\Policies\Tailscale" -Force -ErrorAction SilentlyContinue | Out-Null
  Set-ItemProperty -Path "HKLM:\SOFTWARE\Policies\Tailscale" -Name "LoginURL" -Value $c.HEADSCALE_LOGIN_SERVER -ErrorAction SilentlyContinue
  & $ts login "--login-server=$($c.HEADSCALE_LOGIN_SERVER)"
  if ($LASTEXITCODE -ne 0) {
   & $ts up "--login-server=$($c.HEADSCALE_LOGIN_SERVER)" '--timeout=10s'
  }
  if ($LASTEXITCODE -ne 0) { throw 'Headscale login pending or failed; read displayed URL/error and rerun after enrollment.' }
 }
} finally { Remove-Item -LiteralPath $temp -Recurse -Force }
