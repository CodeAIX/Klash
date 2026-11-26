import AppKit

// A native item leaves a fixed gap before its submenu arrow, so rows are drawn
// here to keep a detail next to the arrow. The metrics copy the native menu so
// these rows line up with the separators the menu still draws.
final class TrayMenuItemView: NSView {
    struct Accessory {
        let id: Int
        let label: String
        let selected: Bool
    }

    struct Content {
        let label: String
        let detail: String?
        let checked: Bool
        let enabled: Bool
        let hasSubmenu: Bool
        var accessory: Accessory? = nil
    }

    private struct Metrics {
        let height: CGFloat
        let stateX: CGFloat
        let titleX: CGFloat
        let trailing: CGFloat
        let highlightInset: CGFloat
        let highlightRadius: CGFloat
        let font: NSFont

        static let current: Metrics = {
            if #available(macOS 26, *) {
                return Metrics(
                    height: 24,
                    stateX: 12,
                    titleX: 30,
                    trailing: 23,
                    highlightInset: 5,
                    highlightRadius: 8,
                    font: .menuFont(ofSize: 13)
                )
            }
            return Metrics(
                height: 22,
                stateX: 9,
                titleX: 21,
                trailing: 14,
                highlightInset: 5,
                highlightRadius: 4,
                font: .menuFont(ofSize: 0)
            )
        }()
    }

    private static let metrics = Metrics.current
    private static let detailGap: CGFloat = 20
    private static let arrowGap: CGFloat = 6
    private static let checkGap: CGFloat = 3

    private static let detailFont = NSFont.monospacedDigitSystemFont(
        ofSize: metrics.font.pointSize,
        weight: .regular
    )

    private static let checkmark = symbol("checkmark", weight: .medium)
    private static let arrow = symbol("chevron.right", weight: .semibold)

    private let content: Content
    private let onAccessory: (Int) -> Void
    private var accessoryButton: NSButton?
    private static let accessoryWidth: CGFloat = 28

    init(content: Content, onAccessory: @escaping (Int) -> Void = { _ in }) {
        self.onAccessory = onAccessory
        self.content = content
        let metrics = TrayMenuItemView.metrics
        var width = metrics.titleX + TrayMenuItemView.width(content.label) + metrics.trailing
        if let detail = content.detail {
            width += TrayMenuItemView.detailGap + TrayMenuItemView.width(detail, font: TrayMenuItemView.detailFont)
        }
        if content.hasSubmenu {
            width += TrayMenuItemView.arrowGap + TrayMenuItemView.arrow.size.width
        }
        if content.accessory != nil { width += TrayMenuItemView.accessoryWidth }
        super.init(frame: NSRect(x: 0, y: 0, width: ceil(width), height: metrics.height))
        autoresizingMask = [.width]
        setAccessibilityElement(true)
        setAccessibilityRole(.menuItem)
        setAccessibilityLabel([content.label, content.detail].compactMap { $0 }.joined(separator: ", "))
        setAccessibilityEnabled(content.enabled)
        if let accessory = content.accessory {
            let button = NSButton(image: TrayMenuItemView.monitorSymbol(accessory.selected), target: self, action: #selector(selectAccessory))
            button.isBordered = false
            button.imagePosition = .imageOnly
            button.toolTip = accessory.label + " (⌥↩)"
            button.setAccessibilityLabel(accessory.label)
            button.setAccessibilityValue(accessory.selected ? 1 : 0)
            button.isEnabled = content.enabled
            accessoryButton = button
            addSubview(button)
            setAccessibilityChildren([button])
            setAccessibilityCustomActions([NSAccessibilityCustomAction(name: accessory.label, target: self, selector: #selector(accessibleAccessory))])
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var isFlipped: Bool {
        true
    }

    private var isHighlighted: Bool {
        content.enabled && enclosingMenuItem?.isHighlighted == true
    }

    override func draw(_ dirtyRect: NSRect) {
        let metrics = TrayMenuItemView.metrics
        let highlighted = isHighlighted
        if highlighted {
            NSColor.controlAccentColor.setFill()
            NSBezierPath(
                roundedRect: bounds.insetBy(dx: metrics.highlightInset, dy: 0),
                xRadius: metrics.highlightRadius,
                yRadius: metrics.highlightRadius
            ).fill()
        }

        let primary: NSColor = highlighted
            ? .selectedMenuItemTextColor
            : content.enabled ? .labelColor : .tertiaryLabelColor
        if content.checked {
            drawSymbol(
                TrayMenuItemView.checkmark,
                x: metrics.stateX,
                color: primary,
                maxWidth: metrics.titleX - metrics.stateX - TrayMenuItemView.checkGap
            )
        }

        var trailingX = bounds.width - metrics.trailing
        if content.hasSubmenu {
            let arrowWidth = TrayMenuItemView.arrow.size.width
            drawSymbol(TrayMenuItemView.arrow, x: trailingX - arrowWidth, color: primary)
            trailingX -= arrowWidth + TrayMenuItemView.arrowGap
        }

        if let detail = content.detail {
            let color: NSColor = highlighted
                ? .selectedMenuItemTextColor
                : content.enabled ? .secondaryLabelColor : .tertiaryLabelColor
            let detailWidth = TrayMenuItemView.width(detail, font: TrayMenuItemView.detailFont)
            drawText(detail, x: trailingX - detailWidth, width: detailWidth, color: color, font: TrayMenuItemView.detailFont)
            trailingX -= detailWidth + TrayMenuItemView.detailGap
        }

        if let button = accessoryButton {
            button.frame = NSRect(x: trailingX - 24, y: 0, width: 24, height: bounds.height)
            button.contentTintColor = primary
            button.alphaValue = highlighted || content.accessory?.selected == true ? 1 : 0
            trailingX -= TrayMenuItemView.accessoryWidth
        }
        drawText(content.label, x: metrics.titleX, width: trailingX - metrics.titleX, color: primary, font: metrics.font)
    }

    #if arch(x86_64)
    // AppKit can ask for click-through while the status menu window is inactive.
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        content.enabled && !content.hasSubmenu
    }
    #endif

    override func mouseUp(with event: NSEvent) {
        if content.enabled, let button = accessoryButton, button.frame.contains(convert(event.locationInWindow, from: nil)) {
            selectAccessory()
            return
        }
        guard content.enabled, !content.hasSubmenu, let item = enclosingMenuItem,
              let action = item.action else {
            return
        }
        var root = item.menu
        while let parent = root?.supermenu {
            root = parent
        }
        root?.cancelTracking()
        NSApp.sendAction(action, to: item.target, from: item)
    }

    @objc private func accessibleAccessory() -> Bool {
        guard content.enabled, content.accessory != nil else { return false }
        selectAccessory()
        return true
    }

    #if arch(x86_64)
    func hitsSubmenuMonitor(at screenPoint: NSPoint) -> Bool {
        guard content.enabled, content.hasSubmenu, let window, window.isVisible,
              let button = accessoryButton, button.alphaValue > 0 else { return false }
        let point = convert(window.convertPoint(fromScreen: screenPoint), from: nil)
        return visibleRect.contains(point) && button.frame.contains(point)
    }
    #endif

    @objc func selectAccessory() {
        guard content.enabled, let accessory = content.accessory else { return }
        var root = enclosingMenuItem?.menu
        while let parent = root?.supermenu { root = parent }
        root?.cancelTracking()
        onAccessory(accessory.id)
    }

    private static func monitorSymbol(_ selected: Bool) -> NSImage {
        let image = NSImage(size: NSSize(width: 16, height: 16), flipped: false) { _ in
            NSColor.black.setStroke()
            NSColor.black.setFill()
            let ring = NSBezierPath(ovalIn: NSRect(x: 3.5, y: 3.5, width: 9, height: 9))
            ring.lineWidth = 1.2
            ring.stroke()
            let cross = NSBezierPath()
            for (a, b) in [(NSPoint(x: 8,y: 0),NSPoint(x: 8,y: 4)), (NSPoint(x: 8,y: 12),NSPoint(x: 8,y: 16)), (NSPoint(x: 0,y: 8),NSPoint(x: 4,y: 8)), (NSPoint(x: 12,y: 8),NSPoint(x: 16,y: 8))] {
                cross.move(to: a); cross.line(to: b)
            }
            cross.lineWidth = 1.2
            cross.stroke()
            if selected { NSBezierPath(ovalIn: NSRect(x: 5.5, y: 5.5, width: 5, height: 5)).fill() }
            return true
        }
        image.isTemplate = true
        return image
    }

    private func drawText(_ text: String, x: CGFloat, width: CGFloat, color: NSColor, font: NSFont) {
        let style = NSMutableParagraphStyle()
        style.lineBreakMode = .byTruncatingTail
        let height = ceil(font.ascender - font.descender)
        let rect = NSRect(x: x, y: (bounds.height - height) / 2, width: max(width, 0), height: height)
        (text as NSString).draw(
            with: rect,
            options: [.usesLineFragmentOrigin, .truncatesLastVisibleLine],
            attributes: [.font: font, .foregroundColor: color, .paragraphStyle: style]
        )
    }

    // Before macOS 26 the title starts closer to the state column than a
    // checkmark at the menu font's size is wide, so the mark shrinks to fit.
    private func drawSymbol(_ image: NSImage, x: CGFloat, color: NSColor, maxWidth: CGFloat = .infinity) {
        let scale = min(1, maxWidth / image.size.width)
        let size = NSSize(width: image.size.width * scale, height: image.size.height * scale)
        let rect = NSRect(
            x: x,
            y: ((bounds.height - size.height) / 2).rounded(),
            width: size.width,
            height: size.height
        )
        let tinted = NSImage(size: size, flipped: false) { bounds in
            image.draw(in: bounds)
            color.setFill()
            bounds.fill(using: .sourceAtop)
            return true
        }
        tinted.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1, respectFlipped: true, hints: nil)
    }

    private static func width(_ text: String, font: NSFont = metrics.font) -> CGFloat {
        ceil((text as NSString).size(withAttributes: [.font: font]).width)
    }

    private static func symbol(_ name: String, weight: NSFont.Weight) -> NSImage {
        let configuration = NSImage.SymbolConfiguration(pointSize: metrics.font.pointSize, weight: weight)
        return NSImage(systemSymbolName: name, accessibilityDescription: nil)?
            .withSymbolConfiguration(configuration) ?? NSImage()
    }
}
