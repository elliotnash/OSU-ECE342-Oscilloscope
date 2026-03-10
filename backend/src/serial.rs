use serde::{Deserialize, Serialize};
use serialport::{SerialPortType, UsbPortInfo};
use serial2_tokio::SerialPort;
use specta::{ Type };
use tauri::{ AppHandle, Emitter, ipc::Channel };
use tauri_specta::Event;
use std::{sync::{Arc, OnceLock}, time::Duration};
use tokio::{select, sync::{broadcast, watch}, time::{Instant, sleep}};
use common::{channel::ChannelOptions, frame::{FrameData, FrontendFrameData, ScopeChannel}, message::{CalibrationMessage, Message, VerificationMessage}, trigger::TriggerOptions, usb::{OSCOPE_PID, OSCOPE_VID}};


#[derive(Debug, Clone, Serialize, Deserialize, Type, Event, PartialEq, Eq)]
pub enum SerialStatus {
    Connected,
    Disconnected,
}

static SERIAL_STATUS_WATCH: OnceLock<watch::Sender<SerialStatus>> = OnceLock::new();
fn get_serial_status_watch() -> watch::Sender<SerialStatus> {
    SERIAL_STATUS_WATCH.get_or_init(|| {
        // Create the channel. Initial value is "init"
        let (tx, _rx) = watch::channel(SerialStatus::Disconnected);
        tx
    }).clone()
}

static LAST_HEARTBEAT_WATCH: OnceLock<watch::Sender<Instant>> = OnceLock::new();
fn get_last_heartbeat_watch() -> watch::Sender<Instant> {
    LAST_HEARTBEAT_WATCH.get_or_init(|| {
        let (tx, _rx) = watch::channel(Instant::now());
        tx
    }).clone()
}

static CHA_FRAME_WATCH: OnceLock<watch::Sender<FrameData>> = OnceLock::new();
fn get_cha_frame_watch() -> watch::Sender<FrameData> {
    CHA_FRAME_WATCH.get_or_init(|| {
        let (tx, _rx) = watch::channel(FrameData::default());
        tx
    }).clone()
}

static CHB_FRAME_WATCH: OnceLock<watch::Sender<FrameData>> = OnceLock::new();
fn get_chb_frame_watch() -> watch::Sender<FrameData> {
    CHB_FRAME_WATCH.get_or_init(|| {
        let (tx, _rx) = watch::channel(FrameData::default());
        tx
    }).clone()
}

static VERIFICATION_BROADCAST: OnceLock<broadcast::Sender<VerificationMessage>> = OnceLock::new();
fn get_verification_broadcast() -> broadcast::Sender<VerificationMessage> {
    VERIFICATION_BROADCAST.get_or_init(|| {
        let (tx, _rx) = broadcast::channel(100);
        tx
    }).clone()
}

static SERIAL_TX_BROADCAST: OnceLock<broadcast::Sender<Message>> = OnceLock::new();
fn get_serial_tx_broadcast() -> broadcast::Sender<Message> {
    SERIAL_TX_BROADCAST.get_or_init(|| {
        let (tx, _rx) = broadcast::channel(100);
        tx
    }).clone()
}

#[tauri::command(async)]
#[specta::specta]
pub async fn get_serial_status() -> SerialStatus {
    get_serial_status_watch().subscribe().borrow().clone()
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
        get_serial_status_watch().send_replace(SerialStatus::Disconnected);
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

        let serial_tx = match SerialPort::open(&port_path, 921600) {
            Ok(s) => s,
            Err(e) => {
                eprintln!("Error opening port: {}. Retrying...", e);
                sleep(Duration::from_secs(1)).await;
                continue; 
            }
        };
        let serial_tx = Arc::new(serial_tx);

        #[cfg(not(target_os = "windows"))]
        let serial_rx = match serial_tx.try_clone() {
            Ok(s) => Arc::new(s),
            Err(e) => {
                eprintln!("Error cloning port: {}. Retrying...", e);
                sleep(Duration::from_secs(1)).await;
                continue; 
            }
        };

        #[cfg(target_os = "windows")]
        let serial_rx = serial_tx.clone();

        // Notify frontend that we are connected
        get_serial_status_watch().send_replace(SerialStatus::Connected);
        app.emit("serial-status", SerialStatus::Connected).unwrap();

        let serial_res = select! {
            res = handle_serial_receive(serial_tx) => res,
            res = handle_serial_send(serial_rx) => res,
            res = handle_heartbeat_monitor() => res,
            res = handle_send_heartbeat() => res,
        };

        // Spawn the connection handler. If this returns, it means the connection died.
        if let Err(e) = serial_res {
            eprintln!("Connection lost: {}. returning to search mode...", e);
        }        
        // Loop triggers again immediately to search for the device
    }
}

async fn handle_heartbeat_monitor() -> std::io::Result<()> {
    let mut last = Instant::now();
    let mut last_heartbeat_rx = get_last_heartbeat_watch().subscribe();

    loop {
        let deadline = last + Duration::from_millis(15000);

        let timeout_fut = tokio::time::sleep_until(deadline);
        let heartbeat_changed_fut = last_heartbeat_rx.changed();

        select! {
            // No heartbeat within 1100 ms of the last one: treat as disconnect
            _ = timeout_fut => {
                return Err(std::io::Error::new(
                    std::io::ErrorKind::TimedOut,
                    "Heartbeat timeout",
                ));
            }
            // Heartbeat arrived before the timeout: update last and keep monitoring
            res = heartbeat_changed_fut => {
                if res.is_err() {
                    // Sender dropped, consider this a disconnection as well
                    return Err(std::io::Error::new(
                        std::io::ErrorKind::BrokenPipe,
                        "Heartbeat watch closed",
                    ));
                }
                last = *last_heartbeat_rx.borrow();
            }
        }
    }
}

async fn handle_send_heartbeat() -> std::io::Result<()> {
    let mut next = Instant::now();

    loop {
        let serial_tx_broadcast = get_serial_tx_broadcast();
        let message = Message::Heartbeat;
        serial_tx_broadcast.send(message).ok();

        next += Duration::from_secs(1);
        tokio::time::sleep_until(next).await;
    }
}

/// Handles the actual data transmission over the serial port.
/// Accumulates bytes into a message buffer until a null terminator (0x00) is received,
/// then parses the buffer as a COBS-encoded message. This matches the firmware's
/// receive_messages logic so messages split across multiple OS read() calls are handled.
async fn handle_serial_receive(serial: Arc<SerialPort>) -> std::io::Result<()> {
    let mut read_buf = [0u8; 1024];
    let mut message_buf = Vec::new();

    loop {
        let read_len = serial.read(&mut read_buf).await?;

        message_buf.reserve(128);

        if read_len > 0 {
            for i in 0..read_len {
                let b = read_buf[i];
                if b == 0x00 {
                    // If the null terminator is encountered, then we've received a complete message.
                    // Parse the message and handle it.
                    match postcard::from_bytes_cobs::<Message>(&mut message_buf) {
                        Ok(message) => {
                            match message {
                                Message::Heartbeat => {
                                    get_last_heartbeat_watch().send_replace(Instant::now());
                                }
                                Message::Frame(frame) => {
                                    match frame.channel {
                                        ScopeChannel::A => {
                                            get_cha_frame_watch().send_replace(frame);
                                        }
                                        ScopeChannel::B => {
                                            get_chb_frame_watch().send_replace(frame);
                                        }
                                    }
                                }
                                Message::Verification(verification_message) => {
                                    get_verification_broadcast().send(verification_message).ok();
                                }
                                _ => {
                                    println!("Message type not implemented yet: {:?}", message);
                                }
                            }
                        }
                        Err(e) => {
                            println!("Error deserializing message: {:?}", e);
                        }
                    }
                    message_buf.clear();
                } else {
                    // Otherwise, this is part of the message, add it to the buffer.
                    message_buf.push(b);
                }
            }
        }
    }
}

async fn handle_serial_send(serial: Arc<SerialPort>) -> std::io::Result<()> {
    let mut serial_tx_broadcast = get_serial_tx_broadcast().subscribe();

    // Now that we've connected, send heartbeat. This will likely fail to be deserialized since
    // there is garbage data in the buffer, but this message will clear it allowing future messages
    // to send successfully.

    let message = Message::Heartbeat;
    let data = postcard::to_stdvec_cobs(&message).expect("Serialization failed");
    serial.write_all(&data).await?;

    loop {
        let message = serial_tx_broadcast.recv().await;
        if let Ok(message) = message {
            let data = postcard::to_stdvec_cobs(&message).expect("Serialization failed");
            serial.write_all(&data).await?;
        }
    }
}

#[tauri::command(async)]
#[specta::specta]
pub async fn get_current_frame() -> (FrontendFrameData, FrontendFrameData) {
    let cha = FrontendFrameData::from(get_cha_frame_watch().borrow().as_ref());
    let chb = FrontendFrameData::from(get_chb_frame_watch().borrow().as_ref());
    (cha, chb)
}


#[tauri::command(async)]
#[specta::specta]
pub async fn receive_verification_messages(_app: AppHandle, on_event: Channel<VerificationMessage>) {
    let mut verification_broadcast = get_verification_broadcast().subscribe();
    let serial_status_watch = get_serial_status_watch().subscribe();
    while serial_status_watch.borrow().clone() == SerialStatus::Connected {
        let verification_message = verification_broadcast.recv().await;
        if let Ok(verification_message) = verification_message {
            on_event.send(verification_message).ok();
        }
    }
}

#[tauri::command]
#[specta::specta]
pub fn send_verification_message(message: VerificationMessage) {
    let serial_tx_broadcast = get_serial_tx_broadcast();
    let message = Message::Verification(message);
    serial_tx_broadcast.send(message).ok();
}

#[tauri::command]
#[specta::specta]
pub fn send_calibration_message(message: CalibrationMessage) {
    let serial_tx_broadcast = get_serial_tx_broadcast();
    let message = Message::Calibration(message);
    serial_tx_broadcast.send(message).ok();
}

#[tauri::command]
#[specta::specta]
pub fn send_channel_options(channel_options: ChannelOptions) {
    let serial_tx_broadcast = get_serial_tx_broadcast();
    println!("Sending channel options: {:?}", channel_options);
    let message = Message::SetChannelOptions(channel_options);
    serial_tx_broadcast.send(message).ok();
}

#[tauri::command]
#[specta::specta]
pub fn send_sample_rate(sample_rate: u32) {
    let serial_tx_broadcast = get_serial_tx_broadcast();
    println!("Sending sample rate: {:?}", sample_rate);
    let message = Message::SetSampleRate(sample_rate);
    serial_tx_broadcast.send(message).ok();
}

#[tauri::command]
#[specta::specta]
pub fn send_trigger_options(trigger_options: TriggerOptions) {
    let serial_tx_broadcast = get_serial_tx_broadcast();
    println!("Sending trigger options: {:?}", trigger_options);
    let message = Message::SetTriggerOptions(trigger_options);
    serial_tx_broadcast.send(message).ok();
}
