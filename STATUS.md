# STATUS – 1.0.0, 2026-11-15
## State
Neon Frosh 1.0.0 is built and store material is ready. Not yet on the user's watch, not uploaded (public release, no beta).

## Packages
- Store: `bin/store/NeonFrosh.iq` (3,283,107 bytes, 72 of 72 part-number builds for the 59 devices), app id
  `d064acde-a932-42bf-a3d8-7acf2462dcb8` checked inside the package. Built after the last code change (kindAt fix).
- Watch (USB): `bin/release/fr165/NeonFrosh.prg` (61,148 bytes).
- Beta app id (scripts/env.sh, unused in 1.0.0): `cfc1f7d9-8955-40b0-83d0-892ed7de48c4`
- Store material: `design/store/` (icon_500.png, 5 screenshots 1024x1024 indexed ≤150 KB, hero_1440x720.png,
  listing_en.md, listing_de.md, README.md = upload guide). Tools: `design/drafts/store_tools/`, raw captures
  `design/drafts/captures/` (`fields_b.png` there is an unused leftover of the first round).

## Content of this version
- Layout after `design/reference.jpg`: solid hours (colour 1), outline minutes and colon (colour 2), top and bottom
  panel, four round fields with progress ring in colour 1, Bluetooth + battery from the user's SVG.
- Light and dark background; 8 colours in two roles; 6 user-selectable slots (new kind DATE); phone settings and
  on-device menu (EN, DE).
- Battery 3 bars by charge, ≤15 % red outline; Bluetooth colour 2 / grey.
- Active calories ring goal 1000 kcal. Weather icons: ink cloud outline, details colour 1.
- AMOLED always-on: time only, white outline, burn-in shift per minute.
- Touch and hold on a field opens the matching system view (mapping in `source/ComplicationSource.mc`).
- Bitmap fonts from Saira (OFL) per resolution, generator in `design/drafts/fonts/`.

## Checked
- `TYPECHECK_LEVEL=3 scripts/build.sh all`: 59 OK, 0 failed (only warning: launcher icon 70x70 scaled).
- Unit tests 24/24 on fr165 and fenix7 after the last change; 19/19 earlier on all 9 representatives
  (fr165, fr265s, approachs7243mm, approachs7247mm, fenix9pro51mm, fr255s, fenix7s, fenix7, enduro3).
  ColorTest incl. always-on white on AMOLED and MIP. TouchTest: opensView, typeForKind, kindAt.
- Simulator screenshots (design/screenshots/): fr165 dark/light, fenix7 dark/light, fr255s; battery 100/60/30/10/null,
  Bluetooth on/off, all 7 weather kinds in field and panel, always-on white (forced drawAlwaysOn).

## Not checked
- Touch and hold opening a view (simulator access for that was not granted) — check on the watch; calendar,
  weekly run/bike and steps views depend on the watch.
- Real low-power / always-on switch and burn-in shift over minutes; "--" for missing data visually; 12 h mode;
  other languages; phone settings in Connect IQ app; memory/watchdog on the smallest device.
- New screenshots on 240/280/360/416/454/466 after the weather and touch changes (only unit tests and builds).
- Store upload form (login only), forum size limits (150 KB screenshots, 300 KB icon).
- On 218 px rain and showers icons are hard to tell apart.

## Next steps (user)
1. Copy `bin/release/fr165/NeonFrosh.prg` to the watch (GARMIN/APPS), test fields, touch and hold, always-on.
2. Upload `bin/store/NeonFrosh.iq` with the material and texts in `design/store/` following `design/store/README.md`.

## Hints
- zsh in the shell: `echo "===="` with unquoted `=` fails (equals expansion). Quote separators.
