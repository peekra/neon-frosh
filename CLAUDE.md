# CLAUDE.md – Neon Frosh
Rule: if something is not settled here, ask the user. Never invent a user decision.
Skill: `~/.claude/skills/garmin-watch-face-dev/` (read `references/best-practices.md` before writing code).

## Goal
Garmin watch face "Neon Frosh" for round watches. Primary device: `fr165` (Forerunner 165, 390 px AMOLED).
Delivery: `.prg` for fr165 and a store `.iq` with store images and texts (user, 2026-11-15).

## Versions
| Version | Date | Content |
|---|---|---|
| 1.0.0 | 2026-11 | store-ready: 59 devices, bitmap fonts, six data fields, eight colours, phone settings (see `STATUS.md`) |

## Environment
Connect IQ SDK 9.3.0 on macOS, key `~/.garmin/developer_key.der` (outside the project, never in git).
Build `TYPECHECK_LEVEL=3 scripts/build.sh <device|all>`, tests `scripts/test.sh <device>`.
Only ONE agent may use the simulator at a time (tests, run, screenshots): that is the tester.
Designer and developer only build.

## Language
Chat with the user: German. Code, comments, commits: English.

## Target devices
59 round watches (40 AMOLED, 19 MIP), the list in `manifest.xml` (AMOLED and MIP),
`minApiLevel` 5.2.0. `scripts/devices.sh groups` prints the test representatives (to be checked for this project).
`monkey.jungle` pairs: `amoled`/`mip` and `climb`/`noclimb`, settings variants `resources-settings-climb` /
`resources-settings-noclimb`. Left out: `instinctcrossoveramoled` (see `references/devices.md`).

## Design specification
Reference image: `design/reference.jpg` (user, 2026-11-15). Round face, light and dark background.
Elements top to bottom:
1. **Battery and Bluetooth** at the top centre, small. Geometry from `design/battery_bluetooth.svg` (viewBox 74x24,
   stroke 2): Bluetooth rune left, battery outline with nipple right, 0..3 bars by charge (0-15 % 0 bars and the
   outline in the warning colour, 16-40 % 1, 41-70 % 2, 71-100 % 3). Drawn as vectors, scaled per resolution.
   Battery in ink; Bluetooth in colour 2 while connected, `btOff` grey when not.
2. **Top panel** (slot 1, default date "AUG 29"): a band below the icons, its lower edge an arc that follows the
   time (concave, as in the reference). Fill: dimmed colour 2, text in ink, bold.
3. **Four round fields** (slots 2-5): circles with an ink outline at upper-left, upper-right, lower-left, lower-right,
   icon above the value. Where the kind has a fraction (`SlotScale.fraction`), a progress arc on the circle in
   colour 1 (reference: calories ring).
4. **Time** large in the centre, `10:08`: hours solid in colour 1, minutes as outline digits in colour 2, colon as two
   small outlined squares in colour 2. Follows the 12/24 h setting.
5. **Bottom panel** (slot 6, default steps): mirror of the top panel, value in ink, label (e.g. "STEP") below in
   colour 2.
Style: flat, high contrast, no glow. No seconds display.

## Colours (decided by the user on 2026-11-15)
- Background: dark (black) or light (white), property `DarkBackground`, default dark.
- One palette of **8 colours** (`ColorChoice`): 0 red, 1 orange, 2 yellow, 3 green, 4 teal, 5 blue, 6 purple,
  7 pink. Two roles, each picks any of the 8:
  - **colour 1** (`Color1`, default red): hours, progress arcs;
  - **colour 2** (`Color2`, default teal): minute outline, colon, panels, Bluetooth, panel labels.
- Each colour has a value per background and per display type (AMOLED / MIP; MIP only channels 00/55/AA/FF), plus a
  dimmed "panel fill" variant per background. Ink: white on dark, black on light. Text on a panel fill is ink and
  must reach contrast 4.5:1; colour 1/2 against the background at least 3:1 (large digits, arcs).
- The designer proposes the values with contrast numbers in `design/drafts/palette.md`; the lead shows them to the
  user before they are final. `tests/ColorTest.mc` checks every pair.

## Data sources
Six user-selectable slots, kind list `DataKind` (numbers stored on the watch, never renumber; `DATE` = 13 is new).

| Slot (index) | Element | Default |
|---|---|---|
| 0 `TOP` | Top panel | DATE |
| 1 `UPPER_LEFT` | Round field | WEATHER |
| 2 `UPPER_RIGHT` | Round field | BODY_BATTERY |
| 3 `LOWER_LEFT` | Round field | HEART_RATE |
| 4 `LOWER_RIGHT` | Round field | ACTIVE_CAL (reference "171" with flame and ring) |
| 5 `BOTTOM` | Bottom panel | STEPS |

`DataKind.NONE` leaves the slot empty (round field: outline only). Null rule: a missing value shows `--`, the icon
stays. DATE in a round field: day number with the month above.

## User settings
Properties (phone app and on-device menu, menu in this order): DarkBackground (bool), Color1 (0..7), Color2 (0..7),
Slot1..Slot6 (DataKind). Invalid stored values fall back to the defaults. Same settings variants climb/noclimb as before.

## Display and energy rules
See `references/best-practices.md` of the skill. Update once per minute (no seconds). Data refresh as in the
copied DataProvider (only kinds in use).
**Always-on / low power (user decision 2026-11-15):** AMOLED shows only the time as thin outline digits, always
white (hours and minutes, independent of colour 1/2), no panels, no fields, no icons; position shifts by a few
pixels per minute (burn-in). MIP keeps the normal face in low power (no seconds anyway).

## Project structure
Layout: `source/`, `tests/`, `scripts/`, `resources*`, `manifest.xml`, `monkey.jungle`.
`design/` for reference pictures, drafts (`design/drafts/`) and the battery/Bluetooth SVG.
`bin/` is build output (not in git).

## Build & run
- `TYPECHECK_LEVEL=3 scripts/build.sh fr165`
- `scripts/test.sh fr165`
- `scripts/run.sh fr165` (simulator, tester only)

## Team and roles
Roles and file ownership from the skill's `references/team-mode.md`:

| Role | Responsible for | Files |
|---|---|---|
| Lead (main session) | Talks to the user, spec, interface, `CLAUDE.md`/`STATUS.md`, commits on the user's word | `CLAUDE.md`, `STATUS.md`, `source/DataKind.mc` and other interface modules |
| UI (designer) | Look, layout, fonts, icons, drawers, colours with contrast test, always-on view | `source/ui/`, `resources/drawables/`, `design/drafts/`, `tests/ColorTest.mc` |
| Developer | Life cycle, sleep/wake, timers, data, null handling, settings and menu, manifest, jungle, strings, scripts | `source/` without `ui/`, `source/settings/`, `manifest.xml`, `monkey.jungle`, `resources/strings/`, `resources-*/`, `scripts/` |
| Tester | Unit tests, simulator checks, screenshots, missing-data cases | `tests/`, `design/screenshots/` |
| Store (only for a store release) | Icon, store screenshots, texts, upload guide | `design/store/`, `design/drafts/` |

Handover rules: see `team-mode.md`. Agents never run git. Simulator: only the tester uses it.
Each agent briefing repeats the language rule above.

## User decisions
### 2026-11-15
- Goal: "Neon Frosh", round, 59 devices, primary device fr165.
- Background: light and dark.
- Colours: 8 selectable, two roles (colour 1 = hours/ring, colour 2 = minutes outline/panels). Default red/teal.
- Data: 6 user-selectable slots (date panel, 4 round fields, steps panel). DataKind includes NONE.
  Defaults: date, weather, body battery, heart rate, steps, calories.
- Battery and Bluetooth icon geometry from `design/battery_bluetooth.svg`.
- Reference: large time 10:08, hours solid, minutes outlined, panels top and bottom.
- Reference image saved as `design/reference.jpg`.
- Slot mapping: top panel date, round fields weather / body battery / heart rate / active calories, bottom panel
  steps (as in the reference). New kind DATE.
- Always-on (AMOLED): only the time as outline, no panels, fields or icons.
- Colour palette: red, orange, yellow, green, teal, blue, purple, pink (lead proposal from the reference, values open).
- Palette in `design/drafts/palette.md` confirmed by the user (all values final).
- Font: Saira (bitmap fonts per resolution, generator in `design/drafts/fonts/`).
- Icon order top: Bluetooth left, battery right (as in the SVG).
- Active calories ring: fixed goal 1000 kcal (`SlotScale.ACTIVE_CAL_GOAL`).
- Date: EN "AUG 29", DE "29. AUG"; 12 h without leading zero, minutes always two digits.
- Always-on is always white (hours and minutes outline, colon), whatever colours are chosen.
- Battery icon: 3 steps (bars) are enough; Bluetooth colour 2 when connected, grey when not.
- Weather icons: cloud as ink outline, sun/rain/snow/lightning in colour 1, same size as the other field icons.
- Every field is pressable: touch and hold on a field opens the matching system view of its data kind
  (watch faces get no short tap — platform limit; needs a touchscreen). Kinds without a system view do nothing.
- Store release 1.0.0: public only (no beta), store languages EN + DE.
- Store package at the end: .iq for the 59 devices (AMOLED and MIP), store images and texts.

## Interface UI <-> logic (lead, 2026-11-15)
Changes only through the lead. The developer implements the logic side first (it must build), the UI side draws.

```
module DataKind      // + const DATE = 13; COUNT = 14;
                     // slots: TOP=0 UPPER_LEFT=1 UPPER_RIGHT=2 LOWER_LEFT=3 LOWER_RIGHT=4 BOTTOM=5; SLOT_COUNT=6
                     // DEFAULT_SLOTS = [DATE, WEATHER, BODY_BATTERY, HEART_RATE, ACTIVE_CAL, STEPS]
module ColorChoice   // replaces AccentChoice: RED=0 ORANGE=1 YELLOW=2 GREEN=3 TEAL=4 BLUE=5 PURPLE=6 PINK=7
                     // COUNT=8, DEFAULT_1=RED, DEFAULT_2=TEAL
class WatchData      // as copied, plus:
  hour, minute (Number); hoursText, minutesText (String, 12/24 h applied, minutes 2 digits)
  dateText (String, e.g. "AUG 29", upper case, watch language); day (Number); monthText (String, "AUG")
  batteryPercent (Number or Null); phoneConnected (Boolean); metric fields unchanged
class FaceSettings
  darkBackground (Boolean, default true); color1, color2 (Number, ColorChoice); slots (Array<Number>, 6)
  load(); static kindAvailable(kind)
class FaceRenderer (UI)
  computeLayout(width, height, settings)      // once per settings change / onLayout
  drawFace(dc, data)                          // high and low power
  drawAlwaysOn(dc, data, minuteOffset)        // AMOLED always-on, outline time only
module UiColors (UI)  apply(dark, color1, color2)  -> background, ink, color1, color2, panelFill, track, btOff,
                     warning
FaceRenderer.kindAt(x, y) -> Number   // DataKind of the slot under the point, NONE if none / always-on
ComplicationSource.exitToKind(kind) -> Boolean, opensView(kind), typeForKind(kind)  // opens the system view behind a field
FaceDelegate (WatchFaceDelegate).onPress -> FaceView.openFieldAt(x, y)
module SlotScale / SlotText (shared, pure): fraction(kind, data), valueOf/format(kind, ...) incl. DATE
```

## Open points
