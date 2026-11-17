# Local validation — 17 November 2026

- `bash -n bootstrap.sh installers/unix.sh`: passed.
- `bash bootstrap.sh`: Linux x86_64 dry-run passed, no downloads or installations.
- `python3 tests/test_bootstrap.py`: five behavior checks passed, with fake tailscale,
  tsh and sudo executables in a temporary directory: placeholder endpoint refusal;
  existing-client install-free path; explicit login flag construction; unknown config
  key refusal; unknown command-line option refusal.
- No PowerShell runtime was available: Windows syntax/runtime NOT verified.
- macOS packages/extensions, Windows MSI/UAC, Linux installation and real enrollment
  NOT exercised. No official installers were executed. No live endpoint was probed.
- Download/extraction/install branches require target-OS pilot tests with verified
  package versions, digests and endpoints before release.

These checks demonstrate local script behavior only, not fleet readiness.
