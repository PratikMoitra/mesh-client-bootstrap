#!/usr/bin/env bash
set -euo pipefail
root=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
case "$(uname -s)" in
 Darwin) exec bash "$root/installers/unix.sh" macos "$@" ;;
 Linux) exec bash "$root/installers/unix.sh" linux "$@" ;;
 MINGW*|MSYS*|CYGWIN*) echo 'Use PowerShell: .\bootstrap.ps1'; exit 2 ;;
 *) echo 'Unsupported OS. See README for phones.' >&2; exit 2 ;;
esac
