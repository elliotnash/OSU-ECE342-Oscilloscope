use serde::{Deserialize, Serialize};

use crate::log::SerializableLogRecord;
use crate::frame::FrameData;

/// Message type enum
#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum Message {
    /// Heartbeat message with no payload
    Heartbeat,
    Frame(FrameData),
    /// Log message with log level and string content
    Log(SerializableLogRecord),
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
