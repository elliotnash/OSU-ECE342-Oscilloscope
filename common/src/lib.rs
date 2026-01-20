#![cfg_attr(not(feature = "std"), no_std)]

pub mod message;
pub mod log;

// Hide the into_log_record macro in the root export
#[doc(hidden)]
pub use crate::log::into_log_record as __hidden_into_log_record_root_export;

extern crate alloc;