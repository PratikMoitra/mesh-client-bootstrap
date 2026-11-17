# Validation — standalone revision, 17 November 2026

- `bash -n bootstrap.sh`: pass.
- `cat bootstrap.sh | bash -s -- --dry-run`: pass; no downloads or client changes.
- `python3 tests/test_bootstrap.py`: pass: mocked Linux/amd64 and Darwin/arm64 dry-run,
  stdin full-apply with existing clients, versions/login flags/URL, pending exit,
  cleanup, invalid endpoint and unknown option refusal. No real client invocation.
- Official SHA256 endpoints fetched successfully: Tailscale 1.104.7 macOS PKG,
  amd64/arm64 Windows MSI; Teleport 18.11.10 macOS PKG, Linux amd64/arm64 archives,
  Windows amd64 ZIP. Actual package binaries were not downloaded or installed.
- Windows ARM64 Teleport archive returned 404; Windows uses published amd64 under
  x64 emulation (pilot required). No PowerShell runtime on authoring host: untested.
- `git diff --check`: pass. Staged content scanned for credential patterns before commit.
- No live mesh/server/DNS/client installation or auth was performed. Vendor metadata
  requests and Git remote readback only.

Outstanding: endpoint/TLS/proxy port verification, Headscale 0.23.0 and Teleport
cluster/client compatibility, signed installer runtime behavior, MacBook pilot,
Windows/ARM64 pilot. Private repo needs authenticated GitHub download; anonymous raw
one-liners cannot work unless the file becomes publicly readable. Visibility unchanged.
