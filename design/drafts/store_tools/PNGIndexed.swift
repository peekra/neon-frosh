import Foundation
import CoreGraphics
import zlib

// 256-colour palette PNG writer (median cut + k-means refinement, optional Floyd-Steinberg or ordered dithering)
// to keep store screenshots small. Writes an sRGB chunk. Ordered (8 x 8 Bayer) dithering smooths gradients and
// glows at a fraction of the file size of Floyd-Steinberg, because its pattern repeats.

private func rgbBytes(_ img: CGImage) -> [UInt8] {
    let w = img.width, h = img.height
    var buf = [UInt8](repeating: 0, count: w * h * 4)
    let c = CGContext(data: &buf, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w * 4, space: sRGB,
                      bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue)!
    c.draw(img, in: CGRect(x: 0, y: 0, width: w, height: h))
    return buf
}

private struct Box { var bins: [Int] }

private func buildPalette(_ px: [UInt8], _ n: Int, colors: Int) -> [(Double, Double, Double)] {
    // histogram with 6 bits per channel for dark colours (faint glows next to a dark background get their own
    // entries), 5 bits for the rest
    var count = [Double](repeating: 0, count: 1 << 18)
    var sr = [Double](repeating: 0, count: 1 << 18), sg = sr, sb = sr
    for i in 0..<n {
        let r = Int(px[i * 4]), g = Int(px[i * 4 + 1]), b = Int(px[i * 4 + 2])
        let m = max(r, g, b) < 96 ? ~3 : ~7
        let k = ((r & m) >> 2) << 12 | ((g & m) >> 2) << 6 | ((b & m) >> 2)
        count[k] += 1; sr[k] += Double(r); sg[k] += Double(g); sb[k] += Double(b)
    }
    let used = (0..<(1 << 18)).filter { count[$0] > 0 }
    func mean(_ k: Int) -> (Double, Double, Double) { (sr[k] / count[k], sg[k] / count[k], sb[k] / count[k]) }
    var boxes = [Box(bins: used)]
    func score(_ b: Box) -> (Double, Int) {
        var lo = [255.0, 255.0, 255.0], hi = [0.0, 0.0, 0.0], tot = 0.0
        for k in b.bins { let m = mean(k); let v = [m.0, m.1, m.2]
            for c in 0..<3 { lo[c] = min(lo[c], v[c]); hi[c] = max(hi[c], v[c]) }; tot += count[k] }
        let ranges = (0..<3).map { hi[$0] - lo[$0] }
        let ch = ranges.firstIndex(of: ranges.max()!)!
        return (b.bins.count < 2 ? -1 : ranges[ch] * sqrt(tot), ch)
    }
    while boxes.count < colors {
        var best = -1, bestScore = 0.0, bestCh = 0
        for (i, b) in boxes.enumerated() { let (s, ch) = score(b); if s > bestScore { bestScore = s; best = i; bestCh = ch } }
        if best < 0 { break }
        let b = boxes.remove(at: best)
        let sorted = b.bins.sorted { let a = mean($0), c = mean($1); return [a.0, a.1, a.2][bestCh] < [c.0, c.1, c.2][bestCh] }
        let tot = sorted.reduce(0.0) { $0 + count[$1] }
        var acc = 0.0, cut = 1
        for (i, k) in sorted.enumerated() { acc += count[k]; if acc >= tot / 2 { cut = max(1, min(sorted.count - 1, i + 1)); break } }
        boxes.append(Box(bins: Array(sorted[..<cut]))); boxes.append(Box(bins: Array(sorted[cut...])))
    }
    var pal: [(Double, Double, Double)] = boxes.map { b in
        var r = 0.0, g = 0.0, bl = 0.0, t = 0.0
        for k in b.bins { r += sr[k]; g += sg[k]; bl += sb[k]; t += count[k] }
        return (r / t, g / t, bl / t)
    }
    for _ in 0..<4 {   // k-means refinement on the histogram
        var acc = [(Double, Double, Double, Double)](repeating: (0, 0, 0, 0), count: pal.count)
        for k in used {
            let m = mean(k)
            var bi = 0, bd = Double.infinity
            for (i, p) in pal.enumerated() { let d = (p.0 - m.0) * (p.0 - m.0) + (p.1 - m.1) * (p.1 - m.1) + (p.2 - m.2) * (p.2 - m.2); if d < bd { bd = d; bi = i } }
            acc[bi].0 += sr[k]; acc[bi].1 += sg[k]; acc[bi].2 += sb[k]; acc[bi].3 += count[k]
        }
        for i in 0..<pal.count where acc[i].3 > 0 { pal[i] = (acc[i].0 / acc[i].3, acc[i].1 / acc[i].3, acc[i].2 / acc[i].3) }
    }
    return pal
}

private var crcTable: [UInt32] = (0..<256).map { n -> UInt32 in
    var c = UInt32(n)
    for _ in 0..<8 { c = (c & 1) != 0 ? 0xEDB88320 ^ (c >> 1) : c >> 1 }
    return c
}
private func crc32(_ d: [UInt8]) -> UInt32 {
    var c: UInt32 = 0xFFFFFFFF
    for b in d { c = crcTable[Int((c ^ UInt32(b)) & 0xFF)] ^ (c >> 8) }
    return c ^ 0xFFFFFFFF
}
private func be32(_ v: UInt32) -> [UInt8] { [UInt8(v >> 24), UInt8((v >> 16) & 255), UInt8((v >> 8) & 255), UInt8(v & 255)] }
private func chunk(_ type: String, _ data: [UInt8]) -> [UInt8] {
    let td = Array(type.utf8) + data
    return be32(UInt32(data.count)) + td + be32(crc32(td))
}

// Bayer 8 x 8 threshold matrix, values 0..63.
private let bayer8: [Int] = {
    var m = [[0]]   // M(2n) = [[4M, 4M+2], [4M+3, 4M+1]]
    while m.count < 8 {
        let n = m.count
        m = (0..<2 * n).map { y in (0..<2 * n).map { x in 4 * m[y % n][x % n] + [[0, 2], [3, 1]][y / n][x / n] } }
    }
    return m.flatMap { $0 }
}()

// dither: Floyd-Steinberg strength (0 = off). ordered: amplitude of the Bayer dither in 8-bit levels (0 = off);
// when set, it replaces Floyd-Steinberg. ditherAt(x, y, rgb) (pixels, y down) limits dithering to part of the image.
func writeIndexedPNG(_ img: CGImage, _ path: String, colors: Int = 256, dither: Double = 0.8, adaptive: Bool = true, ordered: Double = 0,
                     ditherAt: ((Int, Int, (UInt8, UInt8, UInt8)) -> Bool)? = nil) {
    let w = img.width, h = img.height, n = w * h
    let px = rgbBytes(img)
    let pal = buildPalette(px, n, colors: colors).sorted { 0.3 * $0.0 + 0.59 * $0.1 + 0.11 * $0.2 < 0.3 * $1.0 + 0.59 * $1.1 + 0.11 * $1.2 }
    var cache = [Int16](repeating: -1, count: 1 << 18)
    func nearest(_ r: Double, _ g: Double, _ b: Double) -> Int {
        let ri = max(0, min(255, Int(r))), gi = max(0, min(255, Int(g))), bi = max(0, min(255, Int(b)))
        let key = (ri >> 2) << 12 | (gi >> 2) << 6 | (bi >> 2)
        if cache[key] >= 0 { return Int(cache[key]) }
        var best = 0, bd = Double.infinity
        let rr = Double(ri | 2), gg = Double(gi | 2), bb = Double(bi | 2)
        for (i, p) in pal.enumerated() { let d = (p.0 - rr) * (p.0 - rr) + (p.1 - gg) * (p.1 - gg) + (p.2 - bb) * (p.2 - bb); if d < bd { bd = d; best = i } }
        cache[key] = Int16(best)
        return best
    }
    var err = [Double](repeating: 0, count: (w + 2) * 2 * 3)
    var raw = [UInt8](); raw.reserveCapacity(n + h)
    for y in 0..<h {
        raw.append(0)
        let cur = (y % 2) * (w + 2) * 3, nxt = ((y + 1) % 2) * (w + 2) * 3
        for i in 0..<((w + 2) * 3) { err[nxt + i] = 0 }
        for x in 0..<w {
            let o = (y * w + x) * 4, e = cur + (x + 1) * 3
            let on = ditherAt?(x, y, (px[o], px[o + 1], px[o + 2])) ?? true
            if ordered > 0 || !on {
                let t = on ? (Double(bayer8[(y & 7) * 8 + (x & 7)]) + 0.5) / 64 - 0.5 : 0
                raw.append(UInt8(nearest(Double(px[o]) + t * ordered, Double(px[o + 1]) + t * ordered, Double(px[o + 2]) + t * ordered)))
                continue
            }
            let r = Double(px[o]) + err[e], g = Double(px[o + 1]) + err[e + 1], b = Double(px[o + 2]) + err[e + 2]
            let idx = nearest(r, g, b)
            raw.append(UInt8(idx))
            if dither > 0 {
                let p = pal[idx]
                let er = (r - p.0) * dither, eg = (g - p.1) * dither, eb = (b - p.2) * dither
                for (dx, dy, f) in [(1, 0, 7.0 / 16), (-1, 1, 3.0 / 16), (0, 1, 5.0 / 16), (1, 1, 1.0 / 16)] {
                    let base = (dy == 0 ? cur : nxt) + (x + 1 + dx) * 3
                    err[base] += er * f; err[base + 1] += eg * f; err[base + 2] += eb * f
                }
            }
        }
    }
    if adaptive {   // per-row filter choice (minimum sum of absolute residuals)
        var filtered = [UInt8](); filtered.reserveCapacity(raw.count)
        let stride = w + 1
        var cand = [[UInt8]](repeating: [UInt8](repeating: 0, count: w), count: 5)
        for y in 0..<h {
            let row = Array(raw[(y * stride + 1)..<(y * stride + 1 + w)])
            let prev = y > 0 ? Array(raw[((y - 1) * stride + 1)..<((y - 1) * stride + 1 + w)]) : [UInt8](repeating: 0, count: w)
            for x in 0..<w {
                let a = x > 0 ? Int(row[x - 1]) : 0, b = Int(prev[x]), c = x > 0 ? Int(prev[x - 1]) : 0, v = Int(row[x])
                let pa = abs(b - c), pb = abs(a - c), pc = abs(a + b - 2 * c)
                let pr = (pa <= pb && pa <= pc) ? a : (pb <= pc ? b : c)
                cand[0][x] = UInt8(v); cand[1][x] = UInt8((v - a) & 255); cand[2][x] = UInt8((v - b) & 255)
                cand[3][x] = UInt8((v - (a + b) / 2) & 255); cand[4][x] = UInt8((v - pr) & 255)
            }
            var best = 0, bs = Int.max
            for f in 0..<5 { let sc = cand[f].reduce(0) { $0 + min(Int($1), 256 - Int($1)) }; if sc < bs { bs = sc; best = f } }
            filtered.append(UInt8(best)); filtered += cand[best]
        }
        raw = filtered
    }
    var zlen = compressBound(uLong(raw.count))
    var zlib = [UInt8](repeating: 0, count: Int(zlen))
    guard compress2(&zlib, &zlen, raw, uLong(raw.count), 9) == Z_OK else { fatalError("deflate \(path)") }
    zlib.removeSubrange(Int(zlen)...)
    var plte = [UInt8]()
    for p in pal { plte += [UInt8(max(0, min(255, p.0.rounded()))), UInt8(max(0, min(255, p.1.rounded()))), UInt8(max(0, min(255, p.2.rounded())))] }
    var out: [UInt8] = [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]
    out += chunk("IHDR", be32(UInt32(w)) + be32(UInt32(h)) + [8, 3, 0, 0, 0])
    out += chunk("sRGB", [0])
    out += chunk("PLTE", plte)
    out += chunk("IDAT", zlib)
    out += chunk("IEND", [])
    try! Data(out).write(to: URL(fileURLWithPath: path))
}
