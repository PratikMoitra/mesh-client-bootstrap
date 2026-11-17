# SOP: one-line client bootstrap

1. Confirm the README candidate endpoints, public proxy port, Headscale 0.23.0/client
   compatibility and Teleport cluster/client version. Check existing VPN membership.
2. Use the README authenticated private-repo one-liner. Preview with `--dry-run` (Bash)
   or `-DryRun` (PowerShell) if needed. No clone, config file or installer folder required.
3. Run the same command without dry-run. Allow sudo/UAC and OS VPN prompts locally.
   The script installs missing clients, verifies downloads and prints versions. Installed
   clients are preserved. Linux Tailscale uses its official HTTPS package installer.
4. Open the Headscale auth URL printed by `tailscale up` and complete enrollment yourself.
   Pending/failed login returns nonzero; inspect the error. Do not blindly reset preferences.
   Already enrolled devices may print no URL. macOS may require opening Tailscale first.
5. Complete your Teleport invite/MFA yourself; run the printed `tsh login` command.
6. Verify `tailscale status`, `tsh status` and an administrator-provided mesh resource.
   Installation alone does not prove enrollment, reachability or authorization.
7. Pilot on Pratik's MacBook before fleet rollout. Windows and macOS real installs and
   Windows ARM64 emulation remain untested. No automatic node/agent enrollment is provided.

Phones use the manual README instructions. No shell bootstrap applies.

To reverse: `tailscale down` disconnects; `tailscale logout` clears the local login.
Use the OS/vendor uninstaller for Tailscale and macOS Teleport packages. Remove only
bootstrap-installed `/usr/local/bin/tsh` or `%LOCALAPPDATA%\MeshBootstrap\bin\tsh.exe`.
`tsh logout` clears client authentication. Server device cleanup is a separate admin task.
No automatic rollback if the second installer fails. This supersedes all legacy
config.env / --apply / --connect instructions.
