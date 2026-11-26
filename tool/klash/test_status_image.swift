import AppKit
import CoreText

let app = NSApplication.shared
app.setActivationPolicy(.prohibited)

func bitmap(_ image: NSImage, scale: Int) -> NSBitmapImageRep {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 26 * scale, pixelsHigh: 18 * scale,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    rep.size = NSSize(width: 26, height: 18)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    image.draw(in: NSRect(x: 0, y: 0, width: 26, height: 18))
    NSGraphicsContext.restoreGraphicsState()
    return rep
}

func bytes(_ rep: NSBitmapImageRep) -> Data {
    Data(bytes: rep.bitmapData!, count: rep.bytesPerRow * rep.pixelsHigh)
}

func color(_ rep: NSBitmapImageRep, _ x: Int, _ y: Int) -> NSColor {
    rep.colorAt(x: x, y: y)!.usingColorSpace(.deviceRGB)!
}

func reference(_ label: String, scale: Int) -> NSBitmapImageRep {
    let image = NSImage(size: NSSize(width: 26, height: 18), flipped: false) { rect in
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: 12.5, weight: .heavy),
            .foregroundColor: NSColor.white,
        ]
        let text = label as NSString
        let measured = text.size(withAttributes: attributes)
        text.draw(at: NSPoint(x: (rect.width - measured.width) / 2, y: (rect.height - measured.height) / 2), withAttributes: attributes)
        return true
    }
    return bitmap(image, scale: scale)
}

func ink(_ rep: NSBitmapImageRep, scale: Int, reference: Bool, failed: Bool = false) -> (area: Double, y: Double) {
    let background = color(rep, scale, 9 * scale)
    var area = 0.0
    var moment = 0.0
    for y in 0..<rep.pixelsHigh {
        for x in 0..<rep.pixelsWide {
            let pixel = color(rep, x, y)
            let value: Double
            if reference {
                value = Double(pixel.alphaComponent)
            } else if failed {
                value = max(0, Double((pixel.alphaComponent - background.alphaComponent) / (1 - background.alphaComponent)))
            } else {
                value = max(0, Double((pixel.redComponent - background.redComponent) / (1 - background.redComponent)))
            }
            area += value
            moment += value * Double(y)
        }
    }
    return (area / Double(scale * scale), moment / area / Double(scale))
}

let size = NSSize(width: 26, height: 18)
let missing = KlashStatusGlyphs(font: nil)
precondition(missing.path(for: "US", in: size) == nil)
for label in ["US", "CN", "JP", "GB", "DE", "WW", "II", "--", "F"] {
    for scale in [1, 2, 3] {
        let failed = label == "F"
        let actual = bitmap(KlashStatusImage.make(country: label, status: failed ? "failed" : "tun", isHighQuality: true), scale: scale)
        let before = ink(reference(label, scale: scale), scale: scale, reference: true)
        let after = ink(actual, scale: scale, reference: false, failed: failed)
        let ratio = after.area / before.area
        let shift = abs(after.y - before.y)
        print("calibration \(label) @\(scale)x: inkRatio=\(ratio), baselineShift=\(shift)pt")
        precondition((0.80...1.20).contains(ratio) && shift < 0.5)
    }
}

let invalid = ["", "us", "USA", "U", "US\n", "🇺🇸", "中国", "\u{0000}", " US"]
let expected = bytes(bitmap(KlashStatusImage.make(country: "--", status: "tun"), scale: 2))
for label in invalid {
    precondition(bytes(bitmap(KlashStatusImage.make(country: label, status: "tun"), scale: 2)) == expected)
}
let stopped = bitmap(KlashStatusImage.make(country: "US", status: "stopped"), scale: 2)
let fallback = bitmap(KlashStatusImage.make(country: "US", status: "stopped", glyphs: missing), scale: 2)
precondition(bytes(stopped) == bytes(fallback))
let degraded = bitmap(KlashStatusImage.make(country: "US", status: "tun", glyphs: missing), scale: 2)
precondition(bytes(degraded) != expected)

for quality in [false, true] {
    let rep = bitmap(KlashStatusImage.make(country: "US", status: "tun", isHighQuality: quality), scale: 2)
    var matchingPixels = 0
    for y in 0..<36 { for x in 0..<52 {
        let c = color(rep, x, y)
        if c.alphaComponent > 0.99 {
            if quality && min(c.redComponent, c.greenComponent, c.blueComponent) > 0.9 { matchingPixels += 1 }
            if !quality && max(c.redComponent, c.greenComponent, c.blueComponent) < 0.1 { matchingPixels += 1 }
        }
    } }
    precondition(matchingPixels > 30)
}
let errorRep = bitmap(KlashStatusImage.make(country: "US", status: "failed"), scale: 2)
var redPixels = 0
for y in 0..<36 { for x in 0..<52 {
    let c = color(errorRep, x, y)
    if c.redComponent > 0.8 && c.greenComponent < 0.4 && c.blueComponent < 0.4 { redPixels += 1 }
} }
precondition(redPixels > 30)

let reused = KlashStatusImage.make(country: "US", status: "tun", isHighQuality: true)
reused.cacheMode = .never
for name in [NSAppearance.Name.aqua, .darkAqua, .aqua] {
    NSAppearance(named: name)!.performAsCurrentDrawingAppearance {
        for scale in [1, 2, 3, 2, 1] {
            precondition(bitmap(reused, scale: scale).bitmapData != nil)
        }
    }
}

var draws = 0
let countries = (0..<26).flatMap { a in (0..<26).map { b in String(UnicodeScalar(65 + a)!) + String(UnicodeScalar(65 + b)!) } } + invalid
for name in [NSAppearance.Name.aqua, .darkAqua] {
    NSAppearance(named: name)!.performAsCurrentDrawingAppearance {
        for status in ["tun", "route", "entry", "unknown", "stopped", "failed", "invalid"] {
            for quality in [false, true] {
                for scale in [1, 2, 3] {
                    for country in countries {
                        autoreleasepool {
                            let image = KlashStatusImage.make(country: country, status: status, isHighQuality: quality)
                            precondition(image.size == size && !image.isTemplate)
                            let rep = bitmap(image, scale: scale)
                            precondition(color(rep, 0, 0).alphaComponent == 0)
                            let background = color(rep, scale, 9 * scale)
                            if status != "failed" { precondition(background.alphaComponent > 0.99) }
                            let expectedColor: NSColor
                            switch status {
                            case "tun": expectedColor = .systemGreen
                            case "route": expectedColor = .systemBlue
                            case "entry": expectedColor = .systemOrange
                            default: expectedColor = .systemGray
                            }
                            if status != "failed" {
                                let resolved = expectedColor.usingColorSpace(.deviceRGB)!
                                precondition(abs(background.redComponent - resolved.redComponent) < 0.02)
                                precondition(abs(background.greenComponent - resolved.greenComponent) < 0.02)
                                precondition(abs(background.blueComponent - resolved.blueComponent) < 0.02)
                            }
                            draws += 1
                        }
                    }
                }
            }
        }
    }
}
print("PASS: \(draws) status draws; calibrated weight/baseline, states, colors, validation, scales, appearance and missing-glyph fallback")
