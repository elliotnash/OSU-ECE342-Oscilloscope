use crate::theme::OscopeTheme;

pub fn get_system_theme() -> OscopeTheme {
    OscopeTheme {
        accent_bg: None,
        accent_fg: None,
        window_bg: None,
        window_fg: None,
    }
}
