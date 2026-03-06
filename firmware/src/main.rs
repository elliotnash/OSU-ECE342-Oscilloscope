#![no_std]
#![no_main]

extern crate alloc;

use common::channel::{ChannelOptions, ScopeCoupling, ScopeGain};
use common::frame::{FrameData, ScopeChannel};
use common::message::{CalibrationMessage, Message, VerificationMessage};
use common::trigger::TriggerOptions;
use defmt::{debug, error, info};
use embassy_futures::select::{Either, select};
use embassy_rp::adc::Adc;
use embassy_rp::flash::{Async, ERASE_SIZE, FLASH_BASE, Flash};
use embassy_rp::gpio::{Flex, Level, Pull};
use embassy_rp::i2c::I2c;
use embassy_rp::pio::{self, Pio};
use embassy_rp::pio_programs::ws2812::{Grb, PioWs2812, PioWs2812Program};
use embassy_rp::{Peri, adc, bind_interrupts, i2c, peripherals};
use embassy_sync::blocking_mutex::raw::ThreadModeRawMutex;
use embassy_sync::watch::Watch;
use embassy_time::{Duration, Instant, Ticker, Timer};
use embedded_alloc::TlsfHeap as Heap;
use smart_leds::RGB8;

use crate::driver::mcp47feb::Mcp47feb;
use crate::led::{LED_RX, LedPattern, NUM_LEDS, led_color_task};
use crate::message::{MESSAGE_RX, MESSAGE_TX, USB_CONNECTED};
use crate::nvs::{FLASH_SIZE, NvsProperties, get_nvs_properties, write_nvs_properties};
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
pub mod led;
pub mod message;
pub mod nvs;

#[global_allocator]
static HEAP: Heap = Heap::empty();

bind_interrupts!(struct Irqs {
    // Neopixel PIO interrupts
    PIO0_IRQ_0 => pio::InterruptHandler<peripherals::PIO0>;
    // ADC interrupts
    ADC_IRQ_FIFO => adc::InterruptHandler;
    // USB interrupts
    USBCTRL_IRQ => usb::InterruptHandler<peripherals::USB>;
    // I2C interrupts
    I2C1_IRQ => i2c::InterruptHandler<peripherals::I2C1>;
});

const USB_PACKET_SIZE: usize = 64;

pub static LAST_HEARTBEAT_TIME: Watch<ThreadModeRawMutex, Instant, 1> = Watch::new();
pub static SAMPLE_RATE: Watch<ThreadModeRawMutex, u32, 1> = Watch::new();

type ScopeUsbDriver = Driver<'static, peripherals::USB>;
type ScopeUsbDevice = UsbDevice<'static, ScopeUsbDriver>;
type ScopeUsbClass = CdcAcmClass<'static, ScopeUsbDriver>;
type ScopeUsbSender = CdcSender<'static, ScopeUsbDriver>;
type ScopeUsbReceiver = CdcReceiver<'static, ScopeUsbDriver>;

#[embassy_executor::main]
async fn main(spawner: Spawner) -> ! {
    // Initialize the heap allocator
    unsafe {
        embedded_alloc::init!(HEAP, 1024 * 64);
    }

    let p = embassy_rp::init(Default::default());

    // add some delay to give an attached debug probe time to parse the
    // defmt RTT header. Reading that header might touch flash memory, which
    // interferes with flash write operations.
    // https://github.com/knurling-rs/defmt/pull/683
    Timer::after_millis(10).await;

    // Create neopixel pio
    let Pio {
        mut common, sm0, ..
    } = Pio::new(p.PIO0, Irqs);

    let program = PioWs2812Program::new(&mut common);
    let ws2812 =
        PioWs2812::<_, _, NUM_LEDS, Grb>::new(&mut common, sm0, p.DMA_CH0, p.PIN_9, &program);

    let _ = spawner.spawn(led_color_task(ws2812));

    // Create the NVS
    let mut flash = embassy_rp::flash::Flash::<_, Async, FLASH_SIZE>::new(p.FLASH, p.DMA_CH2);
    let nvs_properties = get_nvs_properties(&mut flash);

    // Create the USB driver, from the HAL.
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
    let _ = spawner.spawn(heartbeat_monitor_task());

    // Initialize the DAC and message handler

    let sda = p.PIN_6;
    let scl = p.PIN_7;
    let config = embassy_rp::i2c::Config::default();
    let i2c = I2c::new_async(p.I2C1, scl, sda, Irqs, config);

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

    dac.write_dac(driver::mcp47feb::DacChannel::Dac0, 128)
        .await
        .expect("Failed to write DAC value");
    dac.write_dac(driver::mcp47feb::DacChannel::Dac1, 128)
        .await
        .expect("Failed to write DAC value");

    // trigger input pin
    let mut trigger_pin = Flex::new(p.PIN_21);
    trigger_pin.set_as_input();
    trigger_pin.set_pull(Pull::None);

    // Output pins
    let mut coupling_pins = [Flex::new(p.PIN_10), Flex::new(p.PIN_13)];
    let mut sel1_pins = [Flex::new(p.PIN_11), Flex::new(p.PIN_14)];
    let mut sel2_pins = [Flex::new(p.PIN_12), Flex::new(p.PIN_15)];

    for pin in coupling_pins
        .iter_mut()
        .chain(sel1_pins.iter_mut())
        .chain(sel2_pins.iter_mut())
    {
        pin.set_as_output();
        pin.set_low();
    }

    let _ = spawner.spawn(handle_messages_task(
        dac,
        flash,
        trigger_pin,
        coupling_pins,
        sel1_pins,
        sel2_pins,
        nvs_properties.clone(),
    ));

    // Initialize the ADC and frame sender

    let adc = Adc::new(p.ADC, Irqs, adc::Config::default());
    let adc_dma = p.DMA_CH1;
    let adc_pins = [
        adc::Channel::new_pin(p.PIN_26, Pull::None),
        adc::Channel::new_pin(p.PIN_27, Pull::None),
    ];

    let _ = spawner.spawn(read_adc_task(adc, adc_dma, adc_pins, nvs_properties));

    info!("Firmware started");

    loop {
        Timer::after_secs(1).await;
    }
}

#[embassy_executor::task]
async fn heartbeat_monitor_task() -> ! {
    let mut heartbeat_receiver = LAST_HEARTBEAT_TIME
        .receiver()
        .expect("Failed to get heartbeat receiver");

    let mut usb_connected_receiver = USB_CONNECTED
        .receiver()
        .expect("Failed to get USB connected receiver");

    let led_sender = LED_RX.sender();

    let mut last = Instant::now();

    loop {
        // Only consider disconnected if it is disconnected from client, but the USB is still connected
        let usb_connected = usb_connected_receiver.get().await;
        if !usb_connected {
            usb_connected_receiver.changed().await;
            continue;
        }

        // Wait for either a new heartbeat or for 1100 ms to elapse since `last`
        let deadline = last + Duration::from_millis(1100);

        match select(Timer::at(deadline), heartbeat_receiver.changed()).await {
            // Timer fired first so no heartbeat in 1100 ms, disconnected
            Either::First(_) => {
                // Consider USB/client disconnected
                // Blink pink LED when USB is connected (but the client app is not yet connected)
                led_sender.send(LedPattern::Blink(RGB8::new(128, 20, 64), 1000));
            }
            // Heartbeat arrived first, so client is still connected
            Either::Second(_) => {
                last = heartbeat_receiver.get().await;
                // Pulse green LED when client is connected
                led_sender.send(LedPattern::Pulse(RGB8::new(50, 200, 0), 1000));
            }
        }
    }
}

#[embassy_executor::task]
async fn handle_messages_task(
    mut dac: Mcp47feb<I2c<'static, peripherals::I2C1, embassy_rp::i2c::Async>>,
    mut flash: Flash<'static, peripherals::FLASH, Async, FLASH_SIZE>,
    mut trigger_pin: Flex<'static>,
    mut coupling_pins: [Flex<'static>; 2],
    mut sel1_pins: [Flex<'static>; 2],
    mut sel2_pins: [Flex<'static>; 2],
    mut calibration: NvsProperties,
) -> ! {
    let heartbeat_sender = LAST_HEARTBEAT_TIME.sender();
    let message_receiver = MESSAGE_RX.receiver();
    let message_sender = MESSAGE_TX.sender();
    let sample_rate_sender = SAMPLE_RATE.sender();
    loop {
        let message = message_receiver.receive().await;
        match message {
            Message::Heartbeat => {
                let _ = message_sender.try_send(Message::Heartbeat);
                heartbeat_sender.send(Instant::now());
            }
            Message::SetTriggerOptions(trigger) => {
                set_trigger_options(&mut dac, &trigger, &calibration).await;
            }
            Message::SetChannelOptions(channel) => {
                set_channel_options(&mut coupling_pins, &mut sel1_pins, &mut sel2_pins, &channel)
                    .await;
            }
            Message::SetSampleRate(sample_rate) => {
                sample_rate_sender.send(sample_rate);
            }
            Message::Calibration(calibration_message) => {
                match calibration_message {
                    CalibrationMessage::CalibrateCenter(data) => {
                        calibration.centers[data.channel as usize] = data.value;
                    }
                    CalibrationMessage::CalibrateMax(data) => {
                        calibration.maxes[data.channel as usize] = data.value;
                    }
                    CalibrationMessage::CalibrateMin(data) => {
                        calibration.mins[data.channel as usize] = data.value;
                    }
                }
                write_nvs_properties(&mut flash, &calibration);
            }
            Message::Verification(verification_message) => match verification_message {
                VerificationMessage::StartDacTest => {
                    start_dac_test(&mut dac, &mut trigger_pin).await;
                }
                VerificationMessage::SetGpioHigh => {
                    for pin in coupling_pins
                        .iter_mut()
                        .chain(sel1_pins.iter_mut())
                        .chain(sel2_pins.iter_mut())
                    {
                        pin.set_high();
                    }
                }
                VerificationMessage::SetGpioLow => {
                    for pin in coupling_pins
                        .iter_mut()
                        .chain(sel1_pins.iter_mut())
                        .chain(sel2_pins.iter_mut())
                    {
                        pin.set_low();
                    }
                }
                _ => {}
            },
            _ => {
                error!("Received unexpected message: {:?}", message);
            }
        }
    }
}

async fn set_channel_options(
    coupling_pins: &mut [Flex<'static>; 2],
    sel1_pins: &mut [Flex<'static>; 2],
    sel2_pins: &mut [Flex<'static>; 2],
    channel: &ChannelOptions,
) {
    info!("Setting channel options: {:?}", channel);
    let channel_index = channel.channel.clone() as usize;
    // Set the coupling pin
    coupling_pins[channel_index].set_level(if channel.coupling == ScopeCoupling::DC {
        Level::High
    } else {
        Level::Low
    });

    // Set the sel1 pin
    sel1_pins[channel_index].set_level(if channel.voltage_gain == ScopeGain::Four {
        Level::High
    } else {
        Level::Low
    });

    // Set the sel2 pin
    sel2_pins[channel_index].set_level(if channel.voltage_gain == ScopeGain::Twenty {
        Level::High
    } else {
        Level::Low
    });
}

async fn set_trigger_options(
    dac: &mut Mcp47feb<I2c<'static, peripherals::I2C1, embassy_rp::i2c::Async>>,
    trigger: &TriggerOptions,
    calibration: &NvsProperties,
) {
    let dac_channel = match trigger.channel {
        ScopeChannel::A => driver::mcp47feb::DacChannel::Dac0,
        ScopeChannel::B => driver::mcp47feb::DacChannel::Dac1,
    };

    dac.write_dac(dac_channel, trigger.value as u16)
        .await
        .expect("Failed to write DAC value");
}

async fn start_dac_test(
    dac: &mut Mcp47feb<I2c<'static, peripherals::I2C1, embassy_rp::i2c::Async>>,
    trigger_pin: &mut Flex<'static>,
) {
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
    mut adc_dma: Peri<'static, peripherals::DMA_CH1>,
    mut adc_pins: [adc::Channel<'static>; 2],
    calibration: NvsProperties,
) -> ! {
    let mut frame_ticker = Ticker::every(Duration::from_micros_floor(16_666));
    let message_sender = MESSAGE_TX.sender();
    let mut sample_rate_receiver = SAMPLE_RATE
        .receiver()
        .expect("Failed to get sample rate receiver");
    let mut sample_rate = 250_000;
    const BLOCK_SIZE: usize = 100;
    const NUM_CHANNELS: usize = 2;
    loop {
        // Send frames at 60 Hz
        frame_ticker.next().await;

        if let Some(new_rate) = sample_rate_receiver.try_changed() {
            frame_ticker.reset();
            sample_rate = new_rate;
            info!("Sample rate changed to {}", sample_rate);
        }

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
            voltage_scale: 6.6,
            channel: ScopeChannel::A,
            timestep_ms: 0.005, // This should be timestep of 200kHz
        };
        let _ = message_sender.try_send(Message::Frame(ch_a_frame));

        let ch_b_samples = buf.iter().skip(1).step_by(2);
        let ch_b_frame = FrameData {
            data: ch_b_samples.copied().collect(),
            center: 2048,
            voltage_scale: 6.6,
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
