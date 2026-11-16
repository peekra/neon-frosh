// Store images for Neon Frosh 1.0.0 from simulator captures (466 px, fenix9pro51mm, scripts/screenshot.sh, demo
// values 10:08 / AUG 29 / 17 C / 82 / 76 / 171 / 3.420 in a temporary copy of the project). Flat dark background,
// a device frame drawn here (no photo, no logo, no lettering), text in Saira (OFL, design/drafts/fonts/source).
// Run from the project root:
//   swiftc -O design/drafts/store_tools/main.swift design/drafts/store_tools/PNGIndexed.swift -o "$TMPDIR/compose" && "$TMPDIR/compose" <captures dir> design/store/
import Foundation
import CoreGraphics
import CoreText
import ImageIO

let sRGB = CGColorSpace(name: CGColorSpace.sRGB)!
let cap = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "design/drafts/captures/"
let out = CommandLine.arguments.count > 2 ? CommandLine.arguments[2] : "design/store/"

typealias RGB = (Double, Double, Double)
func hex(_ v: Int) -> RGB { (Double(v >> 16 & 255) / 255, Double(v >> 8 & 255) / 255, Double(v & 255) / 255) }
let navy0 = hex(0x0A0F15), navy1 = hex(0x16212D)
let cyan = hex(0x3DD6C6), red = hex(0xFF3B30), green = hex(0x34C759), orange = hex(0xFF8C1A), yellow = hex(0xFFD60A), pink = hex(0xFF5FA8)
let blue = hex(0x3D9BFF), purple = hex(0xB57BFF)
let white: RGB = (1, 1, 1), grey = hex(0x8FA3B8)

func cg(_ c: RGB, _ a: Double = 1) -> CGColor { CGColor(colorSpace: sRGB, components: [c.0, c.1, c.2, a])! }

// ---------- fonts: Saira variable, weight and width set per call ----------
let sairaDesc: CTFontDescriptor = {
    let url = URL(fileURLWithPath: "design/drafts/fonts/source/Saira[wdth,wght].ttf") as CFURL
    let arr = CTFontManagerCreateFontDescriptorsFromURL(url) as! [CTFontDescriptor]
    return arr[0]
}()
func saira(_ size: Double, weight: Double, width: Double = 100) -> CTFont {
    let base = CTFontCreateWithFontDescriptor(sairaDesc, size, nil)
    let vars: [NSNumber: NSNumber] = [NSNumber(value: 0x77676874): NSNumber(value: weight),   // wght
                                      NSNumber(value: 0x77647468): NSNumber(value: width)]    // wdth
    let d = CTFontDescriptorCreateWithAttributes([kCTFontVariationAttribute: vars] as CFDictionary)
    return CTFontCreateCopyWithAttributes(base, size, nil, d)
}

// ---------- canvas with y pointing down ----------
func canvas(_ w: Int, _ h: Int) -> CGContext {
    let c = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8, bytesPerRow: 0, space: sRGB,
                      bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
    c.translateBy(x: 0, y: CGFloat(h)); c.scaleBy(x: 1, y: -1)
    c.textMatrix = CGAffineTransform(scaleX: 1, y: -1)
    return c
}

func load(_ name: String) -> CGImage {
    let path = cap + name + ".png"
    guard let s = CGImageSourceCreateWithURL(URL(fileURLWithPath: path) as CFURL, nil),
          let i = CGImageSourceCreateImageAtIndex(s, 0, nil) else { fatalError("missing capture " + path) }
    return i
}

// Background: radial navy, faint HUD grid, a few horizontal scan bands, corner brackets
func background(_ c: CGContext, _ w: Double, _ h: Double, focus: CGPoint, accent: RGB = cyan) {
    let g = CGGradient(colorsSpace: sRGB, colors: [cg(navy1), cg(navy0)] as CFArray, locations: [0, 1])!
    c.drawRadialGradient(g, startCenter: focus, startRadius: 0, endCenter: focus, endRadius: max(w, h) * 0.75,
                         options: [.drawsAfterEndLocation])
    c.setStrokeColor(cg(accent, 0.04)); c.setLineWidth(1)
    var x = 0.0; while x <= w { c.move(to: CGPoint(x: x, y: 0)); c.addLine(to: CGPoint(x: x, y: h)); x += 64 }
    var y = 0.0; while y <= h { c.move(to: CGPoint(x: 0, y: y)); c.addLine(to: CGPoint(x: w, y: y)); y += 64 }
    c.strokePath()
    // corner brackets
    c.setStrokeColor(cg(accent, 0.45)); c.setLineWidth(3)
    let m = 26.0, L = 46.0
    for (px, py, sx, sy) in [(m, m, 1.0, 1.0), (w - m, m, -1, 1), (m, h - m, 1, -1), (w - m, h - m, -1, -1)] {
        c.move(to: CGPoint(x: px, y: py + sy * L)); c.addLine(to: CGPoint(x: px, y: py)); c.addLine(to: CGPoint(x: px + sx * L, y: py))
    }
    c.strokePath()
}

// Glow and HUD orbit rings behind a watch
func halo(_ c: CGContext, cx: Double, cy: Double, d: Double, accent: RGB, rings: Bool = true, strength: Double = 1) {
    let p = CGPoint(x: cx, y: cy)
    let g = CGGradient(colorsSpace: sRGB, colors: [cg(accent, 0.30 * strength), cg(accent, 0.10 * strength), cg(accent, 0)] as CFArray,
                       locations: [0, 0.55, 1])!
    c.drawRadialGradient(g, startCenter: p, startRadius: d * 0.45, endCenter: p, endRadius: d * 0.95, options: [])
    guard rings else { return }
    c.setLineWidth(1.5)
    c.setStrokeColor(cg(accent, 0.22)); c.addArc(center: p, radius: d * 0.70, startAngle: 0, endAngle: 2 * .pi, clockwise: false); c.strokePath()
    // dashed outer orbit with two bright segments
    c.setStrokeColor(cg(accent, 0.16)); c.setLineDash(phase: 0, lengths: [4, 10])
    c.addArc(center: p, radius: d * 0.80, startAngle: 0, endAngle: 2 * .pi, clockwise: false); c.strokePath()
    c.setLineDash(phase: 0, lengths: [])
    c.setStrokeColor(cg(accent, 0.75)); c.setLineWidth(3)
    c.addArc(center: p, radius: d * 0.70, startAngle: -.pi * 0.80, endAngle: -.pi * 0.62, clockwise: false); c.strokePath()
    c.addArc(center: p, radius: d * 0.70, startAngle: .pi * 0.18, endAngle: .pi * 0.30, clockwise: false); c.strokePath()
    // tick marks on the inner orbit
    c.setStrokeColor(cg(accent, 0.30)); c.setLineWidth(1.5)
    for i in 0..<72 {
        let a = Double(i) * .pi / 36, r0 = d * (i % 6 == 0 ? 0.645 : 0.665), r1 = d * 0.68
        c.move(to: CGPoint(x: cx + cos(a) * r0, y: cy + sin(a) * r0)); c.addLine(to: CGPoint(x: cx + cos(a) * r1, y: cy + sin(a) * r1))
    }
    c.strokePath()
}

// Device: brushed case, bezel, four plain buttons, the capture clipped to the display circle
func watch(_ c: CGContext, _ img: CGImage, cx: Double, cy: Double, d: Double, buttons: Bool = true, shadow: Bool = true) {
    let R = d / 2, caseR = R * 1.17
    let p = CGPoint(x: cx, y: cy)
    c.saveGState()
    if shadow { c.setShadow(offset: CGSize(width: 0, height: d * 0.03), blur: d * 0.08, color: cg((0, 0, 0), 0.8)) }
    if buttons {
        c.setFillColor(cg(hex(0x2A323C)))
        for (a, s) in [(-0.38, 1.0), (0.38, 1.0), (-0.38, -1.0), (0.38, -1.0)] {   // radians from the horizontal
            let bx = cx + s * cos(a) * caseR, by = cy + sin(a) * caseR
            let r = CGRect(x: bx - (s > 0 ? 0 : R * 0.14), y: by - R * 0.07, width: R * 0.14, height: R * 0.14)
            c.addPath(CGPath(roundedRect: r, cornerWidth: R * 0.03, cornerHeight: R * 0.03, transform: nil))
        }
        c.fillPath()
    }
    c.addEllipse(in: CGRect(x: cx - caseR, y: cy - caseR, width: 2 * caseR, height: 2 * caseR))
    c.setFillColor(cg(hex(0x1B222B))); c.fillPath()
    c.restoreGState()
    // case: metallic linear gradient
    c.saveGState()
    c.addEllipse(in: CGRect(x: cx - caseR, y: cy - caseR, width: 2 * caseR, height: 2 * caseR)); c.clip()
    let metal = CGGradient(colorsSpace: sRGB, colors: [cg(hex(0x6B7785)), cg(hex(0x2B333D)), cg(hex(0x161B22)), cg(hex(0x4A5563))] as CFArray,
                           locations: [0, 0.35, 0.7, 1])!
    c.drawLinearGradient(metal, start: CGPoint(x: cx - caseR, y: cy - caseR), end: CGPoint(x: cx + caseR, y: cy + caseR), options: [])
    c.restoreGState()
    // bezel ring with minute marks
    let bezR = R * 1.085
    c.setFillColor(cg(hex(0x0B0F14)))
    c.fillEllipse(in: CGRect(x: cx - bezR, y: cy - bezR, width: 2 * bezR, height: 2 * bezR))
    c.setStrokeColor(cg(hex(0x56606C))); c.setLineWidth(max(1, R * 0.008))
    for i in 0..<60 {
        let a = Double(i) * .pi / 30, r0 = R * (i % 5 == 0 ? 1.025 : 1.045), r1 = R * 1.07
        c.move(to: CGPoint(x: cx + cos(a) * r0, y: cy + sin(a) * r0)); c.addLine(to: CGPoint(x: cx + cos(a) * r1, y: cy + sin(a) * r1))
    }
    c.strokePath()
    // display
    c.saveGState()
    c.addEllipse(in: CGRect(x: cx - R, y: cy - R, width: d, height: d)); c.clip()
    c.setFillColor(cg((0, 0, 0))); c.fill(CGRect(x: cx - R, y: cy - R, width: d, height: d))
    c.interpolationQuality = .high
    c.translateBy(x: 0, y: cy * 2); c.scaleBy(x: 1, y: -1)        // undo the flip for the bitmap
    c.draw(img, in: CGRect(x: cx - R, y: cy - R, width: d, height: d))
    c.restoreGState()
    // glass reflection
    c.saveGState()
    c.addEllipse(in: CGRect(x: cx - R, y: cy - R, width: d, height: d)); c.clip()
    let glass = CGGradient(colorsSpace: sRGB, colors: [cg(white, 0.06), cg(white, 0)] as CFArray, locations: [0, 1])!
    c.drawLinearGradient(glass, start: CGPoint(x: cx - R, y: cy - R), end: CGPoint(x: cx, y: cy), options: [])
    c.restoreGState()
    _ = p
}

// Text, anchor: 0 left, 0.5 centre, 1 right; y = top of the cap height box
@discardableResult
func text(_ c: CGContext, _ s: String, x: Double, y: Double, size: Double, weight: Double = 700, width: Double = 100,
          color: RGB = white, alpha: Double = 1, anchor: Double = 0.5, track: Double = 0.06) -> Double {
    let f = saira(size, weight: weight, width: width)
    let attrs: [NSAttributedString.Key: Any] = [
        NSAttributedString.Key(kCTFontAttributeName as String): f,
        NSAttributedString.Key(kCTKernAttributeName as String): size * track,
        NSAttributedString.Key(kCTForegroundColorAttributeName as String): cg(color, alpha)]
    let line = CTLineCreateWithAttributedString(NSAttributedString(string: s, attributes: attrs))
    let w = CTLineGetTypographicBounds(line, nil, nil, nil)
    c.textPosition = CGPoint(x: x - w * anchor, y: y + CTFontGetCapHeight(f))
    CTLineDraw(line, c)
    return w
}
// Title with a soft glow
func glowText(_ c: CGContext, _ s: String, x: Double, y: Double, size: Double, color: RGB, anchor: Double = 0.5, track: Double = 0.10) {
    c.saveGState(); c.setShadow(offset: .zero, blur: size * 0.35, color: cg(color, 0.9))
    text(c, s, x: x, y: y, size: size, weight: 800, width: 112, color: color, anchor: anchor, track: track)
    c.restoreGState()
    text(c, s, x: x, y: y, size: size, weight: 800, width: 112, color: color, anchor: anchor, track: track)
}

// Callout: dot on the face element, elbow line, label and small sub-label
func callout(_ c: CGContext, from: CGPoint, elbow: CGPoint, to: CGPoint, label: String, sub: String, accent: RGB, right: Bool) {
    c.setStrokeColor(cg(accent, 0.9)); c.setLineWidth(2)
    c.move(to: from); c.addLine(to: elbow); c.addLine(to: to); c.strokePath()
    c.setFillColor(cg(accent)); c.fillEllipse(in: CGRect(x: from.x - 6, y: from.y - 6, width: 12, height: 12))
    c.setStrokeColor(cg(accent, 0.5)); c.setLineWidth(2)
    c.strokeEllipse(in: CGRect(x: from.x - 12, y: from.y - 12, width: 24, height: 24))
    let ax = right ? 0.0 : 1.0, tx = to.x + (right ? 10 : -10)
    text(c, label, x: tx, y: to.y - 24, size: 23, weight: 700, color: white, anchor: ax, track: 0.08)
    text(c, sub, x: tx, y: to.y + 8, size: 17, weight: 500, color: grey, anchor: ax, track: 0.06)
}
// point on a watch face from fractions of the display diameter (y down from the centre)
func at(_ cx: Double, _ cy: Double, _ d: Double, _ fx: Double, _ fy: Double) -> CGPoint { CGPoint(x: cx + fx * d, y: cy + fy * d) }

func save(_ c: CGContext, _ name: String, limitKB: Int = 150) {
    let img = c.makeImage()!
    for (colors, dither) in [(256, 0.0), (192, 0.0), (128, 0.0), (96, 0.0), (64, 0.0)] {
        writeIndexedPNG(img, out + name, colors: colors, dither: dither, adaptive: false)
        let size = ((try? FileManager.default.attributesOfItem(atPath: out + name)[.size] as? Int) ?? 0) / 1024
        if size < limitKB { print(name, size, "KB,", colors, "colours"); return }
    }
    print(name, "STILL TOO LARGE")
}
// Truecolour RGB PNG without alpha channel (icon)
func saveRGB(_ c: CGContext, _ name: String) {
    let img = c.makeImage()!   // noneSkipLast: ImageIO writes an RGB PNG without alpha channel
    let d = CGImageDestinationCreateWithURL(URL(fileURLWithPath: out + name) as CFURL, "public.png" as CFString, 1, nil)!
    CGImageDestinationAddImage(d, img, nil); CGImageDestinationFinalize(d)
    print(name, ((try? FileManager.default.attributesOfItem(atPath: out + name)[.size] as? Int) ?? 0) / 1024, "KB, RGB")
}
func plain(_ c: CGContext, _ w: Double, _ h: Double) {   // icon: plain background, no gradient
    c.setFillColor(cg(hex(0x0C1C2E))); c.fill(CGRect(x: 0, y: 0, width: w, height: h))
}

// Title with two colours: "NEON" colour a, "FROSH" colour b, centred on x
func title(_ c: CGContext, x: Double, y: Double, size: Double, anchor: Double = 0.5) {
    let f = saira(size, weight: 800, width: 112)
    func w(_ s: String) -> Double {
        let a: [NSAttributedString.Key: Any] = [NSAttributedString.Key(kCTFontAttributeName as String): f,
            NSAttributedString.Key(kCTKernAttributeName as String): size * 0.10]
        return CTLineGetTypographicBounds(CTLineCreateWithAttributedString(NSAttributedString(string: s, attributes: a)), nil, nil, nil)
    }
    let w1 = w("NEON "), w2 = w("FROSH")
    let x0 = x - (w1 + w2) * anchor
    text(c, "NEON ", x: x0, y: y, size: size, weight: 800, width: 112, color: red, anchor: 0, track: 0.10)
    text(c, "FROSH", x: x0 + w1, y: y, size: size, weight: 800, width: 112, color: cyan, anchor: 0, track: 0.10)
}

// ================= images =================
let dark = load("dark_base"), light = load("light_base"), aod = load("aod")

// Icon 500 x 500: plain background, face with the drawn case, no shadow, no text, about 10 px margin
do {
    let c = canvas(500, 500)
    c.setFillColor(cg(hex(0x12303A))); c.fill(CGRect(x: 0, y: 0, width: 500, height: 500))
    watch(c, dark, cx: 250, cy: 250, d: 470 / 1.17, buttons: false, shadow: false)
    saveRGB(c, "icon_500.png")
}

// 1: overview with callouts
do {
    let c = canvas(1024, 1024)
    let cx = 512.0, cy = 600.0, d = 470.0
    background(c, 1024, 1024, focus: CGPoint(x: cx, y: cy))
    title(c, x: 512, y: 60, size: 76)
    text(c, "BOLD TIME  ·  YOUR DATA  ·  YOUR COLOURS", x: 512, y: 160, size: 22, weight: 500, color: grey, track: 0.20)
    watch(c, dark, cx: cx, cy: cy, d: d)
    let L = 56.0, Rx = 968.0
    // anchors lie on empty parts of the face, lines never cross a number
    callout(c, from: at(cx, cy, d, 0.02, -0.415), elbow: CGPoint(x: 700, y: 330), to: CGPoint(x: Rx, y: 330),
            label: "BATTERY + BLUETOOTH", sub: "phone status", accent: cyan, right: false)
    callout(c, from: at(cx, cy, d, -0.04, -0.335), elbow: CGPoint(x: 330, y: 270), to: CGPoint(x: L, y: 270),
            label: "TOP PANEL", sub: "date or any data", accent: cyan, right: true)
    callout(c, from: at(cx, cy, d, -0.375, -0.245), elbow: CGPoint(x: 190, y: 420), to: CGPoint(x: L, y: 420),
            label: "ROUND FIELDS", sub: "4 to choose", accent: cyan, right: true)
    callout(c, from: at(cx, cy, d, 0.387, -0.15), elbow: CGPoint(x: 850, y: 470), to: CGPoint(x: Rx, y: 470),
            label: "PROGRESS RING", sub: "goal at a glance", accent: cyan, right: false)
    callout(c, from: at(cx, cy, d, 0.245, 0.075), elbow: CGPoint(x: 880, y: 640), to: CGPoint(x: Rx, y: 640),
            label: "OUTLINE MINUTES", sub: "colour 2", accent: cyan, right: false)
    callout(c, from: at(cx, cy, d, -0.24, 0.075), elbow: CGPoint(x: 180, y: 700), to: CGPoint(x: L, y: 700),
            label: "SOLID HOURS", sub: "colour 1", accent: cyan, right: true)
    callout(c, from: at(cx, cy, d, 0.15, 0.335), elbow: CGPoint(x: 760, y: 900), to: CGPoint(x: Rx, y: 900),
            label: "BOTTOM PANEL", sub: "any data", accent: cyan, right: false)
    save(c, "screenshot_01_overview.png")
}

// 2: dark or light
do {
    let c = canvas(1024, 1024)
    background(c, 1024, 1024, focus: CGPoint(x: 512, y: 560))
    text(c, "DARK OR LIGHT", x: 512, y: 80, size: 70, weight: 800, width: 112, color: white, track: 0.10)
    text(c, "SWITCH IN THE PHONE APP OR ON THE WATCH", x: 512, y: 180, size: 22, weight: 500, color: grey, track: 0.16)
    watch(c, dark, cx: 268, cy: 570, d: 350); watch(c, light, cx: 756, cy: 570, d: 350)
    text(c, "DARK", x: 268, y: 850, size: 30, weight: 700, color: cyan, track: 0.3)
    text(c, "LIGHT", x: 756, y: 850, size: 30, weight: 700, color: white, track: 0.3)
    save(c, "screenshot_02_backgrounds.png")
}

// 3: colours, 3 x 2 faces
do {
    let c = canvas(1024, 1024)
    background(c, 1024, 1024, focus: CGPoint(x: 512, y: 560))
    text(c, "8 COLOURS, 2 ROLES", x: 512, y: 64, size: 62, weight: 800, width: 112, color: white, track: 0.10)
    text(c, "COLOUR 1: HOURS + RINGS   ·   COLOUR 2: MINUTES + PANELS", x: 512, y: 150, size: 19, weight: 500, color: grey, track: 0.10)
    let items: [(String, RGB, RGB, String, Double, Double)] = [
        ("dark_base", red, cyan, "RED + TEAL", 210, 400), ("dark_orange_blue", orange, blue, "ORANGE + BLUE", 512, 400), ("dark_green_purple", green, purple, "GREEN + PURPLE", 814, 400),
        ("dark_yellow_pink", yellow, pink, "YELLOW + PINK", 210, 760), ("dark_blue_orange", blue, orange, "BLUE + ORANGE", 512, 760), ("dark_purple_green", purple, green, "PURPLE + GREEN", 814, 760)]
    for it in items {
        watch(c, load(it.0), cx: it.4, cy: it.5, d: 240)
        text(c, it.3, x: it.4, y: it.5 + 168, size: 21, weight: 700, color: it.1, track: 0.20)
    }
    save(c, "screenshot_03_colors.png")
}

// 4: data fields
do {
    let c = canvas(1024, 1024)
    let cx = 330.0, cy = 600.0, d = 400.0
    background(c, 1024, 1024, focus: CGPoint(x: cx, y: cy))
    text(c, "YOUR DATA", x: 512, y: 64, size: 66, weight: 800, width: 112, color: white, track: 0.10)
    text(c, "6 FIELDS  ·  YOU PICK WHAT EACH ONE SHOWS", x: 512, y: 156, size: 22, weight: 500, color: grey, track: 0.14)
    watch(c, load("fields_a"), cx: cx, cy: cy + 20, d: d)
    let kinds = ["DATE", "WEATHER", "ENERGY LEVEL", "HEART RATE", "ACTIVE CALORIES", "TOTAL CALORIES", "STEPS",
                 "RUN KM / WEEK", "BIKE KM / WEEK", "SWIM M / WEEK", "CLIMBING / WEEK*", "TRAINING / WEEK", "VO2 MAX"]
    let x0 = 650.0, y0 = 222.0, rowH = 45.0
    for (i, k) in kinds.enumerated() {
        let y = y0 + Double(i) * rowH
        let r = CGRect(x: x0, y: y, width: 320, height: rowH - 12)
        c.addPath(CGPath(roundedRect: r, cornerWidth: 6, cornerHeight: 6, transform: nil))
        c.setFillColor(cg(cyan, 0.08)); c.fillPath()
        c.setFillColor(cg(red)); c.fill(CGRect(x: x0, y: y, width: 4, height: rowH - 12))
        text(c, k, x: x0 + 20, y: y + 11, size: 17, weight: 600, color: white, anchor: 0, track: 0.08)
    }
    text(c, "* DEPENDING ON YOUR WATCH", x: x0, y: y0 + 13 * rowH + 2, size: 15, weight: 400, color: grey, anchor: 0, track: 0.06)
    let tr = CGRect(x: x0, y: 870, width: 320, height: 78)
    c.addPath(CGPath(roundedRect: tr, cornerWidth: 8, cornerHeight: 8, transform: nil))
    c.setStrokeColor(cg(cyan, 0.9)); c.setLineWidth(2); c.strokePath()
    text(c, "TOUCH + HOLD A FIELD", x: x0 + 160, y: 884, size: 20, weight: 700, color: white, anchor: 0.5, track: 0.08)
    text(c, "OPENS ITS VIEW ON TOUCHSCREEN WATCHES", x: x0 + 160, y: 918, size: 13, weight: 500, color: grey, anchor: 0.5, track: 0.04)
    save(c, "screenshot_04_fields.png")
}

// 5: always-on
do {
    let c = canvas(1024, 1024)
    background(c, 1024, 1024, focus: CGPoint(x: 512, y: 560))
    text(c, "ALWAYS-ON VIEW", x: 512, y: 80, size: 66, weight: 800, width: 112, color: white, track: 0.10)
    text(c, "ON AMOLED WATCHES: JUST THE TIME, IN WHITE", x: 512, y: 176, size: 22, weight: 500, color: grey, track: 0.14)
    watch(c, dark, cx: 268, cy: 570, d: 350); watch(c, aod, cx: 756, cy: 570, d: 350)
    text(c, "WRIST RAISED", x: 268, y: 850, size: 26, weight: 700, color: cyan, track: 0.25)
    text(c, "ALWAYS-ON", x: 756, y: 850, size: 26, weight: 700, color: white, track: 0.25)
    text(c, "SAVES BATTERY AND PROTECTS THE SCREEN", x: 512, y: 925, size: 18, weight: 500, color: grey, track: 0.12)
    save(c, "screenshot_05_always_on.png")
}

// Hero 1440 x 720
do {
    let c = canvas(1440, 720)
    let cx = 420.0, cy = 360.0, d = 440.0
    background(c, 1440, 720, focus: CGPoint(x: cx, y: cy))
    watch(c, dark, cx: cx, cy: cy, d: d)
    title(c, x: 1060, y: 220, size: 78)
    text(c, "WATCH FACE", x: 1060, y: 340, size: 30, weight: 600, color: white, track: 0.35)
    text(c, "BOLD TIME  ·  6 DATA FIELDS  ·  8 COLOURS", x: 1060, y: 396, size: 20, weight: 500, color: grey, track: 0.12)
    let dots: [RGB] = [red, orange, yellow, green, cyan, blue, purple, pink]
    for (i, col) in dots.enumerated() {
        let x = 1060 + (Double(i) - 3.5) * 52, y = 480.0
        c.setFillColor(cg(col)); c.fillEllipse(in: CGRect(x: x - 15, y: y - 15, width: 30, height: 30))
    }
    save(c, "hero_1440x720.png", limitKB: 2048)
}
