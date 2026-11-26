import AppKit
import CoreText

final class KlashStatusImage {
    static func make(country: String, status: String, isHighQuality: Bool = false, glyphs: KlashStatusGlyphs = .shared) -> NSImage {
        let colors: [String: NSColor] = [
            "tun": .systemGreen, "route": .systemBlue, "entry": .systemOrange,
            "unknown": .systemGray, "stopped": .systemGray,
        ]
        let characters = Array(country.utf16)
        let validCountry = characters.count == 2 && characters.allSatisfy { (65...90).contains($0) }
        let label = status == "failed" ? "F" : (validCountry ? country : "--")
        let size = NSSize(width: 26, height: 18)
        let labelPath = status == "stopped" ? nil : glyphs.path(for: label, in: size)
        let image = NSImage(size: size, flipped: false) { rect in
            let failed = status == "failed"
            let background = failed ? NSColor.systemGray.withAlphaComponent(0.18) :
                (colors[status] ?? .systemGray)
            background.setFill()
            outline(rect.insetBy(dx: 0, dy: 1)).fill()
            if status == "stopped" {
                drawLogo(in: rect)
                return true
            }
            guard let path = labelPath else {
                drawLogo(in: rect)
                return true
            }
            guard let context = NSGraphicsContext.current?.cgContext else { return false }
            let foreground = failed ? NSColor.systemRed : (isHighQuality ? NSColor.white : NSColor.black)
            context.setFillColor(foreground.cgColor)
            context.setStrokeColor(foreground.cgColor)
            // Outlines need optical weight compensation for the original small-text rasterization.
            context.setLineWidth(0.3)
            context.setLineJoin(.round)
            context.addPath(path)
            context.drawPath(using: .fillStroke)
            return true
        }
        image.isTemplate = false
        return image
    }

    private static func outline(_ rect: NSRect) -> NSBezierPath {
        let radius: CGFloat = 6
        let path = NSBezierPath()
        path.move(to: NSPoint(x: rect.minX + radius, y: rect.minY))
        path.line(to: NSPoint(x: rect.maxX - radius, y: rect.minY))
        path.curve(to: NSPoint(x: rect.maxX, y: rect.minY + radius),
                   controlPoint1: NSPoint(x: rect.maxX, y: rect.minY),
                   controlPoint2: NSPoint(x: rect.maxX, y: rect.minY))
        path.line(to: NSPoint(x: rect.maxX, y: rect.maxY - radius))
        path.curve(to: NSPoint(x: rect.maxX - radius, y: rect.maxY),
                   controlPoint1: NSPoint(x: rect.maxX, y: rect.maxY),
                   controlPoint2: NSPoint(x: rect.maxX, y: rect.maxY))
        path.line(to: NSPoint(x: rect.minX + radius, y: rect.maxY))
        path.curve(to: NSPoint(x: rect.minX, y: rect.maxY - radius),
                   controlPoint1: NSPoint(x: rect.minX, y: rect.maxY),
                   controlPoint2: NSPoint(x: rect.minX, y: rect.maxY))
        path.line(to: NSPoint(x: rect.minX, y: rect.minY + radius))
        path.curve(to: NSPoint(x: rect.minX + radius, y: rect.minY),
                   controlPoint1: NSPoint(x: rect.minX, y: rect.minY),
                   controlPoint2: NSPoint(x: rect.minX, y: rect.minY))
        path.close()
        return path
    }

    private static func drawLogo(in rect: NSRect) {
        // Geometry shared with the upstream assets_source/images/icon/glyph.svg.
        let scale: CGFloat = 14 / 240
        func point(_ x: CGFloat, _ y: CGFloat) -> NSPoint {
            NSPoint(x: rect.midX - 7 + x * scale, y: rect.midY + 7 - y * scale)
        }
        NSColor.white.setStroke()
        let bars = NSBezierPath()
        bars.lineWidth = 46.32 * scale
        bars.lineCapStyle = .round
        bars.move(to: point(59.68, 100.95))
        bars.line(to: point(180.02, 31.47))
        bars.move(to: point(90.56, 154.43))
        bars.line(to: point(150.74, 119.69))
        bars.stroke()
        NSColor.white.setFill()
        let center = point(121.44, 207.92)
        let radius = 23.16 * scale
        NSBezierPath(ovalIn: NSRect(x: center.x - radius, y: center.y - radius,
                                   width: radius * 2, height: radius * 2)).fill()
    }
}

final class KlashStatusGlyphs {
    static let shared = KlashStatusGlyphs(font: NSFont.monospacedSystemFont(ofSize: 12.5, weight: .heavy) as CTFont)

    private struct Glyph {
        let path: CGPath
        let advance: CGFloat
    }

    private let glyphs: [UInt16: Glyph]
    private let lineHeight: CGFloat
    private let descent: CGFloat

    init(font: CTFont?) {
        guard let font = font else {
            glyphs = [:]
            lineHeight = 0
            descent = 0
            return
        }
        lineHeight = ceil(CTFontGetAscent(font) + CTFontGetDescent(font) + CTFontGetLeading(font))
        // NSString aligns this baseline to whole points; no text layout is needed to match it.
        descent = ceil(CTFontGetDescent(font))
        var prepared: [UInt16: Glyph] = [:]
        for scalar in Array(UInt16(65)...UInt16(90)) + [45] {
            var character = scalar
            var glyph: CGGlyph = 0
            guard CTFontGetGlyphsForCharacters(font, &character, &glyph, 1),
                  let path = CTFontCreatePathForGlyph(font, glyph, nil) else { continue }
            var advance = CGSize.zero
            CTFontGetAdvancesForGlyphs(font, .horizontal, &glyph, &advance, 1)
            guard advance.width.isFinite, advance.width > 0 else { continue }
            prepared[scalar] = Glyph(path: path, advance: advance.width)
        }
        glyphs = prepared
    }

    func path(for label: String, in size: NSSize) -> CGPath? {
        let characters = Array(label.utf16)
        let selected = characters.compactMap { glyphs[$0] }
        guard !selected.isEmpty, selected.count == characters.count else { return nil }
        let path = CGMutablePath()
        var x = (size.width - selected.reduce(0) { $0 + $1.advance }) / 2
        let y = (size.height - lineHeight) / 2 + descent
        for glyph in selected {
            path.addPath(glyph.path, transform: CGAffineTransform(translationX: x, y: y))
            x += glyph.advance
        }
        return path
    }
}
