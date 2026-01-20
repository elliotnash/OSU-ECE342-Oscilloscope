use alloc::vec::Vec;
use serde::{Deserialize, Deserializer, Serialize, Serializer};

use crate::log::SerializableLogRecord;

/// Serialize a Vec<u16> of 12-bit values by packing two values into 3 bytes.
/// Each u16 value is clamped to 12 bits (0-4095).
fn serialize_12bit_data<S>(data: &[u16], serializer: S) -> Result<S::Ok, S::Error>
where
    S: Serializer,
{
    let mut bytes = Vec::new();

    // Keeps track of whether the number of values is even or odd for deserialization.
    bytes.push(data.len() as u8 % 2);

    let mut i = 0;
    while i < data.len() {
        // Mask with 0xFFF to clamp to 12 bits
        let v1 = data[i] & 0xFFF;
        let v2 = if i + 1 < data.len() {
            data[i + 1] & 0xFFF
        } else {
            // Pad with 0 if odd number of elements
            0
        };

        // Byte 0: v1[7:0]   (low 8 bits of value 1)
        // Byte 1: v1[11:8] | (v2[3:0] << 4)  (high 4 bits of value 1, low 4 bits of value 2)
        // Byte 2: v2[11:4]  (high 8 bits of value 2)
        bytes.push((v1 & 0xFF) as u8);
        bytes.push((((v1 >> 8) & 0xF) | ((v2 & 0xF) << 4)) as u8);
        bytes.push(((v2 >> 4) & 0xFF) as u8);

        i += 2;
    }

    bytes.serialize(serializer)
}

/// Deserialize bytes back into a Vec<u16> of 12-bit values.
/// Unpacks 3-byte groups into two 12-bit values.
fn deserialize_12bit_data<'de, D>(deserializer: D) -> Result<Vec<u16>, D::Error>
where
    D: Deserializer<'de>,
{
    let bytes: Vec<u8> = Vec::deserialize(deserializer)?;
    let mut data = Vec::new();

    // Process 3-byte groups
    let mut i = 1;
    while i + 2 < bytes.len() {
        let byte0 = bytes[i] as u16;
        let byte1 = bytes[i + 1] as u16;
        let byte2 = bytes[i + 2] as u16;

        // Unpack two 12-bit values from 3 bytes:
        // Value 1: byte0 | ((byte1 & 0xF) << 8)
        // Value 2: ((byte1 >> 4) & 0xF) | (byte2 << 4)
        let v1 = byte0 | ((byte1 & 0xF) << 8);
        let v2 = ((byte1 >> 4) & 0xF) | (byte2 << 4);

        data.push(v1);
        data.push(v2);

        i += 3;
    }

    // If odd number of values, the last bit is padding, so remove it.
    if bytes[0] % 2 == 1 {
        data.pop();
    }

    Ok(data)
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[non_exhaustive]
pub struct FrameData {
    #[serde(
        serialize_with = "serialize_12bit_data",
        deserialize_with = "deserialize_12bit_data"
    )]
    pub data: Vec<u16>,
    pub timescale: f32,
    pub voltagescale: f32,
}

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

    use log::Level;

    #[test]
    fn heartbeat_serialization() {
        let msg = Message::Heartbeat;
        let mut bytes = postcard::to_stdvec_cobs(&msg).expect("Serialization failed");
        let deserialized =
            postcard::from_bytes_cobs::<Message>(&mut bytes).expect("Deserialization failed");
        assert_eq!(msg, deserialized);
    }

    #[test]
    fn log_serialization() {
        let payload = SerializableLogRecord::new(
            Level::Info,
            "System initialized".to_string(),
            "test_target".to_string(),
            Some("test::module".to_string()),
            Some("test.rs".to_string()),
            Some(42),
        );
        let msg = Message::Log(payload);
        let mut bytes = postcard::to_stdvec_cobs(&msg).expect("Serialization failed");
        let deserialized =
            postcard::from_bytes_cobs::<Message>(&mut bytes).expect("Deserialization failed");
        assert_eq!(msg, deserialized);
    }

    #[test]
    fn frame_data_packing_even() {
        // Test with even number of values
        let frame = FrameData {
            data: vec![0x000, 0xFFF, 0x123, 0x456],
            timescale: 1.0,
            voltagescale: 2.0,
        };
        let mut bytes = postcard::to_stdvec_cobs(&frame).expect("Serialization failed");
        let deserialized =
            postcard::from_bytes_cobs::<FrameData>(&mut bytes).expect("Deserialization failed");
        assert_eq!(frame, deserialized);
    }

    #[test]
    fn frame_data_packing_odd() {
        // Test with odd number of values (should pad with 0)
        let frame = FrameData {
            data: vec![0x123, 0x456, 0x789],
            timescale: 1.0,
            voltagescale: 2.0,
        };
        let mut bytes = postcard::to_stdvec_cobs(&frame).expect("Serialization failed");
        let deserialized =
            postcard::from_bytes_cobs::<FrameData>(&mut bytes).expect("Deserialization failed");
        // After deserialization, the padded 0 will be dropped
        assert_eq!(frame, deserialized);
    }

    #[test]
    fn frame_data_packing_clamp() {
        // Test that values > 12 bits are clamped
        let frame = FrameData {
            data: vec![0x1234, 0x5678], // Values > 12 bits
            timescale: 1.0,
            voltagescale: 2.0,
        };
        let mut bytes = postcard::to_stdvec_cobs(&frame).expect("Serialization failed");
        let deserialized =
            postcard::from_bytes_cobs::<FrameData>(&mut bytes).expect("Deserialization failed");
        assert_eq!(deserialized.data[0], 0x234); // Clamped to 12 bits
        assert_eq!(deserialized.data[1], 0x678); // Clamped to 12 bits
    }
}
