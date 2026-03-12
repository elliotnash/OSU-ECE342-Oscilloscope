#import "template.typ": *
#import "@preview/subpar:0.2.2"
#import "@preview/zebraw:0.6.1": zebraw
#import "@preview/oxifmt:1.0.0": strfmt
#import "block-diagram.typ": *
#import "authors.typ": authors

// Take a look at the file `template.typ` in the file panel
// to customize this template and discover how it works.
#show: project.with(
  title: "Dual-Channel USB Oscilloscope",
  authors: authors,
  team-number: "Team Number: 15"
)

#show: zebraw

#set enum(numbering: "1.a.i.")

#show outline.entry.where(level: 1): strong
#show outline.entry.where(level: 3): emph
#outline(title: [Table of Contents], depth: 2)

#pagebreak()

= Video link <video-link>
https://media.oregonstate.edu/media/t/1_n92whzd0

= Team Member Work Distribution <team-member-work-distribution>

#let wd-name = (name) => [#authors.at(name).at("name") \ ID: #authors.at(name).at("id")]

#figure(table(
  columns: 3,
  align: left,
  table.header(
    [
      *Name* // Put the name of each member and their ID number in the cells below.
    ],
    [
      *Contributions* // Put a brief description of what tasks each member contributed to in the cells below.
    ],
    [
      *Hours worked (total)* // {Estimate and include the total hours worked by each team member on the team in the cells below.
    ],
  ),
  
  wd-name("yahir"),
  [],
  [100 Hours], 
  
  wd-name("oliver"),
  [],
  [100 Hours],
  
  wd-name("elliot"),
  [],
  [100 Hours],
), caption: [Team member work distribution]) <work-dist-table>

= Engineering Requirements <engineering-requirements>

1. The system will have at least two channels that can function simultaneously and independently.

+ The system must connect and disconnect from the oscilloscope probes using robust connectors.

+ The system must include a configurable trigger, adjustable time, and adjustable voltage axis.

+ The system must respond to user input in under 100 milliseconds.

+ The system must sample at a rate of at least 200 kHz independently on all channels.

+ #highlight[The system will calculate and display the sum, difference, product, or quotient of the input signals on the primary graph when a math function is selected.]

+ #highlight[The system will measure an input voltage range of at least $-15V$ to $+15V$ on each channel when using 10x attenuation probes.]

= System Level Block Diagram <system-level-block-diagram>

// Create a system level block diagram with all system level interfaces labeled.

// Fig. 1: System level block diagram for the portable sensor.

#figure(system-black-box-diagram, caption: [System level black box diagram.]) <sys-bb-fig>

= System Description <system-description>
The Dual Channel RP2350 USB Oscilloscope is a system designed to acquire, process, and visualize analog voltage signals. The system is implemented as a fully custom Raspberry Pi RP2350 based board and integrates with a cross-platform desktop application written in Tuari with ReactJS. The system is designed to sample two independent channels simultaneously at a rate up to $250 "kHz"$, supporting a wide input voltage range of $plus.minus 15V$. It features robust signal processing, hardware-based triggering for waveform synchronization, and real-time mathematical analysis of input signals. The system level input interfaces are *outside_analog_asig*, *outside_pwr_dcpwr*, and *outside_frontend_usrin*. These interfaces power the system, and let users interact with the features and functions of the system. *outside_analog_asig* takes in up to 2 distinct user inputs in the form of a signal. These inputs are connected via a BNC port on the oscilloscope. They are filtered to ensure they are within -15v and +15v at 10x attenuation, and sent to the adc where they are sampled at 250KHz. *outside_pwr_dcpwr* takes in external power from the usb supply, so it can be used to power 4 different supply rails (VSYS, 3.3V, +1.65V, and -1.65V) to distribute around the system. *outside_frontend_usrin* allows the user to control the system by enabling and disabling features. For example, the user can toggle ac/dc coupling, manually set the gain of the signals, choose the voltage level of the trigger, adjust the axis of the chart, and choose different math operations to be performed on the signals. All inputs are sent to the MCU and processed within 100ms. The system level output interface is *frontend_outside_usrout*, which outputs all data the system displays to the user such as the waveform, the sampling frequency, and the data transfer rate of the system. The output also displays user-selected math functions such as the sum, difference, product, and quotient of the input signals.

= System Design Details and Validation <system-design-details-and-validation>

== Top Level Architecture <top-level-architecture>

#figure(scale(system-diagram, reflow: true, 70%), caption: [Top level block diagram.]) <top-block-fig>

The system is structured into six interacting blocks designed for signal acquisition, conditioning, processing, and visualization for the Dual Channel USB Oscilloscope. Centralized control and digitization are managed by the MCU Block (RP2350), which bridges the analog hardware with the computer-based software.

The system starts with the Power Block, which converts external 5V USB-C power into a group of stable, low-noise rails for the rest of the system. Power flows from the external source via the *outside_power_dcpwr* interface. The block generates four distinct voltage rails: an LM27762 charge pump supplies ±1.65V to the Analog and Trigger blocks via *power_all_dcpwr(1v65)* and *power_all_dcpwr(-1v65)*, an NCP1117 linear regulator steps the input down to 3.3V for digital components via *power_all_dcpwr(vsys)*, and a REF3533 IC produces a highly stable 3.3V reference voltage for accurate ADC operations via *power_all_dcpwr(vref)*.

The Analog Block conditions high-voltage real-world signals (up to ±15V) into a sensitive 0V-3.3V unipolar range. It accepts environmental input through the *outside_analog_asig* interface. Utilizing OPA320 op-amps, an ADG621 switch, and a TLP3441 photorelay, the block performs impedance matching, AC/DC coupling, variable gain scaling, level shifting, and anti-aliasing. The MCU digitally controls the coupling and gain via the *mcu_analog_dsig* interface. The conditioned signal is routed to the MCU via *analog_mcu_asig* for digitization and to the Trigger block via *analog_trigger_asig*. The block receives its power from the *power_analog_dcpwr* interfaces.

The Trigger Block serves as a data acquisition event identifier to synchronize the horizontal time axis and freeze the waveform on the screen. It receives the conditioned signal from the Analog Block via *analog_trigger_asig*. The MCU sets a specific threshold voltage by sending digital values to an MCP47FEB DAC over an I2C bus via the *mcu_trigger_comm* interface. An MCP6571 comparator evaluates the analog input against this threshold, outputting a digital logic signal to the MCU via trigger_mcu_dsig when the designated event occurs. The block is powered through the *power_trigger_dcpwr(vsys)* and *power_trigger_dcpwr(vref)* interfaces.

The MCU Block coordinates data acquisition, system control, and transport. Powered by the *power_mcu_dcpwr(vsys)* and *power_mcu_dcpwr(vref)* interfaces, the RP2350 microcontroller digitizes the incoming *analog_mcu_asig* waveform with its internal ADC. It monitors the *trigger_mcu_dsig* pin to synchronize data capture and drives the *mcu_analog_dsig* GPIO pins to dictate coupling modes. After data is sampled, the firmware serializes the waveform and system state using the postcard library, frames it with COBS, and transmits it via the *mcu_backend_data* interface over a high-speed USB CDC stream.

The Backend Block acts as a protocol translation layer, decoupling the low-level byte-stream from the presentation logic. It ingests raw bytes from the MCU via *mcu_backend_data*, reverses the COBS framing, and deserializes the payload into a type-safe Message enum. This structured data is emitted to the application interface via Tauri IPC channels, represented by *frontend_backend_data*. In reverse, it accepts user commands from the frontend, serializes them into compact binary arrays, and transmits them to the MCU to modify hardware parameters.

The Frontend Block provides the graphical user interface (GUI) and data visualization. Built with React, TypeScript, and the visx library, it translates physical user actions via outside_frontend_usrin into state changes and sends commands over the *frontend_backend_data* IPC bridge. Concurrently, it receives high-frequency waveform updates from the backend and renders them smoothly at 60Hz as a 2D line plot. This visual output is presented to the user through the *frontend_outside_usrout* interface.



== System Design Synthesis <system-design-synthesis>
The system starts at the power block the moment it is powered by a source through the Type-C port. It can handle an input voltage of 4.75-5.25V as that is the common rated voltage for USB 1.0. That voltage is fed into three separate parts within the power block, a charge pump IC (LM2772), a voltage regulator IC (NCP 1117), and a voltage reference IC (REF3533). The power block utilizes the LM2772 IC in order to output both a positive and negative voltage. Using a resistor feedback loop, it ensures that a $plus.minus 1.65$V is being outputted from the charge pump and being fed into the analog front end. The power block utilizes the NCP1117 voltage regulator to take in the input voltage from the USB-C and regulate it down to 3.3V. This is required to power all the digital components of the system such as the MCU and DAC, while also powering certain portions of the analog front end that require 3.3V. The system utilizes a REF3533 voltage reference IC that takes in the input voltage from the USB-C and outputs an accurate, low drift, low noise voltage of 3.3V that will be fed into the built in ADC of the system's MCU. This is done in order to ensure accurate measurements for the analog input signals that the system will be reading. It is also fed into the voltage reference input of the DAC to use as reference point and set a trigger level which doesn't allow for any variance in the voltage.

The system takes user inputs in the form of signals via the robust BNC connectors present on the oscilloscope. The BNC connectors send the signal to the analog frontend. The analog frontend clamps the signal to ensure components will not be damaged by a large signal, before attenuating, boosting, and shifting the signal so it is within the 0v-3.3v range of the onboard ADC. After the analog frontend, the signal reaches the MCU via the onboard ADC on the rp2350. The ADC reads both signals at a 250KHz frequency, alternating the channel it is reading each sample. The MCU uses direct memory access to store the readings from the ADC in memory without using any clock cycles. 

The trigger is comprised of two parts, a DAC (MCP47FEB) and a dual opamp comparator (MCP6571). Both the comparator and DAC are powered by the 3.3V output of the NCP1117. The DAC also takes an input from the REF3533 as the stable voltage is used to set a reference point to set the trigger level. The DAC communicates with the MCU via an I2C bus. This is what tells the DAC what specific voltage level the trigger will be set at depending on user input. The comparator takes in the the raw voltage output of the analog front end and is then being compared with the output of the DAC to compare the two signals. Depending on the condition of the comparison, the comparator will output either a HIGH or LOW voltage that will be fed into the MCU.

== Block Design Details List <block-design-details-list>

https://drive.google.com/drive/folders/10tl-D512dH_5b8krq08DCzfzgaj1gc30?usp=sharing

= System Level Interface Validation Table <system-level-interface-validation-table>

// Be sure to include only system-level interfaces. System-level interface values and properties must match their corresponding block-level interfaces.

#figure(table(
  columns: 3,
  table.header(
    [*Interface Property*],
    [*Why is this interface this value?*],
    [*Why do you know that your #underline[system] design details meet or exceed each property (reference block details as needed)?*]
  ),
  
  table.header(level: 2, table.cell(colspan: 3)[*outside_analog_asig: Input*]),
  [Input Impedance: $1$ M$Omega$],
  [Standard impedance for oscilloscope probes to prevent loading the circuit under test.],
  [We utilize a $1$ M$Omega$ metal film resistor ($"R1"$) at the input. The OPA320 buffer has a bias current of $0.9$ pA, ensuring it does not degrade this impedance @ti_opa320_2023.],
  
  [Input Voltage Range: $plus.minus 15$ V],
  [To allow measurement of a broad range of voltage levels.],
  [The input uses a $10 times$ passive probe (external) combined with internal BAT54T1G clamping diodes that shunt voltages exceeding $plus.minus 1.9$ V (rail + $"V"_f$) to the supplies @onsemi_bat54t1g_2021.],

  [Coupling Bandwidth: DC or $>10$ Hz],
  [Users need to measure both DC offsets and pure AC ripple.],
  [The TLP3441 photorelay bypasses the capacitor for DC. In AC mode, the $10$ nF capacitor and $1$ M$Omega$ resistor form a high-pass filter with $"f"_c approx 16$ Hz, passing all relevant AC frequencies @toshiba_tlp3441_2025.],
  
  table.header(level: 2, table.cell(colspan: 3)[*outisde_power_dcpwr: Input*]),
  [Vmin: 4.75V ],
  [The input will be from a USB connection to a laptop which is usually around 5V.],
  [This is the common rated voltage for the USB 1.0 specification @samesky_uj20. ],
  
  [Vmax: 5.25V ],
  [The input will be from a USB connection to a laptop which is usually around 5V.],
  [This is the common rated voltage for the USB 1.0 specification @samesky_uj20.],

  [Inominal: 129 mA ],
  [The current draw from all components from the oscilloscope under normal operating conditions is 117 mA.  ],
  [For the USB 1.0, it has the ability to handle up to 500 mA of current draw which is high enough to support the system's needs @samesky_uj20. ],

  [Ipeak: Less than 188mA],
  [The current draw from all components from the oscilloscope under max current draw conditions is 187.8 mA meaning the system will have to support up to 188mA.],
  [For the USB 1.0, it has the ability to handle up to 500 mA of current draw which is high enough to support the system's needs @samesky_uj20. ],
  
  table.header(level: 2, table.cell(colspan: 3)[*outside_frontend_usrin: Input/Output*]),
  
  [*Input Types:* Button Group, Dropdown, Switch, Text Input],
  [Button Groups, Dropdowns, and Switches provide easy ways for users to input data and guarantees input data is valid. Text Inputs allow power users to enter custom math expressions that would be impossible to express with more restricted input types @input_ux.],
  [Each input component in the frontend uses components from IntentUI, which use react-aria to implement standard HTML input types @intentui @github[frontend/src/routes/home.tsx, frontend/src/components]],

  [*Actions:* Toggle Channels (A/B), Select Voltage Scale, Select Coupling Mode, Select Probe Attenuation, Set Sampling Rate, Enable Math Mode, Set Math Mode Operation.],
  [These actions allow performing standard oscilloscope operations, allowing users to manipulate both the viewport and sampling characteristics of the hardware @oscope_basic_guide.],
  [The frontend code implements these actions in the event handlers, and invokes a Tauri command to dispatch each action @github[frontend/src/routes/home.tsx].],

  [*Data Ranges:* Voltage: $plus.minus 15V$, $plus.minus 3.6V$, $plus.minus 0.7V$, $plus.minus 1.5V$, $plus.minus 0.36V$, $plus.minus 0.07V$; Coupling: AC, DC; Attenuation: 1x, 10x.],
  [These data ranges are set to restrict user input to values that are supported by the physical hardware. Each voltage scale value corresponds to the maximum input voltage with each gain setting in the Analog Frontend Block, the coupling mode corresponds to whether the DC blocking capacitor is shorted, and attenuation corresponds to the value set on the probes @github[hardware].],
  [The frontend code passes these ranges to each input component which passes it to the native HTML controls, allowing only these specific values to be entered @github[frontend/src/routes/home.tsx].],
  
  table.header(level: 2, table.cell(colspan: 3)[*frontend_outside_usrout: Input/Output*]),

  [*Output Type:* 2D Line Graph],
  [A typical Cartesian graph where the waveform is displayed as a line is the standard way to display oscilloscope waveform data.],
  [The frontend uses the VISX library to visualize data, using `LinePath` from `@visx/shape` to draw a 2d line graph @visx_shape @github[frontend/src/routes/home.tsx].],

  [*Refresh Rate:* > 55Hz],
  [A refresh rate of 60Hz is typical for many displays and 55Hz is fast enough to allow the waveform updates to appear smooth. Additionally, the minimum 55Hz corresponds to a frame time of 18ms (1/55), which is well under the required minimum response time of 100ms.],
  [The frontend code uses the `requestAnimationFrame` API to schedule component redraws that are synchronized with the monitors refresh rate @github[frontend/src/routes/home.tsx]. Since all of the computers we will use with the oscilloscope have at least 60Hz displays, this will happen at at least 60Hz.],

  [*Waveform Interpolation:* \ Linear],
  [Since ADC samples are discrete, some sort of interpolation is required to display the waveform. Linear interpolation is used since it very simple to implement, does not take much computational power, and doesn't suffer from overshoot @interpolation],
  [The frontend code displays the waveform using `LinePath` from the VISX library, which is passed `curveLinear` to the curve argument, setting the waveform to use linear interpolation @github[frontend/src/routes/home.tsx]],

  [*Channel Colors:* \ Channel A: Purple, \ Channel B: Red, \ Math: Green],
  [Setting distinct colors for each channel allow users to easily and quickly identify the signal they are working with @input_ux.],
  [The frontend defines global css variables for each color used on the graph which are consumed by the graph component @github[frontend/src/globals.css]],  
), caption: [System level interface validation table])

= Verification Process <verification-process>

== Verification Setup

The following steps set up the oscilloscope for testing and should be followed before performing any of the engineering requirement verifications. Ensure the oscilloscope is set back to this state before verifying subsequent requirements.

1. Connect an oscilloscope probe to each BNC connector on the oscilloscope. Ensure each probe is set to $1x$ attenuation.

+ Connect the oscilloscope to a computer using the USB C cable.

+ Ensure the latest firmware is flashed by running `cargo run-rp2350` in the `firmware` directory.

+ Start the client app by running `cargo tauri dev` in the project root directory.

+ Wait for the client to connect to the oscilloscope. Once connected, the LED on the oscilloscope will pulse green, and the client will show a waveform.

+ Connect a cable to the function generator and set it to output a $plus.minus 1.5V$ sin wave at $10 "KHz"$.

+ On the client app, ensure both channels are enabled, set the sampling rate to $250 "KHz"$, and click `auto scale`.

== ER 1: The system will have at least two channels that can function simultaneously and independently.

=== Verification

+ Connect a cable to the DC power supply, and set it to output $1.5V$.

+ Connect the the function generator cable to the oscilloscope probe connected to channel A.

+ Verify that the sin wave is displayed on channel A, and that channel B reads $0V$.

+ Connect the DC power supply cable to channel B, and verify channel B reads a constant $1.5V$ while channel A remains unchanged.

=== Pass

Channel A displays a $plus.minus 1.5V$ sin wave, while channel B displays a constant $1.5V$ signal.

=== Fail

At least one of the channels is not displayed or displays incorrect data.

== ER 2: The system must connect and disconnect from the oscilloscope probes using robust connectors.

=== Verification

1. Observe that the two probe connectors on the side of the oscilloscope are BNC connectors. Since BNC connectors are the standard oscilloscope connector type, this property is verified @bnc_are_robust.

== ER 3: The system must include a configurable trigger, adjustable time, and adjustable voltage axis.

=== Verification

1. Locate the time slider below the waveform.

+ Adjust the time scale by dragging either of the end points, and verify that waveform scales horizontally.

+ Pan the time axis by dragging the center of the slider, and verify the waveform pans horizontally.

+ Pan the time axis all the way to the left such that time zero is visible on the waveform.

+ Set the trigger to $0V$. The waveform should freeze in place.

+ Set the trigger to $1V$. The waveform should jump slightly to the left.

+ Locate the two voltage sliders on the right of the waveform. Each channel has an independent scale, denoted by the color of the slider.

+ Drag the endpoints of the channel A voltage scale, and ensure the waveform scales vertically.

+ Drag the center of the channel A voltage scale, and ensure the waveform pans vertically.

=== Pass

The time/voltage axis scales/pan appropriately with the sliders, and the waveform freezes at the trigger point when the trigger is enabled.

=== Fail

Either the time/voltage axis does not scale/pan appropriately with the sliders, or the waveform does not freeze at the trigger point when the trigger is enabled.

== ER 4: The system must respond to user input in under 100 milliseconds.

=== Verification

1. Position a stopwatch with milliseconds near the client window.

+ Using a slow motion camera, record the client app so that both the app and stopwatch are visible.

+ Click the `auto scale` button.

+ Save the video, and observe the time at which the button was clicked and the time in which the axis update

=== Pass

The difference between the time at which the `auto scale` button was clicked and the time the axis updates is less than $100 "ms"$.

=== Fail

The difference between the time at which the `auto scale` button was clicked and the time the axis updates is greater than $100 "ms"$.

== ER 5: The system must sample at a rate of at least 200 kHz independently on all channels.

=== Verification

1. Set the `sample rate` to $250 "KHz"$, and verify the waveform is correctly displayed.

+ Disconnect the probe from the channel A BNC connector, and connect it to channel B. Verify that the waveform is still correctly displayed.

=== Pass

Both channel A and channel B display the $plus.minus 1.5V$ waveform when sampling at $250 "KHz"$.

=== Fail

At least one the channels does not correctly display the $plus.minus 1.5V$ waveform when sampling at $250 "KHz"$.

== ER 6: The system will calculate and display the sum, difference, product, or quotient of the input signals on the primary graph when a math function is selected.

=== Verification

1. Connect a cable to the DC power supply, and set it to output $1V$.

+ Connect the DC power cable to the channel B oscilloscope probe. Ensure both channels are enabled on the client app.

+ Enable the math channel.

+ Set the math mode to `sum`, and verify that the math signal shows the sin wave with a $+1V$ offset.

+ Set the math mode to `difference`, and verify that the math signal shows the sin wave with a $-1V$ offset.

+ Set the math mode to `product`, and verify the math signal shows the sin wave with no offset.

+ Set the math mode to `difference`, and verify the math signal shows the sin wave with no offset.

=== Pass

The math waveform shows the correct values for each operation.

=== Fail

The math waveform fails to display or has at least one operation with an incorrect value.

== ER 7: The system will measure an input voltage range of at least *$-15V$* to *$+15V$* on each channel when using 10x attenuation probes.

=== Verification

1. Switch the attenuation on the probe on channel A to 10x.

+ Set the attenuation setting on the client app to 10x.

+ Set the signal from the function generator to at least 15vpp.

+ Unplug the probe from channel A and connect it to channel B

=== Pass

Both channels A and B display at least +/- 15V range when using 10x attenuation.

=== Fail

One channel does not display at least +/-15V when using 10x attenuation.

= Future Recommendations <future-recommendations>
  
  1. What were the main events? Identify a few (at least 2) key turning points from the past few months.
    + On of the main events was getting our first PCB revision. This is what determined if our initial design worked as intended or if there was more work to do. After testing we quickly realized there had to be a new revision. 
    + Another main event was the arrival of our second PCB revision. After fixing small mistakes and improving upon our first revision, this one was a success and works exactly as intended. This allowed us to focus on documentation and coding the rest of the project. 
  
  2. What were the most important challenges you faced? How did you overcome them or reduce their overall impact on your project?
    + Our biggest challenge was debugging our first pcb, which took long hours and late nights. We overcame this by utilizing unique tests like a heat camera to find shorts in our design.
    + Another challenge was using our Oshpark stencil to solder our parts on the first pcb. We had trouble with our Oshpark stencil because it had too big tolerances that led to connections being shorted. To overcome this, Elliot was able to get the MCU connections cleaned up using a soldering iron. In the future we will just use a JLCPCB stencil from the beginning. 
  
  3. If another team took over this project right now, what is the most important information they would need to move forward?
    + If another team were to take over this project and had the option to order a new pcb, we would tell them that the PSRAM is too far from the MCU to be read. This is important because with extra external PSRAM allows for more data to be stored before sending the frame to the computer frontend.
    + We would tell the team that the pcb design can be improved and optimized a bit more space wise, but that would make the process of soldering and placing the parts much more difficult.
  
  4. What advice would you give that new team starting from now?
    + If your updating the design and ordering a new PCB, be sure to order from JLPCB and order their metal stencils. Using a plastic one doesn't provide the stability and accuracy a metal one would and makes soldering all the small parts difficult. 
    + You should constantly be iterating and updating the documentation. It is much easier to stay on top of the documentation and change interface properties when you change the design instead of waiting until later.
  
  5. What advice would you give yourself if you could relay the information at the start of the term?
    + Oliver: I would tell myself to check the pin assignments of generic KICAD symbols, as we had footprint issues on our first pcb.
    + Yahir: I would tell myself to look at the sizes of any part you are ordering as we had issues with the charge pump due to its size. I never realized how small it would be and we would've benefitted from using a larger size.
    + Elliot: 

#bibliography("references.bib", title: [References]) <references>
