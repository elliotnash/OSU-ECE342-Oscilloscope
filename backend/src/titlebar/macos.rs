use crate::titlebar::{TitlebarButton, TitlebarLayout};

pub fn get_titlebar_layout() -> TitlebarLayout {
    TitlebarLayout {
        left: vec![],
        right: vec![TitlebarButton::Menu],
    }
}
