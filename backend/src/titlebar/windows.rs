use crate::titlebar::{TitlebarLayout, TitlebarButton};

pub fn get_titlebar_layout() -> TitlebarLayout {
    TitlebarLayout {
        left: vec![TitlebarButton::Menu],
        right: vec![TitlebarButton::Minimize, TitlebarButton::Maximize, TitlebarButton::Close],
    }
}