#!/usr/bin/env python3
"""Generates the weather icon tables of source/ui/WeatherIcons.mc (between BEGIN/END GENERATED).

Neon Frosh, UI designer, 2026-11-15. Replaces the SVG-derived tables of the copied face: those had a hatched cloud in
colour 1 and were unreadable at field size. Here: the cloud is a clean ink outline filled with the colour behind it,
sun / rain / snow / lightning are in colour 1. Geometry in a 100 x 100 unit box centred on 0 (y down), drawn with the
same pen as the bitmap icons (about 1/12 of the icon). Run:  python3 design/drafts/weather_icons.py
"""
import math, re, pathlib

ROOT = pathlib.Path(__file__).resolve().parents[2]
TARGET = ROOT / "source/ui/WeatherIcons.mc"
PEN = 110           # tenths of a unit: 11 of 100 units, about as heavy as the font icons at field size

# cloud: union of three circles and a base rectangle, unit coordinates
CIRCLES = [(-18, 6, 13), (4, -6, 20), (26, 7, 12)]
RECT = (-18, 6, 26, 19)


def inside(x, y):
    if RECT[0] <= x <= RECT[2] and RECT[1] <= y <= RECT[3]:
        return True
    return any((x - cx) ** 2 + (y - cy) ** 2 <= r * r for cx, cy, r in CIRCLES)


def cloud(scale, dx, dy, n=40):
    """Outline of the cloud by rays from an inner point; n points (<= WeatherIcons.FILL_POINTS)."""
    ox, oy = 4, 8
    pts = []
    for k in range(n):
        a = 2 * math.pi * k / n
        r = 0.0
        while inside(ox + (r + 0.25) * math.cos(a), oy + (r + 0.25) * math.sin(a)):
            r += 0.25
        x, y = ox + r * math.cos(a), oy + r * math.sin(a)
        p = (round(dx + (x - 4) * scale), round(dy + (y - 6) * scale))
        if not pts or p != pts[-1]:
            pts.append(p)
    if pts[0] == pts[-1]:
        pts.pop()
    return ["OP_SHAPE", len(pts)] + [v for p in pts for v in p]


def sun(cx, cy, r, ray0, ray1, angles):
    ops = ["OP_DISC", cx, cy, r, "OP_PEN", PEN]
    for deg in angles:
        a = math.radians(deg)
        ops += ["OP_LINE", round(cx + ray0 * math.cos(a)), round(cy + ray0 * math.sin(a)),
                round(cx + ray1 * math.cos(a)), round(cy + ray1 * math.sin(a))]
    return ops


def rain(y0, y1, xs):
    ops = ["OP_PEN", PEN]
    for x in xs:
        ops += ["OP_LINE", x, y0, x - 6, y1]
    return ops


ALL8 = range(0, 360, 45)
UPPER_LEFT = [135, 180, 225, 270, 315]       # rays not hidden by the cloud
ICONS = {
    "SUN": ["OP_COLOR", "ACCENT"] + sun(0, 0, 20, 31, 45, ALL8),
    "PARTLY": ["OP_COLOR", "ACCENT"] + sun(-16, -16, 17, 26, 37, UPPER_LEFT)
              + ["OP_COLOR", "INK", "OP_PEN", PEN] + cloud(1.25, 6, 12),
    "CLOUDY": ["OP_COLOR", "INK", "OP_PEN", PEN] + cloud(1.45, 0, 13),
    "RAIN": ["OP_COLOR", "INK", "OP_PEN", PEN] + cloud(1.3, 0, -8)
            + ["OP_COLOR", "ACCENT"] + rain(26, 46, [-18, 2, 22]),
    "SNOW": ["OP_COLOR", "INK", "OP_PEN", PEN] + cloud(1.3, 0, -8)
            + ["OP_COLOR", "ACCENT", "OP_DISC", -20, 32, 8, "OP_DISC", 2, 42, 8, "OP_DISC", 24, 32, 8],
    "THUNDER": ["OP_COLOR", "INK", "OP_PEN", PEN] + cloud(1.3, 0, -8)
               + ["OP_COLOR", "ACCENT", "OP_PEN", PEN, "OP_POLY", 4, 8, 18, -8, 34, 10, 34, -6, 50],
    "SHOWERS": ["OP_COLOR", "ACCENT"] + sun(-18, -22, 15, 23, 33, UPPER_LEFT)
               + ["OP_COLOR", "INK", "OP_PEN", PEN] + cloud(1.15, 6, 0)
               + ["OP_COLOR", "ACCENT"] + rain(28, 46, [-10, 8, 26]),
}


def main():
    body = ["    // BEGIN GENERATED (design/drafts/weather_icons.py, do not edit)"]
    longest = 0
    for name, ops in ICONS.items():
        body.append(f"    const {name} = [")
        line = "        "
        for i, op in enumerate(ops + ["OP_END"]):
            tok = f"{op}, " if i < len(ops) else f"{op}"
            if isinstance(op, str) and op.startswith("OP_") and line.strip():
                body.append(line.rstrip())
                line = "        "
            line += tok
        body.append(line.rstrip())
        body.append("    ] as Array<Number>;")
        for i, op in enumerate(ops):
            if op == "OP_SHAPE":
                longest = max(longest, ops[i + 1])
    body.append("    // Index = WeatherKind.SUN .. SHOWERS")
    body.append("    const SHAPES = [SUN, PARTLY, CLOUDY, RAIN, SNOW, THUNDER, SHOWERS] as Array<Array<Number>>;")
    body.append(f"    const FILL_POINTS = {longest};   // largest OP_SHAPE polygon")
    body.append("    // END GENERATED")
    text = TARGET.read_text()
    text = re.sub(r"    // BEGIN GENERATED.*?// END GENERATED", "\n".join(body), text, flags=re.S)
    TARGET.write_text(text)
    print(f"wrote {TARGET.relative_to(ROOT)}, largest polygon {longest} points")


main()
