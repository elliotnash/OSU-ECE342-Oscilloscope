View this project on [CADLAB.io](https://cadlab.io/project/29860). 

# OSU-ECE342-Oscilloscope

A Dual Channel USB Oscilloscope designed for OSU ECE342 Junior Design 2

## Project Structure

- **`hardware/`** - Contains KiCad schematic and PCB design files for a RP2350 based oscilloscope board.

- **`firmware/`** - Rust firmware that runs on the oscilloscope board. Built using the Embassy async framework for embedded systems, targeting the RP2350 microcontroller. Handles ADC sampling / USB communication.

- **`client/`** - Tauri desktop application providing the oscilloscope user interface. Frontend built with React, TypeScript, and Tailwind CSS. Communicates with the firmware over USB to display waveforms and control oscilloscope settings.

- **`common/`** - Shared Rust crate containing models and (de)serialization logic used for communication between the firmware and Tauri application.
