#import "../../block-diagram.typ": *
#import "../../template.typ": *
#import "../../authors.typ": authors

#show: block-project.with(
  title: [Dual Channel RP2350 USB Oscilloscope],
  authors: authors,
  team-number: "Team Number: 15"
)

#outline(title: none)

#pagebreak()

= Top-Level Architecture Block Diagram <top-level-architecture-block-diagram>

#figure(scale(system-diagram, reflow: true, 80%), caption: [Top-Level Architecture Block Diagram]) <tla-block>

= Backend Video Link <backend-video-link>

https://media.oregonstate.edu/media/t/1_a5lmjchp

= Backend Description <backend-description>
// #TODO[{Create a block diagram of your individual block. Write a detailed description of #emph[what your block does];. What is its role in the system? How does its role relate to the overall system requirements? What is coming into the block? What does the block do to that input? What is created and then delivered as an output? This is where your deep dive into functionality goes. Make sure to include the names and functions of all interfaces related to this block and that they match your top-level architecture above.}]

#figure(backend-diagram, caption: [Backend Black Box Diagram]) <backend-blackbox>

The backend block functions as the protocol translation layer of the system. Its primary role is to bridge the low level byte-stream sent from the MCU to the event-driven domain of the React frontend. By decoupling the serial communication logic from the frontend presentation logic, this block ensures high-throughput waveform data processing without blocking the user interface, ensuring the system requirement of less than 100ms input latency is met.

#figure(image("./backend-block.svg", height: 70%), caption: [Backend Internal Flow Diagram])

== Functionality

The backend functionality is divided into two distinct processing paths:

1. *MCU to Backend (RX)*: The backend listens for incoming byte streams from the MCU. These bytes are passed to a constant overhead byte stuffing (COBS) decoder to remove the packet framing. The resulting serialized payload is deserialized into a type-safe Message enum and emitted to the frontend via Tauri event channels.

2. *Backend to MCU (TX)*: The backend accepts user commands (changing the gain, sample rate, etc) via Tauri's command interface. These commands are serialized into compact binary data, encoded with COBS framing, and transmitted to the MCU to modify hardware behavior.

== Interfaces

The backend interfacts with the other blocks through two interfaces:

1. *`mcu_backend_data`*: This interface functions as the data conduit between the firmware and the application logic. It handles the transmission of the raw byte stream. In the RX direction, it delivers high-frequency waveform samples and status updates from the MCU. In the TX direction, it carries serialized control packets used to configure hardware parameters such as trigger levels and voltage scaling.

2. *`frontend_backend_data`*: This interface represents the Inter-Process Communication (IPC) between the Rust backend and the React frontend. It functions as a bridge, allowing the UI to invoke backend functions asynchronously while simultaneously subscribing to processed data events for real-time visualization.

= Backend Design Details <backend-design-details>
// #TODO[{Write a detailed description of #emph[how your block works];. Demonstrate your learning by explaining clearly what the inputs are and where they come from. Explain how those inputs become outputs through your block. Design details must include in-text citations in IEEE format. Cite resources from prior coursework, module resources lists from this class, or resources you have found externally.}]

In order to support low-latency high-throughput data streaming over serial USB, it is necessary to use a very efficient encoding scheme. This is done using a two step process:

== Transport & Framing

The first layer of the design addresses efficiently framing packets. Since serial USB transmits data as a continuous stream of bytes, it is necessary to create "frames" so that the boundaries of each message are known. To accomplish this, the system utilizes Constant Overhead Byte Stuffing (COBS) to remove a specified sentinel from a given byte array. When encoded via COBS, a byte array is guaranteed to not contain the sentinel, allowing the sentinel to be used as a packet terminator @cobs. As the name suggests, it has a constant memory overhead, using just one extra byte per 254 input bytes @cobs. These properties make it a good fit where latency and efficiency are a necessity.

In the receive direction (RX), the COBS Decoder ingests raw bytes from the `mcu_backend_data` interface, scanning for zero-byte delimiters that mark the end of a frame. It then reverses the byte-stuffing algorithm to produce a clean binary payload @cobs. Conversely, in the transmit direction (TX), the COBS Encoder takes serialized command packets and "stuffs" them with the necessary overhead before transmission. This ensures that a zero byte effectively signifies the end of a packet without ever appearing within the data payload itself @cobs.

== Serialization & Type Safety

The second layer handles the conversion between raw binary payloads and structured application data. This is achieved using postcard, a library designed for `no_std` environments that implements the serde data model @postcard. Since the firmware is also written in rust, this allows the models to be defined in a shared common crate, reducing duplicate code and limiting bugs in serialization logic. Additionally, the specta library is used to introspectively generate typescript bindings for the rust models in the common crate, allowing the data to remain fully typesafe from the firmware to the frontend @beaumont_specta.

On the incoming path, the Postcard Deserializer takes the decoded payload from the COBS layer and maps it to a Rust Message enum defined in the common crate. This structured data is then emitted to the frontend interface (frontend_backend_data) using Tauri's asynchronous event channels @tauri_ipc. On the outgoing path, the Postcard Serializer accepts command objects from Tauri's invocation system, converting them into compact binary arrays ready for COBS encoding. This shared serialization logic guarantees exact data parity between the firmware and the backend.

= Backend Interface Validation <backend-interface-validation>

#figure(table(
  columns: 3,
  table.header(
    [*Interface Property*],
    [*Why is this interface this value?*],
    [*How do you know your design details will meet or exceed this property? Cite your sources in IEEE.*]
  ),
  
  table.header(level: 2, table.cell(colspan: 3)[*mcu_backend_data: Input/Output*]),

  [Packet Framing: \ Consistent Overhead Byte Stuffing (COBS)],
  [Serial communication (USB CDC) transmits a continuous stream of bytes without inherent packet boundaries. COBS is selected because it provides fixed frame delimiters with minimal overhead @cobs.],
  [The backend utilizes the `cobs` Rust crate, which implements the COBS algorithm @cobs_rs. To ensure the design meets this property, unit tests in the `common` crate perform round-trip encoding/decoding verification on various byte arrays to confirm successful packet identification.],

  [Serialization Format: Postcard],
  [The system requires a lightweight, strongly typed binary format to transfer complex data structures between the firmware and the backend. Postcard is chosen because it is designed for `no_std` environments and has very little overhead @postcard.],
  [The `postcard` library is utilized in both the firmware and the backend @postcard. The design guarantees this property is met by defining all models in shared `common` library crate. This ensures at compile-time that the serialization schema used by the firmware matches the deserialization schema used by the backend exactly.],

  [Transport Protocol: USB Serial (CDC)],
  [Universal Serial Bus (USB) Communications Device Class (CDC) is the standard way of emulating serial ports, allowing the oscilloscope to interface with any host OS without custom drivers @axelson_usb_complete.],
  [The backend uses the cross-platform `serialport` crate to manage the connection, which implements USB CDC @serialport_crate.],

  
  table.header(level: 2, table.cell(colspan: 3)[*backend_frontend_data: Input/Output*]),
  // [Communication Mechanism: Tauri Event System (Asynchronous)],
  // [The frontend must remain responsive while receiving high-frequency waveform updates. Synchronous polling would block the UI thread. The Tauri Event System allows the backend to "push" updates to the frontend only when new data is available @ta.],
  // [The design utilizes Tauri's `Window::emit` function to send data asynchronously. This mechanism is built on top of the underlying WebView's IPC channel, which is documented to support non-blocking message passing [3]. We will validate this by verifying that the frontend's frame rate does not drop below 60fps during active capture.],

  // [Data Type Definition: TypeScript Interface (via Specta)],
  // [The React frontend is written in TypeScript to prevent runtime errors. To maintain this safety, the data received from the Rust backend must match the expected frontend types exactly (e.g., a "Waveform" object must have an array of numbers, not strings).],
  // [The `specta` library is integrated into the `common` crate to automatically generate a `bindings.ts` file from the Rust `Message` structs [4]. This guarantees that if the Rust data model changes, the TypeScript build will fail, ensuring that the design strictly meets the property of type safety at compile time.],

  // [Serialization Format: JSON],
  // [The Tauri WebView (the browser environment rendering the UI) natively understands JavaScript Object Notation (JSON). Converting Rust structs to JSON ensures the data is immediately usable by the JavaScript engine without complex parsing logic on the client side.],
  // [The `serde_json` library is used in conjunction with Tauri's command handler to serialize the `Message` enum [3]. This is a standard, industry-proven library for high-performance JSON serialization in Rust, ensuring compatibility with the browser's `JSON.parse` implementation.],

  [Communication Protocol: Tauri IPC],
  [The oscilloscope generates a continuous stream of waveform data. Tauri channels allow the backend to establish a persistent connection to the frontend, streaming partial results (waveform chunks) as they arrive without the overhead of repeated command invocations @tauri_v2_channels. Tauri events allow easily sending one off events @tauri_v2_channels.],
  [The backend code includes the `tauri::ipc::Channel` type argument in the command function headers, and uses `tauri::Emitter` to emit events.],

  [Type Generator: Specta],
  [The React frontend is written in TypeScript. To maintain type safety, the data received from the Rust backend must match the expected frontend types exactly.],
  [The `specta` library is integrated into the `common` crate to automatically generate a `bindings.ts` file from the Rust `Message` structs @beaumont_specta. This guarantees that if the Rust data model changes, the TypeScript build will fail, ensuring that the design strictly meets the property of type safety at compile time.],

  [Serialization Format: JSON],
  [The Tauri WebView uses JavaScript Object Notation (JSON) @tauri_ipc. Converting Rust structs to JSON ensures the data is immediately usable by the JavaScript engine without manual parsing logic on the frontend.],
  [The `serde_json` library is used strictly for serializing the payload sent through the `Channel`. This is the default serialization method for Tauri IPC @tauri_ipc.],
), caption: [Interface Property Table])

= Backend Verification Process <backend-verification-process>

== Interface: `mcu_backend_data`

#set enum(numbering: "1.a.")

+ *Verify Transport Protocol (USB CDC)*

  + Connect the test RP Pico dev board in bootloader mode to a linux computer by holding down the `BOOTSEL` button while pluging it in.

  + From the project root, flash the test firmware by running `cd test-firmware && cargo run`

  + Run `lsusb -v`

  + Observe the output of `bInterfaceClass` under the `ECE342 USB Oscilloscope` section

  *PASS*: `bInterfaceClass` is `Communication` for USB-CDC
  
  *FAIL*: `bInterfaceClass` is not `Communication`

+ *Verify Packet Framing (COBS) & Serialization (Postcard)*

  + From the project root run `cd common && cargo test`

  + Observe the cargo test output

  *PASS*: All cargo tests pass.
  
  *FAIL*: One or more cargo tests fail.

== Interface: `frontend_backend_data`

+ *Verify Type Generator (Specta)*

  + From the project root, delete the existing TypeScript bindings with `rm frontend/src/bindings.ts`.

  + Rebuild the client with `cargo tauri build`

  + Observe the file `frontend/src/bindings.ts`

  *PASS:* The `bindings.ts` file exists and contains type definitions for each used type in the `backend` crate.

  *FAIL:* The `bindings.ts` file does not exist or is missing type definitions.

+ *Verify Communication Protocol (Tauri IPC) & Serialization (JSON)*

  + From the project root, build and run the client with `cargo tauri dev`.

  + Navigate to the `Test Panel` page.

  + Observe the data shown on the window

  *PASS:* The received tauri channels/events are streamed to the test page and are displayed as JSON objects.
  
  *FAIL:* The channel events aren't visible on the test page, or the test page do not consist of JSON data.
  
= Backend Artifacts <backend-artifacts>
// #TODO[{Populate this section with the miscellaneous but important findings that got you to your final block design. This means anything you had to learn in order to make choices about your design details. This might be prior coursework, examples found online, reference schematics, pseudocode, previous or prior version block diagrams, etc. Think of this section as a repository of your progress on this block. Do not include what is in your design details.}]

== Packet Framing

Before deciding on COBS, we evaluated a few other options for packet framing. We first looked at using a simple length header (sending the length first followed by the payload), but rejected it due to its poor synchronization characteristics. If a single byte is missed, the backend misinterprets the data as the "length," causing it to read garbage data indefinitely until a timeout resets the state @cobs.

We also considered escape stuffing, which reserves a special byte to mark boundaries. This solves the issues with length headers, but introduces variable overhead; if the oscilloscope measures a voltage that happens to correspond to the escape character, the bandwidth usage for that packet effectively doubles @romkey_rfc1055. This non-deterministic overhead could potentially translate to jitter, or cause problems if we were running near the bandwidth limit for USB. Ultimately, COBS was selected because it guarantees a constant, low overhead (1 byte per 254 bytes), and the `0x00` byte *always* signifies a packet boundary with COBS @cobs. If the stream desynchronizes, the backend automatically resyncs at the very next zero byte.

= Backend Future Recommendations <backend-future-recommendations>
// #TODO[{This was a lot of work. Take some time to reflect on how far you have come from starting to understand the design process last term, to creating a novel block for a unique, custom system. What went well? What would you tell yourself at the beginning of the term given what you know now?}]

The decision to use the same language between the firmware and backend, and thus the ability to use a common crate with shared models greatly improved the developer experience. Regardless of what direction a future iteration went, it would be very wise to keep the shared model architecture.

There is lots of room to grow in terms of data compression. At higher sample rates, USB CDC speeds start to become a limiting factor, and a compression algorithm could be implemented to help offset this. However, compression introduces latency, so it would need to be carefully considered before being implemented. Implemented a delta encoding for waveforms may also be a good approach (potentially in combination with compression).

/* 
3 byte pairs:
running 1 test
1000 sample sine wave serialized into 1517 bytes.
test message::tests::frame_data_delta_packing ... ok

delta encoding:
running 1 test
1000 sample sine wave serialized into 1016 bytes.
test message::tests::frame_data_delta_packing ... ok
*/

#bibliography("./backend-ref.bib", title: [Backend References]) <backend-references>
