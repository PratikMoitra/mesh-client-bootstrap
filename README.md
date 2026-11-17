# Mesh client bootstrap (17 November 2026)

Installs the Tailscale client for a Headscale mesh and Teleport's `tsh` access client.
Review these files and run locally. Never pipe this bootstrap straight into a shell.

**To actually enroll a device, follow [SOP.md](SOP.md)** — a step-by-step runbook covering
preflight verification, per-OS dry-run → apply → connect, verification and rollback.
This README is the reference; the SOP is the procedure.

## Verify these values before use

Copy `config.example.env` to `config.env` and fill in the six settings. Config is plain
KEY=value data, with no quotes or expansion; never put credentials or invite links in it.

- `HEADSCALE_LOGIN_SERVER`: verified HTTPS control-server URL and trusted TLS certificate.
  Reported candidate: `https://mesh.psmhome.no`; not tested by this package.
- `TELEPORT_PROXY`: externally reachable, certificate-valid hostname:port, without a scheme.
  Reported candidates `teleport.psmhome.no` and LAN `192.168.192.14:3080` do not establish
  the correct public client port. Confirm TLS routing and proxy reachability first.
- `TAILSCALE_URL` and `TAILSCALE_SHA256`: exact official artifact URL and independently
  verified SHA256 for this OS/architecture. macOS standalone PKG; Windows MSI;
  Linux `https://tailscale.com/install.sh` (review and hash the downloaded script first).
- `TELEPORT_URL` and `TELEPORT_SHA256`: exact official signed macOS client PKG,
  Linux tar.gz or Windows bin.zip and independently verified SHA256. Select the cluster's
  supported client version and edition; do not guess a version or download 'latest'.

One config describes ONE OS/CPU; use separate private config files for different machines.
Official download origins are allowlisted; redirects are refused. Check architecture
(`uname -m` or Windows system settings) before choosing packages. Confirm supported OS,
admin rights, existing VPN/mesh membership, Headscale user/device approval procedure,
and Tailscale compatibility with the reported Headscale 0.23.0 before enrollment.
The old control-plane version may require an upgrade plan; this package cannot establish compatibility.
The admin UI's final mesh-only hostname/access state, DNS, subnet routes and ACLs are
not prerequisites to encode here and are not changed. No LAN routes are advertised.

## Quickstart: macOS and Linux

Requires Bash, curl, tar (Linux), a SHA256 tool, sudo and internet access.
On macOS use the standalone Tailscale package; mixing App Store and standalone variants
is unsupported by this bootstrap. Approve OS VPN/system-extension prompts yourself.

```sh
cp config.example.env config.env
# Edit config.env with verified values first.
bash bootstrap.sh                         # dry run, OS/CPU detection only
bash bootstrap.sh --apply                 # install missing clients; no login
bash bootstrap.sh --apply --connect       # request Headscale login; prints auth URL
```

Linux runs the reviewed, digest-checked official Tailscale installer (which manages
its package repository and daemon). macOS uses system PKG installers. For Teleport on
Linux only `teleport/tsh` is extracted to `/usr/local/bin/tsh`; no service is started.
Existing clients are retained and their versions printed; their compatibility must
still be checked by the operator. Repeated runs skip existing executables, not upgrade them.
On macOS open Tailscale once if its extension/daemon is not ready, then rerun.

## Quickstart: Windows

Use Windows PowerShell 5.1+ on Windows 10+ with administrator permission available for
MSI elevation. Do not weaken an organization execution policy; have these scripts approved.

```powershell
Copy-Item config.example.env config.env
# Edit config.env with verified values first.
.\bootstrap.ps1
.\bootstrap.ps1 -Apply
.\bootstrap.ps1 -Apply -Connect
```

The selector calls `installers/windows.ps1`. It verifies the Tailscale MSI digest and
Authenticode validity and runs the installer with UAC elevation; restart is never forced.
`tsh.exe` is installed under `%LOCALAPPDATA%\MeshBootstrap\bin`, without changing PATH.
The printed Teleport command uses its full path. An existing PATH `tsh.exe` is retained.
Windows does not run the Teleport server/node agent.

## Enrollment is a separate user step

`--connect` / `-Connect` runs `tailscale up --login-server=... --timeout=5s` without
auth keys, browser automation or `--reset`. It may print an authentication URL.
Open that URL yourself and follow the Headscale enrollment/administrator approval flow.
A timeout/nonzero exit is pending or failed enrollment, NOT success. An already enrolled
client may show no URL. Existing preferences can cause refusal: inspect the error and
resolve manually; do not blindly reset. Repointing an existing client can disconnect its
current mesh; review membership before choosing Connect. The client/OS may display prompts.

Finish your Teleport invite and MFA enrollment personally. Then use the printed
`tsh login --proxy=...` command; the bootstrap never executes it. Check `tailscale status`
and `tsh status` after user enrollment. Reachability and access depend on server ACLs,
DNS and certificates, none of which this package modifies.

This is a workstation client bootstrap, not automated resource enrollment. A Linux/macOS
Teleport node agent needs a separately approved join method, role, configuration and
service lifecycle. Installing `tsh` does not make this machine an SSH resource.

## Phones (manual)

Install the official Tailscale app from Apple's App Store or Google Play, choose a custom
coordination/login server using the platform's documented procedure, enter the verified
Headscale HTTPS URL, approve VPN permission and finish enrollment yourself. Menu locations
vary by app version; follow the official guide linked below rather than an old screenshot.
A general SSH/agent or Ansible-style host script does not apply to iOS/Android.
Teleport mobile is for supported MFA/access-request workflows, not a full node agent or
replacement for desktop `tsh`. Confirm available mobile features with your cluster edition
and current app documentation; an authenticator can satisfy MFA without providing SSH access.

## Reversal and limitations

No unattended uninstall is included. `tailscale down` disconnects; `tailscale logout`
removes the local login (server device cleanup is a separate administrator action).
Use official OS/package uninstall instructions for Tailscale and macOS Teleport packages.
Linux: remove `/usr/local/bin/tsh` only if this bootstrap installed it. Windows: remove
`%LOCALAPPDATA%\MeshBootstrap\bin\tsh.exe` only if installed here; uninstall Tailscale in
Settings. `tsh logout` removes the active client login. No automatic rollback of an already
successful first installation if the second installation fails; fix config and rerun.
Linux repository installer changes are subject to that official installer's behavior.

## Sources and validation boundary

- [Tailscale custom coordination server (all OS tabs)](https://tailscale.com/docs/how-to/set-up-custom-coordination-server)
- [Tailscale packages](https://pkgs.tailscale.com/stable/)
- [Teleport macOS installation](https://goteleport.com/docs/installation/macos/)
- [Teleport Windows installation](https://goteleport.com/docs/installation/windows/)
- [Teleport Linux installation](https://goteleport.com/docs/installation/linux/)
- [Teleport official packages](https://goteleport.com/download/packages/)

Authoring checks are recorded in VALIDATION.md. No real installation, authentication,
endpoint probe, GitHub publication or live infrastructure change was performed.
