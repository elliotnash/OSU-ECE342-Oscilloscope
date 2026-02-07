#![no_std]
#![no_main]

extern crate alloc;

use embassy_time::Timer;
use embedded_alloc::TlsfHeap as Heap;

use defmt::{info, panic};
use embassy_executor::Spawner;
use embassy_rp::bind_interrupts;
use embassy_rp::peripherals::USB;
use embassy_rp::usb::{Driver, Instance, InterruptHandler};
use embassy_usb::UsbDevice;
use embassy_usb::class::cdc_acm::{CdcAcmClass, State};
use embassy_usb::driver::EndpointError;
use libm::sinf;
use static_cell::StaticCell;
use {defmt_rtt as _, panic_probe as _};
use alloc::vec::Vec;
use alloc::string::{String, ToString};
use common::message::Message;
use common::frame::FrameData;

use common::usb::{OSCOPE_VID, OSCOPE_PID};

#[global_allocator]
static HEAP: Heap = Heap::empty();

bind_interrupts!(struct Irqs {
    USBCTRL_IRQ => InterruptHandler<USB>;
});

#[embassy_executor::main]
async fn main(spawner: Spawner) {
    // Initialize the heap allocator
    unsafe {
        embedded_alloc::init!(HEAP, 1024*16);
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
    let mut class = {
        static STATE: StaticCell<State> = StaticCell::new();
        let state = STATE.init(State::new());
        CdcAcmClass::new(&mut builder, state, 64)
    };

    // Build the builder.
    let usb = builder.build();

    // Run the USB device.
    spawner.spawn(usb_task(usb));

    // Do stuff with the class!
    loop {
        class.wait_connection().await;
        info!("Connected");
        let _ = send_frames(&mut class).await;
        info!("Disconnected");
    }
}

type MyUsbDriver = Driver<'static, USB>;
type MyUsbDevice = UsbDevice<'static, MyUsbDriver>;

#[embassy_executor::task]
async fn usb_task(mut usb: MyUsbDevice) -> ! {
    usb.run().await
}

struct Disconnected {}

impl From<EndpointError> for Disconnected {
    fn from(val: EndpointError) -> Self {
        match val {
            EndpointError::BufferOverflow => panic!("Buffer overflow"),
            EndpointError::Disabled => Disconnected {},
        }
    }
}

async fn send_frames<'d, T: Instance + 'd>(class: &mut CdcAcmClass<'d, Driver<'d, T>>) -> Result<(), Disconnected> {
    let mut buf = [0; 64];
    loop {
        // let n = class.read_packet(&mut buf).await?;
        // let data = &buf[..n];
        // info!("data: {:x}", data);
        // class.write_packet(data).await?;
        
        let mut data = Vec::new();
        for i in 0..10 {
            data.push((2048.0 * sinf(i as f32 / 100.0)) as u16);
        }
        let message = Message::Frame(FrameData {
            data,
            timescale: 1.0,
            voltagescale: 2.0,
        });
        let mut bytes = postcard::to_allocvec_cobs(&message).expect("Serialization failed");

        let length = bytes.len().to_string() + "\n";

        class.write_packet(&bytes).await?;

        Timer::after_secs(1).await;
    }
}