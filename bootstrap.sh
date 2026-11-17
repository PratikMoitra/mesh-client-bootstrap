#!/usr/bin/env bash
# Self-contained: safe to deliver on stdin. No sibling files required.
set -euo pipefail
export PATH="/usr/local/bin:$PATH"
# UNVERIFIED deployment candidates; environment overrides require no file edits.
HEADSCALE_LOGIN_SERVER=${HEADSCALE_LOGIN_SERVER:-https://mesh.psmhome.no}
TELEPORT_PROXY=${TELEPORT_PROXY:-teleport.psmhome.no}
# Vendor release defaults, NOT cluster compatibility claims. Existing clients stay put.
TAILSCALE_VERSION=${TAILSCALE_VERSION:-1.104.7}
TELEPORT_VERSION=${TELEPORT_VERSION:-18.11.10}
main() {
 local os arch dry=0 ts tmp url rc
 case "${1:-}" in --dry-run) dry=1;; '') ;; *) echo 'Usage: bootstrap.sh [--dry-run]' >&2; return 2;; esac
 [[ $# -le 1 ]] || return 2
 os=$(uname -s); arch=$(uname -m)
 case "$os" in Darwin|Linux) ;; *) echo 'Use bootstrap.ps1 on Windows; phones require manual setup.' >&2; return 2;; esac
 case "$arch" in x86_64|amd64) arch=amd64;; aarch64|arm64) arch=arm64;; *) echo "Unsupported CPU: $arch" >&2; return 2;; esac
 [[ "$HEADSCALE_LOGIN_SERVER" =~ ^https://[A-Za-z0-9.-]+(:[0-9]+)?/?$ ]] || return 2
 [[ "$TELEPORT_PROXY" =~ ^[A-Za-z0-9.-]+(:[0-9]+)?$ ]] || return 2
 [[ "$TAILSCALE_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ && "$TELEPORT_VERSION" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]] || return 2
 printf 'Platform: %s/%s\nUNVERIFIED endpoints (including overrides): Headscale %s; Teleport %s\n' "$os" "$arch" "$HEADSCALE_LOGIN_SERVER" "$TELEPORT_PROXY"
 echo 'Headscale 0.23.0/client compatibility and Teleport proxy port/client compatibility need verification.'
 if ((dry)); then echo 'DRY RUN: would install missing clients, verify vendor digests, request Headscale login. No downloads or changes.'; return; fi
 command -v curl >/dev/null || { echo 'Install curl first.' >&2; return 1; }
 tmp=$(mktemp -d); trap "rm -rf -- '$tmp'" EXIT
 fetch() { curl --fail --silent --show-error --location --proto '=https' --proto-redir '=https' --tlsv1.2 "$1" -o "$2"; }
 verified() {
  local digest actual
  fetch "$1" "$2"; fetch "$1.sha256" "$2.sha256"
  digest=$(awk 'NR==1 {print $1}' "$2.sha256")
  [[ "$digest" =~ ^[a-fA-F0-9]{64}$ ]] || { echo 'Invalid vendor SHA256' >&2; return 1; }
  if command -v sha256sum >/dev/null; then actual=$(sha256sum "$2"); else actual=$(shasum -a 256 "$2"); fi
  [[ "${actual%% *}" == "$digest" ]] || { echo 'SHA256 mismatch' >&2; return 1; }
 }
 rootrun() { if [[ $(id -u) == 0 ]]; then "$@"; else sudo "$@"; fi; }
 ts=$(command -v tailscale || true)
 if [[ -z "$ts" && -x /Applications/Tailscale.app/Contents/MacOS/Tailscale ]]; then ts=/Applications/Tailscale.app/Contents/MacOS/Tailscale; fi
 if [[ -z "$ts" ]]; then
  if [[ "$os" == Darwin ]]; then
   verified "https://pkgs.tailscale.com/stable/Tailscale-${TAILSCALE_VERSION}-macos.pkg" "$tmp/tailscale.pkg"
   pkgutil --check-signature "$tmp/tailscale.pkg"
   rootrun installer -pkg "$tmp/tailscale.pkg" -target /
  else
   echo 'Linux Tailscale: official HTTPS installer; no separate vendor script digest. Package signatures are managed by the vendor installer.'
   fetch https://tailscale.com/install.sh "$tmp/tailscale-install.sh"
   rootrun sh "$tmp/tailscale-install.sh" </dev/null
  fi
  ts=$(command -v tailscale || true)
  if [[ -z "$ts" && -x /Applications/Tailscale.app/Contents/MacOS/Tailscale ]]; then ts=/Applications/Tailscale.app/Contents/MacOS/Tailscale; fi
 fi
 if ! command -v tsh >/dev/null; then
  if [[ "$os" == Darwin ]]; then
   verified "https://cdn.teleport.dev/teleport-${TELEPORT_VERSION}.pkg" "$tmp/teleport.pkg"
   pkgutil --check-signature "$tmp/teleport.pkg"
   rootrun installer -pkg "$tmp/teleport.pkg" -target /
  else
   verified "https://cdn.teleport.dev/teleport-v${TELEPORT_VERSION}-linux-${arch}-bin.tar.gz" "$tmp/teleport.tar.gz"
   tar -xOf "$tmp/teleport.tar.gz" teleport/tsh > "$tmp/tsh"
   rootrun install -d /usr/local/bin
   rootrun install -m 0755 "$tmp/tsh" /usr/local/bin/tsh
  fi
 fi
 [[ -n "$ts" ]] || { echo 'Open Tailscale and approve macOS VPN/extension prompts, then rerun.' >&2; return 1; }
 "$ts" version; /usr/bin/env PATH="/usr/local/bin:$PATH" tsh version
 printf 'Complete Teleport invite/MFA yourself, then: tsh login --proxy=%s\n' "$TELEPORT_PROXY"
 echo 'Requesting Headscale login; open the printed URL yourself. Already enrolled clients may show no URL. Existing preferences are never reset.'
 rc=0
 if [[ "$os" == Linux ]]; then rootrun "$ts" up --login-server="$HEADSCALE_LOGIN_SERVER" --timeout=10s || rc=$?; else "$ts" up --login-server="$HEADSCALE_LOGIN_SERVER" --timeout=10s || rc=$?; fi
 if ((rc)); then echo "Login pending or failed (exit $rc). Read URL/error above; installation is not enrollment." >&2; return "$rc"; fi
}
# Parse the whole script before running commands that may consume stdin.
main "$@"
