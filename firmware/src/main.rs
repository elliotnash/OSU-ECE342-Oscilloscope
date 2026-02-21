#![no_std]
#![no_main]

extern crate alloc;

use defmt::{error, info};
use embassy_rp::gpio::{Flex, Pull};
use embassy_rp::i2c::{self, I2c};
use embassy_time::Timer;
use embedded_alloc::TlsfHeap as Heap;

use crate::driver::mcp47feb::Mcp47feb;
use common::usb::{OSCOPE_PID, OSCOPE_VID};
use embassy_executor::Spawner;
use embassy_rp::bind_interrupts;
use embassy_rp::peripherals::{self, USB};
use embassy_rp::usb::{self, Driver};
use embassy_usb::UsbDevice;
use embassy_usb::class::cdc_acm::{
    CdcAcmClass, Receiver as CdcReceiver, Sender as CdcSender, State,
};
use message::{receive_messages_task, send_messages_task};
use static_cell::StaticCell;

use {defmt_rtt as _, panic_probe as _};

pub mod driver;
pub mod message;

#[global_allocator]
static HEAP: Heap = Heap::empty();

bind_interrupts!(struct Irqs {
    USBCTRL_IRQ => usb::InterruptHandler<USB>;
    I2C1_IRQ => i2c::InterruptHandler<peripherals::I2C1>;
});

const USB_PACKET_SIZE: usize = 64;

type ScopeUsbDriver = Driver<'static, USB>;
type ScopeUsbDevice = UsbDevice<'static, ScopeUsbDriver>;
type ScopeUsbClass = CdcAcmClass<'static, ScopeUsbDriver>;
type ScopeUsbSender = CdcSender<'static, ScopeUsbDriver>;
type ScopeUsbReceiver = CdcReceiver<'static, ScopeUsbDriver>;

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
        // 20 microseconds = 50kHz. Safe for weak pull-ups.
        Timer::after_micros(20).await;
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

    /// Sends a byte and returns true if ACK was received
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

#[embassy_executor::main]
async fn main(spawner: Spawner) {
    // Initialize the heap allocator
    unsafe {
        embedded_alloc::init!(HEAP, 1024 * 64);
    }

    let p = embassy_rp::init(Default::default());

    // Create the driver, from the HAL.
    let driver = Driver::new(p.USB, Irqs);

    // Create embassy-usb Config
    let config = {
        let mut config = embassy_usb::Config::new(OSCOPE_VID, OSCOPE_PID);
        config.manufacturer = Some("ECE342");
        config.product = Some("USB Oscilloscope");
        config.serial_number = Some("12345678");
        config.max_power = 100;
        config.max_packet_size_0 = 64;
        config
    };

    // Create embassy-usb DeviceBuilder using the driver and config.
    // It needs some buffers for building the descriptors.
    let mut builder = {
        static CONFIG_DESCRIPTOR: StaticCell<[u8; 256]> = StaticCell::new();
        static BOS_DESCRIPTOR: StaticCell<[u8; 256]> = StaticCell::new();
        static CONTROL_BUF: StaticCell<[u8; 64]> = StaticCell::new();

        let builder = embassy_usb::Builder::new(
            driver,
            config,
            CONFIG_DESCRIPTOR.init([0; 256]),
            BOS_DESCRIPTOR.init([0; 256]),
            &mut [], // no msos descriptors
            CONTROL_BUF.init([0; 64]),
        );
        builder
    };

    // Create classes on the builder.
    let class: ScopeUsbClass = {
        static STATE: StaticCell<State> = StaticCell::new();
        let state = STATE.init(State::new());
        CdcAcmClass::new(&mut builder, state, USB_PACKET_SIZE as u16)
    };

    // Build the builder.
    let usb = builder.build();

    // Run the USB device.
    let _ = spawner.spawn(usb_task(usb));

    let (tx, rx) = class.split();

    let _ = spawner.spawn(send_messages_task(tx));
    let _ = spawner.spawn(receive_messages_task(rx));

    info!("Firmware started");

    let sda = Flex::new(p.PIN_7);
    let scl = Flex::new(p.PIN_6);
    let mut i2c = SoftI2c::new(sda, scl);

    i2c.scan().await;

    info!("I2C scanner completed");

    i2c.start().await;
    if i2c.send_byte(0x60 << 1).await {
        i2c.send_byte(0x00 << 3).await;
        i2c.send_byte(0x08).await;
        i2c.send_byte(0x00).await;
        info!("Data sent to DAC!");
    } else {
        error!("DAC did not ACK address 0x60");
    }
    i2c.stop().await;

    // let mut i2c_config = i2c::Config::default();
    // i2c_config.frequency = 100_000;
    // i2c_config.scl_pullup = false;
    // i2c_config.sda_pullup = false;

    // let mut i2c = I2c::new_async(p.I2C1, p.PIN_6, p.PIN_7, Irqs, i2c_config);

    // i2c_scanner(&mut i2c).await;
    // info!("I2C scanner completed");

    // test_dac(&mut i2c).await;
    // info!("DAC test completed");

    // let mut dac = Mcp47feb::new(i2c, 0x60);
    // dac.ping().await.unwrap();
    // dac.write_dac(driver::mcp47feb::DacChannel::Dac0, 0x0000)
    //     .await
    //     .unwrap();
    // dac.write_dac(driver::mcp47feb::DacChannel::Dac1, 0x0000)
    //     .await
    //     .unwrap();
    // defmt::info!("DAC initialized");
}

async fn i2c_scanner(i2c: &mut i2c::I2c<'_, peripherals::I2C1, i2c::Async>) {
    info!("Scanning I2C bus...");
    for addr in 0x00..0x80u8 {
        // We just try to read 1 byte. If the device is there, it will ACK.
        let mut read_buf = [0u8; 1];
        match i2c.read_async(addr, &mut read_buf).await {
            Ok(_) => info!("Found device at address: 0x{:02x}", addr),
            Err(_) => {} // No device at this address
        }
    }
    info!("Scan complete.");
}

const DAC_ADDR: u8 = 0x61;

// Command bytes for the MCP47FEB
// Memory Address 0x00 is Volatile DAC0
// Write Command bits are typically 00 (bits 4-3 of the command byte)
const WRITE_CMD: u8 = 0x00 << 3;

async fn test_dac(i2c: &mut i2c::I2c<'_, peripherals::I2C1, i2c::Async>) {
    // We want to send 3 bytes: [Command Byte, Data High Byte, Data Low Byte]
    // For a 12-bit DAC (MCP47FEB21/22), the value 0x7FF is roughly mid-scale.
    let dac_value: u16 = 0x7FF;
    let hi_byte = (dac_value >> 8) as u8;
    let lo_byte = (dac_value & 0xFF) as u8;

    let tx_buffer = [WRITE_CMD, hi_byte, lo_byte];

    match i2c.write_async(DAC_ADDR, tx_buffer).await {
        Ok(_) => {
            // Success! You should see a voltage on Vout0 roughly half of Vref/Vdd
            info!("DAC Write Successful");
        }
        Err(e) => {
            // If you get a 'NoAcknowledge' error here, it's likely:
            // 1. The wrong I2C address
            // 2. The internal pull-ups aren't strong enough
            error!("I2C Error: {:?}", e);
        }
    }
}

#[embassy_executor::task]
async fn usb_task(mut usb: ScopeUsbDevice) -> ! {
    usb.run().await
}

// Program metadata for `picotool info`.
#[unsafe(link_section = ".bi_entries")]
#[used]
pub static PICOTOOL_ENTRIES: [embassy_rp::binary_info::EntryAddr; 4] = [
    embassy_rp::binary_info::rp_program_name!(c"ECE342-Oscilloscope/firmware"),
    embassy_rp::binary_info::rp_program_description!(c"Firmware2 for the ECE342 Oscilloscope"),
    embassy_rp::binary_info::rp_cargo_version!(),
    embassy_rp::binary_info::rp_program_build_attribute!(),
];
