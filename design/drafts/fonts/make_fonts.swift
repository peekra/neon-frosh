// Generates the bitmap fonts of Neon Frosh (proposal of the UI designer, 2026-11-15) into resources-round-<D>x<D>/fonts:
//   Hours    Saira digits, solid                       (hours, colour 1)
//   Minutes  the same digits as an outline only        (minutes, colour 2; always-on view for hours and minutes)
//   Value    Saira condensed: digits, capitals, signs  (values and month of the round fields, panel labels)
//   Panel    the same characters, larger               (panel values and the date "AUG 29")
//   Icons    data icons from the SVG files in icons/   (round fields)
// Source font: Saira (SIL OFL 1.1, source/Saira-OFL.txt), icons: Tabler (MIT) and Lucide (ISC), see icons/.
// The results are checked in, the build does
// not need this tool. Sizes are fractions of the display diameter D and must match source/ui/UiSizes.mc.
//
//   cd "Neon Frosh" && swift design/drafts/fonts/make_fonts.swift            all display sizes
//   cd "Neon Frosh" && swift design/drafts/fonts/make_fonts.swift 218 390    only these sizes
//
// Every font is white on a gray page; the colour comes from dc.setColor(). Line height = base = cap height of the
// digits, so drawText(..., TEXT_JUSTIFY_VCENTER) centres the digits and capitals on the given y (descenders of
// "," hang below the line).
import CoreGraphics
import CoreText
import Foundation
import ImageIO
import UniformTypeIdentifiers

let sairaCapEm: CGFloat = 0.704         // height of a Saira digit or capital in em, the same in all cuts
let root = FileManager.default.currentDirectoryPath
let here = root + "/design/drafts/fonts"
let allDiameters = [218, 240, 260, 280, 360, 390, 416, 454, 466]

func requestedDiameters() -> [Int] {
    let args = CommandLine.arguments.dropFirst().compactMap { Int($0) }
    return args.isEmpty ? allDiameters : args
}

// ---- text fonts ----

let digits = "0123456789"
// Values ("12.345", "-12°C", "3:15", "12,4", "100%"), the date and month in Latin languages, panel labels
let textChars = digits + " .,:-+%/°ABCDEFGHIJKLMNOPQRSTUVWXYZÄÖÜÅÉÈÊÁÀÂÍÓÔÚÇÑ"

struct Spec {
    let id: String
    let wght: CGFloat           // Saira axes: wght 100..900, wdth 50..125
    let wdth: CGFloat
    let cap: CGFloat            // digit height, fraction of D (UiSizes.*_CAP)
    let chars: String
    var outline: CGFloat = 0    // > 0: outline only, this thickness in fractions of D (at least minOutlinePx)
    var minCapPx: CGFloat = 0
}

let minOutlinePx: CGFloat = 2
let specs = [
    Spec(id: "Hours", wght: 720, wdth: 85, cap: 0.195, chars: digits),
    Spec(id: "Minutes", wght: 720, wdth: 85, cap: 0.195, chars: digits, outline: 0.0085),
    Spec(id: "Value", wght: 700, wdth: 78, cap: 0.040, chars: textChars, minCapPx: 8),
    Spec(id: "Panel", wght: 700, wdth: 82, cap: 0.058, chars: textChars, minCapPx: 11),
]

func axisTag(_ name: String) -> Int {
    return name.utf8.reduce(0) { $0 << 8 | Int($1) }
}

func loadFont(_ spec: Spec, _ size: CGFloat) -> CTFont {
    let url = URL(fileURLWithPath: here + "/source/Saira[wdth,wght].ttf") as CFURL
    let descriptors = CTFontManagerCreateFontDescriptorsFromURL(url) as! [CTFontDescriptor]
    let wanted = [axisTag("wght"): spec.wght, axisTag("wdth"): spec.wdth]
    let attributes = [kCTFontVariationAttribute: wanted as CFDictionary] as CFDictionary
    return CTFontCreateWithFontDescriptor(CTFontDescriptorCreateCopyWithAttributes(descriptors[0], attributes), size, nil)
}

struct Glyph {
    let char: Character
    let path: CGPath?
    let advance: Int
    let x0: Int
    let top: Int
    let width: Int
    let height: Int
    var atlasX = 0
    var atlasY = 0
}

func nextPowerOfTwo(_ n: Int) -> Int {
    var p = 64
    while p < n {
        p *= 2
    }
    return p
}

func makeGlyphs(_ font: CTFont, _ spec: Spec) -> [Glyph] {
    var result = [Glyph]()
    for ch in spec.chars {
        var utf = Array(String(ch).utf16)
        var g = [CGGlyph](repeating: 0, count: utf.count)
        guard CTFontGetGlyphsForCharacters(font, &utf, &g, utf.count) else {
            fatalError("\(spec.id): no glyph for \(ch)")
        }
        var advanceSize = CGSize.zero
        CTFontGetAdvancesForGlyphs(font, .horizontal, &g, &advanceSize, 1)
        let path = CTFontCreatePathForGlyph(font, g[0], nil)
        let box = path?.boundingBoxOfPath ?? .zero
        let empty = path == nil || box.isEmpty
        let x0 = empty ? 0 : Int(floor(box.minX))
        let x1 = empty ? 0 : Int(ceil(box.maxX))
        let y0 = empty ? 0 : Int(floor(box.minY))
        let y1 = empty ? 0 : Int(ceil(box.maxY))
        result.append(Glyph(char: ch, path: empty ? nil : path, advance: Int(advanceSize.width.rounded()), x0: x0,
            top: y1, width: x1 - x0, height: y1 - y0))
    }
    return result
}

func writePng(_ ctx: CGContext, _ file: String) {
    let png = URL(fileURLWithPath: file) as CFURL
    let dest = CGImageDestinationCreateWithURL(png, UTType.png.identifier as CFString, 1, nil)!
    CGImageDestinationAddImage(dest, ctx.makeImage()!, nil)
    CGImageDestinationFinalize(dest)
}

func outlinePx(_ spec: Spec, _ d: CGFloat) -> CGFloat {
    return max(minOutlinePx, (spec.outline * d).rounded())
}

@discardableResult
func writeFont(_ spec: Spec, diameter: Int, dir: String) -> [Character: Int] {
    let d = CGFloat(diameter)
    let px = (max(spec.cap * d, spec.minCapPx) / sairaCapEm).rounded()
    let font = loadFont(spec, px)
    var glyphs = makeGlyphs(font, spec)
    let capTop = glyphs.filter { digits.contains($0.char) }.map { $0.top }.max()!
    for g in glyphs where g.width > 255 || g.height > 255 {
        fatalError("\(spec.id) \(g.char): cell \(g.width) x \(g.height) is larger than 255 pixels")
    }
    let spacing = 2
    let area = glyphs.reduce(0) { $0 + ($1.width + spacing) * ($1.height + spacing) }
    let widest = glyphs.map { $0.width + spacing }.max()!
    let pageW = nextPowerOfTwo(max(widest, Int(Double(area).squareRoot() * 1.3)))
    var x = 0, y = 0, shelf = 0
    for i in glyphs.indices {
        if x + glyphs[i].width + spacing > pageW {
            x = 0; y += shelf; shelf = 0
        }
        glyphs[i].atlasX = x
        glyphs[i].atlasY = y
        x += glyphs[i].width + spacing
        shelf = max(shelf, glyphs[i].height + spacing)
    }
    let pageH = nextPowerOfTwo(y + shelf)
    let ctx = CGContext(data: nil, width: pageW, height: pageH, bitsPerComponent: 8, bytesPerRow: pageW,
        space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue)!
    ctx.setFillColor(gray: 0, alpha: 1)
    ctx.fill(CGRect(x: 0, y: 0, width: pageW, height: pageH))
    ctx.setAllowsAntialiasing(true)
    let stroke = spec.outline > 0 ? outlinePx(spec, d) : 0
    for g in glyphs {
        guard let path = g.path else { continue }
        ctx.saveGState()
        ctx.translateBy(x: CGFloat(g.atlasX - g.x0), y: CGFloat(pageH - g.atlasY - g.top))
        if stroke > 0 {
            // inner outline: the stroke is clipped to the glyph, so the outer edge stays the edge of the solid digit
            ctx.addPath(path)
            ctx.clip()
            ctx.addPath(path)
            ctx.setStrokeColor(gray: 1, alpha: 1)
            ctx.setLineWidth(2 * stroke)
            ctx.setLineJoin(.round)
            ctx.strokePath()
        } else {
            ctx.setFillColor(gray: 1, alpha: 1)
            ctx.addPath(path)
            ctx.fillPath()
        }
        ctx.restoreGState()
    }
    writePng(ctx, dir + "/" + spec.id + ".png")

    let base = capTop
    var fnt = "info face=\"Saira-\(spec.id)\" size=-\(Int(px)) bold=0 italic=0 charset=\"\" unicode=1 stretchH=100 smooth=1 aa=1 padding=0,0,0,0 spacing=\(spacing),\(spacing) outline=0\n"
    fnt += "common lineHeight=\(base) base=\(base) scaleW=\(pageW) scaleH=\(pageH) pages=1 packed=0 alphaChnl=1 redChnl=0 greenChnl=0 blueChnl=0\n"
    fnt += "page id=0 file=\"\(spec.id).png\"\n"
    fnt += "chars count=\(glyphs.count)\n"
    for g in glyphs {
        let id = g.char.unicodeScalars.first!.value
        fnt += "char id=\(id) x=\(g.atlasX) y=\(g.atlasY) width=\(g.width) height=\(g.height) xoffset=\(g.x0) yoffset=\(base - g.top) xadvance=\(g.advance) page=0 chnl=15\n"
    }
    try! fnt.write(toFile: dir + "/" + spec.id + ".fnt", atomically: true, encoding: .utf8)

    let adv = Dictionary(uniqueKeysWithValues: glyphs.map { ($0.char, $0.advance) })
    func width(_ s: String) -> Int { s.reduce(0) { $0 + (adv[$1] ?? 0) } }
    var report = "\(diameter): \(spec.id) \(Int(px)) px, cap \(capTop) px"
    if stroke > 0 { report += ", outline \(Int(stroke)) px" }
    let samples = spec.chars == digits ? ["00", "08", "88", "11"]
        : ["12.345", "-12°C", "-12°F", "100", "AUG 29", "MÄR 29", "BODY BATT"]
    for s in samples {
        report += ", \"\(s)\" " + String(format: "%.3f", CGFloat(width(s)) / d) + " D"
    }
    print(report)
    return [:]
}

// ---- icon font ----
// 24 x 24 SVG files (stroke 2, round caps and joins). One glyph per icon in a square box of "box" pixels
// (advance = line height = base = box), so drawText(..., CENTER | VCENTER) centres the 24-unit box. Mapping (the same
// table is in source/ui/IconGlyphs.mc, keep both in step):
//   A heart (filled)  B steps  C flame  D run  E bike  F swim  G climb  H training  I body-battery (filled)  J vo2max

let iconFiles: [(Character, String)] = [("A", "heart"), ("B", "steps"), ("C", "flame"), ("D", "run"), ("E", "bike"),
    ("F", "swim"), ("G", "climb"), ("H", "training"), ("I", "body-battery"), ("J", "vo2max")]
let filledIcons: Set<String> = ["heart", "body-battery"]
// visible icon size UiSizes.ICON_SIZE plus the 2 units of empty margin of each SVG: x 24/20
let iconSize: CGFloat = 0.050

func svgPaths(_ file: String) -> [String] {
    let text = try! String(contentsOfFile: here + "/icons/" + file + ".svg", encoding: .utf8)
    var result = [String]()
    var rest = Substring(text)
    while let r = rest.range(of: "<path") {
        rest = rest[r.upperBound...]
        let end = rest.range(of: ">")!
        let tag = String(rest[..<end.lowerBound])
        rest = rest[end.upperBound...]
        if tag.contains("stroke=\"none\"") && tag.contains("fill=\"none\"") { continue }   // bounding box of the file
        let dPos = tag.range(of: " d=\"")!
        let tail = tag[dPos.upperBound...]
        result.append(String(tail[..<tail.firstIndex(of: "\"")!]))
    }
    return result
}

struct PathScanner {
    let chars: [Character]
    var i = 0
    init(_ s: String) { chars = Array(s) }
    mutating func skipSeparators() {
        while i < chars.count, chars[i] == " " || chars[i] == "," || chars[i] == "\n" || chars[i] == "\t" { i += 1 }
    }
    mutating func number() -> CGFloat {
        skipSeparators()
        var s = ""
        if chars[i] == "-" || chars[i] == "+" { s.append(chars[i]); i += 1 }
        var dot = false
        while i < chars.count, chars[i].isNumber || (chars[i] == "." && !dot) {
            if chars[i] == "." { dot = true }
            s.append(chars[i]); i += 1
        }
        return CGFloat(Double(s)!)
    }
    mutating func flag() -> Bool {
        skipSeparators()
        let v = chars[i] == "1"
        i += 1
        return v
    }
}

// SVG elliptical arc to cubic Béziers (SVG 1.1 implementation notes F.6.5)
func addArc(_ p: CGMutablePath, from p0: CGPoint, rx rx0: CGFloat, ry ry0: CGFloat, rot: CGFloat, large: Bool,
            sweep: Bool, to p1: CGPoint) {
    var rx = abs(rx0), ry = abs(ry0)
    if rx == 0 || ry == 0 || p0 == p1 { p.addLine(to: p1); return }
    let phi = rot * .pi / 180
    let cp = cos(phi), sp = sin(phi)
    let dx = (p0.x - p1.x) / 2, dy = (p0.y - p1.y) / 2
    let x1 = cp * dx + sp * dy, y1 = -sp * dx + cp * dy
    let lambda = x1 * x1 / (rx * rx) + y1 * y1 / (ry * ry)
    if lambda > 1 { rx *= lambda.squareRoot(); ry *= lambda.squareRoot() }
    let num = rx * rx * ry * ry - rx * rx * y1 * y1 - ry * ry * x1 * x1
    let den = rx * rx * y1 * y1 + ry * ry * x1 * x1
    var coef = (max(0, num / den)).squareRoot()
    if large == sweep { coef = -coef }
    let cxp = coef * rx * y1 / ry, cyp = -coef * ry * x1 / rx
    let cx = cp * cxp - sp * cyp + (p0.x + p1.x) / 2
    let cy = sp * cxp + cp * cyp + (p0.y + p1.y) / 2
    let th1 = atan2((y1 - cyp) / ry, (x1 - cxp) / rx)
    var dth = atan2((-y1 - cyp) / ry, (-x1 - cxp) / rx) - th1
    if sweep && dth < 0 { dth += 2 * .pi }
    if !sweep && dth > 0 { dth -= 2 * .pi }
    let n = Int(ceil(abs(dth) / (.pi / 2) - 1e-9))
    let step = dth / CGFloat(n)
    let t = 4 / 3 * tan(step / 4)
    var a = th1
    for _ in 0..<n {
        let b = a + step
        func pt(_ ang: CGFloat, _ d: CGFloat) -> CGPoint {
            let ex = rx * (cos(ang) - d * t * sin(ang)), ey = ry * (sin(ang) + d * t * cos(ang))
            return CGPoint(x: cp * ex - sp * ey + cx, y: sp * ex + cp * ey + cy)
        }
        p.addCurve(to: pt(b, 0), control1: pt(a, 1), control2: pt(b, -1))
        a = b
    }
    p.addLine(to: p1)
}

func parsePath(_ d: String) -> CGPath {
    let path = CGMutablePath()
    var sc = PathScanner(d)
    var cur = CGPoint.zero, start = CGPoint.zero
    var lastCtl: CGPoint? = nil, lastQ: CGPoint? = nil
    var cmd: Character = " "
    while true {
        sc.skipSeparators()
        if sc.i >= sc.chars.count { break }
        if sc.chars[sc.i].isLetter { cmd = sc.chars[sc.i]; sc.i += 1 }
        else if cmd == "M" { cmd = "L" } else if cmd == "m" { cmd = "l" }
        let rel = cmd.isLowercase
        let ox = rel ? cur.x : 0, oy = rel ? cur.y : 0
        var newCtl: CGPoint? = nil, newQ: CGPoint? = nil
        switch Character(cmd.uppercased()) {
        case "M":
            cur = CGPoint(x: ox + sc.number(), y: oy + sc.number()); start = cur; path.move(to: cur)
        case "L":
            cur = CGPoint(x: ox + sc.number(), y: oy + sc.number()); path.addLine(to: cur)
        case "H":
            cur = CGPoint(x: ox + sc.number(), y: cur.y); path.addLine(to: cur)
        case "V":
            cur = CGPoint(x: cur.x, y: oy + sc.number()); path.addLine(to: cur)
        case "C":
            let c1 = CGPoint(x: ox + sc.number(), y: oy + sc.number())
            let c2 = CGPoint(x: ox + sc.number(), y: oy + sc.number())
            let e = CGPoint(x: ox + sc.number(), y: oy + sc.number())
            path.addCurve(to: e, control1: c1, control2: c2); newCtl = c2; cur = e
        case "S":
            let c1 = lastCtl.map { CGPoint(x: 2 * cur.x - $0.x, y: 2 * cur.y - $0.y) } ?? cur
            let c2 = CGPoint(x: ox + sc.number(), y: oy + sc.number())
            let e = CGPoint(x: ox + sc.number(), y: oy + sc.number())
            path.addCurve(to: e, control1: c1, control2: c2); newCtl = c2; cur = e
        case "Q":
            let c = CGPoint(x: ox + sc.number(), y: oy + sc.number())
            let e = CGPoint(x: ox + sc.number(), y: oy + sc.number())
            path.addQuadCurve(to: e, control: c); newQ = c; cur = e
        case "T":
            let c = lastQ.map { CGPoint(x: 2 * cur.x - $0.x, y: 2 * cur.y - $0.y) } ?? cur
            let e = CGPoint(x: ox + sc.number(), y: oy + sc.number())
            path.addQuadCurve(to: e, control: c); newQ = c; cur = e
        case "A":
            let rx = sc.number(), ry = sc.number(), rot = sc.number()
            let large = sc.flag(), sweep = sc.flag()
            let e = CGPoint(x: ox + sc.number(), y: oy + sc.number())
            addArc(path, from: cur, rx: rx, ry: ry, rot: rot, large: large, sweep: sweep, to: e); cur = e
        case "Z":
            path.closeSubpath(); cur = start
        default:
            fatalError("path command \(cmd) not supported")
        }
        lastCtl = newCtl; lastQ = newQ
    }
    return path
}

func writeIconFont(diameter: Int, dir: String) {
    let box = max(12, Int((iconSize * 24 / 20 * CGFloat(diameter) / 2).rounded()) * 2)   // even
    struct Cell { let ch: Character; let x0: Int; let y0: Int; let w: Int; let h: Int; let px: [UInt8]; var ax = 0; var ay = 0 }
    var cells = [Cell]()
    for (ch, file) in iconFiles {
        let ctx = CGContext(data: nil, width: box, height: box, bitsPerComponent: 8, bytesPerRow: box,
            space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue)!
        ctx.setAllowsAntialiasing(true)
        ctx.setFillColor(gray: 0, alpha: 1)
        ctx.fill(CGRect(x: 0, y: 0, width: box, height: box))
        let u = CGFloat(box) / 24
        ctx.translateBy(x: 0, y: CGFloat(box))
        ctx.scaleBy(x: u, y: -u)
        let pen = CGFloat(max(1, (box + 6) / 12))
        let filled = filledIcons.contains(file)
        ctx.setFillColor(gray: 1, alpha: 1)
        ctx.setStrokeColor(gray: 1, alpha: 1)
        ctx.setLineWidth(pen / u)
        ctx.setLineCap(.round)
        ctx.setLineJoin(.round)
        for d in svgPaths(file) {
            ctx.addPath(parsePath(d))
            if filled { ctx.fillPath() } else { ctx.strokePath() }
        }
        let data = ctx.data!.assumingMemoryBound(to: UInt8.self)
        var minX = box, minY = box, maxX = -1, maxY = -1
        for y in 0..<box { for x in 0..<box where data[y * box + x] > 0 {
            minX = min(minX, x); maxX = max(maxX, x); minY = min(minY, y); maxY = max(maxY, y)
        } }
        precondition(maxX >= 0, "\(file): empty icon")
        var out = [UInt8]()
        for y in minY...maxY { for x in minX...maxX { out.append(data[y * box + x]) } }
        cells.append(Cell(ch: ch, x0: minX, y0: minY, w: maxX - minX + 1, h: maxY - minY + 1, px: out))
    }
    let spacing = 2
    let area = cells.reduce(0) { $0 + ($1.w + spacing) * ($1.h + spacing) }
    let pageW = nextPowerOfTwo(max(cells.map { $0.w + spacing }.max()!, Int(Double(area).squareRoot() * 1.3)))
    var x = 0, y = 0, shelf = 0
    for i in cells.indices {
        if x + cells[i].w + spacing > pageW { x = 0; y += shelf; shelf = 0 }
        cells[i].ax = x; cells[i].ay = y
        x += cells[i].w + spacing
        shelf = max(shelf, cells[i].h + spacing)
    }
    let pageH = nextPowerOfTwo(y + shelf)
    let ctx = CGContext(data: nil, width: pageW, height: pageH, bitsPerComponent: 8, bytesPerRow: pageW,
        space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.none.rawValue)!
    let page = ctx.data!.assumingMemoryBound(to: UInt8.self)
    for i in 0..<(pageW * pageH) { page[i] = 0 }
    for c in cells { for r in 0..<c.h { for q in 0..<c.w { page[(c.ay + r) * pageW + c.ax + q] = c.px[r * c.w + q] } } }
    writePng(ctx, dir + "/Icons.png")
    var fnt = "info face=\"Icons\" size=-\(box) bold=0 italic=0 charset=\"\" unicode=1 stretchH=100 smooth=1 aa=1 padding=0,0,0,0 spacing=\(spacing),\(spacing) outline=0\n"
    fnt += "common lineHeight=\(box) base=\(box) scaleW=\(pageW) scaleH=\(pageH) pages=1 packed=0 alphaChnl=1 redChnl=0 greenChnl=0 blueChnl=0\n"
    fnt += "page id=0 file=\"Icons.png\"\nchars count=\(cells.count)\n"
    for c in cells {
        fnt += "char id=\(c.ch.unicodeScalars.first!.value) x=\(c.ax) y=\(c.ay) width=\(c.w) height=\(c.h) xoffset=\(c.x0) yoffset=\(c.y0) xadvance=\(box) page=0 chnl=15\n"
    }
    try! fnt.write(toFile: dir + "/Icons.fnt", atomically: true, encoding: .utf8)
    print("\(diameter): Icons box \(box) px")
}

func xmlEscape(_ s: String) -> String {
    return s.replacingOccurrences(of: "&", with: "&amp;").replacingOccurrences(of: "\"", with: "&quot;")
        .replacingOccurrences(of: "<", with: "&lt;")
}

for diameter in requestedDiameters() {
    let dir = "\(root)/resources-round-\(diameter)x\(diameter)/fonts"
    try! FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
    // only what fonts.xml lists belongs in the folder
    for name in (try? FileManager.default.contentsOfDirectory(atPath: dir)) ?? [] {
        try! FileManager.default.removeItem(atPath: dir + "/" + name)
    }
    var xml = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<!-- Generated by design/drafts/fonts/make_fonts.swift, do not edit. -->\n<fonts>\n"
    for spec in specs {
        writeFont(spec, diameter: diameter, dir: dir)
        xml += "    <font id=\"\(spec.id)\" filename=\"\(spec.id).fnt\" antialias=\"true\" filter=\"\(xmlEscape(spec.chars))\" />\n"
    }
    writeIconFont(diameter: diameter, dir: dir)
    xml += "    <font id=\"Icons\" filename=\"Icons.fnt\" antialias=\"true\" filter=\"ABCDEFGHIJ\" />\n"
    xml += "</fonts>\n"
    try! xml.write(toFile: dir + "/fonts.xml", atomically: true, encoding: .utf8)
}
