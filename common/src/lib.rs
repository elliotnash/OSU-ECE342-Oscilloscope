#![cfg_attr(not(feature = "std"), no_std)]

pub mod frame;
pub mod log;
pub mod message;

pub mod usb {
    pub const OSCOPE_VID: u16 = 0x8585; 
    pub const OSCOPE_PID: u16 = 0xC09E;
}

// Hide the into_log_record macro in the root export
#[doc(hidden)]
pub use crate::log::into_log_record as __hidden_into_log_record_root_export;

extern crate alloc;
