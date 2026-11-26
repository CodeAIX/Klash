use crate::api::tray::{TrayBadge, TrayItem, TraySignalKind};
use objc2::rc::Retained;
use objc2_app_kit::{NSImage, NSMenu};
use std::ffi::CString;

unsafe extern "C" {
    fn klash_status_image(
        country: *const std::ffi::c_char,
        status: *const std::ffi::c_char,
        quality: bool,
    ) -> *mut NSImage;
    fn klash_tray_menu(
        bytes: *const u8,
        count: usize,
        on_select: extern "C" fn(u32),
        on_close: extern "C" fn(),
    ) -> *mut NSMenu;
}

pub(super) fn image(badge: &TrayBadge) -> Option<Retained<NSImage>> {
    let country = CString::new(badge.country.as_str()).ok()?;
    let status = CString::new(badge.status.as_str()).ok()?;
    unsafe {
        Retained::from_raw(klash_status_image(
            country.as_ptr(),
            status.as_ptr(),
            badge.high_quality,
        ))
    }
}

pub(super) fn has_accessory(items: &[TrayItem]) -> bool {
    items
        .iter()
        .any(|item| item.accessory.is_some() || has_accessory(&item.items))
}

pub(super) fn menu(items: &[TrayItem]) -> Result<Retained<NSMenu>, String> {
    let bytes = serde_json::to_vec(items).map_err(|error| error.to_string())?;
    unsafe {
        Retained::from_raw(klash_tray_menu(
            bytes.as_ptr(),
            bytes.len(),
            selected,
            closed,
        ))
    }
    .ok_or_else(|| "Klash menu payload could not be decoded".into())
}

extern "C" fn selected(id: u32) {
    super::super::emit(TraySignalKind::ItemSelected, id);
}

extern "C" fn closed() {
    super::close_menu();
}
