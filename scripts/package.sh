#!/usr/bin/env bash
# Create a Connect IQ Store package (.iq, release build) for every device in manifest.xml.
#
# Usage: scripts/package.sh [--beta]
#   (no option)  public app, app id from manifest.xml
#                -> bin/store/<APP_NAME>.iq       (override with PACKAGE_FILE=...)
#   --beta       beta app, fixed app id BETA_APP_ID from scripts/env.sh
#                -> bin/store/<APP_NAME>-beta.iq  (override with BETA_PACKAGE_FILE=...)
#
# How the beta id gets in without touching manifest.xml: a jungle can only name a
# manifest, and the SDK resolves its default resource paths (resources,
# resources-deu, ...) against the folder of that manifest. The beta is therefore
# built from a temporary copy of the project in bin/store/beta-build/
# (monkey.jungle, source/, tests/, every resources*/ folder) with a copy of
# manifest.xml whose application id is replaced by BETA_APP_ID. The copy is
# removed afterwards. Both packages contain the same code and resources.
#
# Environment: see scripts/env.sh
set -euo pipefail

# shellcheck source=env.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/env.sh"

usage() {
  cat <<'EOF'
Usage: scripts/package.sh [--beta]
  Creates a Connect IQ Store package (release build, all devices in manifest.xml).
    (no option)  public app (app id from manifest.xml) -> bin/store/<APP_NAME>.iq
    --beta       beta app (BETA_APP_ID in scripts/env.sh) -> bin/store/<APP_NAME>-beta.iq
  manifest.xml is never changed; the beta is built from a temporary copy in bin/store/.
EOF
}

beta=0
case "${1:-}" in
  -h|--help) usage; exit 0 ;;
  --beta)    beta=1 ;;
  "")        ;;
  *)         usage >&2; exit 2 ;;
esac
if [ "$#" -gt 1 ]; then
  usage >&2
  exit 2
fi

require_toolchain
require_project

devices="$(manifest_devices)"
[ -n "$devices" ] || die "No <iq:product> entries found in $MANIFEST"
public_id="$(manifest_app_id)"
[ -n "$public_id" ] || die "No application id found in $MANIFEST"

# build_root: folder with the jungle and the manifest the package is built from
if [ "$beta" = "1" ]; then
  out="$BETA_PACKAGE_FILE"
  app_id="$BETA_APP_ID"
  [ -n "$app_id" ] || die "BETA_APP_ID is empty: generate one with uuidgen and set it in scripts/env.sh"
  [ "$app_id" != "$public_id" ] || die "BETA_APP_ID equals the public app id in $MANIFEST"
  build_root="$STORE_DIR/beta-build"
  rm -rf "$build_root"
  mkdir -p "$build_root"
  trap 'rm -rf "$build_root"' EXIT
  cp "$JUNGLE" "$build_root/"
  # tests/ is optional; copy only what exists so a project without tests can be packaged too.
  for dir in "$PROJECT_ROOT/source" "$PROJECT_ROOT/tests" "$PROJECT_ROOT"/resources*; do
    if [ -d "$dir" ]; then
      cp -R "$dir" "$build_root/"
    fi
  done
  manifest_copy="$build_root/$(basename "$MANIFEST")"
  # Replace the id only in the <iq:application ...> tag.
  sed "/<iq:application[[:space:]]/s/[[:space:]]id=\"$public_id\"/ id=\"$app_id\"/" \
    "$MANIFEST" > "$manifest_copy"
  [ "$(manifest_app_id "$manifest_copy")" = "$app_id" ] \
    || die "Could not set the beta app id in $manifest_copy"
  [ "$(manifest_devices "$manifest_copy")" = "$devices" ] \
    || die "Device list of $manifest_copy differs from $MANIFEST"
  jungle="$build_root/$(basename "$JUNGLE")"
  info "Packaging BETA app (id $app_id) for: $(printf '%s' "$devices" | tr '\n' ' ')"
else
  out="$PACKAGE_FILE"
  app_id="$public_id"
  build_root="$PROJECT_ROOT"
  jungle="$JUNGLE"
  info "Packaging PUBLIC app (id $app_id) for: $(printf '%s' "$devices" | tr '\n' ' ')"
fi

rm -f "$out"
mkdir -p "$(dirname "$out")"

warn_flag=""
if [ "$MONKEYC_WARN" = "1" ]; then
  warn_flag="-w"
fi
# shellcheck disable=SC2086  # warn_flag and MONKEYC_EXTRA are meant to word-split
( cd "$build_root" && "$MONKEYC" -e -r \
    -f "$jungle" -o "$out" -y "$DEVELOPER_KEY" \
    $warn_flag -l "$TYPECHECK_LEVEL" $MONKEYC_EXTRA )

[ -f "$out" ] || die "monkeyc finished but did not produce $out"
info "OK: $out ($(file_size "$out") bytes, app id $app_id)"
