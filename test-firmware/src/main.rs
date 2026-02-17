#![no_std]
#![no_main]

extern crate alloc;

use alloc::format;
use embassy_sync::blocking_mutex::raw::ThreadModeRawMutex;
use embassy_sync::channel::Channel;
use embassy_time::Timer;
use embedded_alloc::TlsfHeap as Heap;

use defmt::{info, error, panic};
use embassy_executor::Spawner;
use embassy_rp::bind_interrupts;
use embassy_rp::peripherals::USB;
use embassy_rp::usb::{Driver, Instance, InterruptHandler};
use embassy_usb::UsbDevice;
use embassy_usb::class::cdc_acm::{Sender as CdcSender, Receiver as CdcReceiver, CdcAcmClass, State};
use embassy_usb::driver::EndpointError;
use libm::sinf;
use static_cell::StaticCell;
use {defmt_rtt as _, panic_probe as _};
use alloc::vec::Vec;
use alloc::string::{String, ToString};
use common::message::Message;
use common::frame::{ FrameData, ScopeChannel };
use common::usb::{OSCOPE_VID, OSCOPE_PID};

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
        embedded_alloc::init!(HEAP, 1024*64);
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
        CdcAcmClass::new(&mut builder, state, USB_PACKET_SIZE as u16)
    };

    // Build the builder.
    let usb = builder.build();

    // Run the USB device.
    spawner.spawn(usb_task(usb));

    let (mut tx, mut rx) = class.split();

    spawner.spawn(send_messages_task(tx));
    spawner.spawn(receive_messages_task(rx));

    spawner.spawn(send_dummy_frames_task());
}

#[embassy_executor::task]
async fn usb_task(mut usb: ScopeUsbDevice) -> ! {
    usb.run().await
}

#[embassy_executor::task]
async fn send_messages_task(mut tx: ScopeUsbSender) -> ! {
    loop {
        tx.wait_connection().await;
        info!("USB Connected");
        let _ = send_messages(&mut tx).await;
        info!("USB Disconnected");
    }
}

#[embassy_executor::task]
async fn receive_messages_task(mut rx: ScopeUsbReceiver) -> ! {
    loop {
        rx.wait_connection().await;
        let _ = receive_messages(&mut rx).await;
    }
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

        message_sender.send(message).await;

        Timer::after_secs(1).await;
    }
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

static MESSAGE_RX: Channel<ThreadModeRawMutex, Message, 64> = Channel::new();

async fn receive_messages(rx: &mut ScopeUsbReceiver) -> Result<(), Disconnected> {
    let mut buf = Vec::new();
    let mut packet_buf = [0; USB_PACKET_SIZE];
    let mut message_sender = MESSAGE_RX.sender();
    loop {
        let n = rx.read_packet(&mut packet_buf).await?; 
        // let data = &buf[..n];
        buf.reserve(n);
        for i in 0..n {
            if packet_buf[i] == 0x00 {
                // Received null byte indicating the end of message, parse it.
                match postcard::from_bytes_cobs::<Message>(&mut buf) {
                    Ok(message) => {
                        info!("Received message: {:?}", &message);
                        message_sender.send(message).await;
                    }
                    Err(e) => {
                        error!("Failed to deserialize message: {:?}", defmt::Debug2Format(&e));
                    }
                }
                // Reset the message buffer
                unsafe {
                    // Clear the buffer without explicitely zeroing the elements.
                    // Since the elements are u8, they are stored directly in the Vec,
                    // so they do not need to be free'd.
                    // This is more efficient than calling clear().
                    buf.set_len(0);
                }
            } else {
                buf.push(packet_buf[i]);
            }
        }
    }
}

static MESSAGE_TX: Channel<ThreadModeRawMutex, Message, 64> = Channel::new();

async fn send_messages(tx: &mut ScopeUsbSender) -> Result<(), Disconnected> {
    let mut message_receiver = MESSAGE_TX.receiver();
    loop {        
        let message = message_receiver.receive().await;
        
        let bytes = postcard::to_allocvec_cobs(&message).expect("Serialization failed");

        // Send in chunks of USB_PACKET_SIZE
        for chunk in bytes.chunks(USB_PACKET_SIZE) {
            tx.write_packet(chunk).await?;
        }
    }
}