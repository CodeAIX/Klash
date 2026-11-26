import AppKit

@_cdecl("klash_status_image")
func klashStatusImage(_ country: UnsafePointer<CChar>, _ status: UnsafePointer<CChar>, _ quality: Bool) -> UnsafeMutableRawPointer {
    let image = KlashStatusImage.make(country: String(cString: country), status: String(cString: status), isHighQuality: quality)
    return Unmanaged.passRetained(image).toOpaque()
}

@_cdecl("klash_tray_menu")
func klashTrayMenu(_ bytes: UnsafePointer<UInt8>, _ count: Int, _ onSelect: @escaping @convention(c) (UInt32) -> Void, _ onClose: @escaping @convention(c) () -> Void) -> UnsafeMutableRawPointer? {
    guard let items = try? JSONSerialization.jsonObject(with: Data(bytes: bytes, count: count)) as? [[String: Any]] else { return nil }
    let menu = TrayMenu(items: items, onSelect: { onSelect(UInt32($0)) }, onClose: onClose)
    return Unmanaged.passRetained(menu).toOpaque()
}
