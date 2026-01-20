// This file is adapted from the `serializable_log_record` crate for no_std compatibility:
// https://github.com/8192K/serializable_log_record/blob/main/src/lib.rs
// 
// Portions copyright (c) 2022 8192K. Licensed under either MIT or Apache-2.0.
// See original repository for details.

use log::{Level, Record};

use alloc::string::{String, ToString};
use alloc::str::FromStr;
use alloc::borrow::ToOwned;
use serde::{Serialize, Deserialize};

/// A custom representation of the `log::Record` struct which is unfortunately
/// not directly serializable (due to the use of `fmt::Arguments`).
///
/// Use `::from` to convert a `log::Record` to a `SerializedRecord`.
///
/// The use of `::into` is unfortunately not possible. This is why the
/// `log_into_record` macro is provided. Use it directly in a function call to
/// convert a `SerializedRecord` into a `log::Record`.
#[derive(Debug, Clone, PartialEq, Eq, Hash, Serialize, Deserialize)]
#[non_exhaustive]
pub struct SerializableLogRecord {
    pub level: String,
    pub args: String,
    pub target: String,
    pub module_path: Option<String>,
    pub file: Option<String>,
    pub line: Option<u32>,
}

impl SerializableLogRecord {
    /// Create a new `SerializableLogRecord` from the given arguments.
    /// Use `::from` to directly convert a `log::Record` to a `SerializableLogRecord`.
    #[allow(clippy::must_use_candidate)]
    pub fn new(
        level: Level,
        args: String,
        target: String,
        module_path: Option<String>,
        file: Option<String>,
        line: Option<u32>,
    ) -> Self {
        Self {
            level: level.as_str().to_owned(),
            args,
            target,
            module_path,
            file,
            line,
        }
    }

    /// Internal macro use only.
    #[allow(clippy::must_use_candidate)]
    #[doc(hidden)]
    pub fn string_to_level(level: &str) -> Level {
        Level::from_str(level).unwrap_or(Level::Warn)
    }
}

impl<'a> From<&Record<'a>> for SerializableLogRecord {
    /// Convert a `log::Record` to a `SerializableLogRecord`.
    fn from(record: &Record<'a>) -> Self {
        Self::new(
            record.level(),
            record.args().to_string(),
            record.target().to_owned(),
            record.module_path().map(str::to_owned),
            record.file().map(str::to_owned),
            record.line(),
        )
    }
}

impl<'a> From<Record<'a>> for SerializableLogRecord {
    /// Convert a `log::Record` to a `SerializableLogRecord`.
    fn from(value: Record<'a>) -> Self {
        Self::from(&value)
    }
}

#[macro_export]
/// This macro converts a `SerializableLogRecord` into a `log::Record` which is to be passed
/// immediately into a call to the `log` method of any `log::Log` implementation.
macro_rules! into_log_record {
    ($builder:expr, $message:expr) => {
        $builder
            .level(SerializableLogRecord::string_to_level(&$message.level))
            .args(format_args!("{}", $message.args))
            .target($message.target.as_str())
            .module_path($message.module_path.as_deref())
            .file($message.file.as_deref())
            .line($message.line)
            .build()
    };
}

pub use into_log_record;
