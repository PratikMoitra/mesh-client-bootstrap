#!/usr/bin/env bash
set -euo pipefail
platform=${1:?platform required}; shift
root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
config="$root/config.env"; apply=0; connect=0
while (($#)); do
 case "$1" in
 --config) config=${2:?config path required}; shift 2 ;;
 --apply) apply=1; shift ;;
 --connect) connect=1; shift ;;
 *) echo "Unknown option: $1" >&2; exit 2 ;;
 esac
done
if (( ! apply )); then
 printf 'DRY RUN: %s / %s; would install missing Tailscale and tsh; config: %s\n' "$platform" "$(uname -m)" "$config"
 echo 'No download, install or login attempted. Use --apply; add --connect to request Headscale login.'
 exit 0
fi
# Parse data, never source/eval a configuration file.
HEADSCALE_LOGIN_SERVER= TELEPORT_PROXY= TAILSCALE_URL= TAILSCALE_SHA256= TELEPORT_URL= TELEPORT_SHA256=
while IFS= read -r line || [[ -n "$line" ]]; do
 line=${line%$'\r'}
 [[ -z "$line" || "$line" == \#* ]] && continue
 [[ "$line" == *=* ]] || { echo 'Invalid config line' >&2; exit 2; }
 key=${line%%=*}; value=${line#*=}
 case "$key" in
 HEADSCALE_LOGIN_SERVER|TELEPORT_PROXY|TAILSCALE_URL|TAILSCALE_SHA256|TELEPORT_URL|TELEPORT_SHA256) printf -v "$key" '%s' "$value" ;;
 *) echo "Unknown config key: $key" >&2; exit 2 ;;
 esac
done < "$config"
[[ "$HEADSCALE_LOGIN_SERVER" =~ ^https://[A-Za-z0-9.-]+(:[0-9]+)?/?$ && "$HEADSCALE_LOGIN_SERVER" != *example.invalid* ]] || { echo 'Set a verified HTTPS Headscale endpoint' >&2; exit 2; }
[[ "$TELEPORT_PROXY" =~ ^[A-Za-z0-9.-]+:[0-9]+$ && "$TELEPORT_PROXY" != *example.invalid* ]] || { echo 'Set a verified Teleport hostname:port' >&2; exit 2; }
command -v curl >/dev/null || { echo 'Install curl first' >&2; exit 2; }
tmp=$(mktemp -d); trap 'rm -rf -- "$tmp"' EXIT
fetch() {
 local url=$1 digest=$2 dest=$3 host
 host=${url#https://}; host=${host%%/*}
 case "$host" in pkgs.tailscale.com|tailscale.com|cdn.teleport.dev) ;; *) echo 'Artifact must use an allowed official HTTPS host' >&2; exit 2 ;; esac
 [[ "$url" == https://* && "$digest" =~ ^[A-Fa-f0-9]{64}$ ]] || { echo 'Exact HTTPS URL and SHA256 required' >&2; exit 2; }
 curl --fail --silent --show-error --proto '=https' --tlsv1.2 "$url" -o "$dest"
 if command -v sha256sum >/dev/null; then actual=$(sha256sum "$dest"); else actual=$(shasum -a 256 "$dest"); fi
 [[ "${actual%% *}" == "$digest" ]] || { echo 'Checksum mismatch' >&2; exit 2; }
}
ts=$(command -v tailscale || true)
if [[ -z "$ts" && "$platform" == macos && -x /Applications/Tailscale.app/Contents/MacOS/Tailscale ]]; then ts=/Applications/Tailscale.app/Contents/MacOS/Tailscale; fi
if [[ -z "$ts" ]]; then
 fetch "$TAILSCALE_URL" "$TAILSCALE_SHA256" "$tmp/tailscale"
 if [[ "$platform" == macos ]]; then
  sudo installer -pkg "$tmp/tailscale" -target /
 else
  sudo sh "$tmp/tailscale"
 fi
 ts=$(command -v tailscale || true)
 if [[ -z "$ts" && "$platform" == macos && -x /Applications/Tailscale.app/Contents/MacOS/Tailscale ]]; then ts=/Applications/Tailscale.app/Contents/MacOS/Tailscale; fi
fi
if ! command -v tsh >/dev/null; then
 fetch "$TELEPORT_URL" "$TELEPORT_SHA256" "$tmp/teleport"
 if [[ "$platform" == macos ]]; then
  sudo installer -pkg "$tmp/teleport" -target /
 else
  # Extract only the expected client executable from the verified official tarball.
  tar -xOf "$tmp/teleport" teleport/tsh > "$tmp/tsh"
  sudo install -m 0755 "$tmp/tsh" /usr/local/bin/tsh
 fi
fi
[[ -n "$ts" ]] || { echo 'Open Tailscale, approve OS VPN/system-extension prompts, then rerun.' >&2; exit 1; }
"$ts" version
tsh version
printf 'User completes invite + MFA separately. Then run: tsh login --proxy=%s\n' "$TELEPORT_PROXY"
if (( connect )); then
 echo 'Requesting Headscale login. Complete the displayed URL yourself; no browser is launched by this script.'
 # No --reset: never silently erase existing preferences. timeout bounds pending auth.
 if [[ "$platform" == linux ]]; then
  sudo "$ts" up --login-server="$HEADSCALE_LOGIN_SERVER" --timeout=5s
 else
  "$ts" up --login-server="$HEADSCALE_LOGIN_SERVER" --timeout=5s
 fi
else
 printf 'To request Headscale login, rerun with --apply --connect (server: %s).\n' "$HEADSCALE_LOGIN_SERVER"
fi
