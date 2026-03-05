use serde::{Deserialize, Serialize};

use crate::channel::ChannelOptions;
use crate::frame::FrameData;
use crate::log::SerializableLogRecord;
use crate::trigger::TriggerOptions;
#[cfg(feature = "std")]
use specta::Type;

/// Message type enum
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[cfg_attr(feature = "alloc", derive(defmt::Format))]
pub enum Message {
    /// Heartbeat message with no payload
    Heartbeat,
    Frame(FrameData),
    /// Log message with log level and string content
    Log(SerializableLogRecord),
    SetSampleRate(u32),
    SetChannelOptions(ChannelOptions),
    SetTriggerOptions(TriggerOptions),
    Verification(VerificationMessage),
    Calibration(CalibrationMessage),
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[cfg_attr(feature = "alloc", derive(defmt::Format))]
#[cfg_attr(feature = "std", derive(Type))]
pub enum VerificationMessage {
    TriggerState(bool),
    StartDacTest,
    SetGpioHigh,
    SetGpioLow,
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[cfg_attr(feature = "alloc", derive(defmt::Format))]
#[cfg_attr(feature = "std", derive(Type))]
pub enum CalibrationMessage {
    CalibrateCenter,
    CalibrateMax,
    CalibrateMin,
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn heartbeat_serialization() {
        let msg = Message::Heartbeat;
        let mut bytes = postcard::to_stdvec_cobs(&msg).expect("Serialization failed");
        let deserialized =
            postcard::from_bytes_cobs::<Message>(&mut bytes).expect("Deserialization failed");
        assert_eq!(msg, deserialized);
    }
}
