use serde::{Deserialize, Serialize};
#[cfg(feature = "std")]
use specta::Type;

use crate::frame::ScopeChannel;

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[cfg_attr(feature = "alloc", derive(defmt::Format))]
#[cfg_attr(feature = "std", derive(Type))]
pub struct TriggerOptions {
    pub channel: ScopeChannel,
    pub enabled: bool,
    pub value: u8,
}