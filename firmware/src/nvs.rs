use common::usb::{OSCOPE_PID, OSCOPE_VID};
use defmt::info;
use embassy_rp::{
    flash::{Async, ERASE_SIZE, Flash},
    peripherals::FLASH,
};
use embassy_sync::{blocking_mutex::raw::CriticalSectionRawMutex, watch::Watch};

#[macro_use]
mod macros;

pub const FLASH_SIZE: usize = 16 * 1024 * 1024;
pub const NVS_SIZE: usize = ERASE_SIZE;
pub const NVS_OFFSET: u32 = (FLASH_SIZE - NVS_SIZE) as u32;

const MAGIC_NUMBER: u32 = OSCOPE_PID as u32 | ((OSCOPE_VID as u32) << 16);
const VERSION: u8 = 1;

nvs_layout! {
    magic: u32
    version: u8
    center_a: u16
    center_b: u16
    max_a: u16
    max_b: u16
    min_a: u16
    min_b: u16
}

const DEFAULT_CENTER: u16 = 2048;
const DEFAULT_MAX: u16 = 4095;
const DEFAULT_MIN: u16 = 0;

pub static NVS_PROPERTIES_WATCH: Watch<CriticalSectionRawMutex, (NvsProperties, bool), 4> =
    Watch::new();

#[derive(Debug, Clone, PartialEq, defmt::Format)]
pub struct NvsProperties {
    pub centers: [u16; 2],
    pub maxes: [u16; 2],
    pub mins: [u16; 2],
}

#[embassy_executor::task]
pub async fn nvs_properties_task(mut flash: Flash<'static, FLASH, Async, FLASH_SIZE>) -> ! {
    let nvs_properties_sender = NVS_PROPERTIES_WATCH.sender();
    let mut nvs_properties_receiver = NVS_PROPERTIES_WATCH
        .receiver()
        .expect("Failed to get NVS properties receiver");

    // Get saved properties from NVS (initing if needed)
    let nvs_properties = get_nvs_properties(&mut flash);
    nvs_properties_sender.send((nvs_properties, false));

    // Watch for changes to the NVS properties, and if save is true, write to flash
    loop {
        let (nvs_properties, save) = nvs_properties_receiver.changed().await;
        if save {
            write_nvs_properties(&mut flash, &nvs_properties);
        }
    }
}

pub fn get_nvs_properties(flash: &mut Flash<'static, FLASH, Async, FLASH_SIZE>) -> NvsProperties {
    // Read NVS magic number. If this is not correct, we need to initialize NVS.
    let mut buffer = [0_u8; NVS_LAYOUT.length as usize];
    flash
        .blocking_read(NVS_OFFSET, &mut buffer)
        .expect("Failed to read NVS properties");

    let magic = read_u32!(buffer, magic);
    let version = read_u8!(buffer, version);

    info!("NVS Magic: {:08X}, Version: {}", magic, version);

    if magic != MAGIC_NUMBER || version != VERSION {
        init_nvs(flash);

        // Read new properties from flash
        flash
            .blocking_read(NVS_OFFSET, &mut buffer)
            .expect("Failed to read NVS properties");
    }

    let centers = [read_u16!(buffer, center_a), read_u16!(buffer, center_b)];
    let maxes = [read_u16!(buffer, max_a), read_u16!(buffer, max_b)];
    let mins = [read_u16!(buffer, min_a), read_u16!(buffer, min_b)];

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
    flash
        .blocking_erase(NVS_OFFSET, NVS_OFFSET + NVS_SIZE as u32)
        .expect("Failed to erase NVS before write");

    let mut buffer = [0u8; NVS_LAYOUT.length as usize];

    // Write header
    write_u32!(buffer, magic, MAGIC_NUMBER);
    write_u8!(buffer, version, VERSION);

    // Write properties
    write_u16!(buffer, center_a, properties.centers[0]);
    write_u16!(buffer, center_b, properties.centers[1]);
    write_u16!(buffer, max_a, properties.maxes[0]);
    write_u16!(buffer, max_b, properties.maxes[1]);
    write_u16!(buffer, min_a, properties.mins[0]);
    write_u16!(buffer, min_b, properties.mins[1]);

    flash
        .blocking_write(NVS_OFFSET, &buffer)
        .expect("Failed to write NVS properties");

    info!("NVS Properties written {:?}", properties);
}
