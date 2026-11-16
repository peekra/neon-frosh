#!/usr/bin/env bash
# Build a device and load it into the Connect IQ simulator.
#
# Usage: scripts/run.sh [device]        (default: DEFAULT_DEVICE in env.sh)
#   1. builds bin/<device>.prg (scripts/build.sh)
#   2. starts the simulator only if it is not running and waits until it is ready
#   3. loads the app with monkeydo
#
# monkeydo stays attached and streams the app's System.println output; press
# Ctrl-C to detach (the simulator keeps running).
#
# Environment: SKIP_BUILD=1 reuses an existing bin/<device>.prg.
#              See scripts/env.sh for the other variables.
set -euo pipefail

# shellcheck source=env.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/env.sh"

usage() {
  cat <<'EOF'
Usage: scripts/run.sh [device]
  Builds bin/<device>.prg (default: DEFAULT_DEVICE in env.sh), starts the simulator if needed and
  loads the app with monkeydo. SKIP_BUILD=1 skips the build step.
EOF
}

if [ "$#" -gt 1 ]; then
  usage >&2
  exit 2
fi
device="${1:-$DEFAULT_DEVICE}"
case "$device" in
  -h|--help) usage; exit 0 ;;
  -*)        usage >&2; exit 2 ;;
esac

require_toolchain
if [ "${SKIP_BUILD:-0}" != "1" ]; then
  "$SCRIPTS_DIR/build.sh" "$device"
fi

prg="$BIN_DIR/$device.prg"
[ -f "$prg" ] || die "Build output not found: $prg"

ensure_simulator

info "Loading $device into the simulator (Ctrl-C detaches, the simulator stays open)"
rc=0
"$MONKEYDO" "$prg" "$device" || rc=$?
# monkeydo of SDK 9.3.0 returns 1 even on success, so its exit code carries no
# information and is only logged. Errors (e.g. simulator unreachable, unsigned
# .prg) are visible in its own output above.
info "monkeydo finished (exit code $rc, not evaluated)"
