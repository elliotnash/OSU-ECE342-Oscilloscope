use serde::{Deserialize, Serialize};
use serialport::{SerialPortType, UsbPortInfo};
use serial2_tokio::SerialPort;
use specta::{ Type };
use tauri::{ AppHandle, Emitter };
use tauri_specta::Event;
use std::{sync::OnceLock, time::Duration};
use tokio::{sync::RwLock, time::sleep};
use common::usb::{OSCOPE_VID, OSCOPE_PID};


#[derive(Debug, Clone, Serialize, Deserialize, Type, Event)]
pub enum SerialStatus {
    Connected,
    Disconnected,
}

static SERIAL_STATUS: OnceLock<RwLock<SerialStatus>> = OnceLock::new();

#[tauri::command(async)]
#[specta::specta]
pub async fn get_serial_status() -> SerialStatus {
    SERIAL_STATUS.get_or_init(|| RwLock::new(SerialStatus::Disconnected)).read().await.clone()
}

/// Finds the port path of the oscilloscope USB-CDC device.
/// Returns None if no device is found.
fn find_port_path() -> Option<String> {
    let ports = serialport::available_ports().ok()?;
    for port in ports {
        if let SerialPortType::UsbPort(UsbPortInfo { vid, pid, .. }) = port.port_type {
            if vid == OSCOPE_VID && pid == OSCOPE_PID {
                return Some(port.port_name);
            }
        }
    }
    None
}

/// Task that manages the serial connections.
pub async fn serial_task(app: AppHandle) {
    loop {
        {
            let mut data = SERIAL_STATUS.get_or_init(|| RwLock::new(SerialStatus::Disconnected)).write().await;
            *data = SerialStatus::Disconnected; 
        }
        app.emit("serial-status", SerialStatus::Disconnected).unwrap();
        
        // Poll for device connections
        let port_path = loop {
            if let Some(path) = find_port_path() {
                break path;
            }
            // Poll interval
            sleep(Duration::from_secs(1)).await;
        };

        println!("Device found at {}! Connecting...", port_path);

        // Attempt to open port. If it fails we go back to searching.
        let mut serial = match SerialPort::open(&port_path, 115200) {
            Ok(s) => s,
            Err(e) => {
                eprintln!("Error opening port: {}. Retrying...", e);
                sleep(Duration::from_secs(1)).await;
                continue; 
            }
        };

        // Notify frontend that we are connected
        {
            let mut data = SERIAL_STATUS.get_or_init(|| RwLock::new(SerialStatus::Disconnected)).write().await;
            *data = SerialStatus::Connected; 
        }
        app.emit("serial-status", SerialStatus::Connected).unwrap();

        // Spawn the connection handler. If this returns, it means the connection died.
        if let Err(e) = handle_connection(&mut serial).await {
            eprintln!("Connection lost: {}. returning to search mode...", e);
        }        
        // Loop triggers again immediately to search for the device
    }
}

/// Handles the actual data transmission over the serial port.
async fn handle_connection(serial: &mut SerialPort) -> std::io::Result<()> {
    let mut buffer = [0u8; 1024];

    loop {
        let read_len = serial.read(&mut buffer).await?; 

        if read_len > 0 {
            // Process your oscilloscope data here
            let data = &buffer[..read_len];
            println!("Received {} bytes: {:?}", read_len, data);
        }
    }
}