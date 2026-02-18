#![no_std]
#![no_main]

extern crate alloc;

use embassy_time::Timer;
use embedded_alloc::TlsfHeap as Heap;

use alloc::vec::Vec;
use common::frame::{FrameData, ScopeChannel};
use common::message::Message;
use common::usb::{OSCOPE_PID, OSCOPE_VID};
use defmt::info;
use embassy_executor::Spawner;
use embassy_rp::bind_interrupts;
use embassy_rp::peripherals::USB;
use embassy_rp::usb::{Driver, InterruptHandler};
use embassy_usb::UsbDevice;
use embassy_usb::class::cdc_acm::{
    CdcAcmClass, Receiver as CdcReceiver, Sender as CdcSender, State,
};
use libm::sinf;
use message::{MESSAGE_RX, MESSAGE_TX, receive_messages_task, send_messages_task};
use static_cell::StaticCell;
use {defmt_rtt as _, panic_probe as _};

pub mod message;

#[global_allocator]
static HEAP: Heap = Heap::empty();

bind_interrupts!(struct Irqs {
    USBCTRL_IRQ => InterruptHandler<USB>;
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

    let _ = spawner.spawn(send_dummy_frames_task());
}

#[embassy_executor::task]
async fn usb_task(mut usb: ScopeUsbDevice) -> ! {
    usb.run().await
}

#[embassy_executor::task]
async fn send_dummy_frames_task() -> ! {
    let message_sender = MESSAGE_TX.sender();
    let mut shift = 0;
    loop {
        let mut data = Vec::new();
        for i in 0..1000 {
            data.push((2048.0 * sinf((i + shift) as f32 / 100.0)) as u16);
        }
        shift += 1;
        let message = Message::Frame(FrameData {
            channel: ScopeChannel::A,
            data,
            center: 2048,
            timestep_ms: 0.1,
            voltage_scale: 2.0,
        });

        message_sender.send(message);

        Timer::after_secs(1).await;
    }
}

#[embassy_executor::task]
async fn print_messages_task() -> ! {
    let mut message_receiver = MESSAGE_RX
        .receiver()
        .expect("Failed to create message receiver");
    loop {
        let message = message_receiver.changed().await;
        info!("Received message: {:?}", &message);
    }
}
