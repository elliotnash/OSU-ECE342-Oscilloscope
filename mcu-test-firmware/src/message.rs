use crate::{ScopeUsbReceiver, ScopeUsbSender, USB_PACKET_SIZE};
use alloc::vec::Vec;
use common::message::Message;
use defmt::{error, info, panic};
use embassy_sync::blocking_mutex::raw::ThreadModeRawMutex;
use embassy_sync::channel::Channel;
use embassy_usb::driver::EndpointError;

pub static MESSAGE_RX: Channel<ThreadModeRawMutex, Message, 2> = Channel::new();
pub static MESSAGE_TX: Channel<ThreadModeRawMutex, Message, 2> = Channel::new();

#[embassy_executor::task]
pub async fn send_messages_task(mut tx: ScopeUsbSender) -> ! {
    loop {
        tx.wait_connection().await;
        info!("USB Connected");
        let _ = send_messages(&mut tx).await;
        info!("USB Disconnected");
    }
}

#[embassy_executor::task]
pub async fn receive_messages_task(mut rx: ScopeUsbReceiver) -> ! {
    loop {
        rx.wait_connection().await;
        let _ = receive_messages(&mut rx).await;
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

async fn receive_messages(rx: &mut ScopeUsbReceiver) -> Result<(), Disconnected> {
    let mut buf = Vec::new();
    let mut packet_buf = [0; USB_PACKET_SIZE];
    let message_sender = MESSAGE_RX.sender();
    loop {
        let n = rx.read_packet(&mut packet_buf).await?;
        // let data = &buf[..n];
        buf.reserve(n);
        for i in 0..n {
            if packet_buf[i] == 0x00 {
                // Received null byte indicating the end of message, parse it.
                match postcard::from_bytes_cobs::<Message>(&mut buf) {
                    Ok(message) => {
                        message_sender.send(message).await;
                    }
                    Err(e) => {
                        error!(
                            "Failed to deserialize message: {:?}",
                            defmt::Debug2Format(&e)
                        );
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

async fn send_messages(tx: &mut ScopeUsbSender) -> Result<(), Disconnected> {
    let message_receiver = MESSAGE_TX.receiver();
    loop {
        let message = message_receiver.receive().await;
        info!("Sending message: {:?}", &message);

        let bytes = postcard::to_allocvec_cobs(&message).expect("Serialization failed");

        // Send in chunks of USB_PACKET_SIZE
        for chunk in bytes.chunks(USB_PACKET_SIZE) {
            tx.write_packet(chunk).await?;
        }
    }
}
