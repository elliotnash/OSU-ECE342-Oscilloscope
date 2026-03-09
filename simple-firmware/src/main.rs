#![no_std]
#![no_main]

extern crate alloc;

use common::frame::{FrameData, ScopeChannel};
use defmt::info;
use embassy_rp::adc::Adc;
use embassy_rp::gpio::{Flex, Pull};
use embassy_rp::i2c::I2c;
use embassy_rp::{adc, bind_interrupts, i2c, peripherals};
use embassy_time::{Duration, Instant, Ticker, Timer};
use embedded_alloc::TlsfHeap as Heap;

use crate::driver::mcp47feb::Mcp47feb;

use embassy_executor::Spawner;

use {defmt_rtt as _, panic_probe as _};

pub mod driver;

#[global_allocator]
static HEAP: Heap = Heap::empty();

bind_interrupts!(struct Irqs {
    // ADC interrupts
    ADC_IRQ_FIFO => adc::InterruptHandler;
    // I2C interrupts
    I2C1_IRQ => i2c::InterruptHandler<peripherals::I2C1>;
});

#[embassy_executor::main]
async fn main(spawner: Spawner) -> ! {
    // Initialize the heap allocator
    unsafe {
        embedded_alloc::init!(HEAP, 1024 * 256);
    }

    let p = embassy_rp::init(Default::default());

    // add some delay to give an attached debug probe time to parse the
    // defmt RTT header. Reading that header might touch flash memory, which
    // interferes with flash write operations.
    // https://github.com/knurling-rs/defmt/pull/683
    Timer::after_millis(10).await;

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

    // trigger input pins
    let mut trigger_pins = [Flex::new(p.PIN_21), Flex::new(p.PIN_20)];
    for pin in trigger_pins.iter_mut() {
        pin.set_as_input();
        pin.set_pull(Pull::None);
    }

    // Output pins
    let mut coupling_pins = [Flex::new(p.PIN_10), Flex::new(p.PIN_13)];
    let mut sel1_pins = [Flex::new(p.PIN_11), Flex::new(p.PIN_14)];
    let mut sel2_pins = [Flex::new(p.PIN_12), Flex::new(p.PIN_15)];

    for pin in coupling_pins.iter_mut() {
        pin.set_as_output();
        pin.set_high();
    }

    for pin in sel1_pins.iter_mut().chain(sel2_pins.iter_mut()) {
        pin.set_as_output();
        pin.set_low();
    }

    // Initialize the ADC and frame sender

    let mut adc = Adc::new(p.ADC, Irqs, adc::Config::default());
    let mut adc_dma = p.DMA_CH1;
    let mut adc_pins = [
        adc::Channel::new_pin(p.PIN_26, Pull::None),
        adc::Channel::new_pin(p.PIN_27, Pull::None),
    ];

    info!("Firmware started");

    let mut frame_ticker = Ticker::every(Duration::from_micros_floor(16_666 * 60));

    // let sample_rate = 250_000;
    // const BLOCK_SIZE: usize = 1000;
    // const NUM_CHANNELS: usize = 2;
    loop {
        // Busy-poll for falling edge instead of wait_for_falling_edge().await.
        // IRQ + async wake adds many µs of latency; by the time we read the ADC
        // the signal has already moved past 0V. Spinning here keeps us in the
        // same context so we start the ADC read within ~hundreds of ns of the edge.
        // trigger_pins[0].wait_for_high().await;
        while trigger_pins[0].is_low() {}
        while trigger_pins[0].is_high() {}

        // trigger_pins[0].wait_for_falling_edge().await;

        // let value = adc
        //     .blocking_read(&mut adc_pins[0])
        //     .expect("Failed to read ADC value");

        let value = adc
            .read(&mut adc_pins[0])
            .await
            .expect("Failed to read ADC value");
        info!("ADC value: {}", value);

        // Rate-limit to 60 Hz after capture (so we're always ready for the next edge).
        frame_ticker.next().await;

        // adc.read_many_multichannel(&mut adc_pins, &mut buf, div, adc_dma.reborrow())
        //     .await
        //     .expect("Failed to read ADC samples");

        // let ch_a_samples = buf.iter().step_by(2);
        // let ch_a_frame = FrameData {
        //     data: ch_a_samples.copied().collect(),
        //     center: 2048,
        //     voltage_scale: 3.3,
        //     channel: ScopeChannel::A,
        //     timestep_ms: 1000.0 / (sample_rate as f32),
        // };

        // let ch_b_samples = buf.iter().skip(1).step_by(2);
        // let ch_b_frame = FrameData {
        //     data: ch_b_samples.copied().collect(),
        //     center: 2048,
        //     voltage_scale: 3.3,
        //     channel: ScopeChannel::B,
        //     timestep_ms: 1000.0 / (sample_rate as f32),
        // };

        // info!("FINISHED READING");

        // info!("Channel A: {:?}", ch_a_frame);
    }
}

// Program metadata for `picotool info`.
#[unsafe(link_section = ".bi_entries")]
#[used]
pub static PICOTOOL_ENTRIES: [embassy_rp::binary_info::EntryAddr; 4] = [
    embassy_rp::binary_info::rp_program_name!(c"ECE342-Oscilloscope/simple-firmware"),
    embassy_rp::binary_info::rp_program_description!(
        c"Simple Firmware for the ECE342 Oscilloscope"
    ),
    embassy_rp::binary_info::rp_cargo_version!(),
    embassy_rp::binary_info::rp_program_build_attribute!(),
];
