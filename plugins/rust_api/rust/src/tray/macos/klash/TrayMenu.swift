import AppKit
#if arch(x86_64)
import CoreGraphics
#endif

final class TrayMenu: NSMenu, NSMenuDelegate {
    private let onSelect: (Int) -> Void
    private let onClose: (() -> Void)?
    private var accessories: [Int: Int] = [:]
    private var contents: [TrayMenuItemView.Content?] = []
    #if arch(x86_64)
    private var monitorTap: CFMachPort?
    private var monitorSource: CFRunLoopSource?
    private weak var pressedMonitor: TrayMenuItemView?

    deinit {
        if let monitorSource { CFRunLoopSourceInvalidate(monitorSource) }
        if let monitorTap { CFMachPortInvalidate(monitorTap) }
    }
    #endif

    init(items: [[String: Any]], onSelect: @escaping (Int) -> Void, onClose: (() -> Void)? = nil) {
        self.onSelect = onSelect
        self.onClose = onClose
        super.init(title: "")
        autoenablesItems = false
        delegate = self
        for entry in items {
            let item = makeItem(entry)
            addItem(item)
            contents.append(item.isSeparatorItem ? nil : TrayMenu.content(entry, item))
        }
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private static func detail(_ entry: [String: Any]) -> String? {
        guard let detail = entry["detail"] as? String, !detail.isEmpty else {
            return nil
        }
        return detail
    }

    private func makeItem(_ entry: [String: Any]) -> NSMenuItem {
        let type = entry["type"] as? String ?? ""
        if type == "separator" {
            return NSMenuItem.separator()
        }

        let item = NSMenuItem()
        item.title = entry["label"] as? String ?? ""
        item.tag = entry["id"] as? Int ?? 0
        if let accessory = entry["accessory"] as? [String: Any], let id = accessory["id"] as? Int {
            accessories[item.tag] = id
            if let label = accessory["label"] as? String {
                item.setAccessibilityCustomActions([NSAccessibilityCustomAction(name: label, handler: { [weak self, weak item] in
                    guard let self = self, let item = item, item.isEnabled else { return false }
                    var root: NSMenu = self
                    while let parent = root.supermenu { root = parent }
                    root.cancelTracking()
                    self.onSelect(id)
                    return true
                })])
            }
        }
        item.isEnabled = entry["enabled"] as? Bool ?? true
        item.state = type == "checkbox" && entry["checked"] as? Bool == true ? .on : .off

        if type == "submenu" {
            let children = entry["items"] as? [[String: Any]] ?? []
            setSubmenu(TrayMenu(items: children, onSelect: onSelect), for: item)
        } else {
            item.target = self
            item.action = #selector(didSelectItem(_:))
        }
        return item
    }

    private static func content(_ entry: [String: Any], _ item: NSMenuItem) -> TrayMenuItemView.Content {
        TrayMenuItemView.Content(
            label: item.title,
            detail: detail(entry),
            checked: item.state == .on,
            enabled: item.isEnabled,
            hasSubmenu: item.hasSubmenu,
            accessory: (entry["accessory"] as? [String: Any]).flatMap { value in
                guard let id = value["id"] as? Int, let label = value["label"] as? String else { return nil }
                return TrayMenuItemView.Accessory(id: id, label: label, selected: value["selected"] as? Bool ?? false)
            }
        )
    }

    // A delay test rebuilds the menu per result; measuring every row then costs ~20x.
    func menuNeedsUpdate(_ menu: NSMenu) {
        guard !contents.isEmpty else {
            return
        }
        for (item, content) in zip(items, contents) {
            if let content = content {
                item.view = TrayMenuItemView(content: content, onAccessory: onSelect)
            }
        }
        contents = []
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if event.modifierFlags.contains(.option), [36, 76].contains(Int(event.keyCode)),
           let item = highlightedItem, item.isEnabled, let id = accessories[item.tag] {
            var root: NSMenu = self
            while let parent = root.supermenu { root = parent }
            root.cancelTracking()
            onSelect(id)
            return true
        }
        return super.performKeyEquivalent(with: event)
    }

    // AppKit does not redraw an item's view when its highlight changes.
    func menu(_ menu: NSMenu, willHighlight item: NSMenuItem?) {
        highlightedItem?.view?.needsDisplay = true
        item?.view?.needsDisplay = true
    }

    func menuDidClose(_ menu: NSMenu) {
        #if arch(x86_64)
        if let monitorSource { CFRunLoopSourceInvalidate(monitorSource) }
        if let monitorTap { CFMachPortInvalidate(monitorTap) }
        monitorSource = nil
        monitorTap = nil
        pressedMonitor = nil
        #endif
        onClose?()
    }

    #if arch(x86_64)
    func menuWillOpen(_ menu: NSMenu) {
        if #available(macOS 14, *) { return }
        guard supermenu == nil, monitorTap == nil,
              items.contains(where: { $0.hasSubmenu && $0.isEnabled && accessories[$0.tag] != nil }) else {
            return
        }
        // Ventura can withhold parent-row clicks while AppKit tracks the submenu.
        let mask = (CGEventMask(1) << CGEventType.leftMouseDown.rawValue)
            | (CGEventMask(1) << CGEventType.leftMouseUp.rawValue)
        guard let tap = CGEvent.tapCreateForPid(
            pid: getpid(), place: .headInsertEventTap, options: .listenOnly,
            eventsOfInterest: mask, callback: { _, type, event, context in
                if let context {
                    let menu = Unmanaged<TrayMenu>.fromOpaque(context).takeUnretainedValue()
                    menu.handleMonitorClick(type, event: event)
                }
                return Unmanaged.passUnretained(event)
            }, userInfo: Unmanaged.passUnretained(self).toOpaque()
        ), let source = CFMachPortCreateRunLoopSource(nil, tap, 0) else { return }
        monitorTap = tap
        monitorSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, CFRunLoopMode(rawValue: RunLoop.Mode.eventTracking.rawValue as CFString))
    }

    private func handleMonitorClick(_ type: CGEventType, event: CGEvent) {
        guard type == .leftMouseDown || type == .leftMouseUp else { return }
        let point = event.unflippedLocation
        if type == .leftMouseDown {
            pressedMonitor = items.lazy.compactMap { $0.view as? TrayMenuItemView }
                .first { $0.hitsSubmenuMonitor(at: point) }
        } else {
            let pressed = pressedMonitor
            pressedMonitor = nil
            if let pressed, pressed.hitsSubmenuMonitor(at: point) {
                pressed.selectAccessory()
            }
        }
    }
    #endif

    @objc private func didSelectItem(_ sender: NSMenuItem) {
        onSelect(sender.tag)
    }
}
