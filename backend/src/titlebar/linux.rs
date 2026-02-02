use gio::prelude::SettingsExt;
use gio::Settings;

use crate::titlebar::{TitlebarButton, TitlebarLayout};

/// Parse a dconf button string into a TitlebarButton
fn parse_button(button: &str) -> Option<TitlebarButton> {
    match button {
        "menu" => Some(TitlebarButton::Menu),
        "minimize" => Some(TitlebarButton::Minimize),
        "maximize" => Some(TitlebarButton::Maximize),
        "close" => Some(TitlebarButton::Close),
        _ => None,
    }
}

/// Get the titlebar layout from dconf
pub fn get_titlebar_layout() -> TitlebarLayout {
    let settings = Settings::new("org.gnome.desktop.wm.preferences");

    let has_button_layout = settings
        .settings_schema()
        .is_some_and(|schema| schema.has_key("button-layout"));

    if has_button_layout {
        let layout = settings.string("button-layout").to_string();

        let mut left_buttons = vec![];
        let mut right_buttons = vec![];

        // Left of : corresponds to left buttons, right of : corresponds to right buttons
        let mut split = layout.split(":");
        if let Some(left) = split.next() {
            for button in left.split(",") {
                if let Some(button) = parse_button(button) {
                    left_buttons.push(button);
                }
            }
        }
        if let Some(right) = split.next() {
            for button in right.split(",") {
                if let Some(button) = parse_button(button) {
                    right_buttons.push(button);
                }
            }
        }

        // Make sure there's a menu in the layout, default to the left
        if !left_buttons.contains(&TitlebarButton::Menu)
            && !right_buttons.contains(&TitlebarButton::Menu)
        {
            left_buttons.push(TitlebarButton::Menu);
        }

        TitlebarLayout {
            left: left_buttons,
            right: right_buttons,
        }
    } else {
        TitlebarLayout {
            left: vec![TitlebarButton::Menu],
            right: vec![
                TitlebarButton::Minimize,
                TitlebarButton::Maximize,
                TitlebarButton::Close,
            ],
        }
    }
}
