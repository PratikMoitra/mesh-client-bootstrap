# Windows selector. Unix users should use bootstrap.sh.
param([string]$Config = "$PSScriptRoot/config.env", [switch]$Apply, [switch]$Connect)
$ErrorActionPreference = 'Stop'
if ($env:OS -ne 'Windows_NT') { throw 'Use bash bootstrap.sh on macOS/Linux.' }
& "$PSScriptRoot/installers/windows.ps1" -Config $Config -Apply:$Apply -Connect:$Connect
