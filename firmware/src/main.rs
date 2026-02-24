#![no_std]
#![no_main]

extern crate alloc;

use defmt::{error, info};
use embassy_rp::gpio::Flex;
use embassy_rp::i2c;
use embedded_alloc::TlsfHeap as Heap;

use crate::driver::mcp47feb::Mcp47feb;
use crate::softi2c::SoftI2c;
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
pub mod softi2c;

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

    // let mut psram_config = embassy_rp::psram::Config::aps6404l();
    // psram_config.max_mem_freq = 25_000_000;
    // psram_config.init_clkdiv = 30;
    // let psram = embassy_rp::psram::Psram::new(
    //     embassy_rp::qmi_cs1::QmiCs1::new(p.QMI_CS1, p.PIN_8),
    //     psram_config,
    // );

    // let Ok(psram) = psram else {
    //     error!("PSRAM not found");
    //     loop {
    //         Timer::after_secs(1).await;
    //     }
    // };

    // let psram_slice = unsafe {
    //     let psram_ptr = psram.base_address();
    //     let slice: &'static mut [u8] =
    //         core::slice::from_raw_parts_mut(psram_ptr, psram.size() as usize);
    //     slice
    // };

    // psram_slice.fill(0x55);
    // // psram_slice[0x100] = 0x55;
    // info!("PSRAM filled with 0x55");
    // let at_addr = psram_slice[0x100];
    // info!("Read from PSRAM at address 0x100: 0x{:02x}", at_addr);
    // Timer::after_secs(1).await;

    // // psram_slice.fill(0xAA);
    // // info!("PSRAM filled with 0xAA");
    // // let at_addr = psram_slice[0x100];
    // // info!("Read from PSRAM at address 0x100: 0x{:02x}", at_addr);
    // // Timer::after_secs(1).await;

    let sda = Flex::new(p.PIN_7);
    let scl = Flex::new(p.PIN_6);
    let mut i2c = SoftI2c::new(sda, scl);

    i2c.scan().await;

    info!("I2C scanner completed");

    // Use the MCP47FEB driver with the bitbanged SoftI2c
    let mut dac = Mcp47feb::new(i2c, driver::mcp47feb::default_address::A0);
    match dac.ping().await {
        Ok(()) => info!("DAC found and responding"),
        Err(_) => error!("DAC ping failed (no ACK or bus error)"),
    }
    if let Ok(()) = dac.ping().await {
        if dac
            .set_vref(
                driver::mcp47feb::DacChannel::Dac0,
                driver::mcp47feb::VrefSource::Vdd,
            )
            .await
            .is_ok()
        {
            info!("DAC VREF set to VDD");
        }
        if dac
            .write_dac(driver::mcp47feb::DacChannel::Dac0, 0)
            .await
            .is_ok()
        {
            info!("DAC0 set to 0");
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
