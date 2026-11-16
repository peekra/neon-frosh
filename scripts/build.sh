#!/usr/bin/env bash
# Build debug .prg files with monkeyc.
#
# Usage: scripts/build.sh [device|all]
#   device   one product id from manifest.xml (default: DEFAULT_DEVICE in env.sh) -> bin/<device>.prg
#   all      every product listed in manifest.xml; prints an OK/FAILED overview
#            and exits non-zero if any device fails
#
# Environment: SDK_BIN, DEVELOPER_KEY, TYPECHECK_LEVEL (default 2), MONKEYC_WARN,
#              MONKEYC_EXTRA, DEFAULT_DEVICE (see scripts/env.sh)
set -euo pipefail

# shellcheck source=env.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/env.sh"

usage() {
  cat <<'EOF'
Usage: scripts/build.sh [device|all]
  device   product id from manifest.xml (default: DEFAULT_DEVICE in env.sh) -> bin/<device>.prg
  all      build every device listed in manifest.xml and print a summary
EOF
}

build_single() {
  local device="$1" out="$BIN_DIR/$1.prg"
  check_device "$device"
  info "Building $device -> ${out#"$PROJECT_ROOT"/}"
  rm -f "$out"
  build_device "$device" "$out" || die "Build failed for $device"
  [ -f "$out" ] || die "monkeyc finished but did not produce $out"
  info "OK: $out ($(file_size "$out") bytes)"
}

build_all() {
  local devices device out log
  local ok_count=0 fail_count=0 summary="" started=$SECONDS
  devices="$(manifest_devices)"
  [ -n "$devices" ] || die "No <iq:product> entries found in $MANIFEST"

  # Global on purpose: the EXIT trap runs after this function has returned.
  BUILD_TMP="$(mktemp -d)"
  trap 'rm -rf "${BUILD_TMP:-}"' EXIT

  for device in $devices; do
    out="$BIN_DIR/$device.prg"
    log="$BUILD_TMP/$device.log"
    rm -f "$out"
    if build_device "$device" "$out" >"$log" 2>&1 && [ -f "$out" ]; then
      ok_count=$((ok_count + 1))
      summary="$summary$(printf '  %-14s OK (%s bytes)\n' "$device" "$(file_size "$out")")"$'\n'
      info "$device: OK"
      # Successful builds only show their warnings.
      grep -i 'warning' "$log" | sed 's/^/      /' || true
    else
      fail_count=$((fail_count + 1))
      summary="$summary$(printf '  %-14s FAILED\n' "$device")"$'\n'
      info "$device: FAILED"
      # Drop monkeyc's usage text, which it appends to argument errors.
      sed -e '/^usage:/,$d' -e 's/^/      /' "$log"
    fi
  done

  printf '\n==> Summary (%ss)\n%s' "$((SECONDS - started))" "$summary"
  printf '    %d OK, %d FAILED\n' "$ok_count" "$fail_count"
  [ "$fail_count" -eq 0 ]
}

if [ "$#" -gt 1 ]; then
  usage >&2
  exit 2
fi
target="${1:-$DEFAULT_DEVICE}"
case "$target" in
  -h|--help) usage; exit 0 ;;
  -*)        usage >&2; exit 2 ;;
esac

require_toolchain
require_project

if [ "$target" = "all" ]; then
  build_all
else
  build_single "$target"
fi
