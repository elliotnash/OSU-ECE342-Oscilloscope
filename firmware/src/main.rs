#![no_std]
#![no_main]

extern crate alloc;

use common::frame::{FrameData, ScopeChannel};
use common::message::{Message, VerificationMessage};
use common::trigger::TriggerOptions;
use defmt::{debug, error, info};
use embassy_rp::adc::Adc;
use embassy_rp::gpio::{Flex, Pull};
use embassy_rp::{Peri, adc, bind_interrupts, i2c, peripherals};
use embassy_time::{Duration, Ticker, Timer};
use embedded_alloc::TlsfHeap as Heap;

use crate::driver::mcp47feb::Mcp47feb;
use crate::message::{MESSAGE_RX, MESSAGE_TX};
use crate::softi2c::SoftI2c;
use common::usb::{OSCOPE_PID, OSCOPE_VID};
use embassy_executor::Spawner;
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
    ADC_IRQ_FIFO => adc::InterruptHandler;
    USBCTRL_IRQ => usb::InterruptHandler<peripherals::USB>;
    I2C1_IRQ => i2c::InterruptHandler<peripherals::I2C1>;
});

const USB_PACKET_SIZE: usize = 64;

type ScopeUsbDriver = Driver<'static, peripherals::USB>;
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

    // Initialize the DAC and message handler

    let sda = Flex::new(p.PIN_7);
    let scl = Flex::new(p.PIN_6);
    let i2c = SoftI2c::new(sda, scl);

    let mut dac = Mcp47feb::new(i2c, driver::mcp47feb::default_address::A0);

    dac.ping().await.expect("DAC ping failed");
    dac.set_vref(
        driver::mcp47feb::DacChannel::Dac0,
        driver::mcp47feb::VrefSource::ExternalBuffered,
    )
    .await
    .expect("Failed to set VREF on channel A");
    dac.set_vref(
        driver::mcp47feb::DacChannel::Dac1,
        driver::mcp47feb::VrefSource::ExternalBuffered,
    )
    .await
    .expect("Failed to set VREF on channel B");

    dac.write_dac(driver::mcp47feb::DacChannel::Dac0, 128).await;
    dac.write_dac(driver::mcp47feb::DacChannel::Dac1, 128).await;

    // trigger input pin
    let mut trigger_pin = Flex::new(p.PIN_21);
    trigger_pin.set_as_input();
    trigger_pin.set_pull(Pull::None);

    let _ = spawner.spawn(handle_messages_task(dac, trigger_pin));

    // Initialize the ADC and frame sender

    let adc = Adc::new(p.ADC, Irqs, adc::Config::default());
    let adc_dma = p.DMA_CH0;
    let adc_pins = [
        adc::Channel::new_pin(p.PIN_26, Pull::None),
        adc::Channel::new_pin(p.PIN_27, Pull::None),
    ];

    let _ = spawner.spawn(read_adc_task(adc, adc_dma, adc_pins));
}

#[embassy_executor::task]
async fn handle_messages_task(mut dac: Mcp47feb<SoftI2c<'static>>, mut trigger_pin: Flex<'static>) -> ! {
    let message_receiver = MESSAGE_RX.receiver();
    let message_sender = MESSAGE_TX.sender();
    loop {
        let message = message_receiver.receive().await;
        match message {
            Message::Heartbeat => {
                let _ = message_sender.try_send(Message::Heartbeat);
            }
            Message::SetTriggerOptions(trigger) => {
                set_trigger_options(&mut dac, &trigger).await;
            }
            Message::SetChannelOptions(_channel) => {}
            Message::SetSampleRate(_sample_rate) => {}
            Message::Verification(verification_message) => {
                match verification_message {
                    VerificationMessage::StartDacTest => {
                        start_dac_test(&mut dac, &mut trigger_pin).await;
                    },
                    _ => {}
                }
            }
            _ => {
                error!("Received unexpected message: {:?}", message);
            }
        }
    }
}

async fn set_trigger_options(dac: &mut Mcp47feb<SoftI2c<'static>>, trigger: &TriggerOptions) {
    let dac_channel = match trigger.channel {
        ScopeChannel::A => driver::mcp47feb::DacChannel::Dac0,
        ScopeChannel::B => driver::mcp47feb::DacChannel::Dac1,
    };

    dac.write_dac(dac_channel, trigger.value as u16)
        .await
        .expect("Failed to write DAC value");
}

async fn start_dac_test(dac: &mut Mcp47feb<SoftI2c<'static>>, trigger_pin: &mut Flex<'static>) {
    dac.write_dac(driver::mcp47feb::DacChannel::Dac0, 0)
        .await
        .expect("Failed to write DAC value");
    Timer::after_millis(100).await;
    dac.write_dac(driver::mcp47feb::DacChannel::Dac0, 128)
        .await
        .expect("Failed to write DAC value");
    Timer::after_nanos(100).await;

    info!("DAC test complete");
    if trigger_pin.is_low() {
        info!("Trigger is low");
    } else {
        info!("Trigger is high");
    }
}

#[embassy_executor::task]
async fn read_adc_task(
    mut adc: Adc<'static, adc::Async>,
    mut adc_dma: Peri<'static, peripherals::DMA_CH0>,
    mut adc_pins: [adc::Channel<'static>; 2],
) -> ! {
    let mut frame_ticker = Ticker::every(Duration::from_micros_floor(16_666));
    let message_sender = MESSAGE_TX.sender();
    const BLOCK_SIZE: usize = 100;
    const NUM_CHANNELS: usize = 2;
    loop {
        // Send frames at 60 Hz
        frame_ticker.next().await;

        let sample_rate = 250_000;

        let mut buf = [0_u16; { BLOCK_SIZE * NUM_CHANNELS }];
        let div = (48_000_000_u32 / (sample_rate * 2) - 1) as u16;
        // debug!("Sampling with div: {}", div);
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
