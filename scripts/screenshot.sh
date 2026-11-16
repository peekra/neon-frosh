#!/usr/bin/env bash
# Capture only the display of the running Connect IQ simulator, without the
# picture of the watch around it (no Garmin logo), for store images and READMEs.
#
# Usage: scripts/screenshot.sh [device [out.png]]   (default: DEFAULT_DEVICE in env.sh)
#   Load the face first: scripts/run.sh <device>
#   -> bin/screenshots/<device>.png (or out.png): native display size, PNG,
#      transparent corners on round displays.
#
# macOS only (screencapture, Swift from the Xcode Command Line Tools). The
# terminal needs the Screen Recording permission once. On Windows and Linux,
# save and crop the screenshot by hand.
#
# Environment: see scripts/env.sh
set -euo pipefail

# shellcheck source=env.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/env.sh"

usage() {
  cat <<'EOF'
Usage: scripts/screenshot.sh [device [out.png]]
  Captures the display of the running simulator (load it with scripts/run.sh <device>)
  -> bin/screenshots/<device>.png at the display's native size. macOS only.
EOF
}

case "${1:-}" in
  -h|--help) usage; exit 0 ;;
  -*)        usage >&2; exit 2 ;;
esac
if [ "$#" -gt 2 ]; then
  usage >&2
  exit 2
fi
device="${1:-$DEFAULT_DEVICE}"
out="${2:-$BIN_DIR/screenshots/$device.png}"

[ "$CIQ_OS" = "mac" ] || die "screenshot.sh needs macOS. On this system save the simulator screenshot and crop the display by hand."
command -v swift >/dev/null 2>&1 || die "swift not found. Install the Xcode Command Line Tools: xcode-select --install"
require_project
check_device "$device"
profile="$GARMIN_DATA_DIR/Devices/$device"
[ -f "$profile/simulator.json" ] || die "Device profile not found: $profile (download it in the SDK Manager)"
simulator_listening || die "The simulator is not running. Load the face first: scripts/run.sh $device"

helper="$SCRIPTS_DIR/screenshot.swift"
window_id="$(swift "$helper" window)"
raw="$(mktemp -t ciq-window).png"
trap 'rm -f "$raw"' EXIT
screencapture -x -o -l "$window_id" "$raw" || die "screencapture failed (Screen Recording permission for the terminal?)"
mkdir -p "$(dirname "$out")"
swift "$helper" crop "$raw" "$profile" "$device" "$out"
info "OK: $out ($(file_size "$out") bytes)"
