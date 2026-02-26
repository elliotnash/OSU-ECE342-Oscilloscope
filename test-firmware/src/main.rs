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
use embassy_rp::adc::Adc;
use embassy_executor::Spawner;
use embassy_rp::{Peri, adc, bind_interrupts, i2c, peripherals};
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
    ADC_IRQ_FIFO => adc::InterruptHandler;
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

    
    let adc = Adc::new(p.ADC, Irqs, adc::Config::default());
    let adc_dma = p.DMA_CH0;
    let adc_pins = [
        adc::Channel::new_pin(p.PIN_26, Pull::None),
        adc::Channel::new_pin(p.PIN_27, Pull::None),
    ];

    let _ = spawner.spawn(read_adc_task(adc, adc_dma, adc_pins));
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
        .receiver();
    loop {
        let message = message_receiver.receive().await;
        info!("Received message: {:?}", &message);
    }
}

#[embassy_executor::task]
async fn read_adc_task(
    mut adc: Adc<'static, adc::Async>,
    mut adc_dma: Peri<'static, peripherals::DMA_CH0>,
    mut adc_pins: [adc::Channel<'static>; 2],
) -> ! {
    let mut frame_ticker = Ticker::every(Duration::from_micros_floor(16_666 * 60));
    let message_sender = MESSAGE_TX.sender();
    const BLOCK_SIZE: usize = 100;
    const NUM_CHANNELS: usize = 2;
    loop {
        // Send frames at 60 Hz
        frame_ticker.next().await;

        let sample_rate = 250_000;

        let mut buf = [0_u16; { BLOCK_SIZE * NUM_CHANNELS }];
        let div = (48_000_000_u32 / (sample_rate * 2) - 1) as u16;
        debug!("Sampling with div: {}", div);
        adc.read_many_multichannel(&mut adc_pins, &mut buf, div, adc_dma.reborrow())
            .await
            .expect("Failed to read ADC samples");

        let ch_a_samples = buf.iter().step_by(2);
        let ch_a_frame = FrameData {
            data: ch_a_samples.copied().collect(),
            center: 2048,
            voltage_scale: 2.0,
            channel: ScopeChannel::A,
            timestep_ms: 0.005, // This should be timestep of 200kHz
        };
        let _ = message_sender.try_send(Message::Frame(ch_a_frame));

        let ch_b_samples = buf.iter().skip(1).step_by(2);
        let ch_b_frame = FrameData {
            data: ch_b_samples.copied().collect(),
            center: 2048,
            voltage_scale: 2.0,
            channel: ScopeChannel::B,
            timestep_ms: 0.005, // This should be timestep of 200kHz
        };
        let _ = message_sender.try_send(Message::Frame(ch_b_frame));
    }
}