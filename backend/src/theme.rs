use serde::{Deserialize, Serialize};
use specta::Type;

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

impl Color {
    pub fn with_brightness(&self, amount: f32) -> Color {
        Color {
            red: (self.red as f32 * amount) as u8,
            green: (self.green as f32 * amount) as u8,
            blue: (self.blue as f32 * amount) as u8,
            alpha: self.alpha,
        }
    }
}

#[derive(Deserialize, Serialize, Type)]
pub struct OscopeTheme {
    pub primary: Option<Color>,
    pub primary_fg: Option<Color>,
    pub bg: Option<Color>,
    pub fg: Option<Color>,
    pub secondary: Option<Color>,
    pub secondary_fg: Option<Color>,
    pub ring: Option<Color>,
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
