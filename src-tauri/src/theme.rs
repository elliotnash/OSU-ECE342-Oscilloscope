use specta::Type;
use serde::{Deserialize, Serialize};

#[cfg(target_os = "linux")]
mod linux;

mod default;
 
#[derive(Serialize, Deserialize, Type)]
pub struct Color {
    red: u8,
    green: u8,
    blue: u8,
    alpha: u8,
}

#[derive(Deserialize, Serialize, Type)]
pub struct OscopeTheme {
    pub accent_color: Option<Color>,
}

#[tauri::command]
#[specta::specta]
pub fn get_system_theme() -> OscopeTheme {
    // Platform specific theme implementations
    #[cfg(target_os = "linux")]
    return linux::get_system_theme();

    #[allow(unreachable_code)]
    default::get_system_theme()
}
