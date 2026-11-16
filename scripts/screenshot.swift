// screenshot.swift - helper of scripts/screenshot.sh (macOS only).
//
//   swift screenshot.swift window
//       Prints the window id of the Connect IQ simulator (for screencapture -l).
//   swift screenshot.swift crop <window.png> <device profile dir> <device> <out.png>
//       Cuts the display out of a window capture, using the display location from the device profile's
//       simulator.json, and writes it at the display's native size. Round displays get transparent corners.
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

func fail(_ message: String) -> Never {
    FileHandle.standardError.write(("ERROR: " + message + "\n").data(using: .utf8)!)
    exit(1)
}

func loadImage(_ path: String) -> CGImage {
    guard let source = CGImageSourceCreateWithURL(URL(fileURLWithPath: path) as CFURL, nil),
          let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
        fail("cannot read image \(path)")
    }
    return image
}

func findSimulatorWindow() {
    let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly], kCGNullWindowID) as? [[String: Any]] ?? []
    for window in windows {
        let name = window[kCGWindowName as String] as? String ?? ""
        let layer = window[kCGWindowLayer as String] as? Int ?? -1
        if layer == 0 && name.contains("CIQ Simulator"), let id = window[kCGWindowNumber as String] as? Int {
            print(id)
            return
        }
    }
    fail("no simulator window on screen (start it with scripts/run.sh; the terminal needs the Screen Recording permission to see window names)")
}

func crop(windowPath: String, profileDir: String, device: String, outPath: String) {
    let jsonURL = URL(fileURLWithPath: profileDir).appendingPathComponent("simulator.json")
    guard let data = try? Data(contentsOf: jsonURL),
          let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
          let display = json["display"] as? [String: Any],
          let location = display["location"] as? [String: Any],
          let dx = location["x"] as? Double, let dy = location["y"] as? Double,
          let dw = location["width"] as? Double, let dh = location["height"] as? Double else {
        fail("no display location in \(jsonURL.path)")
    }
    let round = (display["shape"] as? String ?? "round") == "round"
    let deviceImageName = json["image"] as? String ?? "\(device).png"
    let deviceImage = loadImage(URL(fileURLWithPath: profileDir).appendingPathComponent(deviceImageName).path)
    let window = loadImage(windowPath)

    // The window shows the device picture scaled by the screen factor (1 or 2), between the title bar and the
    // status bar of equal height (observed with SDK 9.3.0).
    let scale = Double(window.width) / Double(deviceImage.width)
    if abs(scale - scale.rounded()) > 0.02 {
        fail("the simulator window does not show \(device) (scale \(scale)); load that device with scripts/run.sh \(device)")
    }
    let top = (Double(window.height) - Double(deviceImage.height) * scale) / 2.0

    let width = Int(dw), height = Int(dh)
    let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
    guard let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                                  space: colorSpace, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
        fail("cannot create the output image")
    }
    context.interpolationQuality = .high
    if round {
        // 1 px inset: the edge pixels of the capture still show the bezel of the device picture.
        context.addEllipse(in: CGRect(x: 0, y: 0, width: dw, height: dh).insetBy(dx: 1, dy: 1))
        context.clip()
    }
    // Map the display rectangle of the window capture onto the output; CoreGraphics counts y from the bottom.
    let k = 1.0 / scale
    let windowBottomOfDisplay = Double(window.height) - (top + (dy + dh) * scale)
    context.draw(window, in: CGRect(x: -dx * scale * k, y: -windowBottomOfDisplay * k,
                                    width: Double(window.width) * k, height: Double(window.height) * k))
    guard let output = context.makeImage(),
          let destination = CGImageDestinationCreateWithURL(URL(fileURLWithPath: outPath) as CFURL,
                                                            UTType.png.identifier as CFString, 1, nil) else {
        fail("cannot write \(outPath)")
    }
    CGImageDestinationAddImage(destination, output, nil)
    if !CGImageDestinationFinalize(destination) {
        fail("cannot write \(outPath)")
    }
}

let args = CommandLine.arguments
if args.count == 2 && args[1] == "window" {
    findSimulatorWindow()
} else if args.count == 6 && args[1] == "crop" {
    crop(windowPath: args[2], profileDir: args[3], device: args[4], outPath: args[5])
} else {
    fail("usage: screenshot.swift window | crop <window.png> <device profile dir> <device> <out.png>")
}
