# Palette Neon Frosh – PROPOSAL, the user must confirm

Status: proposal of the UI designer, 2026-11-15. **Not confirmed by the user.** Built into `source/ui/UiColors.mc`
so the face can be built and looked at; `tests/ColorTest.mc` checks every pair (8 x 8 colour pairs x dark/light,
AMOLED build and MIP build).

Roles (CLAUDE.md, "Colours"): colour 1 = hours and progress arcs; colour 2 = minute outline, colon, Bluetooth,
panel fill (dimmed) and panel label. Ink = white on dark, black on light (text, icons, field outlines, battery).

Contrast: WCAG 2 relative luminance. Limits used:
- colour 1/2 against the background >= 3.0 (large digits, arcs, outline digits)
- ink on the panel fill >= 4.5 (panel text)
- panel fill against the background >= 1.5 (the panel must be visible; designer's own limit)
- panel label (small bold "STEP"): colour 2 where it reaches 3.0 on its own fill, otherwise ink (marked "ink")
- always-on digits >= 3.0 on black; btOff >= 2.0; track >= 1.5 (weak on purpose)

MIP: only channels 00/55/AA/FF. Notes: on MIP light the yellow is a dark olive (`#555500`), because a real yellow
does not reach 3:1 on white with these 64 colours; MIP light green `#00AA00` (3.11) and pink `#FF00AA` (3.60) are
close to the limit. No two colours of one table are equal (test `testTables`).

### AMOLED dark (background `#000000`, ink `#FFFFFF`)

| # | colour | colour 1/2 | vs background (min 3.0) | panel fill | fill vs background (min 1.5) | ink on fill (min 4.5) | colour on fill | panel label (min 3.0) |
|---|---|---|---|---|---|---|---|---|
| 0 | red | `#FF3B30` | 5.92 | `#5C1512` | 1.57 | 13.37 | 3.77 | colour 2 (3.77) |
| 1 | orange | `#FF8C1A` | 9.02 | `#5C3009` | 1.88 | 11.16 | 4.79 | colour 2 (4.79) |
| 2 | yellow | `#FFD60A` | 14.88 | `#4D4000` | 2.05 | 10.25 | 7.26 | colour 2 (7.26) |
| 3 | green | `#34C759` | 9.46 | `#0F4A22` | 2.02 | 10.38 | 4.68 | colour 2 (4.68) |
| 4 | teal | `#3DD6C6` | 11.63 | `#0E4D49` | 2.18 | 9.65 | 5.34 | colour 2 (5.34) |
| 5 | blue | `#3D9BFF` | 7.33 | `#12355C` | 1.69 | 12.43 | 4.34 | colour 2 (4.34) |
| 6 | purple | `#B57BFF` | 7.24 | `#3D2766` | 1.68 | 12.50 | 4.31 | colour 2 (4.31) |
| 7 | pink | `#FF5FA8` | 7.45 | `#5C1A3A` | 1.66 | 12.62 | 4.48 | colour 2 (4.48) |

### AMOLED light (background `#FFFFFF`, ink `#000000`)

| # | colour | colour 1/2 | vs background (min 3.0) | panel fill | fill vs background (min 1.5) | ink on fill (min 4.5) | colour on fill | panel label (min 3.0) |
|---|---|---|---|---|---|---|---|---|
| 0 | red | `#D70015` | 5.38 | `#F5C2C7` | 1.56 | 13.42 | 3.44 | colour 2 (3.44) |
| 1 | orange | `#C25400` | 4.60 | `#EBC8AD` | 1.57 | 13.40 | 2.94 | ink (13.40) |
| 2 | yellow | `#8F6B00` | 4.92 | `#DACEAB` | 1.57 | 13.40 | 3.14 | colour 2 (3.14) |
| 3 | green | `#1E7F3A` | 5.06 | `#B7D6C0` | 1.57 | 13.39 | 3.23 | colour 2 (3.23) |
| 4 | teal | `#00807A` | 4.81 | `#ADD6D4` | 1.57 | 13.35 | 3.05 | colour 2 (3.05) |
| 5 | blue | `#0062CC` | 5.80 | `#B5D1F0` | 1.57 | 13.34 | 3.69 | colour 2 (3.69) |
| 6 | purple | `#7A3DD6` | 6.06 | `#D8C7F3` | 1.57 | 13.38 | 3.86 | colour 2 (3.86) |
| 7 | pink | `#C2186B` | 5.77 | `#EFC3D9` | 1.56 | 13.48 | 3.71 | colour 2 (3.71) |

### MIP dark (background `#000000`, ink `#FFFFFF`)

| # | colour | colour 1/2 | vs background (min 3.0) | panel fill | fill vs background (min 1.5) | ink on fill (min 4.5) | colour on fill | panel label (min 3.0) |
|---|---|---|---|---|---|---|---|---|
| 0 | red | `#FF0000` | 5.25 | `#AA0000` | 2.71 | 7.75 | 1.94 | ink (7.75) |
| 1 | orange | `#FF5500` | 6.55 | `#AA5500` | 4.01 | 5.24 | 1.63 | ink (5.24) |
| 2 | yellow | `#FFFF00` | 19.56 | `#555500` | 2.69 | 7.82 | 7.28 | colour 2 (7.28) |
| 3 | green | `#00FF00` | 15.30 | `#005500` | 2.30 | 9.13 | 6.66 | colour 2 (6.66) |
| 4 | teal | `#00AAAA` | 7.33 | `#005555` | 2.43 | 8.64 | 3.02 | colour 2 (3.02) |
| 5 | blue | `#55AAFF` | 8.58 | `#0000AA` | 1.58 | 13.29 | 5.43 | colour 2 (5.43) |
| 6 | purple | `#AA55FF` | 5.45 | `#5500AA` | 1.97 | 10.68 | 2.77 | ink (10.68) |
| 7 | pink | `#FF55AA` | 7.13 | `#AA0055` | 2.84 | 7.39 | 2.51 | ink (7.39) |

### MIP light (background `#FFFFFF`, ink `#000000`)

| # | colour | colour 1/2 | vs background (min 3.0) | panel fill | fill vs background (min 1.5) | ink on fill (min 4.5) | colour on fill | panel label (min 3.0) |
|---|---|---|---|---|---|---|---|---|
| 0 | red | `#AA0000` | 7.75 | `#FFAAAA` | 1.81 | 11.58 | 4.28 | colour 2 (4.28) |
| 1 | orange | `#AA5500` | 5.24 | `#FFAA55` | 1.89 | 11.13 | 2.78 | ink (11.13) |
| 2 | yellow | `#555500` | 7.82 | `#AAAA00` | 2.48 | 8.46 | 3.15 | colour 2 (3.15) |
| 3 | green | `#00AA00` | 3.11 | `#55AA55` | 2.89 | 7.27 | 1.08 | ink (7.27) |
| 4 | teal | `#005555` | 8.64 | `#55AAAA` | 2.72 | 7.72 | 3.17 | colour 2 (3.17) |
| 5 | blue | `#0000FF` | 8.59 | `#55AAFF` | 2.45 | 8.58 | 3.51 | colour 2 (3.51) |
| 6 | purple | `#5500AA` | 10.68 | `#AAAAFF` | 2.12 | 9.90 | 5.04 | colour 2 (5.04) |
| 7 | pink | `#FF00AA` | 3.60 | `#FFAAFF` | 1.69 | 12.45 | 2.13 | ink (12.45) |

### Always-on (AMOLED only, always on black): dark AMOLED colour x 3/4 per channel

| # | colour | dimmed | vs black (min 3.0) |
|---|---|---|---|
| 0 | red | `#BF2C24` | 3.60 |
| 1 | orange | `#BF6913` | 5.25 |
| 2 | yellow | `#BFA007` | 8.25 |
| 3 | green | `#279542` | 5.46 |
| 4 | teal | `#2DA094` | 6.57 |
| 5 | blue | `#2D74BF` | 4.36 |
| 6 | purple | `#875CBF` | 4.31 |
| 7 | pink | `#BF477E` | 4.42 |

### Other roles (contrast against the background)

| role | AMOLED dark | AMOLED light | MIP dark | MIP light | limit |
|---|---|---|---|---|---|
| warning (battery outline 0-15 %) | `#FF453A` 6.16 | `#D70015` 5.38 | `#FF5555` 6.68 | `#AA0000` 7.75 | 3.0 |
| track (weak, reserved, not drawn) | `#333333` 1.66 | `#D0D0D0` 1.54 | `#555555` 2.82 | `#AAAAAA` 2.32 | 1.5 |
| btOff (Bluetooth not connected) | `#777777` 4.69 | `#888888` 3.54 | `#555555` 2.82 | `#AAAAAA` 2.32 | 2.0 |
| ink (text, icons, outlines) | `#FFFFFF` 21.00 | `#000000` 21.00 | `#FFFFFF` 21.00 | `#000000` 21.00 | 4.5 |

## Look
Mock-ups from the same numbers (fonts, sizes, AMOLED palette, red/teal): `mockup_dark.png`, `mockup_light.png`
(390 px), `mockup_218_dark.png` (smallest display), `mockup_aod.png` (always-on). Script: `design/drafts/mockup.swift`.

## Not checked
Readability on the real watch (indoors, sunlight), the MIP panel reflecting light, the simulator.
