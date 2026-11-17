# SOP — Enrolling a device with the mesh client bootstrap

Scope: install the Tailscale client (pointed at our Headscale control server) and the
Teleport `tsh` access client on a workstation. Applies to macOS, Windows and Linux.
Phones use the manual procedure in step 6. This installs **client** software only;
it does not make the machine a Teleport SSH node or change the mesh server.

Owner: whoever runs it. Nothing here completes authentication for you — every login,
invite and MFA step is a human action on the device.

---

## 0. Before you start (do this once, carefully)

This package ships with **placeholder** endpoints. It cannot guess our real values, and
a wrong value installs a client that cannot connect. Fill these in **before** any run.

1. Open `config.example.env`, copy it to `config.env`, and set all six values:
   - `HEADSCALE_LOGIN_SERVER` — the verified HTTPS control-server URL (a reported
     candidate is `https://mesh.psmhome.no`, but it is **not verified by this package**).
   - `TELEPORT_PROXY` — the real client-facing proxy `host:port`, no scheme. The recorded
     `teleport.psmhome.no` / `192.168.192.14:3080` do not confirm the correct public port.
   - `TAILSCALE_URL` + `TAILSCALE_SHA256` — exact official artifact for this OS/CPU and
     its independently checked hash.
   - `TELEPORT_URL` + `TELEPORT_SHA256` — exact official client artifact and hash.
2. Confirm the OS and CPU architecture (`uname -m` on macOS/Linux; Windows system settings).
   Use a **separate** `config.env` per OS/CPU — one file describes one machine type.
3. Confirm the machine has admin/sudo rights, internet access, and note any existing VPN or
   mesh membership. Repointing or resetting an enrolled client can disconnect its mesh.
4. Confirm the Tailscale client version you select is compatible with the reported
   Headscale `0.23.0`. This package cannot establish that compatibility — check the
   official compatibility matrix or the mesh admin before proceeding.
5. Never put a token, password or invite link in `config.env`. It is plain KEY=value data.

**STOP condition:** if any of the six values is still a placeholder or unverified, stop.
Do not run with defaults.

---

## 1. Download and inspect

Clone the private repo (or download and unzip it) and read `README.md` and `VALIDATION.md`
before running anything.

```sh
git clone https://github.com/PratikMoitra/mesh-client-bootstrap.git
cd mesh-client-bootstrap
```

Never pipe the bootstrap straight into a shell. Review the scripts first.

---

## 2. Dry run (all OS) — expected: detection only, no changes

```sh
# macOS / Linux
bash bootstrap.sh
```
```powershell
# Windows PowerShell
.\bootstrap.ps1
```

Expected: OS/CPU detection printed, **no downloads, no installs**. If it reports a
placeholder or unknown config key, fix `config.env` and repeat.

---

## 3. Apply — install missing clients only

```sh
bash bootstrap.sh --apply
```
```powershell
.\bootstrap.ps1 -Apply
```

Expected: missing Tailscale client and `tsh` are installed from the allowlisted,
digest-checked URLs. Existing clients are kept (their version printed) — not upgraded.
macOS may prompt for the VPN/system extension; open Tailscale once if the daemon is not
ready, then rerun. Windows may trigger UAC for the MSI; restart is never forced.

Success check: `tailscale version` and `tsh version` both return a version.

---

## 4. Connect — request Headscale login (you finish it)

```sh
bash bootstrap.sh --apply --connect
```
```powershell
.\bootstrap.ps1 -Apply -Connect
```

Expected: `tailscale up --login-server=... --timeout=5s` runs **without** an auth key and
may print an authentication URL. A timeout or nonzero exit here means pending/failed
enrollment, **not** success. An already-enrolled device may print no URL.

1. Open any printed auth URL yourself and approve the node in the Headscale enrollment /
   admin-approval flow. Do not share that URL.
2. Verify: `tailscale status` shows the node online on the mesh.
3. If the client refuses due to existing preferences, read the error and resolve it
   manually. Do not blindly reset.

---

## 5. Teleport login (you finish it)

Enrollment and MFA are personal. Complete the Teleport invite and MFA on the device,
then run the command the bootstrap prints:

```sh
tsh login --proxy=<TELEPORT_PROXY>
```

Verify: `tsh status` shows an active login. Installing `tsh` does **not** make this
machine an SSH resource; node enrollment is a separate approved action.

---

## 6. Phones (manual — no script)

1. Install the official Tailscale app from the App Store or Google Play.
2. Choose a custom coordination/login server using the app's documented procedure.
3. Enter the verified Headscale HTTPS URL, approve VPN permission, finish enrollment.
4. Teleport mobile supports limited MFA / access-request workflows, not a full node agent.
   Confirm features against current official docs. Menu labels change between versions —
   follow the official guide, not old screenshots.

---

## 7. Verify the whole job

- `tailscale status` — node present and online.
- `tsh status` — active Teleport login.
- Open the portal / a known mesh-only app from this device to confirm DNS and reachability.
- If a link fails, check server-side ACLs, DNS and certificates — this package changes none of them.

---

## 8. Rollback

No automatic uninstall. To back out:

- `tailscale down` disconnects; `tailscale logout` removes the local login (server-side
  device removal is a separate admin action).
- Linux: remove `/usr/local/bin/tsh` **only if this bootstrap installed it**.
- Windows: remove `%LOCALAPPDATA%\MeshBootstrap\bin\tsh.exe` only if installed here;
  uninstall Tailscale in Settings.
- macOS: use the official package uninstall instructions.
- `tsh logout` clears the client login.

There is no automatic rollback if the first install succeeds and the second fails — fix
`config.env` and rerun.

---

## 9. Known limits / escalate

- Windows runtime was not available to the author; the PowerShell path is **not runtime-tested**.
- No real installer, download, enrollment or endpoint probe was exercised before publication.
- Validate against a target-OS pilot device (a MacBook first) before fleet rollout.
- Internal hostnames appear in config comments; the repo is private — keep it that way.

Stop and ask the mesh administrator if: the control-server URL or TLS is uncertain, the
Headscale version compatibility is unknown, or an enrollment must be reset on a live node.
