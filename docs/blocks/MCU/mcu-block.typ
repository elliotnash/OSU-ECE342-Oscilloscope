#import "/block-diagram.typ": *
#import "/template.typ": *
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

= Block 2 Video Link <block-2-video-link>
https://media.oregonstate.edu/media/t/1_2ans176v

= Block 2 Description <block-2-description>
The MCU Block acts as the central control unit for the USB oscilloscope, bridging the analog signal acquisition hardware with the PC-based visualization software. Built around the Raspberry Pi RP2350 microcontroller, this block is responsible for digitizing incoming analog waveforms, detecting trigger events, and managing the state of the analog front-end (such as AC/DC coupling). Additionally, it handles the serialization of sample data into packets and transmits them to the host computer via a high-speed USB Serial (CDC) interface. The block design emphasizes low-latency data handling and robust communication protocols to ensure real-time performance.
#figure(scale(mcu-diagram, 120%, reflow: true), caption: [MCU block black box diagram.]) <analog-block-fig>

= Block 2 Design Details <block-2-design-details>
The MCU block centers on the RP2350 microcontroller, which coordinates data acquisition and system control. The design flow operates as follows:

*Power and Reference:*
The block receives power via the `power_mcu_dcpwr(vsys)` interface, utilizing the RP2350's internal regulator to run the digital core at $1.1$ V while the I/O operates at $3.3$ V [1]. A critical input is `power_mcu_dcpwr(vref)`, which provides a precision $3.3$ V reference voltage. This reference ensures that the internal ADC's conversion range matches the $0$ V -- $3.3$ V linear output of the analog block, maximizing dynamic range and minimizing quantization errors [3].

*Signal Acquisition:*
The conditioned analog signal enters through `analog_mcu_asig`. The RP2350's internal SAR ADC samples this signal at a configurable rate. To prevent aliasing, the input bandwidth is limited to $5$ MHz by the analog block's anti-aliasing filter before reaching the MCU [1].

*Triggering:*
Hardware triggering is managed via the `trigger_mcu_dsig` input. This digital signal comes from an external comparator in the trigger block. The MCU monitors this pin for rising or falling edges (interrupt-driven or polled) to synchronize the data buffer capture, ensuring that the waveform is stable on the user's screen [11]. The trigger threshold voltage is set by the MCU via the `mcu_trigger_comm` interface, which uses an I2C bus running at $100$ kHz to write digital values to the MCP4725 DAC [5].

*Control Outputs:*
The MCU controls the signal coupling mode through the `mcu_analog_dsig` interface. By driving a GPIO pin High ($3.3$ V) or Low ($0$ V), the system activates or deactivates a TLP3441 photorelay. A High signal enables the DC path, while a Low signal forces the signal through the AC coupling capacitor. The drive strength is configured to provide $approx 10$ mA, sufficient to bias the relay's internal LED [2].

*Data Transport:*
Data processing and communication occur over the `mcu_backend_data` interface. The firmware serializes the acquired waveform data and system state using the `postcard` library, a `no_std` compatible serializer designed for embedded systems [8]. To ensure robust transmission over the USB CDC stream, the `cobs` (Consistent Overhead Byte Stuffing) algorithm frames the packets, allowing the receiver to recover from stream errors easily [6] [7]. The USB interface is implemented using the standard CDC class, making the device compatible with most operating systems without custom drivers [9].

= Block 2 Interface Validation <block-2-interface-validation>

#figure(table(
  columns: 3,
  table.header(
    [*Interface Property*],
    [*Why is this interface this value?*],
    [*How do you know your design details will meet or exceed this property? Cite your sources in IEEE.*]
  ),
  
  table.header(level: 2, table.cell(colspan: 3)[*power_mcu_dcpwr(vsys): input*]),
  [Vmax: 3.6v],
  [The rp2350 drives the GPIO pins to control features in the analog block.],
  [This is the maximum voltage input for the RP2350 i/o digital supply to accurately supply 3.3v at 12mA[1].],

  [Vmin: 2.4v],
  [This is the minimum the gpio output of the MCU needs to be to support the switch controls.],
  [This is the minimum voltage for the TLP3441 to bias it enough to be considered on [2].],

  [Inominal: 100mA],
  [Covers full speed operation for all operation at one core.],
  [Nominal current for the rp2350 at full speed with two cores is 200mA[1]. We are only running one core at less than full speed.],

  [Ipeak: 200mA],
  [Covers maximum current draw by rp2350.],
  [This is the maximum current the onboard voltage regulator can draw from the power supply [1].],

  table.header(level: 2, table.cell(colspan: 3)[*power_mcu_dcpwr(vref): input*]),
  [Vmax: 3.6v],
  [The adc Vref input cannot exceed the maximum gpio Vdd input, which is 3.6v],
  [The output variance of the voltage regulator in the power block of $plus.minus 0.05%$ is assumed to be in room temperature and it is specified in the data sheet [3].],

  [Vmin: 3.3v],
  [The adc needs to be capable of reading 3vpp signals centered at 1v65, meaning 3.15v is the minimum acceptable Vref, but 3.3v is necessary because ADC_AVDD needs to be the same or greater than Vsys.],
  [The output variance of the voltage regulator in the power block of $plus.minus 0.05%$ is assumed to be in room temperature and it is specified in the data sheet [3].],

  [Inominal: 650nA],
  [The adc will draw extremely low currents since Vref must be kept very stable.],
  [This is met by this IC in the power block as specified in the datasheet [4]. The adc will draw >1mA from the Vref input [1].],

  [Ipeak: 650nA],
  [The adc will draw extremely low currents since Vref must be kept very stable.],
  [This is met by this IC in the power block as specified in the datasheet [4]. The adc will draw >1mA from the Vref input [1].],

  table.header(level: 2, table.cell(colspan: 3)[*analog_mcu_asig: Input*]),
  [Voltage Range: $0.15$ V -- $3.15$ V],
  [The RP2350 internal ADC has an absolute maximum input of $3.6$ V and linear range of $0.15$ -- $3.15$ V [1].],
  [The analog block has stage 3 ($"U2"$), which shifts the $plus.minus 1.65$ V signal by adding $+1.65$ V. The op-amp is powered by $3.3$ V and GNDA, physically preventing output below $0$ V or above $3.3$ V [4].],
  
  [Bandwidth: $200$ KHz],
  [To support 200kHz sampling now and future external ADC upgrades.],
  [The anti-aliasing filter ($"R5"=1$ k$Omega, "C2"=30$ pF) creates a cutoff at $5.3$ MHz. The TLP3441 photorelay capacitance ($0.7$ pF) is negligible [2].],

  [Offset Accuracy: $plus.minus 100$ mV],
  [To ensure the "zero" line is centered on the screen.],
  [In the analog block, we use 1% tolerance resistors for the summing junction and the OPA320 has a max offset voltage of $150 mu$V [4].],

  table.header(level: 2, table.cell(colspan: 3)[*trigger_mcu_dsig: Input*]),
  [V high: > 2.31v],
  [This is the minimum input that will be read as HIGH by the rp2350[1]],
  [The high level output voltage worst case scenario for the comparator output is Vdd-0.2v [11].],
  
  [V low: < 0.99v],
  [This is the maximum input that will be read as LOW by the rp2350[1].],
  [The low level output voltage worst case scenario for the comparator output is is Vss+0.2v [11].],
 
  [Toggle frequency: < 120KHz],
  [This is the maximum toggle frequency when Vdd-Vss is >1.6v [11].],
  [We will not run the dac at greater than 120KHz to make sure this comparator does not have rise/fall time issues [11][5].],

  table.header(level: 2, table.cell(colspan: 3)[*mcu_backend_data: Input/Output*]),

  [Packet Framing: \ Consistent Overhead Byte Stuffing (COBS)],
  [Serial communication (USB CDC) transmits a continuous stream of bytes without inherent packet boundaries. COBS is selected because it provides fixed frame delimiters with minimal overhead [6].],
  [The backend utilizes the `cobs` Rust crate, which implements the COBS algorithm [7]. To ensure the design meets this property, unit tests in the `common` crate perform round-trip encoding/decoding verification on various byte arrays to confirm successful packet identification.],

  [Serialization Format: Postcard],
  [The system requires a lightweight, strongly typed binary format to transfer complex data structures between the firmware and the backend. Postcard is chosen because it is designed for `no_std` environments and has very little overhead [8].],
  [The `postcard` library is utilized in both the firmware and the backend [8]. The design guarantees this property is met by defining all models in shared `common` library crate. This ensures at compile-time that the serialization schema used by the firmware matches the deserialization schema used by the backend exactly.],

  [Transport Protocol: USB Serial (CDC)],
  [Universal Serial Bus (USB) Communications Device Class (CDC) is the standard way of emulating serial ports, allowing the oscilloscope to interface with any host OS without custom drivers [9].],
  [The backend uses the cross-platform `serialport` crate to manage the connection, which implements USB CDC [10].],
  
  table.header(level: 2, table.cell(colspan: 3)[*mcu_analog_dsig(DC capacitor): Output*]),
  [Vmax: 3.3v],
  [The MCU supplies a high-level digital signal to close the photorelay for signal acquisition.],
  [The RP2350 GPIO output voltage follows the IOVDD supply, which is nominally 3.3V[2].],

  [Voff(max): 1.02v],
  [Ensures the relay remains in the OFF state to maintain signal isolation when the channel is disabled.],
  [The TLP3441 has a maximum return LED current ($I$) of 0.1mA. With the $200$Ohms series resistor, any voltage below 1.02V (0.0001A*200Ohms + 1.0V) guarantees the relay stays off[2].],

  [Inominal: 10.15mA],
  [Provides sufficient current to reliably trigger the photo-MOSFET while minimizing power consumption.],
  [With a 200Ohms resistor and a typical $V_F$ of 1.27V, the 3.3V GPIO provides 10.15mA , which exceeds the 3mA minimum trigger current (I) required for the relay[2].],

  [Ipeak: 12mA],
  [The current must not exceed the maximum sourcing capability of the MCU GPIO pins.],
  [The RP2350 GPIO pins have a maximum software-selectable drive strength of 12mA[2].],

  
  table.header(level: 2, table.cell(colspan: 3)[*mcu_analog_dsig(Switches): Output*]),
  [Vmax > 2.4v],
  [The adg621 reads anything above 2.4v as on [12].],
  [The RP2350 GPIO output voltage follows the IOVDD supply, which is nominally 3.3V[2].],

  [Voff < 0.8v],
  [The adg621 reads anything below 0.8v as off [12].],
  [The RP2350 GPIO output voltage followes the IOGND supply which is nominally 0V[2].],

  [Inominal: 0.005uA],
  [This is the input current of the select pins of the adg621 [12].],
  [The rp2350 can supply up to 12mA to all GPIO pins[2].],

  [Ipeak: 0.1uA],
  [This is the input current of the select pins of the adg621 [12].],
  [The rp2350 can supply up to 12mA to all GPIO pins[2].],

  table.header(level: 2, table.cell(colspan: 3)[*mcu_trigger_comm: Output*]),
  [Target address: 1100000],
  [This is the I2C address for the MCP47 that is the dac controlled by the mcu.],
  [The MCP47 model we bought has the target address specified in the datasheet [5].],
  
  [Baud rate: 100Khz],
  [This is the baud rate allocated by our backend.],
  [The MCP47 datasheet specifies 100Khz as the standard baud rate [5].],

  [High Speed Mode: false],
  [We will not be communicating with the trigger using a high speed I2C connection as the rp2350 is limited by the internal clock.],
  [We will not initiate the high speed connection in our backend, ensuring the MCP47 does not expect a high speed baud rate [5].],
  
),caption: [Interface Validation Table])

= Block 2 Verification Process <block-2-verification-process>

#set enum(numbering: "1.a.")

== Interface: `power_mcu_dcpwr(vsys)`

+ *Verify Voltage Limits (Vmax 3.6V, Vmin 2V)*
  + verify using datasheet for rp2350 [1].
  
  *PASS*: Datasheet says pass.

+ *Verify Current Consumption (Inominal 100mA, Ipeak 200mA)*
  + Set the DC power supply to $3.3$ V.
  + Run the MCU in a loop mimicking standard operation (single core).
  + Observe the current draw on the DC power supply.
  + Run a stress test (if applicable) or maximum toggle rate to simulate peak load.

  *PASS*: Nominal current is $approx 100$ mA and peak current stays below $200$ mA. \
  *FAIL*: Current exceeds $200$ mA.

== Interface: `power_mcu_dcpwr(vref)`

+ *Verify ADC Reference Stability (Vmax 3.6V, Vmin 3.3V)*
  + Power the board via the power block regulator.
  + Measure the voltage at the VREF input pin of the ADC.

  *PASS*: VREF voltage is between $3.3$ V and $3.6$ V.
  *FAIL*: VREF is outside the range or ADC readings fluctuate significantly.

+ *Verify Current Draw (Inominal 1uA)*
  + Verify using datasheet

  *PASS*: Datasheet verifies current draw.

+ *Verify Current Draw (Ipeak 200uA)*
  + Verify using datasheet

  *PASS*: Datasheet verifies current draw.

== Interface: `analog_mcu_asig`

+ *Verify Input Voltage Range ($0.15$ V -- $3.15$ V)*
  Apply a 0V and 3.3V signal to the adc

  *PASS*: The ADC reports values from 0 to 4095 (12-bit) linearly without saturation before $0.15$ V or $3.15$ V. \
  *FAIL*: The ADC output clips early or shows non-linearity.

+ *Verify Bandwidth ($200$ KHz)*
  + Look at the code sampling rate of the ADC

  *PASS*: The ADC is set to sample at 200KHz. \
  *FAIL*: The ADC is not set to 200KHz.

+ *Verify Offset Accuracy ($plus.minus 100$ mV)*
  + Ground the analog input (apply $0$ V at the probe tip).
  + Read the ADC value.

  *PASS*: The ADC reads a voltage value corresponding to $0$ V $plus.minus 100$ mV. \
  *FAIL*: The offset is $> 100$ mV.

== Interface: `trigger_mcu_dsig`

+ *Verify Logic Levels (High $> 2.31$ V, Low $< 0.99$ V)*
  + Set comparator output high, read GPIO input
  + Set comparator output low, read GPIO input

  *PASS*: MCU reads Logic HIGH for comparator high and Logic Low for comparator low. \
  *FAIL*: MCU fails to detect the state change.

+ *Verify Toggle Frequency ($< 120$ kHz)*
  The nyquist frequency for the input signal is 200KHz so we will not be sampling signals greater than 100KHz.

  *PASS*: We never apply frequencies greater than 200KHz \
  *FAIL*: We apply frequencies greater than 200KHz

== Interface: `mcu_backend_data`

+ *Verify Transport Protocol (USB CDC)*
  + Connect the test RP Pico dev board in bootloader mode to a linux computer by holding down the `BOOTSEL` button while plugging it in.
  + From the project root, flash the test firmware by running `cd test-firmware && cargo run`
  + Run `lsusb -v`
  + Observe the output of `bInterfaceClass` under the `ECE342 USB Oscilloscope` section

  *PASS*: `bInterfaceClass` is `Communication` for USB-CDC \
  *FAIL*: `bInterfaceClass` is not `Communication`

+ *Verify Packet Framing (COBS) & Serialization (Postcard)*
  + From the project root run `cd common && cargo test`
  + Observe the cargo test output

  *PASS*: All cargo tests pass. \
  *FAIL*: One or more cargo tests fail.

== Interface: `mcu_analog_dsig` (DC Capacitor)

+ *Verify Output Voltage Levels (Vmax > 2.4V, Voff < 1.02V)*
  + Configure the MCU GPIO to toggle HIGH.
  + Measure voltage at the pin with a multimeter.
  + Configure the MCU GPIO to toggle LOW.
  + Measure voltage at the pin.

  *PASS*: High voltage is $> 2.4$ V (driving relay ON) and Low voltage is $< 1.02$ V (relay OFF). \
  *FAIL*: Low voltage is $> 1.02$ V (risking relay not turning off).

+ *Verify Drive Current (Inominal 10.15mA)*.
  + GPIO pins of the rp2350 can supply up to 12mA at all voltages [1].

  *PASS*: Datasheet says pass. \

== Interface: `mcu_analog_dsig` (Switches)

+ *Verify Output Voltage Levels (Vmax > 2.4V, Voff < 0.8V)*
  + Configure the MCU GPIO to toggle HIGH.
  + Measure voltage at the pin with a multimeter.
  + Configure the MCU GPIO to toggle LOW.
  + Measure voltage at the pin.

  *PASS*: High voltage is $> 2.4$ V (driving relay ON) and Low voltage is $< 0.8$ V (relay OFF). \
  *FAIL*: Low voltage is $> 0.8$ V (risking relay not turning off) or high voltage is < 2.4V.

+ *Verify Drive Current (Inominal 0.005uA)*.
  + GPIO pins of the rp2350 can supply up to 12mA at all voltages [1].

  *PASS*: Datasheet says pass. \

== Interface: `mcu_trigger_comm`

+ *Verify I2C Address (1100000 / 0x60)*
  Look at code to verify I2C address is 1100000.

  *PASS*: The 7-bit address frame matches binary `1100000` (0x60). \
  *FAIL*: The address is incorrect.

+ *Verify Baud Rate (100 kHz)*
  + Look at code to verify baud rate is 100KHz.

  *PASS*: The clock frequency is $approx 100$ kHz. \
  *FAIL*: The frequency is now 100KHz.

  *Verify Baud Rate (100 kHz)*
  + Look at code to verify high speed mode is off

  *PASS*: Code doesn't enable high speed mode. \
  *FAIL*: Code enables high speed mode.
  

= Block 2 Artifacts <block-2-artifacts>
The development of the MCU block required synthesizing resources from embedded systems literature and modern Rust ecosystem tools. Key artifacts that drove the design decisions include:
- *RP2350 Datasheet [1]:* Essential for understanding the GPIO drive strengths and ADC input impedance requirements.
- *Rust Embedded Community Crates:* The discovery of `postcard` [8] and `cobs` [7] was pivotal. Previous attempts using raw binary structs were error-prone; switching to these libraries significantly reduced serialization bugs and overhead.
- *USB CDC Specification:* Understanding the difference between raw bulk transfers and CDC Serial implementation [9] helped in choosing the right driverless approach for the host PC.
- *I2C Logic Analyzer Traces:* Early debugging involved verifying the I2C waveforms for the MCP4725 DAC to confirm address alignment and ACK/NACK behavior before writing the full driver.

= Block 2 Future Recommendations <block-2-future-recommendations>
Reflecting on the Block 2 design cycle, the shift from pure hardware (Block 1) to firmware-heavy integration was a significant change in scope. While Block 1 focused on signal integrity and op-amp stability, Block 2 required a "systems thinking" approach.

For future iterations, I recommend exploring the RP2350's PIO (Programmable I/O) state machines to handle the trigger detection and ADC data movement in parallel with the CPU. This would free up core cycles for digital signal processing (DSP) features like averaging or FFTs directly on the device.

= Block 2 References <block-2-references>

[1] Raspberry Pi Ltd., “RP2350 Datasheet,” Raspberry Pi Ltd., Cambridge, U.K., Jul. 2025. [Online]. Available: https://pip-assets.raspberrypi.com/categories/1214-rp2350/documents/RP-008373-DS-2-rp2350-datasheet.pdf. [Accessed: Feb. 12, 2026].

[2] Toshiba Electronic Devices & Storage Corp., “Photocoupler TLP3441 Datasheet,” May 28, 2025. [Online]. Available: https://toshiba.semicon-storage.com/info/TLP3441_datasheet_en_20250528.pdf?did=29492&prodName=TLP3441. [Accessed: Feb. 12, 2026].

[3]“REF35 Ultra Low-Power, High-Precision Voltage Reference.” Accessed: Jan. 26, 2026. [Online]. Available: https://www.ti.com/lit/ds/symlink/ref35.pdf

[4] Texas Instruments, "OPA320 Precision, 20MHz, RRIO CMOS Op-Amp Datasheet," Rev. D, 2023. \

[5] Microchip Technology Inc., "MCP4725 12-Bit Digital-to-Analog Converter with EEPROM Memory Datasheet," 20005405A, 2007. [Online]. Available: https://ww1.microchip.com/downloads/aemDocuments/documents/OTH/ProductDocuments/DataSheets/20005405A.pdf

[6] S. Cheshire and M. Baker, "Consistent overhead byte stuffing," IEEE/ACM Transactions on Networking, vol. 7, no. 2, pp. 159-172, Apr. 1999, doi: 10.1109/90.769765.

[7] A. Welkie, "cobs: COBS (Consistent Overhead Byte Stuffing) encoding and decoding for Rust," crates.io. [Online]. Available: https://crates.io/crates/cobs. [Accessed: Jan. 25, 2026].

[8] J. Munns, "postcard: A no_std + serde compatible message library for Rust," GitHub. [Online]. Available: https://github.com/jamesmunns/postcard. [Accessed: Jan. 25, 2026].

[9] J. Axelson, USB Complete: The Developer's Guide, 5th ed. Madison, WI, USA: Lakeview Research LLC, 2015.

[10] serialport-rs Contributors, "serialport: A cross-platform serial port library for Rust," crates.io. [Online]. Available: https://crates.io/crates/serialport. [Accessed: Jan. 25, 2026].

[11] Microchip Technology Inc., "MCP6541/1R/1U/2/3/4 Push-Pull Output Sub-Microamp Comparators," DS20001696K, 2020. [Online]. Available: https://ww1.microchip.com/downloads/en/DeviceDoc/MCP6541%20Output%20SubMicroamp%20Comparators%2020001696K.pdf. [Accessed: Feb. 15, 2026].

[12] Analog Devices, "CMOS, Low Voltage, 4 Ω Dual SPST Switches: ADG621/ADG622/ADG623," ADG621 datasheet, Rev. A. [Online]. Available: https://www.analog.com/media/en/technical-documentation/data-sheets/adg621.pdf. [Accessed: Feb. 26, 2026].

#TODO[Uncomment this to use references for this block]
// #bibliography("./my-block-references.yaml")
