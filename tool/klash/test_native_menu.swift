import AppKit
let app = NSApplication.shared
app.setActivationPolicy(.prohibited)
var received: [Int] = []
let menu = TrayMenu(items: [
    ["id": 100, "type": "submenu", "label": "手动", "detail": "181", "accessory": ["id": 101, "label": "监测手动", "selected": true], "items": [["id": 102,"type": "checkbox", "label": "自动", "checked": true, "detail": "181", "accessory": ["id":103,"label":"监测自动","selected":false]]]],
    ["id": 104,"type":"checkbox","label":"日本节点","checked":false,"detail":"168","accessory":["id":105,"label":"监测日本节点","selected":false]]
], onSelect: { received.append($0) })
precondition(menu.items[0].accessibilityCustomActions()?.count == 1)
menu.menuNeedsUpdate(menu)
let child = menu.items[0].submenu as! TrayMenu
child.menuNeedsUpdate(child)
let views = [menu.items[0].view!, child.items[0].view!, menu.items[1].view!]
precondition(!views[0].acceptsFirstMouse(for: nil))
#if arch(x86_64)
precondition(views[1].acceptsFirstMouse(for: nil))
precondition(views[2].acceptsFirstMouse(for: nil))
#else
precondition(!views[1].acceptsFirstMouse(for: nil))
precondition(!views[2].acceptsFirstMouse(for: nil))
#endif
for (index, view) in views.enumerated() {
    let image = NSImage(size:view.frame.size)
    image.lockFocus()
    view.draw(view.bounds)
    image.unlockFocus()
    let button = view.subviews.compactMap { $0 as? NSButton }.first!
    precondition(button.frame.width == 24 && button.frame.maxX < view.bounds.maxX)
    precondition(button.accessibilityLabel()?.hasPrefix("监测") == true)
    precondition(view.accessibilityCustomActions()?.count == 1)
    button.performClick(nil)
    precondition(received.last == [101,103,105][index])
}
precondition(!received.contains(100) && !received.contains(102) && !received.contains(104))
precondition(menu.items[0].hasSubmenu && child.items[0].state == .on)
let node = menu.items[1]
NSApp.sendAction(node.action!, to: node.target, from: node)
precondition(received.last == 104)

print("PASS: group/subgroup/node accessory controls, geometry, accessibility and independent primary selection")
