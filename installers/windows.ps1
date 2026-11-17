param([string]$Config, [switch]$Apply, [switch]$Connect)
$ErrorActionPreference = 'Stop'
if (-not $Apply) {
 Write-Output "DRY RUN: Windows / $env:PROCESSOR_ARCHITECTURE; install missing Tailscale and tsh. Config: $Config"
 Write-Output 'No download, install or login attempted. Add -Apply; add -Connect to request Headscale login.'
 return
}
$c = @{}
$allowed = @('HEADSCALE_LOGIN_SERVER','TELEPORT_PROXY','TAILSCALE_URL','TAILSCALE_SHA256','TELEPORT_URL','TELEPORT_SHA256')
foreach ($line in Get-Content -LiteralPath $Config) {
 if ($line -eq '' -or $line.StartsWith('#')) { continue }
 $pair = $line.Split('=',2)
 if ($pair.Count -ne 2 -or $pair[0] -notin $allowed -or $c.ContainsKey($pair[0])) { throw 'Invalid/duplicate config key' }
 $c[$pair[0]] = $pair[1]
}
if ($c.HEADSCALE_LOGIN_SERVER -notmatch '^https://[a-zA-Z0-9.-]+(:[0-9]+)?/?$' -or $c.HEADSCALE_LOGIN_SERVER -like '*example.invalid*') { throw 'Set verified HTTPS Headscale endpoint' }
if ($c.TELEPORT_PROXY -notmatch '^[a-zA-Z0-9.-]+:[0-9]+$' -or $c.TELEPORT_PROXY -like '*example.invalid*') { throw 'Set verified Teleport hostname:port' }
function Fetch($url, $digest, $destination) {
 $uri = [uri]$url
 if ($uri.Scheme -ne 'https' -or $uri.Host -notin @('pkgs.tailscale.com','cdn.teleport.dev') -or $uri.UserInfo -or $digest -notmatch '^[a-fA-F0-9]{64}$') { throw 'Official HTTPS URL and SHA256 required' }
 Invoke-WebRequest -Uri $uri -OutFile $destination -MaximumRedirection 0 -UseBasicParsing
 if ((Get-FileHash -LiteralPath $destination -Algorithm SHA256).Hash -ne $digest) { throw 'Checksum mismatch' }
}
$temp = Join-Path ([IO.Path]::GetTempPath()) ([guid]::NewGuid().ToString())
New-Item -ItemType Directory -Path $temp | Out-Null
try {
 $ts = Join-Path $env:ProgramFiles 'Tailscale/tailscale.exe'
 if (-not (Test-Path -LiteralPath $ts)) {
  $msi = Join-Path $temp 'tailscale.msi'
  Fetch $c.TAILSCALE_URL $c.TAILSCALE_SHA256 $msi
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
  Fetch $c.TELEPORT_URL $c.TELEPORT_SHA256 $zip
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
 if ($Connect) {
  & $ts up "--login-server=$($c.HEADSCALE_LOGIN_SERVER)" '--timeout=5s'
  if ($LASTEXITCODE -ne 0) { throw 'Headscale login pending or failed; read displayed URL/error and rerun after enrollment.' }
 }
} finally { Remove-Item -LiteralPath $temp -Recurse -Force }
