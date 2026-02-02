use crate::theme::OscopeTheme;

pub fn get_system_theme() -> OscopeTheme {
    OscopeTheme {
        primary: None,
        primary_fg: None,
        bg: None,
        fg: None,
        secondary: None,
        secondary_fg: None,
    }
}
