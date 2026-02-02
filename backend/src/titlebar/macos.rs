use crate::titlebar::{TitlebarButton, TitlebarLayout};

pub fn get_titlebar_layout() -> TitlebarLayout {
    TitlebarLayout {
        left: vec![
            TitlebarButton::Close,
            TitlebarButton::Minimize,
            TitlebarButton::Maximize,
        ],
        right: vec![TitlebarButton::Menu],
    }
}
