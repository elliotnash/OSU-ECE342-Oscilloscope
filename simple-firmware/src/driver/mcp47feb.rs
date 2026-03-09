use embedded_hal_async::i2c::I2c as I2cTrait;

/// MCP47FEBxx DAC driver
pub struct Mcp47feb<I2C> {
    i2c: I2C,
    address: u8,
}

/// Memory addresses for volatile registers
#[allow(dead_code)]
pub mod volatile_address {
    pub const DAC0: u8 = 0x00;
    pub const DAC1: u8 = 0x01;
    pub const VREF: u8 = 0x08;
    pub const POWER_DOWN: u8 = 0x09;
    pub const GAIN_STATUS: u8 = 0x0A;
}

/// Memory addresses for nonvolatile registers
#[allow(dead_code)]
pub mod nonvolatile_address {
    pub const DAC0: u8 = 0x10;
    pub const DAC1: u8 = 0x11;
    pub const VREF: u8 = 0x18;
    pub const POWER_DOWN: u8 = 0x19;
    pub const GAIN_SLAVE_ADDR: u8 = 0x1A;
}

/// Command bits (C1:C0)
mod command {
    pub(super) const WRITE: u8 = 0b00;
    pub(super) const READ: u8 = 0b11;
}

/// Voltage reference source (2-bit field per DAC in VREF register).
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
#[repr(u8)]
pub enum VrefSource {
    /// VDD as reference (unbuffered). Gain is forced to 1x when using VDD.
    Vdd = 0b00,
    /// Internal band gap (~1.22 V). VREF buffer enabled.
    InternalBandGap = 0b01,
    /// External VREF pin, unbuffered.
    ExternalUnbuffered = 0b10,
    /// External VREF pin, buffered.
    ExternalBuffered = 0b11,
}

/// DAC channel index (0 = DAC0, 1 = DAC1; DAC1 only on dual-channel devices).
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum DacChannel {
    Dac0 = 0,
    Dac1 = 1,
}

/// Default I2C slave addresses
#[allow(dead_code)]
pub mod default_address {
    pub const A0: u8 = 0x60; // '1100000' (write), 0x61 (read)
    pub const A1: u8 = 0x62; // '1100001' (write), 0x63 (read)
    pub const A2: u8 = 0x64; // '1100010' (write), 0x65 (read)
    pub const A3: u8 = 0x66; // '1100011' (write), 0x67 (read)
}

impl<I2C> Mcp47feb<I2C>
where
    I2C: I2cTrait,
{
    /// Create a new MCP47FEBxx driver instance
    ///
    /// # Arguments
    /// * `i2c` - I2C peripheral instance
    /// * `address` - 7-bit I2C slave address (default is 0x60 for A0 variant)
    pub fn new(i2c: I2C, address: u8) -> Self {
        Self { i2c, address }
    }

    /// Check if the DAC is connected and responding on the I2C bus.
    ///
    /// Performs a read of the status register; if the device acknowledges and the
    /// read succeeds, it is considered present. Returns `Ok(())` if the device
    /// responded, or `Err` on bus/address errors (e.g. no device, NACK).
    pub async fn ping(&mut self) -> Result<(), I2C::Error> {
        let _ = self.read(volatile_address::GAIN_STATUS).await?;
        Ok(())
    }

    /// Write a 16-bit value to a volatile memory address
    ///
    /// # Arguments
    /// * `mem_addr` - Memory address (5 bits, 0x00-0x0F)
    /// * `value` - 16-bit value to write (right-justified)
    pub async fn write_volatile(&mut self, mem_addr: u8, value: u16) -> Result<(), I2C::Error> {
        let command_byte = (mem_addr & 0x1F) << 3 | command::WRITE;
        let buffer = [command_byte, (value >> 8) as u8, (value & 0xFF) as u8];

        self.i2c.write(self.address, &buffer).await?;
        Ok(())
    }

    /// Write a 16-bit value to a nonvolatile memory address
    ///
    /// # Arguments
    /// * `mem_addr` - Memory address (5 bits, 0x10-0x1F)
    /// * `value` - 16-bit value to write (right-justified)
    ///
    /// # Note
    /// This will start an EEPROM write cycle. The EEWA bit in the status register
    /// can be checked to determine when the write cycle completes.
    pub async fn write_nonvolatile(&mut self, mem_addr: u8, value: u16) -> Result<(), I2C::Error> {
        let command_byte = (mem_addr & 0x1F) << 3 | command::WRITE;
        let buffer = [command_byte, (value >> 8) as u8, (value & 0xFF) as u8];

        self.i2c.write(self.address, &buffer).await?;
        Ok(())
    }

    /// Read a 16-bit value from a memory address
    ///
    /// # Arguments
    /// * `mem_addr` - Memory address (5 bits)
    ///
    /// # Returns
    /// The 16-bit value read from the register
    ///
    /// # Note
    /// This uses a write-then-read transaction with repeated start condition
    pub async fn read(&mut self, mem_addr: u8) -> Result<u16, I2C::Error> {
        let command_byte = (mem_addr & 0x1F) << 3 | command::READ;

        // Write command byte, then read data (2 bytes) with repeated start
        let cmd_buf = [command_byte];
        let mut data = [0u8; 2];
        self.i2c
            .write_read(self.address, &cmd_buf, &mut data)
            .await?;

        Ok(((data[0] as u16) << 8) | (data[1] as u16))
    }

    /// Write DAC value to a volatile DAC register.
    ///
    /// # Arguments
    /// * `channel` - DAC channel (Dac1 only on dual-channel devices)
    /// * `value` - DAC value (8-bit, 10-bit, or 12-bit depending on device)
    pub async fn write_dac(&mut self, channel: DacChannel, value: u16) -> Result<(), I2C::Error> {
        let addr = match channel {
            DacChannel::Dac0 => volatile_address::DAC0,
            DacChannel::Dac1 => volatile_address::DAC1,
        };
        self.write_volatile(addr, value).await
    }

    /// Read DAC value from a volatile DAC register.
    pub async fn read_dac(&mut self, channel: DacChannel) -> Result<u16, I2C::Error> {
        let addr = match channel {
            DacChannel::Dac0 => volatile_address::DAC0,
            DacChannel::Dac1 => volatile_address::DAC1,
        };
        self.read(addr).await
    }

    /// Set the voltage reference source for a DAC channel.
    ///
    /// The VREF register (0x08) holds a 2-bit field per channel: DAC0 uses bits 1:0,
    /// DAC1 uses bits 3:2. Other bits are preserved. When setting VDD as reference,
    /// the device forces gain to 1x (see datasheet).
    pub async fn set_vref(
        &mut self,
        channel: DacChannel,
        source: VrefSource,
    ) -> Result<(), I2C::Error> {
        let shift = (channel as u8) * 2;
        let mask = 0xFFFFu16 & !(3u16 << shift);
        let current = self.read(volatile_address::VREF).await?;
        let value = (current & mask) | ((source as u16) << shift);
        self.write_volatile(volatile_address::VREF, value).await
    }

    /// Read the voltage reference source for a DAC channel.
    ///
    /// Returns the 2-bit VREF field for the given channel (DAC0 = bits 1:0, DAC1 = bits 3:2).
    pub async fn read_vref(&mut self, channel: DacChannel) -> Result<VrefSource, I2C::Error> {
        let raw = self.read(volatile_address::VREF).await?;
        let shift = (channel as u8) * 2;
        let bits = ((raw >> shift) & 3) as u8;
        Ok(match bits {
            0b00 => VrefSource::Vdd,
            0b01 => VrefSource::InternalBandGap,
            0b10 => VrefSource::ExternalUnbuffered,
            _ => VrefSource::ExternalBuffered,
        })
    }

    /// Read the status register (address 0x0A).
    ///
    /// There is no device ID or part-number register on the MCP47FEBxx; this
    /// register is the closest to "device info" and gives runtime state: POR,
    /// EEPROM write active, and gain bits.
    ///
    /// # Returns
    /// Status register value containing:
    /// - POR bit (bit 7): Power-on reset status
    /// - EEWA bit (bit 6): EEPROM write active status
    /// - G0/G1 bits (bit 8/9): Gain control bits
    pub async fn read_status(&mut self) -> Result<u16, I2C::Error> {
        self.read(volatile_address::GAIN_STATUS).await
    }

    /// Check if EEPROM write is active
    pub async fn is_eeprom_write_active(&mut self) -> Result<bool, I2C::Error> {
        let status = self.read_status().await?;
        Ok((status & (1 << 6)) != 0)
    }

    /// Wait for EEPROM write cycle to complete
    ///
    /// This function polls the status register until the EEPROM write cycle completes.
    /// Note: In a real application, you may want to add a timeout or use async delays.
    pub async fn wait_for_eeprom_write(&mut self) -> Result<(), I2C::Error> {
        while self.is_eeprom_write_active().await? {
            // In a real implementation, you might want to add a small delay here
            // using embassy_time::Timer::after() or similar
        }
        Ok(())
    }
}
