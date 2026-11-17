# One-line mesh client bootstrap

One self-contained script per shell. Defaults install missing Tailscale and Teleport
`tsh`, verify downloads, then request Headscale login and print the authentication URL.
You complete authentication yourself. Existing clients are retained and versions printed;
no silent upgrades. No sibling files or config.env are read.

## macOS / Linux

For a publicly readable raw URL, the interface is:

```sh
curl -fsSL https://raw.githubusercontent.com/PratikMoitra/mesh-client-bootstrap/main/bootstrap.sh | bash
```

**This repository is private. That anonymous command currently returns 404.** With GitHub
CLI installed and authenticated to this repo, the working private-repo one-liner is:

```sh
gh api 'repos/PratikMoitra/mesh-client-bootstrap/contents/bootstrap.sh?ref=main' -H 'Accept: application/vnd.github.raw+json' | bash
```

To preview, change `| bash` to `| bash -s -- --dry-run`. Requires Bash, curl, tar,
SHA256 tools and administrator/sudo access. macOS requires approval of VPN/system
extension prompts; open Tailscale if its daemon is unavailable and rerun.

## Windows (PowerShell 5.1+)

Private repository, GitHub CLI authenticated:

```powershell
& ([scriptblock]::Create((gh api 'repos/PratikMoitra/mesh-client-bootstrap/contents/bootstrap.ps1?ref=main' -H 'Accept: application/vnd.github.raw+json' | Out-String)))
```

If the raw file becomes publicly readable, the equivalent interface is:

```powershell
& ([scriptblock]::Create((Invoke-WebRequest -UseBasicParsing 'https://raw.githubusercontent.com/PratikMoitra/mesh-client-bootstrap/main/bootstrap.ps1').Content))
```

Append `-DryRun` after the final `)` to preview. No execution-policy bypass is used.
UAC elevation may be required for Tailscale. Restart requests are reported, never forced.
`tsh.exe` goes to `%LOCALAPPDATA%\MeshBootstrap\bin`; the script prints its exact login
command. Windows ARM64 uses native Tailscale plus the Windows amd64 Teleport binary
under OS x64 emulation; this requires a pilot on a supporting Windows release.

## Verify these values

Top-of-script variables have **UNVERIFIED candidate defaults**, printed on every run:

| Variable | Default | Still needs verification |
| --- | --- | --- |
| HEADSCALE_LOGIN_SERVER | https://mesh.psmhome.no | Control URL, trusted TLS, reachability |
| TELEPORT_PROXY | teleport.psmhome.no | Public client port/routing/TLS |
| TAILSCALE_VERSION | 1.104.7 | Compatibility with reported Headscale 0.23.0 |
| TELEPORT_VERSION | 18.11.10 | Compatibility with actual cluster version/edition |

The release defaults were observed at official vendor sources during authoring; they
are not evidence of deployment compatibility. Linux Tailscale's official installer
selects its stable package release; TAILSCALE_VERSION applies to macOS/Windows packages.
Override variables without editing. For example, put assignments on the receiving Bash:

```sh
curl -fsSL '<readable-raw-url>/bootstrap.sh' | HEADSCALE_LOGIN_SERVER=https://verified.example TELEPORT_PROXY=verified.example:443 bash
```

PowerShell: set `$env:HEADSCALE_LOGIN_SERVER` / `$env:TELEPORT_PROXY` before the one-liner.
Never put credentials, tokens or invite URLs in these variables or files.

Default apply can repoint an existing client to the candidate mesh. Confirm values and
existing VPN membership before running; use dry-run for inspection. No `--reset` or
auth key is used. `tailscale up --login-server=... --timeout=10s` may return pending
login/nonzero while displaying the URL. Already enrolled clients may show no URL.
This is never reported as successful enrollment. Teleport login is printed, not run.

## Official downloads and verification

- macOS: official Tailscale universal PKG and Teleport universal client PKG; vendor
  `.sha256` required and package signature checked before system installer invocation.
- Linux: [official Tailscale HTTPS installer](https://tailscale.com/install.sh). No
  independent vendor script digest is used; the installer manages signed OS packages.
  Teleport archive uses vendor `.sha256`; only `teleport/tsh` is installed.
- Windows: official Tailscale MSI with vendor SHA256 and valid Authenticode;
  Teleport ZIP with vendor SHA256. A missing/mismatched digest fails closed.

Digests delivered from the same vendor over HTTPS provide integrity, not an independent
trust channel. Script execution trusts this repository and vendor delivery endpoints.
Installation may partially complete; rerun skips installed clients rather than rolling
back. No mesh server, DNS, ACL, node-agent or Teleport resource enrollment is performed.

## Phones

Install the official Tailscale app from App Store/Play Store, select a custom coordination
server using the current platform guide, and finish VPN/enrollment prompts yourself.
A shell/Ansible-style host installer does not apply to iOS/Android. Teleport mobile
supports MFA/access-request workflows where available, not a full node agent or desktop
`tsh` replacement. Confirm features for the actual cluster.

## Documentation and validation

[SOP.md](SOP.md) covers the one-line flow, verification and reversal.
[VALIDATION.md](VALIDATION.md) records authoring checks and remaining pilot work.
`installers/` and `config.example.env` are legacy stubs and unused.

Sources: [Tailscale packages and checksum convention](https://pkgs.tailscale.com/stable/),
[custom coordination server](https://tailscale.com/docs/how-to/set-up-custom-coordination-server),
[Teleport macOS](https://goteleport.com/docs/installation/macos/),
[Teleport Windows](https://goteleport.com/docs/installation/windows/),
[Teleport Linux](https://goteleport.com/docs/installation/linux/).
