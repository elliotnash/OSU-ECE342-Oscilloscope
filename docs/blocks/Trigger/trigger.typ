#import "../../block-diagram.typ": *
#import "../../template.typ": *
#import "../../authors.typ": authors

#show: block-project.with(
  title: [Dual Channel RP2350 USB Oscilloscope Block 2 Documentation],
  authors: authors,
  team-number: "Team Number: 15"
)

#outline(title: none)

#pagebreak()

= Top-Level Architecture Block Diagram <top-level-architecture-block-diagram>

#figure(scale(system-diagram, reflow: true, 80%), caption: [Top-Level Architecture Block Diagram]) <tla-block>

= Block 2 Video Link <block-2-video-link>
https://photos.app.goo.gl/tC3w2M6FDcpBYVYG7


= Block 2 Description <block-2-description>

#figure(scale(trigger-diagram, 120%, reflow: true), caption: [Trigger block black box diagram.]) <analog-block-fig>
The trigger acts as a data acquisition device. In an oscilloscope, the systems is always sampling data and the trigger's role is to identify a specific event to freeze that data in time. If this block didn't exist in the oscilloscope, the waveform would appear unstable. this block ensures that horizontal time axis is synchronized with the input signal. Thr process starts with an input signal from the MCU and the trigger translates that signal into two precise DC voltages which act as the threshold for the trigger. It also takes in the inputs from the analog front end and compares them to the threshold voltages. This comparison leads to a digital output that informs the MCU sample the current data and freeze the signal. 

= Block 2 Design Details <block-2-design-details>
The trigger is comprised of two components, the MCP6571 comparator [2] and the MCP47FEB DAC [1]. The whole trigger block is powered by the power_trigger_dcpwr(vsys) which is from the power block. These two components rely on three different inputs to make a decision, those being analog_trigger_asig, mcu_trigger_comm, and power_trigger_dcpwr(vref). For the analog input (analog_trigger_asig), it takes in the raw voltage waveform from the analog front end and goes into the non-inverting inputs of the comparator. For the digital input (mcu_trigger_comm), this is the communication link from the RP2350 MCU via an I2C bus [5] This is what tells the DAC what specific voltage levle the user wants to trigger at. The reference input (power_trigger_dcpwr(vref)) is a steady DC voltage from the power block that sets the scale for the DAC and defines the maximum possible trigger voltage the system can handle. The process start when the MCU sends a digital value over I2C to the DAC. The DAC then uses the vref input to slice it into smaller steps. For example, since vref is 3.3V and if the MCU sends a 50% code, the DAC will output 1.65V (threshold voltage) to the comparator. Specifically, that 1.65V will be fed into the inverting input of the comparator. The comparator will then look at the difference between the analog input signal and the threshold voltage to output either a logic HIGH or LOW to signify to the MCU that this is the exact time we want to look at at the waveform. This is the trigger_mcu_dsig output interface.     


= Block 2 Interface Validation <block-2-interface-validation>

#figure(table(
  columns: 3,
  table.header(
    [*Interface Property*],
    [*Why is this interface this value?*],
    [*How do you know your design details will meet or exceed this property? Cite your sources in IEEE.*]
  ),
  
  table.header(level: 2, table.cell(colspan: 3)[power_trigger_dcpwr(vsys): Input]),
  [Vmax: 3.3V $plus.minus 5%$ ],
  [This is from the output of the NCP1117 which is in the power block and is getting fed into the MCP6572T-E/SN comparator and MCP47FEB02A0T-E/ST DAC.],
  [For the comparator, it has an input voltage range of 2.7V to 5.5V for guaranteed full specifications which is stated in the datasheet [2]. For the DAC it has an input voltage range of 2.7V to 5.5V for guaranteed full specifications which is stated in the datasheet [1]. ],
  
  [Vmin: 3.3V $plus.minus 5%$ ],
  [This is from the output of the NCP1117 which is in the power block and is getting fed into the MCP6572T-E/SN comparator and MCP47FEB02A0T-E/ST DAC.],
  [For the comparator, it has an input voltage range of 2.7V to 5.5V for guaranteed full specifications which is stated in the datasheet [2]. For the DAC it has an input voltage range of 2.7V to 5.5V for guaranteed full specifications which is stated in the datasheet [1].],

  [Inominal: 350 uA ],
  [The current will be drawn from the NCP1117 and both the comparator and DAC will draw a total of 350 uA under normal operating conditions [1] [2]. ],
  [The NCP1117 can handle a max current draw output of 1A which is more than enough for the DAC and comparator. It is also stated in the datasheet that the comparator draws a nominal current of 90 uA and the DAC draws a 260 uA nominal current [3] [1] [2].  ],

  [Imax: 520 uA ],
  [The current will be drawn from the NCP1117 and both the comparator and DAC will draw a total of 520 uA under max operating conditions [1] [2].],
  [The NCP1117 can handle a max current draw output of 1A which is more than enough for the DAC and comparator. It is also stated in the datasheet that the comparator draws a max current of 140 uA and the DAC draws a max current of 380 uA [3] [1] [2].],

  table.header(level: 2, table.cell(colspan: 3)[power_trigger_dcpwr(vref): Input]),
  [Vmax: 3.3V $plus.minus 0.05%$],
  [This is from the output of the REF3533 IC from the power block and is being fed into the DAC. Since it is meant to be used as a voltage reference to set the trigger level and therefor there is little variance in the input. ],
  [The REF3533 outputs a voltage of 3.3V to be used as reference and this is within the range of the MCP6571 which is 1.8V to 5.5V [2] [4]. ],
  
  [Vmin: 3.3V $plus.minus 0.5%$],
  [This is from the output of the REF3533 IC from the power block and is being fed into the DAC. Since it is meant to be used as a voltage reference to set the trigger level and therefor there is little variance in the input.],
  [The REF3533 outputs a voltage of 3.3V to be used as reference and this is within the range of the MCP6571 which is 1.8V to 5.5V [2] [4].],

  [Inominal: 650nA  ],
  [As this is used as a reference voltage, there should be little to no current draw from the DAC to ensure as much stability as possible.],
  [The datasheet for the REF3533 states that it will typically output a current of 650nA under all operations which is low enough to not cause any instability in the voltage.],

  [Ipeak: 650nA ],
  [As this is used as a reference voltage, there should be little to no current draw from the DAC to ensure as much stability as possible.],
  [The datasheet for the REF3533 states that it will typically output a current of 650nA under all operations which is low enough to not cause any instability in the voltage.],

   table.header(level: 2, table.cell(colspan: 3)[mcu_trigger_comm: Input]),
  [I2C Logic Level: 3.3V $plus.minus$30%],
  [The "high" state is determined by the I2C SDA and SCL lines which are tied to the MCU. ],
  [The MCP47FEB defines a logic high as a minimum of 0.7 X VDD [1]. Since we are feeding a 3.3V supply into VDD it leads to a minimum requirement of 2.31V which gives a lot of head room. ],
  
  [I2C Logic Level: 0V -- 0.99V, LOW ],
  [A logic "low" is created when the MCU connects the bus line to VSS/GND witht he I2C communication lines. Since we have the VSS and GND pins tied together, then the ideal low state is 0V.],
  [The MCP47FEB defines a logic low as a max of 0.3 X VDD [1]. Since we are feeding a 3.3V supply into VDD it leads to a max requirement 0.99V.],

  [Clock Frequency: 100kHz],
  [This is the frequency allocated by our backend.],
  [The MCP47FEB has 100kHZ designated as the "Standard Mode" [1]. ],

   table.header(level: 2, table.cell(colspan: 3)[analog_trigger_asig: Input]),
  [Voltage Range: $0$ V -- $3.3$ V],
  [The RP2350 internal ADC has an absolute maximum input of $3.6$ V and linear range of $0$ -- $3.3$ V [5].],
  [The datasheet for the comparator state that it can take an input voltage of 0 - 3.3V [1]. ],
  
  [Bandwidth: 100kHz],
  [100 kHz is the nyquist frequency while the sampling frequency is 200 kHz. ],
  [The comparator can support up to 100ns switching speed which is in line with the 100kHz bandwidth [1]. ],

  [Offset Accuracy: $plus.minus 100$ mV],
  [To ensure the "zero" line is centered on the screen.],
  [In the analog block, we use 1% tolerance resistors for the summing junction and the OPA320 has a max offset voltage of $150 mu$V [6].],

  table.header(level: 2, table.cell(colspan: 3)[trigger_mcu_dsig: Output]),
  [Output Logic: HIGH],
  [The RP2350 will recognize any voltage value above 2.0V as a logic HIGH [5]. It will read this high as a digital interrupt. It is > 2.4V to ensure there is no chance for the signal to be read as LOW.  ],
  [The MCP6571 is powered by a 3.3V input for power and depending on if conditions are met on the positive and negative rails, the output will reach 3.1V to 3.2V which exceeds the 2.4V requirement [2]. ],
  
  [Output Logic: LOW ],
  [The RP2350 will recognize any voltage value below 0.8V to be recognize as a logic LOW. Once read low, it will stop the trigger from functioning and the oscilloscope will continue as usual.],
  [Since the output of the DAC will be 0V when signaled to, the output of the MCP6571 will also be 0V if certain conditions are met at the positive and negative rails of the input [2]. ],

  [Propagation Delay: < 100ns],
  [In an oscilloscope, the trigger must happen as close to real time as possible. If there is any delay for the comparator to flip its output, the waveform will appear inaccurate leading to timing errors. Setting the interface to 100ns provides a safe buffer to ensure accuracy. ],
  [The MCP6571 has a typical propagation delay of 56ns. This is due to the comparator being optimized for high speed [2]. ],
))

= Block 2 Verification Process <block-2-verification-process>
 *Setup with Power Supply*: In the case where the power block is being tested with a DC power supply, follow the steps below for all interfaces.
      + Get two alligator clips and attach the positive to the input pin of the type-C port and the negative to ground. 
      + Turn on the power supply and set it at 4.75V.
        + Measure all the interfaces with the steps below and confirm that everything is functioning as expected.
      + After measuring all interfaces with 4.75V, turn of the power supply and then set it at 5.25V.
        + Measure all the interfaces with the steps below and confirm that everything is functioning as expected. 
    *Setup with USB-A to Type-C port from a laptop*: In the case where the power block is being tested from a laptop with a USB-A to a Type-C cable, follow the steps below for a interfaces.
      + Get a laptop with a USB-A port and a cable that has goes from USB-A to Type-C. 
      + Plug the cable into the laptop and the Type-C port of the oscilloscope. 
      + Measure all the interfaces with the steps below and confirm that everything is function as expected. 
    *Testing*
    + *Interface: power_trigger_dcpwr(vsys) Input*
      + Measure the voltage directly with a digital multimeter or from the power supply.
      + Confirm that the measured voltage is 3.3V with 5% variances.
      + Increase the current draw up to the expected system load and verify that there is no excessive voltage drop. However since the current draw is in uA scale, it is negligible.
    + *Interface: power_trigger_dcpwr(vref) Input*
      + Measure the voltage with a digital multimeter and ensure that it is stable at 3.3V. 
      + Leave the circuit powered on for around for 2 minutes and remeasure to confirm stability.
      + + Increase the current draw up to the expected system load and verify that there is no excessive voltage drop. However since the current draw is in nA scale, it is negligible.
    + *Interface: mcu_trigger_comm (Input) and trigger_mcu_dsig (Output)* 
      + Open tauri and run `cargo tauri dev`.
      + Once its done programming the board get a wire and a digital multimeter.  
      + Get a wire and short test point 1 on the board to ground to ensure the that the connection to the negative pin is 0V. Since this is lower than the output level of the DAC it should be LOW
      + Go to the test panel on the Oscilloscope app and run the DAC test. 
      + Look at the terminal and sure it says "Trigger level: LOW".
      + Once confirmed, short test point 1 to a 3.3V input. Since this is higher than the output level of the DAC it should be HIGH. 
      + Look at the terminal and ensure it says "Trigger level: HIGH". 
      + Remove wire from the 3.3V signal and run the DAC test again and ensure it says "Trigger level: LOW". This confirms that the propogation delay is less than 100ns.
    + *Interface: analog_trigger_asig Input*
      + The voltage range is confirmed with the previous verification steps from the *nterface: mcu_trigger_comm (Input) and trigger_mcu_dsig (Output)* interfaces as we short the input to ground and 3.3V. 
      + For the bandwidth, it is verified through code as it is set to sample at 200kHz which sets a nyquist frequency of 100kHz. 
      + The offest can be verified by measuring the DAC output and ensuring that the value it is outputting is $plus.minus 100$mV. 



= Block 2 Artifacts <block-2-artifacts>
The development of the trigger block required to think of the trade off and benefits with the use of either an 8-bit DAC or a 12-bit DAC. We eventually found that using an 8-bit DAC is enough for our requirements and was significantly cheaper to reduce costs. The 8-bits perfectly matched the MCU output and was easier to code for [1] . 

= Block 2 Future Recommendations <block-2-future-recommendations>
Upon reflection, this was a slightly more vigorous block than the power block. The power block was straightforward as just had to ensure all the power requirements were met for the system wide. As for the trigger this was a whole new learning process as I never really understood how it functioned. I learned how DACs worked and what the requirements for a functioning trigger are. At first glance, the block was a challenge but looking back it is much more simple than it seems and has given me new insight into how digital and analog communicates function together.

For the future, I recommend looking deeper into DACs and ensure firsthand that all inputs and outputs within the block match properly. Otherwise, you might have to redo the whole block from the beginning.

= Block 2 References <block-2-references>

  [1] 2015 Microchip Technology Inc.. DS20005375A-page 1 MCP47FEBXX features, https://ww1.microchip.com/downloads/en/DeviceDoc/20005375A.pdf (accessed Feb. 12, 2026).

  [2] 2025 Microchip Technology Inc. and its subsidiaries DS20006965B, https://ww1.microchip.com/downloads/aemDocuments/documents/APID/ProductDocuments/DataSheets/MCP6571-1R-1U-2-4-1-8V-40ns-Low-Power-Push-Pull-Output-Comparator-DS20006965.pdf (accessed Feb. 12, 2026). 

  [3]“• NCV Prefix for Automotive and Other Applications Requiring Unique Site and Control Change Requirements; AEC−Q100 Qualified and PPAP Capable.” Available: https://www.onsemi.com/pdf/datasheet/ncp1117-d.pdf

  [4]“REF35 Ultra Low-Power, High-Precision Voltage Reference.” Accessed: Jan. 26, 2026. [Online]. Available: https://www.ti.com/lit/ds/symlink/ref35.pdf

  [5] Raspberry Pi Ltd., “RP2350 Datasheet,” Raspberry Pi Ltd., Cambridge, U.K., Jul. 2025. [Online]. Available: https://pip-assets.raspberrypi.com/categories/1214-rp2350/documents/RP-008373-DS-2-rp2350-datasheet.pdf. [Accessed: Feb. 12, 2026].

  [6] Texas Instruments, "OPA320 Precision, 20MHz, RRIO CMOS Op-Amp Datasheet," Rev. D, 2023.

  [7] Toshiba Electronic Devices & Storage Corp., “Photocoupler TLP3441 Datasheet,” May 28, 2025. [Online]. Available: https://toshiba.semicon-storage.com/info/TLP3441_datasheet_en_20250528.pdf?did=29492&prodName=TLP3441.

 