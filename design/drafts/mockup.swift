// PNG mock-ups of the Neon Frosh face without the simulator, from the same numbers the watch uses:
// source/ui/UiSizes.mc (geometry), source/ui/UiColors.mc (AMOLED palette), the bitmap fonts of
// resources-round-<D>x<D>/fonts and the weather table of source/ui/WeatherIcons.mc. The drawing mirrors
// source/ui/FaceRenderer.mc; it is an approximation (CoreGraphics anti-aliasing, not the watch's renderer).
// It also checks that the widest texts fit their field or panel on every display size.
//
//   cd "Neon Frosh" && swift design/drafts/mockup.swift
//   -> design/drafts/mockup_dark.png, mockup_light.png (390 px), mockup_218_dark.png, mockup_aod.png
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

let root = FileManager.default.currentDirectoryPath
func read(_ path: String) -> String { try! String(contentsOfFile: root + "/" + path, encoding: .utf8) }

// ---- numbers from the Monkey C sources ----
var S = [String: CGFloat]()
for line in read("source/ui/UiSizes.mc").split(separator: "\n") {
    let parts = line.split(separator: "=", maxSplits: 1)
    guard parts.count == 2, parts[0].contains("const ") else { continue }
    let name = parts[0].replacingOccurrences(of: "const", with: "").trimmingCharacters(in: .whitespaces)
    let value = parts[1].split(separator: ";")[0].trimmingCharacters(in: .whitespaces)
    if let v = Double(value) { S[name] = CGFloat(v) }
}
func s(_ k: String) -> CGFloat { guard let v = S[k] else { fatalError("UiSizes.\(k) missing") }; return v }

func table(_ name: String) -> [UInt32] {
    let text = read("source/ui/UiColors.mc")
    for line in text.split(separator: "\n") where line.contains("(:amoled)") && line.contains("const \(name) ") {
        if let open = line.firstIndex(of: "["), let close = line.firstIndex(of: "]") {
            return line[line.index(after: open)..<close].split(separator: ",").map {
                UInt32($0.trimmingCharacters(in: .whitespaces).dropFirst(2), radix: 16)!
            }
        }
    }
    fatalError("UiColors.\(name) not found")
}

struct Palette { var bg, ink, c1, c2, fill, label, btOff: UInt32 }
func palette(dark: Bool, c1: Int, c2: Int) -> Palette {
    let p = dark ? "DARK" : "LIGHT"
    let labels = (dark ? table("DARK_COLORS") : table("LIGHT_LABELS"))
    return Palette(bg: dark ? 0x000000 : 0xFFFFFF, ink: dark ? 0xFFFFFF : 0x000000, c1: table("\(p)_COLORS")[c1],
        c2: table("\(p)_COLORS")[c2], fill: table("\(p)_FILLS")[c2], label: labels[c2], btOff: dark ? 0x777777 : 0x888888)
}

// ---- bitmap fonts ----
struct BMChar { let x, y, w, h, xo, yo, adv: Int }
struct BMFont {
    let page: CGImage
    let chars: [UInt32: BMChar]
    let base: Int
    init(_ d: Int, _ id: String) {
        let dir = root + "/resources-round-\(d)x\(d)/fonts/"
        let src = CGImageSourceCreateWithURL(URL(fileURLWithPath: dir + id + ".png") as CFURL, nil)!
        page = CGImageSourceCreateImageAtIndex(src, 0, nil)!
        var c = [UInt32: BMChar](), b = 0
        for line in (try! String(contentsOfFile: dir + id + ".fnt", encoding: .utf8)).split(separator: "\n") {
            var kv = [String: Int]()
            for f in line.split(separator: " ") {
                let p = f.split(separator: "=")
                if p.count == 2, let v = Int(p[1]) { kv[String(p[0])] = v }
            }
            if line.hasPrefix("common") { b = kv["base"]! }
            if line.hasPrefix("char ") {
                c[UInt32(kv["id"]!)] = BMChar(x: kv["x"]!, y: kv["y"]!, w: kv["width"]!, h: kv["height"]!,
                    xo: kv["xoffset"]!, yo: kv["yoffset"]!, adv: kv["xadvance"]!)
            }
        }
        chars = c; base = b
    }
    func width(_ t: String) -> Int { t.unicodeScalars.reduce(0) { $0 + (chars[$1.value]?.adv ?? 0) } }
}

func rgb(_ c: UInt32) -> CGColor {
    CGColor(red: CGFloat((c >> 16) & 255) / 255, green: CGFloat((c >> 8) & 255) / 255, blue: CGFloat(c & 255) / 255, alpha: 1)
}

// justify: -1 left, 0 centre, 1 right; y = centre of the line (VCENTER, line height = cap)
func text(_ ctx: CGContext, _ f: BMFont, _ t: String, _ x: CGFloat, _ y: CGFloat, _ color: UInt32, _ justify: Int) {
    let w = CGFloat(f.width(t))
    var pen = justify == 0 ? x - w / 2 : (justify < 0 ? x : x - w)
    let top = (y - CGFloat(f.base) / 2).rounded(.down)
    for u in t.unicodeScalars {
        guard let c = f.chars[u.value] else { continue }
        if c.w > 0, let img = f.page.cropping(to: CGRect(x: c.x, y: c.y, width: c.w, height: c.h)) {
            let r = CGRect(x: pen.rounded() + CGFloat(c.xo), y: top + CGFloat(c.yo), width: CGFloat(c.w), height: CGFloat(c.h))
            ctx.saveGState()
            ctx.translateBy(x: r.minX, y: r.maxY)
            ctx.scaleBy(x: 1, y: -1)
            ctx.clip(to: CGRect(x: 0, y: 0, width: r.width, height: r.height), mask: img)
            ctx.setFillColor(rgb(color))
            ctx.fill(CGRect(x: 0, y: 0, width: r.width, height: r.height))
            ctx.restoreGState()
        }
        pen += CGFloat(c.adv)
    }
}

// ---- weather icon (table of WeatherIcons.mc) ----
func weatherOps(_ name: String) -> [Int] {
    let t = read("source/ui/WeatherIcons.mc")
    let start = t.range(of: "const \(name) = [")!.upperBound
    let body = t[start..<t[start...].range(of: "]")!.lowerBound]
    let names = ["OP_END": 0, "OP_COLOR": 1, "OP_PEN": 2, "OP_LINE": 3, "OP_FLINE": 4, "OP_POLY": 5, "OP_CLOSED": 6,
        "OP_SHAPE": 7, "OP_RING": 8, "OP_DISC": 9, "ACCENT": 0, "INK": 1, "BG": 2]
    return body.split(whereSeparator: { ", \n".contains($0) }).compactMap {
        let w = $0.trimmingCharacters(in: .whitespaces)
        return w.hasPrefix("//") ? nil : (names[w] ?? Int(w))
    }
}

func weather(_ ctx: CGContext, _ cx: CGFloat, _ cy: CGFloat, _ size: CGFloat, _ p: Palette, back: UInt32,
             kind: String = "PARTLY") {
    let ops = weatherOps(kind)
    ctx.setLineJoin(.round)
    var i = 0
    var color = p.c1
    func P(_ a: Int, _ b: Int) -> CGPoint { CGPoint(x: cx + CGFloat(a) * size / 100, y: cy + CGFloat(b) * size / 100) }
    ctx.setLineCap(.butt)
    while ops[i] != 0 {
        let op = ops[i]
        ctx.setStrokeColor(rgb(color)); ctx.setFillColor(rgb(color))
        switch op {
        case 1: color = [p.c1, p.ink, back][ops[i + 1]]; i += 2
        case 2: ctx.setLineWidth(max(1, (CGFloat(ops[i + 1]) * size / 1000).rounded())); i += 2
        case 3, 4:
            if !(op == 4 && size < 40) { ctx.move(to: P(ops[i + 1], ops[i + 2])); ctx.addLine(to: P(ops[i + 3], ops[i + 4])); ctx.strokePath() }
            i += 5
        case 8, 9:
            let r = CGFloat(ops[i + 3]) * size / 100
            let c = P(ops[i + 1], ops[i + 2])
            let e = CGRect(x: c.x - r, y: c.y - r, width: 2 * r, height: 2 * r)
            if op == 8 { ctx.strokeEllipse(in: e) } else { ctx.fillEllipse(in: e) }
            i += 4
        default:
            let n = ops[i + 1]
            let pts = (0..<n).map { P(ops[i + 2 + 2 * $0], ops[i + 3 + 2 * $0]) }
            if op == 7 { ctx.setFillColor(rgb(back)); ctx.addLines(between: pts); ctx.closePath(); ctx.fillPath() }
            ctx.setStrokeColor(rgb(color))
            ctx.addLines(between: pts); if op != 5 { ctx.closePath() }; ctx.strokePath()
            i += 2 + 2 * n
        }
    }
}

// ---- face ----
struct Fonts { let hours, minutes, value, panel, icons: BMFont }
func fonts(_ d: Int) -> Fonts {
    Fonts(hours: BMFont(d, "Hours"), minutes: BMFont(d, "Minutes"), value: BMFont(d, "Value"), panel: BMFont(d, "Panel"),
        icons: BMFont(d, "Icons"))
}

func panelPolygon(_ d: CGFloat, _ cx: CGFloat, _ cy: CGFloat, _ side: CGFloat) -> [CGPoint] {
    let n = Int(s("PANEL_STEPS")), hw = s("PANEL_HALF_W"), ro = s("PANEL_OUTER_R"), ri = s("PANEL_INNER_R")
    var outer = [CGPoint](), inner = [CGPoint]()
    for k in 0..<n {
        let x = -hw + 2 * hw * CGFloat(k) / CGFloat(n - 1)
        outer.append(CGPoint(x: (cx + x * d).rounded(), y: (cy + side * (ro * ro - x * x).squareRoot() * d).rounded()))
        let xi = -x
        let yi = s("PANEL_INNER_CY") - (ri * ri - xi * xi).squareRoot()
        inner.append(CGPoint(x: (cx + xi * d).rounded(), y: (cy - side * yi * d).rounded()))
    }
    return outer + inner
}

func render(d: Int, dark: Bool, aod: Bool, file: String) {
    let D = CGFloat(d), cx = CGFloat(d / 2), cy = CGFloat(d / 2)
    let f = fonts(d)
    let p = palette(dark: aod ? true : dark, c1: 0, c2: 4)
    let ctx = CGContext(data: nil, width: d, height: d, bitsPerComponent: 8, bytesPerRow: 0,
        space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    ctx.translateBy(x: 0, y: D); ctx.scaleBy(x: 1, y: -1)    // y down as on the watch
    ctx.setFillColor(rgb(0x202020)); ctx.fill(CGRect(x: 0, y: 0, width: D, height: D))
    ctx.addEllipse(in: CGRect(x: 0, y: 0, width: D, height: D)); ctx.clip()
    ctx.setFillColor(rgb(aod ? 0 : p.bg)); ctx.fill(CGRect(x: 0, y: 0, width: D, height: D))
    let outline = max(s("OUTLINE_MIN"), (s("OUTLINE") * D).rounded())
    let gap = (s("COLON_GAP") * D).rounded()
    var colon = (s("COLON_SIZE") * D).rounded(); colon = max(colon, 2 * outline + 2)
    func drawTime(_ hoursFont: BMFont, _ h: UInt32, _ m: UInt32, _ back: UInt32, _ dx: CGFloat) {
        let y = cy + (s("TIME_Y") * D).rounded()
        text(ctx, hoursFont, "10", cx + dx - gap, y, h, 1)
        text(ctx, f.minutes, "08", cx + dx + gap, y, m, -1)
        for k in [-1.0, 1.0] as [CGFloat] {
            let r = CGRect(x: cx + dx - (colon / 2).rounded(.down), y: y + k * (s("COLON_DY") * D).rounded() - (colon / 2).rounded(.down), width: colon, height: colon)
            ctx.setFillColor(rgb(m)); ctx.fill(r)
            ctx.setFillColor(rgb(back)); ctx.fill(r.insetBy(dx: outline, dy: outline))
        }
    }
    if aod {
        let dim = { (c: UInt32) -> UInt32 in (((c >> 16 & 255) * 3 / 4) << 16) | (((c >> 8 & 255) * 3 / 4) << 8) | ((c & 255) * 3 / 4) }
        drawTime(f.minutes, dim(p.c1), dim(p.c2), 0, 0)
    } else {
        // panels and the gaps around the fields
        let fx = (s("FIELD_X") * D).rounded(), fy = (s("FIELD_Y") * D).rounded()
        let fieldR = (s("FIELD_R") * D).rounded()
        let arcPen = max(1, (s("ARC_PEN") * D).rounded()), fieldPen = max(1, (s("FIELD_PEN") * D).rounded())
        let cutR = fieldR + (s("FIELD_GAP") * D).rounded() + ((arcPen + 1) / 2).rounded(.down)
        ctx.setFillColor(rgb(p.fill))
        for side in [-1.0, 1.0] as [CGFloat] {
            ctx.addLines(between: panelPolygon(D, cx, cy, side)); ctx.closePath(); ctx.fillPath()
        }
        let centres = [(-fx, -fy), (fx, -fy), (-fx, fy), (fx, fy)].map { CGPoint(x: cx + $0.0, y: cy + $0.1) }
        ctx.setFillColor(rgb(p.bg))
        for c in centres { ctx.fillEllipse(in: CGRect(x: c.x - cutR, y: c.y - cutR, width: 2 * cutR, height: 2 * cutR)) }
        // Bluetooth and battery
        let u = s("STATUS_UNIT") * D, my = cy + s("STATUS_Y") * D
        func sx(_ x: CGFloat) -> CGFloat { (cx + (x - s("STATUS_CX")) * u).rounded() }
        func sy(_ y: CGFloat) -> CGFloat { (my + (y - 12) * u).rounded() }
        let pen = max(1, (2 * u).rounded())
        ctx.setStrokeColor(rgb(p.c2)); ctx.setLineWidth(pen); ctx.setLineCap(.butt); ctx.setLineJoin(.miter)
        ctx.addLines(between: [(7, 17), (17, 7), (12, 2), (12, 22), (17, 17), (7, 7)].map { CGPoint(x: sx($0.0), y: sy($0.1)) })
        ctx.strokePath()
        let bat = CGRect(x: sx(34), y: sy(3), width: sx(66) - sx(34), height: sy(21) - sy(3))
        let br = max(1, (3 * u).rounded())
        ctx.setFillColor(rgb(p.ink))
        ctx.addPath(CGPath(roundedRect: bat, cornerWidth: br, cornerHeight: br, transform: nil)); ctx.fillPath()
        ctx.fill(CGRect(x: bat.maxX, y: sy(9), width: max(1, (1.5 * u).rounded()), height: sy(15) - sy(9)))
        ctx.setFillColor(rgb(p.bg))
        let inner = bat.insetBy(dx: pen, dy: pen), ir = max(0, br - pen)
        ctx.addPath(CGPath(roundedRect: inner, cornerWidth: ir, cornerHeight: ir, transform: nil)); ctx.fillPath()
        ctx.setFillColor(rgb(p.ink))
        let bw = max(1, (3 * u).rounded())
        for x in [40, 47, 54] as [CGFloat] {
            let y0 = max(sy(7), bat.minY + pen + 1), y1 = min(sy(17), bat.maxY - pen - 1)
            ctx.fill(CGRect(x: sx(x) - (bw / 2).rounded(.down), y: y0, width: bw, height: y1 - y0))
        }
        drawTime(f.hours, p.c1, p.c2, p.bg, 0)
        // round fields: weather, body battery 82 %, heart rate 76 (40 %), active calories 171
        let iconDy = (s("FIELD_ICON_Y") * D).rounded(), valueDy = (s("FIELD_VALUE_Y") * D).rounded()
        let contents: [(String, String, CGFloat?)] = [("W", "17°C", nil), ("I", "82", 0.82), ("A", "76", 0.40), ("C", "171", nil)]
        for (i, c) in centres.enumerated() {
            ctx.setStrokeColor(rgb(p.ink)); ctx.setLineWidth(fieldPen)
            ctx.strokeEllipse(in: CGRect(x: c.x - fieldR, y: c.y - fieldR, width: 2 * fieldR, height: 2 * fieldR))
            if let fr = contents[i].2 {
                ctx.setStrokeColor(rgb(p.c1)); ctx.setLineWidth(arcPen)
                ctx.addArc(center: c, radius: fieldR, startAngle: -.pi / 2, endAngle: -.pi / 2 + 2 * .pi * fr, clockwise: false)
                ctx.strokePath()
            }
            if contents[i].0 == "W" {
                weather(ctx, c.x, c.y + iconDy, (s("WEATHER_SIZE") * D).rounded(), p, back: p.bg)
            } else {
                text(ctx, f.icons, contents[i].0, c.x, c.y + iconDy, p.ink, 0)
            }
            text(ctx, f.value, contents[i].1, c.x, c.y + valueDy, p.ink, 0)
        }
        // panels: date, steps
        text(ctx, f.panel, "AUG 29", cx, cy - (s("PANEL_SINGLE_Y") * D).rounded(), p.ink, 0)
        text(ctx, f.panel, "3.420", cx, cy + (s("PANEL_VALUE_Y") * D).rounded(), p.ink, 0)
        text(ctx, f.value, "STEP", cx, cy + (s("PANEL_LABEL_Y") * D).rounded(), p.label, 0)
    }
    let dest = CGImageDestinationCreateWithURL(URL(fileURLWithPath: root + "/design/drafts/" + file) as CFURL,
        UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(dest, ctx.makeImage()!, nil)
    CGImageDestinationFinalize(dest)
    print("wrote design/drafts/\(file)")
}

// ---- fit check: widest texts against the inside of a field and the panel area ----
func fitCheck(_ d: Int) -> [String] {
    let D = CGFloat(d), f = fonts(d)
    var problems = [String]()
    let fieldInner = (s("FIELD_R") * D).rounded() - max(1, (s("ARC_PEN") * D).rounded()) / 2
    func boxFits(_ w: CGFloat, _ h: CGFloat, _ dy: CGFloat, _ r: CGFloat) -> Bool {
        let top = dy - h / 2, bottom = dy + h / 2
        return [top, bottom].allSatisfy { (w / 2) * (w / 2) + $0 * $0 <= r * r }
    }
    for t in ["12.345", "-12°C", "-12°F", "108°F", "100", "12,4", "88:88", "MÄR", "AUG", "DEZ"] {
        let isMonth = t.allSatisfy { $0.isLetter }
        let dy = (s(isMonth ? "FIELD_ICON_Y" : "FIELD_VALUE_Y") * D).rounded()
        if !boxFits(CGFloat(f.value.width(t)), CGFloat(f.value.base), dy, fieldInner) {
            problems.append("\(d): field \"\(t)\" \(f.value.width(t)) px does not fit")
        }
    }
    // panel: the box must stay inside the outer circle, outside the inner circle and the field cut-outs
    let cutR = (s("FIELD_R") + s("FIELD_GAP")) * D + max(1, (s("ARC_PEN") * D).rounded()) / 2
    func panelFits(_ w: CGFloat, _ h: CGFloat, _ yc: CGFloat) -> Bool {
        for x in [-w / 2, w / 2] { for y in [yc - h / 2, yc + h / 2] {
            if x * x + y * y > pow(s("PANEL_OUTER_R") * D, 2) { return false }
            let yi = s("PANEL_INNER_CY") * D - ((s("PANEL_INNER_R") * D) * (s("PANEL_INNER_R") * D) - x * x).squareRoot()
            if y > yi { return false }       // below the inner edge (top panel, y negative up)
            let dx = abs(x) - s("FIELD_X") * D, dy = y + s("FIELD_Y") * D
            if dx * dx + dy * dy < cutR * cutR { return false }
        } }
        return true
    }
    for t in ["12.345", "99.999", "AUG 29", "MÄR 29", "-12°C"] {
        let single = t.contains(" ")
        let y = -(s(single ? "PANEL_SINGLE_Y" : "PANEL_VALUE_Y") * D).rounded()
        if !panelFits(CGFloat(f.panel.width(t)), CGFloat(f.panel.base), y) {
            problems.append("\(d): panel value \"\(t)\" \(f.panel.width(t)) px does not fit")
        }
    }
    for t in ["STEP", "BODY BATT", "ACT KCAL", "TRAINING", "VO2 MAX", "BIKE KM"] {
        if !panelFits(CGFloat(f.value.width(t)), CGFloat(f.value.base), -(s("PANEL_LABEL_Y") * D).rounded()) {
            problems.append("\(d): panel label \"\(t)\" \(f.value.width(t)) px does not fit")
        }
    }
    return problems
}

// ---- contact sheet of the weather icons: every kind in a round field, at 218, 390 and 466, dark and light,
// with heart, bolt and flame of the icon font for comparison; drawn at the real pixel size, then enlarged 2x ----
func contactSheet(file: String) {
    let kinds = ["SUN", "PARTLY", "CLOUDY", "RAIN", "SNOW", "THUNDER", "SHOWERS"]
    let refs = ["A", "I", "C"]
    let rows = [218, 390, 466].flatMap { d in [true, false].map { (d, $0) } }
    let cell = 0.24 * 466.0
    let width = Int(cell * CGFloat(kinds.count + refs.count)), height = Int(cell * CGFloat(rows.count))
    let ctx = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
        space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    ctx.translateBy(x: 0, y: CGFloat(height)); ctx.scaleBy(x: 1, y: -1)
    for (r, row) in rows.enumerated() {
        let (d, dark) = row
        let D = CGFloat(d), f = fonts(d), p = palette(dark: dark, c1: 0, c2: 4)
        ctx.setFillColor(rgb(p.bg))
        ctx.fill(CGRect(x: 0, y: CGFloat(r) * cell, width: CGFloat(width), height: cell))
        let fieldR = (s("FIELD_R") * D).rounded(), fieldPen = max(1, (s("FIELD_PEN") * D).rounded())
        for i in 0..<(kinds.count + refs.count) {
            let c = CGPoint(x: (CGFloat(i) + 0.5) * cell, y: (CGFloat(r) + 0.5) * cell)
            ctx.setStrokeColor(rgb(p.ink)); ctx.setLineWidth(fieldPen)
            ctx.strokeEllipse(in: CGRect(x: c.x - fieldR, y: c.y - fieldR, width: 2 * fieldR, height: 2 * fieldR))
            let iy = c.y + (s("FIELD_ICON_Y") * D).rounded()
            if i < kinds.count {
                weather(ctx, c.x, iy, (s("WEATHER_SIZE") * D).rounded(), p, back: p.bg, kind: kinds[i])
            } else {
                text(ctx, f.icons, refs[i - kinds.count], c.x, iy, p.ink, 0)
            }
            text(ctx, f.value, i < kinds.count ? "17°C" : "82", c.x, c.y + (s("FIELD_VALUE_Y") * D).rounded(), p.ink, 0)
        }
    }
    let small = ctx.makeImage()!
    let big = CGContext(data: nil, width: 2 * width, height: 2 * height, bitsPerComponent: 8, bytesPerRow: 0,
        space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    big.interpolationQuality = .none
    big.draw(small, in: CGRect(x: 0, y: 0, width: 2 * width, height: 2 * height))
    let dest = CGImageDestinationCreateWithURL(URL(fileURLWithPath: root + "/design/drafts/" + file) as CFURL,
        UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(dest, big.makeImage()!, nil)
    CGImageDestinationFinalize(dest)
    print("wrote design/drafts/\(file): rows 218/390/466 x dark/light; columns sun, partly, cloudy, rain, snow, thunder, showers | heart, bolt, flame")
}

contactSheet(file: "weather_icons.png")
render(d: 390, dark: true, aod: false, file: "mockup_dark.png")
render(d: 390, dark: false, aod: false, file: "mockup_light.png")
render(d: 218, dark: true, aod: false, file: "mockup_218_dark.png")
render(d: 390, dark: true, aod: true, file: "mockup_aod.png")
var all = [String]()
for d in [218, 240, 260, 280, 360, 390, 416, 454, 466] { all += fitCheck(d) }
print(all.isEmpty ? "fit check: every text fits on every display size" : all.joined(separator: "\n"))
