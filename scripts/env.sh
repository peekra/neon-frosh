# shellcheck shell=bash
# env.sh - shared configuration and helpers for the Connect IQ watch face scripts.
#
# This file is sourced by the other scripts; it is not meant to be executed.
# Every setting below can be overridden from the environment, e.g.
#
#   DEVELOPER_KEY=/path/to/key.der scripts/build.sh fr965
#   TYPECHECK_LEVEL=3 scripts/build.sh all
#   SDK_BIN=/path/to/connectiq-sdk/bin scripts/run.sh
#
# NOTE: a project folder name may contain spaces. Every path is therefore
# derived from this file's location and quoted everywhere; never hard-code it.
#
# Compatible with the bash 3.2 that ships with macOS.
# Platforms: macOS (tested), Windows with Git Bash and Linux (not verified).
# WSL counts as Linux and needs the Linux SDK, or SDK_BIN pointing to an SDK.

if [ -n "${CIQ_ENV_LOADED:-}" ]; then
  return 0
fi
CIQ_ENV_LOADED=1

# --- Platform ----------------------------------------------------------------
case "$(uname -s 2>/dev/null)" in
  Darwin)              CIQ_OS="mac" ;;
  MINGW*|MSYS*|CYGWIN*) CIQ_OS="windows" ;;
  *)                   CIQ_OS="linux" ;;
esac

# to_unix_path <path>: C:\dir -> /c/dir on Windows (Git Bash), unchanged elsewhere.
to_unix_path() {
  if [ "$CIQ_OS" = "windows" ] && command -v cygpath >/dev/null 2>&1; then
    cygpath -u "$1"
  else
    printf '%s\n' "$1"
  fi
}

# --- Locations ---------------------------------------------------------------
# BASH_SOURCE is empty when this file is sourced from zsh; $0 is the sourced file there. Without the
# fallback the project root resolves to the wrong folder and a neighbouring project gets built.
SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
PROJECT_ROOT="${PROJECT_ROOT:-$SCRIPTS_DIR/..}"
PROJECT_ROOT="$(cd "$PROJECT_ROOT" && pwd)"

MANIFEST="${MANIFEST:-$PROJECT_ROOT/manifest.xml}"
JUNGLE="${JUNGLE:-$PROJECT_ROOT/monkey.jungle}"
BIN_DIR="${BIN_DIR:-$PROJECT_ROOT/bin}"

# --- Build settings ----------------------------------------------------------
# The watch of the developer. SET PER PROJECT.
DEFAULT_DEVICE="${DEFAULT_DEVICE:-fr165}"
DEVELOPER_KEY="${DEVELOPER_KEY:-$HOME/.garmin/developer_key.der}"
# monkeyc -l: 0=off, 1=gradual, 2=informative, 3=strict; build releases with 3
TYPECHECK_LEVEL="${TYPECHECK_LEVEL:-2}"
# 1 = pass -w (show compiler warnings)
MONKEYC_WARN="${MONKEYC_WARN:-1}"
# Extra monkeyc flags, word-split on purpose (e.g. MONKEYC_EXTRA="-O 2")
MONKEYC_EXTRA="${MONKEYC_EXTRA:-}"
# File name of the app on the watch (GARMIN/APPS/<APP_NAME>.prg). SET PER PROJECT.
APP_NAME="${APP_NAME:-NeonFrosh}"
# Output of scripts/package.sh (Connect IQ Store packages)
STORE_DIR="${STORE_DIR:-$BIN_DIR/store}"
PACKAGE_FILE="${PACKAGE_FILE:-$STORE_DIR/$APP_NAME.iq}"             # public app
BETA_PACKAGE_FILE="${BETA_PACKAGE_FILE:-$STORE_DIR/$APP_NAME-beta.iq}" # beta app
# App id of the beta app in the Connect IQ Store. SET PER PROJECT: generate it once
# with uuidgen (lower case). Every beta update must be uploaded with this same id, so it is
# fixed here and NOT overridable. The public app keeps the id in manifest.xml.
# shellcheck disable=SC2034  # used by package.sh
BETA_APP_ID="cfc1f7d9-8955-40b0-83d0-892ed7de48c4"

# --- SDK / simulator ---------------------------------------------------------
# Folder of the Garmin SDK Manager (SDKs, device profiles, current-sdk.cfg), as given in the SDK
# documentation "Using Monkey C from the Command Line".
if [ -z "${GARMIN_DATA_DIR:-}" ]; then
  case "$CIQ_OS" in
    mac)     GARMIN_DATA_DIR="$HOME/Library/Application Support/Garmin/ConnectIQ" ;;
    windows) GARMIN_DATA_DIR="$(to_unix_path "${APPDATA:-$HOME/AppData/Roaming}")/Garmin/ConnectIQ" ;;
    *)       GARMIN_DATA_DIR="$HOME/.Garmin/ConnectIQ" ;;
  esac
fi
# monkeydo talks to the simulator on 127.0.0.1:1234 (hard-wired in the SDK's
# "shell" tool); only change this if the SDK changes.
SIM_PORT="${SIM_PORT:-1234}"
SIM_START_TIMEOUT="${SIM_START_TIMEOUT:-90}"   # seconds to wait for the simulator
SIM_SETTLE_SECONDS="${SIM_SETTLE_SECONDS:-2}"  # extra pause once the port is open

# --- Output helpers ----------------------------------------------------------
info() { printf '==> %s\n' "$*"; }
warn() { printf 'WARNING: %s\n' "$*" >&2; }
err()  { printf 'ERROR: %s\n' "$*" >&2; }
die()  { err "$*"; exit 1; }

# --- SDK and toolchain checks ------------------------------------------------

# Sets SDK_BIN (the SDK's bin directory). Order: $SDK_BIN, then the SDK that the
# Garmin SDK Manager marks as current, then the newest installed SDK.
resolve_sdk_bin() {
  if [ -n "${SDK_BIN:-}" ]; then
    return 0
  fi
  local cfg="$GARMIN_DATA_DIR/current-sdk.cfg" root="" newest=""
  if [ -r "$cfg" ]; then
    root="$(head -n 1 "$cfg" | tr -d '\r')"
    root="$(to_unix_path "$root")"
    root="${root%/}"
    root="${root%\\}"
  fi
  if [ -n "$root" ] && [ -d "$root/bin" ]; then
    SDK_BIN="$root/bin"
    return 0
  fi
  # shellcheck disable=SC2012  # SDK folder names are plain ASCII
  newest="$(ls -1d "$GARMIN_DATA_DIR"/Sdks/connectiq-sdk-*/ 2>/dev/null | sort | tail -n 1 || true)"
  newest="${newest%/}"
  if [ -n "$newest" ] && [ -d "$newest/bin" ]; then
    SDK_BIN="$newest/bin"
    return 0
  fi
  return 1
}

# sdk_tool <name>: path of an SDK command (monkeyc, monkeydo, connectiq). Windows uses the .bat files.
sdk_tool() {
  if [ "$CIQ_OS" = "windows" ] && [ -f "$SDK_BIN/$1.bat" ]; then
    printf '%s\n' "$SDK_BIN/$1.bat"
  else
    printf '%s\n' "$SDK_BIN/$1"
  fi
}

# Verifies SDK, Java and developer key. Exports SDK_BIN for child processes.
require_toolchain() {
  resolve_sdk_bin || die "Connect IQ SDK not found in $GARMIN_DATA_DIR. Install it with the SDK Manager or set SDK_BIN to its bin directory."
  export SDK_BIN
  MONKEYC="$(sdk_tool monkeyc)"
  # shellcheck disable=SC2034  # used by run.sh and test.sh
  MONKEYDO="$(sdk_tool monkeydo)"
  CONNECTIQ="$(sdk_tool connectiq)"
  [ -f "$MONKEYC" ] || die "monkeyc not found: $MONKEYC"
  java -version >/dev/null 2>&1 || die "Java not found (needed by monkeyc). Install a JDK or fix PATH / JAVA_HOME."
  [ -f "$DEVELOPER_KEY" ] || die "Developer key not found: $DEVELOPER_KEY (create one with the VS Code command 'Monkey C: Generate a Developer Key' and keep it outside the project; override with DEVELOPER_KEY=...)"
}

# Verifies that the project files exist (they are written by other agents).
require_project() {
  [ -f "$MANIFEST" ] || die "manifest.xml not found: $MANIFEST (project is not buildable yet)"
  [ -f "$JUNGLE" ]   || die "monkey.jungle not found: $JUNGLE (project is not buildable yet)"
}

# --- Manifest helpers --------------------------------------------------------

# manifest_devices [manifest]
# Prints the product (device) IDs from manifest.xml (or the given manifest), one per line.
manifest_devices() {
  tr '\n\r' '  ' < "${1:-$MANIFEST}" \
    | { grep -o '<iq:product[[:space:]][^>]*>' || true; } \
    | sed -n 's/.*[[:space:]]id="\([^"]*\)".*/\1/p'
}

# manifest_app_id [manifest]
# Prints the application id from manifest.xml (or the given manifest).
manifest_app_id() {
  tr '\n\r' '  ' < "${1:-$MANIFEST}" \
    | { grep -o '<iq:application[[:space:]][^>]*>' || true; } \
    | sed -n 's/.*[[:space:]]id="\([^"]*\)".*/\1/p'
}

# Dies with a helpful message unless $1 is a product listed in manifest.xml.
check_device() {
  local wanted="$1" known="" d=""
  case "$wanted" in
    ""|*[!a-z0-9_]*) die "Invalid device id: '$wanted'" ;;
  esac
  known="$(manifest_devices)"
  [ -n "$known" ] || die "No <iq:product> entries found in $MANIFEST"
  for d in $known; do
    if [ "$d" = "$wanted" ]; then
      return 0
    fi
  done
  die "Device '$wanted' is not listed in manifest.xml. Available: $(printf '%s' "$known" | tr '\n' ' ')"
}

# --- Build -------------------------------------------------------------------

# build_device <device> <output.prg> [extra monkeyc flags...]
# Runs monkeyc for one device; the exit code is monkeyc's.
build_device() {
  local device="$1" out="$2"
  shift 2
  local warn_flag=""
  if [ "$MONKEYC_WARN" = "1" ]; then
    warn_flag="-w"
  fi
  mkdir -p "$(dirname "$out")"
  # shellcheck disable=SC2086  # warn_flag and MONKEYC_EXTRA are meant to word-split
  ( cd "$PROJECT_ROOT" && "$MONKEYC" \
      -d "$device" -f "$JUNGLE" -o "$out" -y "$DEVELOPER_KEY" \
      $warn_flag -l "$TYPECHECK_LEVEL" $MONKEYC_EXTRA "$@" )
}

# Prints a size in bytes for a file (portable, no stat flags).
file_size() { wc -c < "$1" | tr -d ' '; }

# --- Simulator ---------------------------------------------------------------

# process_running <name>: true if a process whose command line contains <name> runs.
# Windows: matched against the image names of tasklist (not verified).
process_running() {
  if [ "$CIQ_OS" = "windows" ]; then
    tasklist 2>/dev/null | grep -qi -- "$1"
  else
    pgrep -fi -- "$1" >/dev/null 2>&1
  fi
}

simulator_process_running() {
  case "$CIQ_OS" in
    mac) pgrep -f 'ConnectIQ\.app/Contents/MacOS/simulator' >/dev/null 2>&1 ;;
    *)   process_running 'simulator' ;;
  esac
}

# True once something accepts connections on the simulator port. Without lsof
# (Git Bash, minimal Linux) bash's /dev/tcp opens a test connection.
simulator_listening() {
  if command -v lsof >/dev/null 2>&1; then
    lsof -nP -iTCP:"$SIM_PORT" -sTCP:LISTEN >/dev/null 2>&1
  else
    (exec 3<>"/dev/tcp/127.0.0.1/$SIM_PORT") 2>/dev/null
  fi
}

# Starts the Connect IQ simulator only if it is not running, then waits until it
# listens on SIM_PORT.
ensure_simulator() {
  if simulator_listening; then
    info "Simulator already running (port $SIM_PORT)"
    return 0
  fi
  if simulator_process_running; then
    info "Simulator is starting, waiting for port $SIM_PORT ..."
  else
    info "Starting Connect IQ simulator ..."
    if [ "$CIQ_OS" = "mac" ]; then
      "$CONNECTIQ"
    else
      # In the background, in case the launcher waits for the simulator to exit (not verified).
      "$CONNECTIQ" >/dev/null 2>&1 &
    fi
  fi
  local waited=0
  until simulator_listening; do
    if [ "$waited" -ge "$SIM_START_TIMEOUT" ]; then
      die "Simulator did not open port $SIM_PORT within ${SIM_START_TIMEOUT}s. Start it manually: \"$CONNECTIQ\""
    fi
    sleep 1
    waited=$((waited + 1))
  done
  sleep "$SIM_SETTLE_SECONDS"
  info "Simulator ready (port $SIM_PORT)"
}
