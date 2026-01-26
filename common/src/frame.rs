use alloc::vec::Vec;
use serde::{Deserialize, Deserializer, Serialize, Serializer};

/// Serialize a Vec<u16> of 12-bit values by packing two values into 3 bytes.
/// Each u16 value is clamped to 12 bits (0-4095).
#[allow(dead_code)]
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
        bytes.push(v1 as u8);
        bytes.push((((v1 >> 8) & 0xF) | ((v2 & 0xF) << 4)) as u8);
        bytes.push(((v2 >> 4) & 0xFF) as u8);

        i += 2;
    }

    bytes.serialize(serializer)
}

/// Deserialize bytes back into a Vec<u16> of 12-bit values.
/// Unpacks 3-byte groups into two 12-bit values.
#[allow(dead_code)]
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

/// Serialize a Vec<u16> of 12-bit values using delta packing.
/// Each u16 value is clamped to 12 bits (0-4095).
fn serialize_12bit_data_delta_packed<S>(data: &[u16], serializer: S) -> Result<S::Ok, S::Error>
where
    S: Serializer,
{
    let mut bytes = Vec::new();

    if data.is_empty() {
        return bytes.serialize(serializer);
    }

    /// Pushes an absolute value to the bytes vector.
    fn push_absolute(bytes: &mut Vec<u8>, value: u16) {
        // The most significant bit is 1 to indicate an absolute value, followed by 3 bits of padding
        // The next 4 bits are the high 4 bits of the value
        // The next 8 bits are the low 8 bits of the value
        bytes.push(((1 << 7) | ((value >> 8) & 0xF)) as u8);
        bytes.push(value as u8);
    }

    /// Pushes a delta value to the bytes vector.
    fn push_delta(bytes: &mut Vec<u8>, delta: u8) {
        bytes.push(delta & 0b0111_1111);
    }

    // The first byte is always a absolute value, push it
    push_absolute(&mut bytes, data[0]);

    let mut i = 1;
    while i < data.len() {
        let delta = (data[i] as i16) - (data[i - 1] as i16);
        if (-64..64).contains(&delta) {
            push_delta(&mut bytes, delta as u8);
        } else {
            push_absolute(&mut bytes, data[i]);
        }
        i += 1;
    }

    bytes.serialize(serializer)
}

/// Deserialize bytes back into a Vec<u16> of 12-bit values.
/// Decodes delta packed bytes into absolute 12-bit values.
fn deserialize_12bit_data_delta_packed<'de, D>(deserializer: D) -> Result<Vec<u16>, D::Error>
where
    D: Deserializer<'de>,
{
    let bytes: Vec<u8> = Vec::deserialize(deserializer)?;
    let mut data = Vec::new();

    if bytes.len() < 2 {
        return Ok(data);
    }

    fn push_absolute(data: &mut Vec<u16>, value: &[u8]) {
        data.push((((value[0] & 0b0111_1111) as u16) << 8) | value[1] as u16);
    }

    fn push_delta(data: &mut Vec<u16>, value: u8) {
        // Since the most significant bit signifies absolute/delta, we need to sign extend the value
        // before we interpret it as a two's complement value (casting to i8).
        let delta = ((value & 0b0111_1111) | ((value & 0b0100_0000) << 1)) as i16;
        let last = *data
            .last()
            .expect("Delta value received without previous value") as i16;
        data.push((last + delta) as u16);
    }

    // The first byte is always an absolute value, push it
    push_absolute(&mut data, &bytes[0..2]);

    let mut i = 2;
    while i < bytes.len() {
        if bytes[i] & 0b1000_0000 == 0 {
            push_delta(&mut data, bytes[i]);
            i += 1;
        } else {
            push_absolute(&mut data, &bytes[i..i + 2]);
            i += 2;
        }
    }

    Ok(data)
}

#[derive(Debug, Clone, PartialEq, Serialize, Deserialize)]
#[non_exhaustive]
pub struct FrameData {
    #[serde(
        serialize_with = "serialize_12bit_data_delta_packed",
        deserialize_with = "deserialize_12bit_data_delta_packed"
    )]
    pub data: Vec<u16>,
    pub timescale: f32,
    pub voltagescale: f32,
}

#[cfg(test)]
mod tests {
    use super::*;

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

    #[test]
    fn frame_data_packing_sine_wave() {
        // Create a sine wave with 1000 samples
        let mut data = Vec::new();
        for i in 0..1000 {
            data.push((2048.0 * (i as f32 / 1000.0).sin()) as u16);
        }
        let frame = FrameData {
            data,
            timescale: 1.0,
            voltagescale: 2.0,
        };
        let mut bytes = postcard::to_stdvec_cobs(&frame).expect("Serialization failed");
        let deserialized =
            postcard::from_bytes_cobs::<FrameData>(&mut bytes).expect("Deserialization failed");
        println!(
            "1000 sample sine wave serialized into {} bytes.",
            bytes.len()
        );
        assert_eq!(frame, deserialized);
    }
}
