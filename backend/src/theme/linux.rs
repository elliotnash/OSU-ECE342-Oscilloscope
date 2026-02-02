use crate::theme::{Color, OscopeTheme};

impl TryInto<Color> for &cssparser_color::Color {
    type Error = &'static str; // TODO: Better error handling

    fn try_into(self) -> Result<Color, Self::Error> {
        match self {
            cssparser_color::Color::Rgba(color) => Ok(Color {
                red: color.red,
                green: color.green,
                blue: color.blue,
                alpha: (color.alpha * 255.0) as u8,
            }),
            cssparser_color::Color::Hsl(color) => {
                let h = color.hue.unwrap_or(0.0);
                let s = color.saturation.unwrap_or(0.0);
                let l = color.lightness.unwrap_or(0.0);
                let alpha = color.alpha.unwrap_or(1.0);

                let (r, g, b) = cssparser_color::hsl_to_rgb(h, s, l);

                Ok(Color {
                    red: (r * 255.0) as u8,
                    green: (g * 255.0) as u8,
                    blue: (b * 255.0) as u8,
                    alpha: (alpha * 255.0) as u8,
                })
            }
            cssparser_color::Color::Hwb(color) => {
                let h = color.hue.unwrap_or(0.0);
                let w = color.whiteness.unwrap_or(0.0);
                let b = color.blackness.unwrap_or(0.0);
                let alpha = color.alpha.unwrap_or(1.0);

                let (r, g, b) = cssparser_color::hwb_to_rgb(h, w, b);

                Ok(Color {
                    red: (r * 255.0) as u8,
                    green: (g * 255.0) as u8,
                    blue: (b * 255.0) as u8,
                    alpha: (alpha * 255.0) as u8,
                })
            }
            // TODO: Support all css color types
            _ => Err("Unsupported color type"),
        }
    }
}

pub fn get_system_theme() -> OscopeTheme {
    let system_theme = linux_theme::gtk::current::current();
    OscopeTheme {
        primary: system_theme
            .0
            .get("accent_bg_color")
            .and_then(|color| color.try_into().ok()),
        primary_fg: system_theme
            .0
            .get("accent_fg_color")
            .and_then(|color| color.try_into().ok()),
        bg: system_theme
            .0
            .get("window_bg_color")
            .and_then(|color| color.try_into().ok()),
        fg: system_theme
            .0
            .get("window_fg_color")
            .and_then(|color| color.try_into().ok()),
        secondary: system_theme
            .0
            .get("card_bg_color")
            .and_then(|color| color.try_into().ok()),
        secondary_fg: system_theme
            .0
            .get("card_fg_color")
            .and_then(|color| color.try_into().ok()),
    }
}
