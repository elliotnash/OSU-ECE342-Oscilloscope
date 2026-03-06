use common::usb::{OSCOPE_PID, OSCOPE_VID};
use defmt::info;
use embassy_rp::{
    flash::{Async, ERASE_SIZE, Flash},
    peripherals::FLASH,
};

pub const FLASH_SIZE: usize = 16 * 1024 * 1024;
pub const NVS_SIZE: usize = ERASE_SIZE;
pub const NVS_OFFSET: u32 = (FLASH_SIZE - NVS_SIZE) as u32;

const MAGIC_NUMBER: u32 = OSCOPE_PID as u32 | ((OSCOPE_VID as u32) << 16);
const VERSION: u8 = 1;

const MAGIC_LOCATION: u32 = 0;
const VERSION_LOCATION: u32 = MAGIC_LOCATION + 4;
const CENTER_LOCATION: u32 = VERSION_LOCATION + 1;
#[allow(unused)]
const MAX_LOCATION: u32 = CENTER_LOCATION + 4;
#[allow(unused)]
const MIN_LOCATION: u32 = MAX_LOCATION + 4;

const DEFAULT_CENTER: u16 = 2048;
const DEFAULT_MAX: u16 = 4095;
const DEFAULT_MIN: u16 = 0;

#[derive(Debug, Clone, PartialEq, defmt::Format)]
pub struct NvsProperties {
    pub centers: [u16; 2],
    pub maxes: [u16; 2],
    pub mins: [u16; 2],
}

pub fn get_nvs_properties(flash: &mut Flash<'static, FLASH, Async, FLASH_SIZE>) -> NvsProperties {
    // Read NVS magic number. If this is not correct, we need to initialize NVS.
    let mut header_buffer = [0_u8; CENTER_LOCATION as usize];
    flash
        .blocking_read(NVS_OFFSET + MAGIC_LOCATION, &mut header_buffer)
        .expect("Failed to read NVS magic number");
    let magic = u32::from_ne_bytes(header_buffer[0..4].try_into().unwrap());
    let version = header_buffer[4];

    info!("NVS Magic: {:08X}, Version: {}", magic, version);

    if magic != MAGIC_NUMBER {
        init_nvs(flash);
    }

    // Read the properties from NVS.
    let mut properties_buffer = [0_u8; 12];
    flash
        .blocking_read(NVS_OFFSET + CENTER_LOCATION, &mut properties_buffer)
        .expect("Failed to read NVS center");
    let centers = [
        u16::from_ne_bytes(properties_buffer[0..2].try_into().unwrap()),
        u16::from_ne_bytes(properties_buffer[2..4].try_into().unwrap()),
    ];
    let maxes = [
        u16::from_ne_bytes(properties_buffer[4..6].try_into().unwrap()),
        u16::from_ne_bytes(properties_buffer[6..8].try_into().unwrap()),
    ];
    let mins = [
        u16::from_ne_bytes(properties_buffer[8..10].try_into().unwrap()),
        u16::from_ne_bytes(properties_buffer[10..12].try_into().unwrap()),
    ];

    let properties = NvsProperties {
        centers,
        maxes,
        mins,
    };

    info!("NVS Properties: {:?}", properties);

    properties
}

fn init_nvs(flash: &mut Flash<'static, FLASH, Async, FLASH_SIZE>) {
    info!("NVS Uninitialized, erasing and populating defaults");

    flash
        .blocking_erase(NVS_OFFSET, FLASH_SIZE as u32)
        .expect("Failed to erase NVS");

    let mut buf = [0u8; 5];
    buf[0..4].copy_from_slice(&MAGIC_NUMBER.to_ne_bytes());
    buf[4] = VERSION;

    flash
        .blocking_write(NVS_OFFSET, &buf)
        .expect("Failed to write NVS defaults");

    write_nvs_properties(
        flash,
        &NvsProperties {
            centers: [DEFAULT_CENTER, DEFAULT_CENTER],
            maxes: [DEFAULT_MAX, DEFAULT_MAX],
            mins: [DEFAULT_MIN, DEFAULT_MIN],
        },
    );

    info!("NVS Initialized");
}

pub fn write_nvs_properties(
    flash: &mut Flash<'static, FLASH, Async, FLASH_SIZE>,
    properties: &NvsProperties,
) {
    let mut buf = [0u8; 12];
    buf[0..2].copy_from_slice(&properties.centers[0].to_ne_bytes());
    buf[2..4].copy_from_slice(&properties.centers[1].to_ne_bytes());
    buf[4..6].copy_from_slice(&properties.maxes[0].to_ne_bytes());
    buf[6..8].copy_from_slice(&properties.maxes[1].to_ne_bytes());
    buf[8..10].copy_from_slice(&properties.mins[0].to_ne_bytes());
    buf[10..12].copy_from_slice(&properties.mins[1].to_ne_bytes());

    flash
        .blocking_write(NVS_OFFSET + CENTER_LOCATION, &buf)
        .expect("Failed to write NVS properties");

    info!("NVS Properties written {:?}", properties);
}
