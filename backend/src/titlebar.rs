use serde::{Deserialize, Serialize};
use specta::Type;

#[cfg(target_os = "linux")]
mod linux;

#[cfg(target_os = "macos")]
mod macos;

#[cfg(target_os = "windows")]
mod windows;

#[derive(Serialize, Deserialize, Type, PartialEq, Eq)]
pub enum TitlebarButton {
    Menu,
    Minimize,
    Maximize,
    Close,
}

#[derive(Deserialize, Serialize, Type, PartialEq, Eq)]
pub struct TitlebarLayout {
    pub left: Vec<TitlebarButton>,
    pub right: Vec<TitlebarButton>,
}

#[tauri::command]
#[specta::specta]
pub fn get_titlebar_layout() -> TitlebarLayout {
    // Platform specific titlebar implementations
    #[cfg(target_os = "linux")]
    return linux::get_titlebar_layout();

    // Platform specific titlebar implementations
    #[cfg(target_os = "macos")]
    return macos::get_titlebar_layout();

    // Platform specific titlebar implementations
    #[cfg(target_os = "windows")]
    return windows::get_titlebar_layout();
}
