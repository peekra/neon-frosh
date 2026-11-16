#!/usr/bin/env python3
"""Converts design/icons/weather/*.svg into the Monkey C tables of source/ui/WeatherIcons.mc.

Supports circle, line (also stroke-dasharray), path (M L C Z), g transform=translate.
Each icon is scaled to fit FIT units and centred at 0,0 (y down, integers).
Usage: scripts/svg2weather.py   (rewrites the block between BEGIN/END GENERATED)
"""
import math, re, sys, pathlib

ROOT = pathlib.Path(__file__).resolve().parent.parent
SVG_DIR = ROOT / "design/icons/weather"
TARGET = ROOT / "source/ui/WeatherIcons.mc"
ORDER = ["sun", "partly", "cloudy", "rain", "snow", "thunder", "showers"]   # = WeatherKind 0..6
SUN_BEHIND_CLOUD = ("partly", "showers")
FIT = 96.0
BEZIER_STEPS = 6
ACCENT, INK, BG = 0, 1, 2


def attrs(tag):
    return dict(re.findall(r'([\w-]+)="([^"]*)"', tag))


def flatten_path(d):
    toks = re.findall(r"[MLCZ]|-?\d+\.?\d*", d)
    pts, i, cur = [], 0, None
    while i < len(toks):
        t = toks[i]
        if t in "ML":
            cur = (float(toks[i + 1]), float(toks[i + 2])); pts.append(cur); i += 3
        elif t == "C":
            p0 = cur
            c = [(float(toks[i + 1 + 2 * k]), float(toks[i + 2 + 2 * k])) for k in range(3)]
            for s in range(1, BEZIER_STEPS + 1):
                u = s / BEZIER_STEPS; v = 1 - u
                x = v**3 * p0[0] + 3 * v * v * u * c[0][0] + 3 * v * u * u * c[1][0] + u**3 * c[2][0]
                y = v**3 * p0[1] + 3 * v * v * u * c[0][1] + 3 * v * u * u * c[1][1] + u**3 * c[2][1]
                pts.append((x, y))
            cur = c[2]; i += 7
        else:
            i += 1   # Z
    if pts[0] == pts[-1]:
        pts.pop()
    return pts


def parse(name):
    text = (SVG_DIR / f"{name}.svg").read_text()
    text = re.sub(r"<!--.*?-->", "", text, flags=re.S)
    tx = [(0.0, 0.0)]
    items, seen_path, hatch = [], False, 0
    for m in re.finditer(r"<(/?)(\w+)([^>]*)>", text):
        close, tag, rest = m.groups()
        if tag == "g":
            if close:
                tx.pop()
            else:
                a = attrs(rest); n = re.findall(r"-?\d+\.?\d*", a.get("transform", ""))
                tx.append((tx[-1][0] + float(n[0]), tx[-1][1] + float(n[1])))
            continue
        if close or tag not in ("circle", "line", "path"):
            continue
        a = attrs(rest); ox, oy = tx[-1]
        sw = float(a.get("stroke-width", 1))
        front = name in SUN_BEHIND_CLOUD and not seen_path
        col = INK if front else ACCENT
        if tag == "circle":
            r = float(a["r"])
            items.append(dict(k="disc" if a.get("fill", "none") != "none" else "ring", c=col, w=sw,
                              x=float(a["cx"]) + ox, y=float(a["cy"]) + oy, r=r))
        elif tag == "line":
            p = [(float(a["x1"]) + ox, float(a["y1"]) + oy), (float(a["x2"]) + ox, float(a["y2"]) + oy)]
            fine = False
            if "stroke-dasharray" in a:
                on, off = [float(v) for v in a["stroke-dasharray"].split()]
                (x1, y1), (x2, y2) = p
                length = math.hypot(x2 - x1, y2 - y1); t = 0
                while t < length:
                    e = min(t + on, length)
                    items.append(dict(k="line", c=col, w=sw, fine=True,
                                      p=[(x1 + (x2 - x1) * t / length, y1 + (y2 - y1) * t / length),
                                         (x1 + (x2 - x1) * e / length, y1 + (y2 - y1) * e / length)]))
                    t += on + off
                continue
            if seen_path and not front and p[0][1] == p[1][1] and sw == 1.5 and not ox and not oy:
                fine = hatch % 2 == 1; hatch += 1
            items.append(dict(k="line", c=col, w=sw, p=p, fine=fine))
        else:
            seen_path = True
            filled = a.get("fill", "none") != "none"
            stroked = a.get("stroke", "none") != "none"
            shape = "shape" if name in SUN_BEHIND_CLOUD else "closed"
            items.append(dict(k=shape if stroked else "closed", c=INK, w=float(a.get("stroke-width", 1.5)),
                              p=flatten_path(a["d"]), filled=filled and name in SUN_BEHIND_CLOUD))
    return items


def bbox(items):
    xs, ys = [], []
    for it in items:
        if "p" in it:
            xs += [p[0] for p in it["p"]]; ys += [p[1] for p in it["p"]]
        else:
            xs += [it["x"] - it["r"], it["x"] + it["r"]]; ys += [it["y"] - it["r"], it["y"] + it["r"]]
    return min(xs), max(xs), min(ys), max(ys)


def emit(name, items):
    x0, x1, y0, y1 = bbox(items)
    s = FIT / max(x1 - x0, y1 - y0)
    cx, cy = (x0 + x1) / 2, (y0 + y1) / 2
    T = lambda x, y: (round((x - cx) * s), round((y - cy) * s))
    out, col, pen, npts = [], None, None, 0
    for it in items:
        if it["c"] != col:
            col = it["c"]; out.append(f"OP_COLOR, {['ACCENT','INK','BG'][col]}")
        w = round(it["w"] * s * 10)
        if w != pen:
            pen = w; out.append(f"OP_PEN, {w}")
        k = it["k"]
        if k == "line":
            (a, b), (c, d) = T(*it["p"][0]), T(*it["p"][1])
            out.append(f"{'OP_FLINE' if it['fine'] else 'OP_LINE'}, {a}, {b}, {c}, {d}")
        elif k in ("ring", "disc"):
            x, y = T(it["x"], it["y"])
            out.append(f"OP_{k.upper()}, {x}, {y}, {max(1, round(it['r'] * s))}")
        else:
            pts = [T(*p) for p in it["p"]]
            if k == "shape":
                npts = max(npts, len(pts))
            flat = ", ".join(f"{x}, {y}" for x, y in pts)
            out.append(f"OP_{k.upper()}, {len(pts)}, {flat}")
    return out, npts


def main():
    lines, fill_pts = [], 0
    for n in ORDER:
        ops, npts = emit(n, parse(n))
        fill_pts = max(fill_pts, npts)
        lines.append(f"    // {n}.svg")
        lines.append(f"    const {n.upper()} = [")
        lines += [f"        {o}," for o in ops]
        lines.append("        OP_END\n    ] as Array<Number>;")
    lines.append(f"    // Index = WeatherKind.SUN .. SHOWERS")
    lines.append("    const SHAPES = [" + ", ".join(n.upper() for n in ORDER) + "] as Array<Array<Number>>;")
    lines.append(f"    const FILL_POINTS = {fill_pts};   // largest OP_SHAPE polygon")
    block = "    // BEGIN GENERATED (scripts/svg2weather.py, do not edit)\n" + "\n".join(lines) \
        + "\n    // END GENERATED"
    src = TARGET.read_text()
    new = re.sub(r"    // BEGIN GENERATED.*?// END GENERATED", lambda m: block, src, flags=re.S)
    TARGET.write_text(new)
    print("written", TARGET, "fill points", fill_pts)


main()
