#!/usr/bin/env bash
# Prepare (and, if a suitable CLI tool exists, perform) the sideload of the
# watch face onto a Garmin watch.
#
# Usage: scripts/install-watch.sh [--yes] [--debug] [device]   (default: DEFAULT_DEVICE in env.sh)
#   1. builds a RELEASE .prg named <APP_NAME>.prg (set in scripts/env.sh)
#      -> bin/release/<device>/<APP_NAME>.prg   (--debug: bin/debug/<device>/...)
#   2. looks for an MTP tool:
#        - 'mtp-rs' on PATH      -> offers to copy to /GARMIN/APPS/ itself
#        - an MTP GUI app found  -> prints the manual copy steps
#        - Windows               -> prints the steps for File Explorer
#        - nothing found         -> prints an error and how to get a tool; exit 3
#
# macOS does not mount Garmin watches in Finder (they use MTP, not USB mass
# storage), so a third-party MTP tool is required there. Windows shows the
# watch in File Explorer (not verified). This script NEVER installs anything.
# The 'mtp-rs' branch follows that tool's documented syntax and has not been
# tested against a real watch.
#
# Environment: see scripts/env.sh
set -euo pipefail

# shellcheck source=env.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/env.sh"

usage() {
  cat <<'EOF'
Usage: scripts/install-watch.sh [--yes] [--debug] [device]
  Builds a release .prg for the device (default: DEFAULT_DEVICE in env.sh) and copies it to
  GARMIN/APPS on the watch if an MTP command line tool (mtp-rs) is available;
  otherwise prints how to copy it with a GUI tool such as OpenMTP.
  --yes     do not ask before copying
  --debug   use a debug build instead of a release build
EOF
}

assume_yes=0
release_flag="-r"
device=""
while [ "$#" -gt 0 ]; do
  case "$1" in
    -h|--help) usage; exit 0 ;;
    -y|--yes)  assume_yes=1 ;;
    --debug)   release_flag="" ;;
    -*)        usage >&2; exit 2 ;;
    *)         [ -z "$device" ] || { usage >&2; exit 2; }; device="$1" ;;
  esac
  shift
done
device="${device:-$DEFAULT_DEVICE}"

require_toolchain
require_project
check_device "$device"

# Prints the first MTP GUI app found, or nothing.
find_mtp_gui_app() {
  local name dir
  for name in "OpenMTP" "Android File Transfer" "MacDroid"; do
    for dir in /Applications "$HOME/Applications"; do
      if [ -d "$dir/$name.app" ]; then
        printf '%s\n' "$dir/$name.app"
        return 0
      fi
    done
  done
  return 0
}

print_manual_steps() {
  cat <<EOF

Copy the app to the watch manually:
  1. Quit Garmin Express completely (also its menu bar icon). Garmin Express and
     MTP tools cannot talk to the watch at the same time.
  2. Connect the watch with the USB cable and unlock it.
  3. Open the MTP tool and browse to GARMIN/APPS on the watch.
  4. Copy this file there:
       $prg
  5. Disconnect / eject. On newer watches the .prg may vanish from GARMIN/APPS
     right after the copy; that is expected (the watch moves it to internal
     storage).
  6. On the watch: long-press the watch face, add a new face and pick the
     sideloaded one.
EOF
}

if [ -n "$release_flag" ]; then kind="release"; else kind="debug"; fi
prg="$BIN_DIR/$kind/$device/$APP_NAME.prg"
info "Building $kind .prg for $device -> ${prg#"$PROJECT_ROOT"/}"
rm -f "$prg"
build_device "$device" "$prg" $release_flag || die "Build failed for $device"
[ -f "$prg" ] || die "monkeyc finished but did not produce $prg"
info "Built $prg ($(file_size "$prg") bytes)"

# On Windows the process is listed as express.exe (not verified).
if process_running 'Garmin Express' || { [ "$CIQ_OS" = "windows" ] && process_running 'express.exe'; }; then
  warn "Garmin Express is running. Quit it completely before using an MTP tool."
fi

remote="/GARMIN/APPS/$APP_NAME.prg"

if command -v mtp-rs >/dev/null 2>&1; then
  info "Found MTP tool: $(command -v mtp-rs)"
  mtp-rs devices || die "mtp-rs could not list devices. Connect and unlock the watch; on macOS ptpcamerad may be grabbing it (see the mtp-rs documentation)."
  if [ "$assume_yes" -ne 1 ]; then
    printf 'Copy %s to the watch as %s? [y/N] ' "$prg" "$remote"
    read -r answer || answer=""
    case "$answer" in
      y|Y|yes|YES) ;;
      *) info "Aborted, nothing was copied."; print_manual_steps; exit 0 ;;
    esac
  fi
  mtp-rs put "$prg" "$remote" --replace --verify
  info "Copied. Disconnect the watch and select the watch face on it."
  exit 0
fi

if [ "$CIQ_OS" = "windows" ]; then
  info "Windows: copy the file with File Explorer (the watch appears under 'This PC')."
  print_manual_steps | sed 's/Open the MTP tool and browse to/Open File Explorer, select the watch under "This PC" and browse to/'
  exit 0
fi

gui_app="$(find_mtp_gui_app)"
if [ -n "$gui_app" ]; then
  info "No command line MTP tool, but found: $gui_app"
  print_manual_steps
  exit 0
fi

if [ "$CIQ_OS" = "linux" ]; then
  err "No MTP tool found."
  cat >&2 <<EOF
The build itself is done: $prg

Most Linux desktops show an MTP device in the file manager; copy the file to
GARMIN/APPS there (not verified), or install the CLI (this script does not
install anything):
  - mtp-rs (CLI, Rust):   cargo install mtp-rs-cli
EOF
  exit 3
fi

err "No MTP tool found. macOS cannot copy files to a Garmin watch without one."
cat >&2 <<EOF
The build itself is done: $prg

Install one of these (this script does not install anything):
  - OpenMTP (free GUI):   brew install --cask openmtp
  - mtp-rs (CLI, Rust):   cargo install mtp-rs-cli
Then run this script again, or copy the file to GARMIN/APPS on the watch yourself.
EOF
exit 3
