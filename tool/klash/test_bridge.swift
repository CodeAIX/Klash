import AppKit

let app = NSApplication.shared
app.setActivationPolicy(.prohibited)
var selected: UInt32 = 0
var closed = false
func didSelect(_ id: UInt32) { selected = id }
func didClose() { closed = true }
let payload = Data("""
[{"id":1024,"type":"submenu","label":"Manual","detail":null,"enabled":true,"checked":false,"accessory":{"id":1025,"label":"Monitor Manual","selected":true},"items":[{"id":1026,"type":"checkbox","label":"Japan","detail":"42","enabled":true,"checked":true,"accessory":{"id":1027,"label":"Monitor Japan","selected":false},"items":[]}]}]
""".utf8)
let pointer = payload.withUnsafeBytes { bytes in
    klashTrayMenu(bytes.bindMemory(to: UInt8.self).baseAddress!, bytes.count, didSelect, didClose)
}!
let menu = Unmanaged<TrayMenu>.fromOpaque(pointer).takeRetainedValue()
menu.menuNeedsUpdate(menu)
precondition(menu.items.count == 1 && menu.items[0].hasSubmenu)
let view = menu.items[0].view!
view.subviews.compactMap { $0 as? NSButton }.first!.performClick(nil)
precondition(selected == 1025)
let child = menu.items[0].submenu as! TrayMenu
child.menuNeedsUpdate(child)
precondition(child.items[0].state == .on)
child.items[0].view!.subviews.compactMap { $0 as? NSButton }.first!.performClick(nil)
precondition(selected == 1027)
menu.menuDidClose(menu)
precondition(closed)
let imagePointer = "JP".withCString { country in
    "tun".withCString { status in klashStatusImage(country, status, true) }
}
let image = Unmanaged<NSImage>.fromOpaque(imagePointer).takeRetainedValue()
precondition(image.size == NSSize(width: 26, height: 18) && !image.isTemplate)
print("PASS: typed payload C ABI, accessory callbacks, close callback and retained badge image")
