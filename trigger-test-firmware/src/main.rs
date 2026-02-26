#![no_std]
#![no_main]

extern crate alloc;

use alloc::format;
use alloc::string::String;
use alloc::vec::Vec;
use embassy_rp::gpio::{Flex, Pull};
use embassy_time::Timer;
// use common::frame::{FrameData, ScopeChannel};
// use common::message::Message;
// use common::trigger::TriggerOptions;
// use defmt::{debug, error, info};
// use embassy_rp::adc::Adc;
// use embassy_rp::gpio::{Flex, Pull};
// use embassy_rp::{Peri, adc, bind_interrupts, i2c, peripherals};
// use embassy_time::{Duration, Ticker};
use embedded_alloc::TlsfHeap as Heap;

use crate::driver::mcp47feb::Mcp47feb;
// use crate::message::{MESSAGE_RX, MESSAGE_TX};
use crate::softi2c::SoftI2c;
// use common::usb::{OSCOPE_PID, OSCOPE_VID};
// use embassy_executor::Spawner;
// use embassy_rp::usb::{self, Driver};
// use embassy_usb::UsbDevice;
// use embassy_usb::class::cdc_acm::{
//     CdcAcmClass, Receiver as CdcReceiver, Sender as CdcSender, State,
// };
// use message::{receive_messages_task, send_messages_task};
// use static_cell::StaticCell;

// use {defmt_rtt as _, panic_probe as _};

pub mod driver;
pub mod softi2c;

#[global_allocator]
static HEAP: Heap = Heap::empty();

// bind_interrupts!(struct Irqs {
//     ADC_IRQ_FIFO => adc::InterruptHandler;
//     USBCTRL_IRQ => usb::InterruptHandler<peripherals::USB>;
//     I2C1_IRQ => i2c::InterruptHandler<peripherals::I2C1>;
// });

// const USB_PACKET_SIZE: usize = 64;

// type ScopeUsbDriver = Driver<'static, peripherals::USB>;
// type ScopeUsbDevice = UsbDevice<'static, ScopeUsbDriver>;
// type ScopeUsbClass = CdcAcmClass<'static, ScopeUsbDriver>;
// type ScopeUsbSender = CdcSender<'static, ScopeUsbDriver>;
// type ScopeUsbReceiver = CdcReceiver<'static, ScopeUsbDriver>;

// #[embassy_executor::main]
// async fn main(spawner: Spawner) {
//     // Initialize the heap allocator
//     unsafe {
//         embedded_alloc::init!(HEAP, 1024 * 64);
//     }

//     let p = embassy_rp::init(Default::default());

//     // Create the driver, from the HAL.
//     let driver = Driver::new(p.USB, Irqs);

//     // Create embassy-usb Config
//     let config = {
//         let mut config = embassy_usb::Config::new(OSCOPE_VID, 0x1234);
//         config.manufacturer = Some("ECE342");
//         config.product = Some("USB Oscilloscope");
//         config.serial_number = Some("12345678");
//         config.max_power = 100;
//         config.max_packet_size_0 = 64;
//         config
//     };

//     // Create embassy-usb DeviceBuilder using the driver and config.
//     // It needs some buffers for building the descriptors.
//     let mut builder = {
//         static CONFIG_DESCRIPTOR: StaticCell<[u8; 256]> = StaticCell::new();
//         static BOS_DESCRIPTOR: StaticCell<[u8; 256]> = StaticCell::new();
//         static CONTROL_BUF: StaticCell<[u8; 64]> = StaticCell::new();

//         let builder = embassy_usb::Builder::new(
//             driver,
//             config,
//             CONFIG_DESCRIPTOR.init([0; 256]),
//             BOS_DESCRIPTOR.init([0; 256]),
//             &mut [], // no msos descriptors
//             CONTROL_BUF.init([0; 64]),
//         );
//         builder
//     };

//     // Create classes on the builder.
//     let class: ScopeUsbClass = {
//         static STATE: StaticCell<State> = StaticCell::new();
//         let state = STATE.init(State::new());
//         CdcAcmClass::new(&mut builder, state, USB_PACKET_SIZE as u16)
//     };

//     // Build the builder.
//     let usb = builder.build();

//     // Run the USB device.
//     let _ = spawner.spawn(usb_task(usb));

//     // Initialize the DAC and message handler

//     let sda = Flex::new(p.PIN_7);
//     let scl = Flex::new(p.PIN_6);
//     let i2c = SoftI2c::new(sda, scl);

//     let mut dac = Mcp47feb::new(i2c, driver::mcp47feb::default_address::A0);

//     dac.ping().await.expect("DAC ping failed");
//     dac.set_vref(
//         driver::mcp47feb::DacChannel::Dac0,
//         driver::mcp47feb::VrefSource::ExternalUnbuffered,
//     )
//     .await
//     .expect("Failed to set VREF on channel A");
//     dac.set_vref(
//         driver::mcp47feb::DacChannel::Dac1,
//         driver::mcp47feb::VrefSource::ExternalUnbuffered,
//     )
//     .await
//     .expect("Failed to set VREF on channel B");
// }

// async fn set_trigger_options(dac: &mut Mcp47feb<SoftI2c<'static>>, trigger: &TriggerOptions) {
//     let dac_channel = match trigger.channel {
//         ScopeChannel::A => driver::mcp47feb::DacChannel::Dac0,
//         ScopeChannel::B => driver::mcp47feb::DacChannel::Dac1,
//     };

//     dac.write_dac(dac_channel, trigger.value as u16)
//         .await
//         .expect("Failed to write DAC value");
// }

// #[embassy_executor::task]
// async fn usb_task(mut usb: ScopeUsbDevice) -> ! {
//     usb.run().await
// }

use defmt::{info, panic, unwrap};
use embassy_executor::Spawner;
use embassy_rp::bind_interrupts;
use embassy_rp::peripherals::USB;
use embassy_rp::usb::{Driver, Instance, InterruptHandler};
use embassy_usb::UsbDevice;
use embassy_usb::class::cdc_acm::{CdcAcmClass, State};
use embassy_usb::driver::EndpointError;
use static_cell::StaticCell;
use {defmt_rtt as _, panic_probe as _};

bind_interrupts!(struct Irqs {
    USBCTRL_IRQ => InterruptHandler<USB>;
});

#[embassy_executor::main]
async fn main(spawner: Spawner) {
    // Initialize the heap allocator
    unsafe {
        embedded_alloc::init!(HEAP, 1024 * 64);
    }

    info!("Hello there!");

    let p = embassy_rp::init(Default::default());

    // Create the driver, from the HAL.
    let driver = Driver::new(p.USB, Irqs);

    // Create embassy-usb Config
    let config = {
        let mut config = embassy_usb::Config::new(0xc0de, 0xcafe);
        config.manufacturer = Some("Embassy");
        config.product = Some("USB-serial example");
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
    let _ = spawner.spawn(usb_task(usb));

    let sda = Flex::new(p.PIN_7);
    let scl = Flex::new(p.PIN_6);
    let i2c = SoftI2c::new(sda, scl);

    let mut dac = Mcp47feb::new(i2c, driver::mcp47feb::default_address::A0);

    dac.ping().await.expect("DAC ping failed");
    dac.set_vref(
        driver::mcp47feb::DacChannel::Dac0,
        driver::mcp47feb::VrefSource::Vdd,
    )
    .await
    .expect("Failed to set VREF on channel A");

    dac.write_dac(driver::mcp47feb::DacChannel::Dac0, 255)
        .await
        .expect("Failed to write DAC value");

    dac.write_dac(driver::mcp47feb::DacChannel::Dac1, 255)
        .await
        .expect("Failed to write DAC value");

    // trigger input pin
    let mut trigger_pin = Flex::new(p.PIN_5);
    trigger_pin.set_as_input();
    trigger_pin.set_pull(Pull::None);

    // Do stuff with the class!
    loop {
        class.wait_connection().await;
        info!("Connected");
        let _ = dac_loop(&mut class, &mut dac, &mut trigger_pin).await;
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

async fn dac_loop<'d, T: Instance + 'd>(
    class: &mut CdcAcmClass<'d, Driver<'d, T>>,
    dac: &mut Mcp47feb<SoftI2c<'static>>,
    trigger_pin: &mut Flex<'static>,
) -> Result<(), Disconnected> {
    let mut buf = Vec::new();
    let mut packet_buf = [0; 64];
    loop {
        let n = class.read_packet(&mut packet_buf).await?;
        buf.reserve(n);
        for i in 0..n {
            if packet_buf[i] == '|' as u8 {
                // Received new line
                let input = String::from_utf8(buf.clone());

                if let Ok(input) = input {
                    // Process input

                    let output = format!("Received command: {}\n", input);

                    let value = input.parse::<u8>();
                    if let Ok(value) = value {
                        dac.write_dac(driver::mcp47feb::DacChannel::Dac0, value as u16)
                            .await
                            .expect("Failed to write DAC value");

                        let output = format!("Wrote value: {}\n", value);
                        class.write_packet(output.as_bytes()).await?;

                        Timer::after_nanos(100).await;

                        if trigger_pin.is_low() {
                            class.write_packet("Trigger is true\n".as_bytes()).await?;
                        } else {
                            class.write_packet("Trigger is false\n".as_bytes()).await?;
                        }
                    } else {
                        class.write_packet("Invalid value\n".as_bytes()).await?;
                    }

                    class.write_packet(output.as_bytes()).await?;
                } else {
                    class.write_packet("Invalid input\n".as_bytes()).await?;
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
    // let mut buf = [0; 64];
    // loop {
    //     loop {
    //         let n = class.read_packet(&mut buf).await?;

    //     }
    //     let data = &buf[..n];
    //     info!("data: {:x}", data);
    //     let test = "Test Output";
    //     class.write_packet(test.as_bytes()).await?;
    // }
}
