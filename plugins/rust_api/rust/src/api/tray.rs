use crate::frb_generated::StreamSink;
use crate::tray;
use flutter_rust_bridge::for_generated::SseCodec;
use flutter_rust_bridge::frb;
use serde::Serialize;

#[derive(Debug, Clone, Copy, PartialEq, Eq, Serialize)]
#[serde(rename_all = "lowercase")]
pub enum TrayItemKind {
    Action,
    Checkbox,
    Submenu,
    Separator,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize)]
pub struct TrayItem {
    pub id: u32,
    #[serde(rename = "type")]
    pub kind: TrayItemKind,
    pub label: String,
    pub detail: Option<String>,
    pub enabled: bool,
    pub checked: bool,
    pub items: Vec<TrayItem>,
    pub accessory: Option<TrayAccessory>,
}

#[derive(Debug, Clone, PartialEq, Eq, Serialize)]
pub struct TrayAccessory {
    pub id: u32,
    pub label: String,
    pub selected: bool,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct TrayBadge {
    pub country: String,
    pub status: String,
    pub high_quality: bool,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum TrayIconPlacement {
    Leading,
    Trailing,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct TrayImage {
    pub path: String,
    pub pngs: Vec<Vec<u8>>,
    pub template: bool,
    pub size: u32,
    pub placement: TrayIconPlacement,
    pub badge: Option<TrayBadge>,
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub struct TrayContent {
    pub id: String,
    pub image: TrayImage,
    pub tool_tip: String,
    pub title: String,
    pub menu: Vec<TrayItem>,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum TraySignalKind {
    IconActivated,
    MenuRequested,
    ItemSelected,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct TraySignal {
    pub kind: TraySignalKind,
    pub item_id: u32,
}

#[frb]
pub fn tray_signals(sink: StreamSink<TraySignal, SseCodec>) {
    tray::listen(sink);
}

#[frb(sync)]
pub fn show_tray(content: TrayContent) -> Result<(), String> {
    tray::show(content)
}

#[frb(sync)]
pub fn set_tray_title(title: String) -> bool {
    tray::set_title(title)
}

#[frb(sync)]
pub fn hide_tray() {
    tray::hide();
}

#[frb(sync)]
pub fn open_tray_menu() -> bool {
    tray::open_menu()
}
