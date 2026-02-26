use defmt::info;
use embassy_rp::gpio::{Flex, Pull};
use embassy_time::Timer;
use embedded_hal_1::i2c::{ErrorKind, NoAcknowledgeSource, Operation};
use embedded_hal_async::i2c::I2c as I2cTrait;

/// Simple bitbanged I2C implementation.
pub struct SoftI2c<'d> {
    sda: Flex<'d>,
    scl: Flex<'d>,
}

impl<'d> SoftI2c<'d> {
    pub fn new(sda: Flex<'d>, scl: Flex<'d>) -> Self {
        let mut s = Self { sda, scl };
        s.sda.set_as_output();
        s.scl.set_as_output();
        s.sda.set_high();
        s.scl.set_high();
        s
    }

    async fn wait(&self) {
        // 10 microseconds = 100kHz
        Timer::after_micros(10).await;
    }

    async fn start(&mut self) {
        self.sda.set_as_output();
        self.sda.set_high();
        self.scl.set_high();
        self.wait().await;
        self.sda.set_low();
        self.wait().await;
        self.scl.set_low();
        self.wait().await;
    }

    async fn stop(&mut self) {
        self.sda.set_as_output();
        self.sda.set_low();
        self.wait().await;
        self.scl.set_high();
        self.wait().await;
        self.sda.set_high();
        self.wait().await;
    }

    /// Sends a byte and returns true if ACK was received.
    async fn send_byte(&mut self, byte: u8) -> bool {
        self.sda.set_as_output();
        for i in 0..8 {
            let bit = (byte >> (7 - i)) & 1;
            if bit == 1 {
                self.sda.set_high();
            } else {
                self.sda.set_low();
            }
            self.wait().await;
            self.scl.set_high();
            self.wait().await;
            self.scl.set_low();
            self.wait().await;
        }

        // Check ACK
        self.sda.set_as_input();
        self.sda.set_pull(Pull::Up);
        self.wait().await;
        self.scl.set_high();
        self.wait().await;

        let ack = self.sda.is_low(); // Slave pulls low to ACK

        self.scl.set_low();
        self.wait().await;
        ack
    }

    /// Reads a byte; `ack` = true to send ACK, false to send NACK (e.g. for last byte of read).
    async fn read_byte(&mut self, ack: bool) -> u8 {
        self.sda.set_as_input();
        self.sda.set_pull(Pull::Up);
        let mut byte = 0u8;
        for i in 0..8 {
            self.wait().await;
            self.scl.set_high();
            self.wait().await;
            if self.sda.is_high() {
                byte |= 1 << (7 - i);
            }
            self.scl.set_low();
        }
        // Master ACK/NACK
        self.sda.set_as_output();
        if ack {
            self.sda.set_low();
        } else {
            self.sda.set_high();
        }
        self.wait().await;
        self.scl.set_high();
        self.wait().await;
        self.scl.set_low();
        self.wait().await;
        byte
    }

    pub async fn scan(&mut self) {
        info!("Scanning (Software I2C)...");
        for addr in 0x08..0x78u8 {
            // Standard I2C range
            self.start().await;
            if self.send_byte(addr << 1).await {
                info!("Device found at 0x{:02x}", addr);
            }
            self.stop().await;
            Timer::after_millis(5).await;
        }
        info!("Scan complete.");
    }
}

impl embedded_hal_1::i2c::ErrorType for SoftI2c<'_> {
    type Error = ErrorKind;
}

impl I2cTrait for SoftI2c<'_> {
    async fn transaction(
        &mut self,
        address: u8,
        operations: &mut [Operation<'_>],
    ) -> Result<(), Self::Error> {
        let mut first = true;
        let mut was_write = true; // arbitrary, only used after first

        for op in operations.iter_mut() {
            let is_write = matches!(op, Operation::Write(_));

            if first {
                self.start().await;
                if !self
                    .send_byte(address << 1 | if is_write { 0 } else { 1 })
                    .await
                {
                    self.stop().await;
                    return Err(ErrorKind::NoAcknowledge(NoAcknowledgeSource::Address));
                }
            } else if is_write != was_write {
                self.start().await; // repeated start
                if !self
                    .send_byte(address << 1 | if is_write { 0 } else { 1 })
                    .await
                {
                    self.stop().await;
                    return Err(ErrorKind::NoAcknowledge(NoAcknowledgeSource::Address));
                }
            }

            match op {
                Operation::Write(buf) => {
                    for &b in buf.iter() {
                        if !self.send_byte(b).await {
                            self.stop().await;
                            return Err(ErrorKind::NoAcknowledge(NoAcknowledgeSource::Data));
                        }
                    }
                }
                Operation::Read(buf) => {
                    let len = buf.len();
                    for (i, slot) in buf.iter_mut().enumerate() {
                        *slot = self.read_byte(i != len - 1).await; // NACK on last byte
                    }
                }
            }

            first = false;
            was_write = is_write;
        }

        self.stop().await;
        Ok(())
    }
}

