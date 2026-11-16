#!/usr/bin/env bash
# Build and run the Monkey C unit tests in the Connect IQ simulator.
#
# Usage: scripts/test.sh [device [test_name ...]]     (default: DEFAULT_DEVICE in env.sh)
#   Builds bin/test-<device>.prg with -t, starts the simulator if needed and
#   runs monkeydo with -t. Without test names all (:test) functions run.
#   monkeydo's own exit code is NOT used (SDK 9.3.0 returns 1 even when all tests
#   pass). The result is taken from monkeydo's summary line instead, and the
#   full output is kept in bin/test-<device>.log:
#     exit 0  "PASSED (passed=N, failed=0 , errors=0)"
#     exit 1  "FAILED (...)"
#     exit 2  neither line found (no tests compiled in, simulator unreachable, crash)
#
# Needs (:test) functions in a directory that monkey.jungle puts on the source
# path (the project layout of this skill keeps them in tests/).
#
# Environment: see scripts/env.sh
set -euo pipefail

# shellcheck source=env.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/env.sh"

usage() {
  cat <<'EOF'
Usage: scripts/test.sh [device [test_name ...]]
  Builds bin/test-<device>.prg (default: DEFAULT_DEVICE in env.sh) with unit tests enabled,
  starts the simulator if needed and runs the tests with monkeydo -t.
EOF
}

case "${1:-}" in
  -h|--help) usage; exit 0 ;;
  -*)        usage >&2; exit 2 ;;
esac
device="${1:-$DEFAULT_DEVICE}"
if [ "$#" -gt 0 ]; then
  shift
fi

require_toolchain
require_project
check_device "$device"

if ! grep -rqs --include='*.mc' '(:test)' "$PROJECT_ROOT/source" "$PROJECT_ROOT/tests"; then
  warn "No (:test) functions found under source/ or tests/; the test run will report no results."
fi

prg="$BIN_DIR/test-$device.prg"
info "Building unit tests for $device -> ${prg#"$PROJECT_ROOT"/}"
rm -f "$prg"
build_device "$device" "$prg" -t || die "Build of the unit tests failed for $device"
[ -f "$prg" ] || die "monkeyc finished but did not produce $prg"

ensure_simulator

log="$BIN_DIR/test-$device.log"
info "Running unit tests on $device (output also in ${log#"$PROJECT_ROOT"/})"
rc=0
"$MONKEYDO" "$prg" "$device" -t "$@" 2>&1 | tee "$log" || rc=$?
info "monkeydo exit code $rc (ignored, see header)"

# Read the verdict from the summary line; FAILED wins if both should appear.
failed_line="$(tr -d '\r' < "$log" | grep -E '^[[:space:]]*FAILED \(' | tail -n 1 || true)"
passed_line="$(tr -d '\r' < "$log" | grep -E '^[[:space:]]*PASSED \(' | tail -n 1 || true)"

if [ -n "$failed_line" ]; then
  err "Tests ${failed_line#"${failed_line%%[![:space:]]*}"}"
  exit 1
elif [ -n "$passed_line" ]; then
  case "$passed_line" in
    *"passed=0,"*) warn "The test run reports 0 passed tests; are there any (:test) functions?" ;;
  esac
  info "Tests ${passed_line#"${passed_line%%[![:space:]]*}"}"
  exit 0
else
  err "No test result found: monkeydo printed neither 'PASSED (...)' nor 'FAILED (...)'."
  err "Possible causes: no (:test) functions compiled in, simulator not reachable, app crash. See ${log#"$PROJECT_ROOT"/}"
  exit 2
fi
