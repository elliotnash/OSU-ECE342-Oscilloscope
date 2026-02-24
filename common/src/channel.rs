use serde::{Deserialize, Serialize};
#[cfg(feature = "std")]
use specta::Type;

use crate::frame::ScopeChannel;

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[cfg_attr(feature = "alloc", derive(defmt::Format))]
#[cfg_attr(feature = "std", derive(Type))]
pub enum ScopeGain {
    One,
    Four,
    Twenty,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[cfg_attr(feature = "alloc", derive(defmt::Format))]
#[cfg_attr(feature = "std", derive(Type))]
pub enum ScopeCoupling {
    DC,
    AC,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[cfg_attr(feature = "alloc", derive(defmt::Format))]
#[cfg_attr(feature = "std", derive(Type))]
pub struct ChannelOptions {
    pub channel: ScopeChannel,
    pub enabled: bool,
    pub voltage_gain: ScopeGain,
    pub coupling: ScopeCoupling,
}