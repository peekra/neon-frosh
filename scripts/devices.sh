#!/usr/bin/env bash
# List Garmin devices from the installed device profiles and print ready-made manifest and jungle lines.
#
# Usage: scripts/devices.sh <command> [amoled|mip|all] [--min-api X.Y.Z] [--any-shape]
#   list      table: device id, display type, resolution, lowest Connect IQ version, name
#   ids       device ids only, one per line
#   manifest  <iq:product> lines for manifest.xml, AMOLED first, then MIP
#   jungle    excludeAnnotations lines for monkey.jungle (base = AMOLED, one line per MIP device)
#   groups    devices of the project's manifest.xml grouped by display type and resolution, with one
#             representative per group for the tests (references/testing.md)
#   find <text>   device ids whose name or id contains every word of <text>, e.g. find forerunner 165
#
# Only devices that can run a watch face are listed. Default filter: display type "all" (AMOLED and MIP),
# round displays, Connect IQ 5.2.0 or newer on every part number of the device (the template's minApiLevel).
# --any-shape also lists rectangular and semi-round watches, which need their own layout.
#
# The data comes from <Garmin folder>/Devices/<id>/compiler.json and simulator.json, which the SDK Manager
# downloads. A device whose profile is not installed cannot be listed: see references/devices.md for a
# checked list.
#
# Environment: GARMIN_DATA_DIR, DEVICES_DIR (see scripts/env.sh)
set -euo pipefail

# shellcheck source=env.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/env.sh"

DEVICES_DIR="${DEVICES_DIR:-$GARMIN_DATA_DIR/Devices}"

usage() {
  sed -n '2,12p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
}

# shellcheck disable=SC2020  # tr maps each of the five characters to a newline on purpose
# profile_rows: one line per installed watch-face device, tab separated:
#   id  displayType  width  height  shape  lowestApi  name
# The JSON is split at , { } [ ] so that the same code reads pretty-printed and minified files.
profile_rows() {
  local dir="" shape=""
  [ -d "$DEVICES_DIR" ] || die "Device profiles not found: $DEVICES_DIR (install devices with the SDK Manager or set DEVICES_DIR)"
  for dir in "$DEVICES_DIR"/*/; do
    [ -f "$dir/compiler.json" ] || continue
    shape="unknown"
    if [ -f "$dir/simulator.json" ]; then
      shape="$(tr ',{}[]' '\n\n\n\n\n' < "$dir/simulator.json" \
        | sed -n 's/.*"shape"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -n 1)"
      [ -n "$shape" ] || shape="unknown"
    fi
    tr ',{}[]' '\n\n\n\n\n' < "$dir/compiler.json" | tr -d '\r' | awk -v shape="$shape" '
      function value(line) {
        sub(/^[^:]*:[[:space:]]*/, "", line); gsub(/^"|"[[:space:]]*$/, "", line); return line
      }
      function rank(v,   p) { split(v, p, "."); return p[1] * 1000000 + p[2] * 1000 + p[3] }
      /"deviceId"[[:space:]]*:/     { id = value($0) }
      /"displayName"[[:space:]]*:/  { name = value($0) }
      /"displayType"[[:space:]]*:/  { type = value($0) }
      /"resolution"[[:space:]]*:/   { inRes = 1; next }
      inRes && /"width"[[:space:]]*:/  { w = value($0) + 0 }
      inRes && /"height"[[:space:]]*:/ { h = value($0) + 0 }
      inRes && w && h               { inRes = 0 }
      /"type"[[:space:]]*:[[:space:]]*"watchFace"/ { face = 1 }
      /"connectIQVersion"[[:space:]]*:/ {
        v = value($0); if (api == "" || rank(v) < rank(api)) { api = v }
      }
      END {
        if (face && id != "") { printf "%s\t%s\t%d\t%d\t%s\t%s\t%s\n", id, type, w, h, shape, api, name }
      }'
  done
}

# filtered_rows <type> <min api> <any shape 0|1>: profile_rows reduced to the wanted devices,
# AMOLED first, then MIP, each sorted by id.
filtered_rows() {
  profile_rows | awk -F '\t' -v want="$1" -v min="$2" -v anyShape="$3" '
    function rank(v,   p) { split(v, p, "."); return p[1] * 1000000 + p[2] * 1000 + p[3] }
    ($2 == "amoled" || $2 == "mip") && (want == "all" || $2 == want) \
      && (anyShape == 1 || $5 == "round") && rank($6) >= rank(min)' \
    | sort -t "$(printf '\t')" -k2,2 -k1,1
}

# normalized: lower case, without trademark signs and with plain letters, so "fenix 7" finds "fēnix® 7".
normalized() {
  sed -e 's/®//g' -e 's/™//g' -e 's/ē/e/g' -e 's/í/i/g' -e 's/ī/i/g' | tr '[:upper:]' '[:lower:]'
}

cmd_find() {
  [ "$#" -gt 0 ] || die "Usage: scripts/devices.sh find <text>"
  local query=""
  query="$(printf '%s' "$*" | normalized)"
  profile_rows | awk -F '\t' -v query="$query" '
    BEGIN { n = split(query, words, " ") }
    {
      hay = tolower($1 " " $7)
      gsub(/®|™/, "", hay); gsub(/ē/, "e", hay); gsub(/í|ī/, "i", hay)
      for (i = 1; i <= n; i++) { if (index(hay, words[i]) == 0) { next } }
      printf "%-22s %-7s %4dx%-4d %-12s API %-7s %s\n", $1, $2, $3, $4, $5, $6, $7
    }'
}

cmd_groups() {
  local wanted=""
  require_project
  wanted="$(manifest_devices | tr '\n' ' ')"
  [ -n "$wanted" ] || die "No <iq:product> entries found in $MANIFEST"
  profile_rows | awk -F '\t' -v wanted="$wanted" -v primary="$DEFAULT_DEVICE" '
    BEGIN { n = split(wanted, list, " "); for (i = 1; i <= n; i++) { inManifest[list[i]] = 1 } }
    inManifest[$1] {
      key = sprintf("%-6s %4dx%-4d", $2, $3, $4)
      seen[$1] = 1
      count[key]++
      members[key] = members[key] " " $1
      if (!(key in rep) || $1 == primary) { rep[key] = $1 }
    }
    END {
      for (key in count) { printf "%s  representative %-22s %2d devices:%s\n", key, rep[key], count[key], members[key] }
      for (i = 1; i <= n; i++) { if (!seen[list[i]]) { printf "NO PROFILE  %s\n", list[i] } }
    }' | sort
}

command="${1:-}"
case "$command" in
  ""|-h|--help) usage; [ -n "$command" ] || exit 2; exit 0 ;;
esac
shift

if [ "$command" = "find" ]; then
  cmd_find "$@"
  exit 0
fi
if [ "$command" = "groups" ]; then
  cmd_groups
  exit 0
fi

display="all"
min_api="5.2.0"
any_shape=0
while [ "$#" -gt 0 ]; do
  case "$1" in
    amoled|mip|all) display="$1" ;;
    --min-api)      shift; min_api="${1:-}"; [ -n "$min_api" ] || die "--min-api needs a version, e.g. 5.2.0" ;;
    --any-shape)    any_shape=1 ;;
    *)              usage >&2; exit 2 ;;
  esac
  shift
done
case "$min_api" in
  *[!0-9.]*|"") die "Invalid version: '$min_api'" ;;
esac

rows="$(filtered_rows "$display" "$min_api" "$any_shape")"
[ -n "$rows" ] || die "No device matches (display $display, Connect IQ >= $min_api). Are the device profiles installed?"

case "$command" in
  list)
    printf '%s\n' "$rows" | awk -F '\t' '
      { printf "%-22s %-7s %4dx%-4d %-12s API %-7s %s\n", $1, $2, $3, $4, $5, $6, $7; count[$2]++ }
      END { printf "\n%d AMOLED, %d MIP, %d devices\n", count["amoled"], count["mip"], NR }'
    ;;
  ids)
    printf '%s\n' "$rows" | cut -f 1
    ;;
  manifest)
    printf '%s\n' "$rows" | awk -F '\t' '
      $2 != last {
        printf "            <!-- %s -->\n", ($2 == "mip" ? "MIP (64 colours)" : "AMOLED"); last = $2
      }
      { printf "            <iq:product id=\"%s\"/>\n", $1 }'
    ;;
  jungle)
    echo "# Display type, selected at compile time: exactly one annotation of the pair stays in a build."
    echo "# A device line replaces the base value, so it names every pair again."
    echo "base.excludeAnnotations = mip"
    printf '%s\n' "$rows" | awk -F '\t' '$2 == "mip" { printf "%s.excludeAnnotations = amoled\n", $1 }'
    ;;
  *)
    usage >&2
    exit 2
    ;;
esac
