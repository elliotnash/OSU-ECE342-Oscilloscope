#import "/block-diagram.typ": *
#import "/template.typ": *
#import "./analog-diagram.typ": *
#import "/authors.typ": authors

// Helper for red TODO text if not defined in template.typ
#let TODO(content) = text(fill: red, weight: "bold")[#content]

#show: block-project.with(
  title: [Dual Channel RP2350 USB Oscilloscope Analog Block],
  authors: authors,
  team-number: "Team Number: 15"
)

#outline(title: none)

#pagebreak()

= Top-Level Architecture Block Diagram <top-level-architecture-block-diagram>

#figure(
  scale(80%, reflow: true, system-diagram), 
  caption: [Top-Level Architecture Block Diagram]
) <tla-block>

= Block 1 Video Link <block-1-video-link>
https://media.oregonstate.edu/media/t/1_pqyc4hpy

= Block 1 Description <block-1-description>

// #figure(analog-diagram, caption: [Caption here]) <power-bb>


#figure(
  scale(95%, reflow: true, analog-internal-diagram), 
  caption: [Block 1 Internal Design Diagram]
) <block-1-diagram>

#figure(scale(analog-diagram, 120%, reflow: true), caption: [Analog block black box diagram.]) <analog-block-fig>

The *Analog Front-End (AFE)* is responsible for conditioning real-world voltage signals so they can be accurately digitized by the RP2350 microcontroller. Its primary role is to bridge the gap between high-voltage external signals (up to $plus.minus 15$V) and the sensitive, low-voltage input range of the ADC ($0$V -- $3.3$V). 

This block receives the raw analog signal from the BNC connector (`outside_analog_asig`) and control signals from the MCU (`mcu_analog_ctrl`). It performs impedance matching ($1$M$Omega$), AC/DC coupling selection, signal scaling (attenuation and variable gain), and level shifting. The conditioned output (`analog_mcu_asig`) is delivered to the MCU block for digitization. The block is powered by the Power Block (`power_analog_dcpwr`), which provides the necessary $plus.minus 1.65$V and $+3.3$V rails.

= Block 1 Design Details <block-1-design-details>
The Analog Block is designed as a three-stage conditioning chain using high-precision OPA320 operational amplifiers [1]. 

*Stage 1: Input Coupling and Protection*

The input signal first passes through an AC/DC coupling network. A *TLP3441* photorelay is placed in parallel with a $10$nF C0G capacitor [2]. The TLP3441 was selected for its ultra-low OFF-state leakage ($1$nA) and low output capacitance ($0.7$pF), ensuring the system maintains a $5$MHz bandwidth in future iterations. Input protection is provided by *BAT54T1G* Schottky diodes, which clamp any voltage exceeding the $plus.minus 1.65$V rails to prevent damage to the downstream buffer [3]. A $1$M$Omega$ resistor sets the input impedance to match standard oscilloscope probes.

*Stage 2: High-Z Buffer and Programmable Gain*

The signal is buffered by a unity-gain *OPA320* to prevent loading the source. This feeds into the gain stage, which utilizes an *ADG621* analog switch to select different feedback resistors ($320 Omega$, $51 Omega$) [4]. This allows the MCU to digitally select between $1 times$, $4.1 times$, and $20.6$ times gain modes to maximize the ADC's dynamic range for different signal amplitudes. The switch is powered with $-1.65$V and $+3.3$V to handle the full bipolar signal swing without clipping.

*Stage 3: Level Shifting and Anti-Aliasing*

The final stage acts as a summing amplifier, adding a fixed $+1.65$V offset to the bipolar signal. This shifts the $plus.minus 1.65$V swing into the $0$V -- $3.3$V unipolar range required by the RP2350 [5]. Finally, a passive RC anti-aliasing filter ($1$k$Omega$ and $30$pF) limits the bandwidth to approximately $5.3$MHz to reduce noise and prevent aliasing artifacts during digitization.

= Block 1 Interface Validation <block-1-interface-validation>

#figure(table(
  columns: 3,
  table.header(
    [*Interface Property*],
    [*Why is this interface this value?*],
    [*How do you know your design details will meet or exceed this property? Cite your sources in IEEE.*]
  ),
  
  table.header(table.cell(colspan: 3)[*outside_analog_asig: Input*]),
  [Input Impedance: $1$ M$Omega$],
  [Standard impedance for oscilloscope probes to prevent loading the circuit under test.],
  [We utilize a $1$ M$Omega$ metal film resistor ($"R1"$) at the input. The OPA320 buffer has a bias current of $0.9$ pA, ensuring it does not degrade this impedance [1].],
  
  [Input Voltage Range: $plus.minus 15$ V],
  [To allow measurement of a broad range of voltage levels.],
  [The input uses a $10 times$ passive probe (external) combined with internal BAT54T1G clamping diodes that shunt voltages exceeding $plus.minus 1.9$ V (rail + $"V"_f$) to the supplies [3].],

  [Coupling Bandwidth: DC or $>10$ Hz],
  [Users need to measure both DC offsets and pure AC ripple.],
  [The TLP3441 photorelay bypasses the capacitor for DC. In AC mode, the $10$ nF capacitor and $1$ M$Omega$ resistor form a high-pass filter with $"f"_c approx 16$ Hz, passing all relevant AC frequencies [2].],
  
  table.header(table.cell(colspan: 3)[*analog_mcu_asig: Output*]),
  [Voltage Range: $0$ V -- $3.3$ V],
  [The RP2350 internal ADC has an absolute maximum input of $3.6$ V and linear range of $0$ -- $3.3$ V [5].],
  [Stage 3 ($"U2"$) shifts the $plus.minus 1.65$ V signal by adding $+1.65$ V. The op-amp is powered by $3.3$ V and GNDA, physically preventing output below $0$ V or above $3.3$ V [1].],
  
  [Bandwidth: $5$ MHz],
  [To support 200kHz sampling now and future external ADC upgrades.],
  [The anti-aliasing filter ($"R5"=1$ k$Omega, "C2"=30$ pF) creates a cutoff at $5.3$ MHz. The TLP3441 switch capacitance ($0.7$ pF) is negligible [2].],

  [Offset Accuracy: $plus.minus 100$ mV],
  [To ensure the "zero" line is centered on the screen.],
  [We use 1% tolerance resistors for the summing junction and the OPA320 has a max offset voltage of $150 mu$V [1].],

  table.header(table.cell(colspan: 3)[*mcu_analog_dsig: Input (DC Blocking Capacitor)*]),
  [On Voltage: $>2.4$ V],
  [The RP2350 GPIO operates at $3.3$ V and requires compatible input thresholds on switches.],
  [The TLP3441 photorelay needs a current of 10mA with a forward voltage of 1.4v to close the switch [2]. The RP2350 can supply up to 12mA [5].],

  [Off Voltage: $<1$ V],
  [Ensures the photorelay LED is fully extinguished. This opens the switch, forcing the signal through the capacitor for AC coupling.],
  [When the GPIO is at $1$ V, the LED current is $5$ mA with a forward voltage of 0v. The TLP3441 datasheet guarantees an OFF-state leakage of only $1$ nA, ensuring effective isolation [2]. The RP2350 GPIO pins have a default off state at 0v [5].],

  [Coupling Bandwidth: DC or $>10$ Hz],
  [Users need to measure both DC offsets and pure AC ripple.],
  [The TLP3441 photorelay bypasses the capacitor for DC. In AC mode, the $10$ nF capacitor and $1$ M$Omega$ resistor form a high-pass filter with $"f"_c approx 16$ Hz, passing all relevant AC frequencies [2].],

  table.header(table.cell(colspan: 3)[*mcu_analog_dsig: Input (Switch Controls)*]),
  [On Voltage: $3.3$ V],
  [The RP2350 GPIO operates at $3.3$ V for logic high and requires compatible input thresholds on switches.],
  [The ADG621 switch logic high threshold is $2.4$ V [4].],

  [Off Voltage: $0$ V],
  [The RP2350 GPIO operates at $0$ V for logic low and requires compatible input thresholds on switches.],
  [The ADG621 has a logic low threshold of anything less than 0.8v [4].],

  [Gain is adjustable from 0x-23x],
  [Users will need to measure very small signals that are too small for the 12-bit adc to differentiate.],
  [The resistors connected to the switch will create a variable gain stage when combined with the OPA320 op-amp [1], [4].],

  table.header(table.cell(colspan: 3)[*power_analog_dcpwr(vsys): Input*]),
  [Vmax: $3.3$ v],
  [This is the maximum vsys our power block can output.],
  [The OPA2350 has a maximum voltage range from V+ to V- of 6v, which is more than 3.3v, and the ADG621 has a maximum voltage range of 5v, which also covers the 3.3v it is biased with [1],[4].],

  [Vmin: 3.045v],
  [This is the minimum the positive rail of the OPA320 can be biased to and still output a 0-3vpp signal.],
  [The OPA320 needs to be able to swing up to 3v, meaning the power rail needs to be higher by 45mV [1].],

  [Inominal: 1.45mA],
  [This is the nominal current for the opa320, we assume that nominally we will be in ac coupling.],
  [Nominal current draw for 1 power rail of an OPA320 is 1.45mA [1], plus plus negligible quiscent current for ADG621 (1nA)[4].],

  [Ipeak: less than 10mA],
  [Covers the maximum current draw for 1 OPA320, and switch quiescent current.],
  [Calculated peak draw is one OPA320 with a max current of 1.75mA, plus negligible quiscent current for ADG621 (1nA) [1],[2],[4].],

  table.header(table.cell(colspan: 3)[*power_analog_dcpwr(1v65): Input*]),
  [Vmax: $1.67475$ V ],
  [This is the maximum voltage supplied by the power block for this input.],
  [The OPA2350 needs a range of greater than 3v, the ones biased with the 1v65 supply will have a max range of  3.3495, so this will work for the analog block [1].],

  [Vmin:  $1.62525$ V],
  [This is the minimum voltage supplied by the power block for this input.],
  [The OPA2350 needs a range of greater than 3v, the ones biased with the 1v65 supply will have a minimum range of 3.25V, so this will work for the analog block [1].],

  [Imax: less than 10mA ],
  [The max current for the power block for this source is 7.4mA.],
  [The max current for one channel (2 OPA320's) is 3.7mA. This was calculated because the max current draw for one OPA320 is 1.75mA [1].],

  [Inominal: 3mA],
  [The nominal current for the power block for this source is 6mA.],
  [The nominal current draw for one channel (2 OPA320's) is 3mA, this was calculated because the nominal current draw for one OPA320 is 1.45mA [1].],

  table.header(table.cell(colspan: 3)[*power_analog_dcpwr(-1v65): Input*]),
  [Vmax: $-1.62525$ V ],
  [This is the maximum voltage supplied by the power block for this input.],
  [The OPA2350 needs a range of greater than 3v, the ones biased with the -1v65 supply will have a max range of  3.3495, so this will work for the analog block [1].],

  [Vmin:  $-1.67475$ V],
  [This is the minimum voltage supplied by the power block for this input.],
  [The OPA2350 needs a range of greater than 3v, the ones biased with the -1v65 supply will have a minimum range of 3.25V, so this will work for the analog block [1].],

  [Imax: less than 10mA ],
  [The max current for the power block for this source is 7.4mA.],
  [The max current for one channel (2 OPA320's) is 3.7mA. This was calculated because the max current draw for one OPA320 is 1.75mA [1].],

  [Inominal: 3mA],
  [The nominal current for the power block for this source is 6mA.],
  [The nominal current draw for one channel (2 OPA320's) is 3mA, this was calculated because the nominal current draw for one OPA320 is 1.45mA [1].],

  table.header(table.cell(colspan: 3)[*analog_trigger_asig: Output*]),
  [Voltage Range: $0$ V -- $3.3$ V],
  [The RP2350 internal ADC has an absolute maximum input of $3.6$ V and linear range of $0$ -- $3.3$ V [5].],
  [Stage 3 ($"U2"$) shifts the $plus.minus 1.65$ V signal by adding $+1.65$ V. The op-amp is powered by $3.3$ V and GNDA, physically preventing output below $0$ V or above $3.3$ V [1].],
  
  [Bandwidth: $5$ MHz],
  [To support 200kHz sampling now and future external ADC upgrades.],
  [The anti-aliasing filter ($"R5"=1$ k$Omega, "C2"=30$ pF) creates a cutoff at $5.3$ MHz. The TLP3441 switch capacitance ($0.7$ pF) is negligible [2].],

  [Offset Accuracy: $plus.minus 100$ mV],
  [To ensure the "zero" line is centered on the screen.],
  [We use 1% tolerance resistors for the summing junction and the OPA320 has a max offset voltage of $150 mu$V [1].],
  
), caption: [Block 1 Interface Validation Table])

= Block 1 Verification Process <block-1-verification-process>

+ *Interface: outside_analog_asig (Input)*
  + *Input Impedance ($1$ M$Omega$)*
    - *Test:* Using a multimeter, measure the resistance from the input of the block to GNDA on the block.
    - *Verify:* A resistance around 1MOhm is correct.
  + *Input Voltage Range ($plus.minus 15$ V)*
    - *Test:* Apply a DC voltage of $+15$ V and then $-15$ V to the input. Monitor the `analog_mcu_asig` output with an oscilloscope.
    - *Verify:* Ensure the output saturates ("rails out") at safe levels ($3.3$ V and $0$ V respectively) without inverting, and that no components (specifically the TLP3441 or protection diodes) smoke or overheat.
  + *Coupling Bandwidth (DC or $10$ Hz)*
    - *Test:* Set the photorelay to AC-coupled mode (Logic LOW). Apply a $1$ V#sub[pp] sine wave and sweep the frequency from $100$ Hz down to $1$ Hz.
    - *Verify:* The output amplitude should drop by $3$ dB (to $approx 0.707$ V#sub[pp]) at approximately $16$ Hz.

+ *Interface: analog_mcu_asig (Output)*
  + *Voltage Range ($0$ V -- $3.3$ V)*
    - *Test:* Apply overdrive signals ($plus.minus 15$ V) to the main input. Monitor the output.
    - *Verify:* The output clamps cleanly at $0$ V and $3.3$ V.
  + *Bandwidth ($5$ MHz)*
    - *Test:* Sweep input frequency from 1Mhz to 7Mhz and monitor the output.
    - *Verify:* After 5MHz the output becomes a flat line.
  + *Offset Accuracy ($plus.minus 100$ mV)*
    - *Test:* Give a signal from the function generator as an input. Use an oscilloscope to measure the difference between the mean of the signal at the output, and the 1v65 center point.
    - *Verify:* The output reads $1.65$ V $plus.minus 100$ mV.

+ *Interface: mcu_analog_dsig (DC Blocking Capacitor)*
  + *On Voltage ($>2.4$ V)*
    - *Test:* Check that when the voltage is high (>2.4v) the photorelay bypasses the DC blocking capacitor.
    - *Verify:* The output is no longer AC couples and moves with DC offsets.
  + *Off Voltage ($<1$ V)*
    - *Test:* Check that when the voltage is low (< 1v) the photorelay does not bypass the DC blocking capacitor.
    - *Verify:* The output is AC coupled and does not respond to DC offsets.
  + *Coupling Bandwidth (DC or $> 10$ Hz)*
    - *Test:* Set the photorelay to AC-coupled mode (Logic LOW). Apply a $1$ V#sub[pp] sine wave and sweep the frequency from $100$ Hz down to $1$ Hz.
    - *Verify:* The output amplitude should drop by $3$ dB (to $approx 0.707$ V#sub[pp]) at approximately $16$ Hz.

+ *Interface: mcu_analog_dsig: Input (Switch Controls)*
 + *On Voltage ($3.3$ V)*
    - *Test:* Check that when the voltage is high (3v3) the photorelay bypasses the DC blocking capacitor.
    - *Verify:* The output is no longer AC couples and moves with DC offsets.
  + *Off Voltage ($0$ V)*
    - *Test:* Check that when the voltage is low (0v) the photorelay does not bypass the DC blocking capacitor.
    - *Verify:* The output is AC coupled and does not respond to DC offsets.
  + *Gain is adjustable from 0x-23x*
    - *Test:* Set the both inputs of the ADG621 to 0v, measure the gain of the signal from input to output. Set both inputs to high, measure the gain of the signal from input to output. 
    - *Verify:* The gain when both inputs are low is 1x, and the gain when both inputs are high is ~23x.

+ *Interface: power_analog_dcpwr(vsys)*
  + *Maximum Voltage ($3.3$ V)*
    - *Test:* Supply the 3.3v rail with 3.3v.
    - *Verify:* The system works, outputting an attenuated, and filtered waveform.
  + *Minimum Voltage ($3.045$ V )*
    - *Test:* Supply the 3.3v rail with 3.045v.
    - *Verify:* The system works, outputting an attenuated, and filtered waveform.
  + *Current Draw ($10$ mA Max)*
    - *Test:* Check the current coming out of the DC power supply.
    - *Verify:* Total current consumption for the 3v3 source stays below $10$ mA.

+ *Interface: power_analog_dcpwr(1v65)*
  + *Voltage Maximum($1.67475$ V)*
    - *Test:* Supply the 1v65 rail with 1.67475V.
    - *Verify:* The system works, outputting an attenuated, and filtered waveform.
  + *Voltage Minimum($1.62525$ V)*
    - *Test:* Supply the 1v65 rail with 1.62525.
    - *Verify:* The system works, outputting an attenuated, and filtered waveform.
  + *Current Draw(less than $10$ mA)*
    - *Test:* Check the current coming out of the DC power supply.
    - *Verify:* Current draw is $< 10$ mA.

+ *Interface: power_analog_dcpwr(-1v65)*
  + *Voltage Maximum($-1.62525$ V)*
    - *Test:* Supply the -1v65 rail with -1.62525.
    - *Verify:* The system works, outputting an attenuated, and filtered waveform.
  + *Voltage Minimum($-1.67475$ V)*
    - *Test:* Supply the -1v65 rail with -1.67475V.
    - *Verify:* The system works, outputting an attenuated, and filtered waveform.
  + *Current Draw (less than $10$ mA)*
    - *Test:* Check the current coming out of the DC power supply.
    - *Verify:* Current draw is $< 10$ mA.

+ *Interface: analog_trigger_asig (Output)*
  + *Voltage Range ($0$ V -- $3.3$ V)*
    - *Test:* Apply overdrive signals ($plus.minus 15$ V) to the main input. Monitor the output.
    - *Verify:* The output clamps cleanly at $0$ V and $3.3$ V.
  + *Bandwidth ($5$ MHz)*
    - *Test:* Sweep input frequency from 1Mhz to 7Mhz and monitor the output.
    - *Verify:* After 5MHz the output becomes a flat line.
  + *Offset Accuracy ($plus.minus 100$ mV)*
    - *Test:* Give a signal from the function generator as an input. Use an oscilloscope to measure the difference between the mean of the signal at the output, and the 1v65 center point.
    - *Verify:* The output reads $1.65$ V $plus.minus 100$ mV.

= Block 1 Artifacts <block-1-artifacts>
The selection of the **TLP3441** was a key finding; we initially considered the TLP172A but found its $1 mu$A leakage would cause visible DC drift in AC-coupled mode. The TLP3441's $1$nA leakage and sub-pF capacitance ($0.7$pF) ensure signal integrity at $5$MHz. We also determined through simulation that powering the **ADG621** with a $-1.65$V and $+3.3$V split rail was necessary to maintain logic compatibility with the RP2350 while allowing for full bipolar signal swing. Finally, we learned that using 0.1% precision resistors ($"R3", "R6"$) is mandatory for the level-shifter, as standard 1% resistors would result in a centering error larger than 20 LSBs on the 12-bit ADC.

= Block 1 Future Recommendations <block-1-future-recommendations>
The prototype successfully demonstrates the core analog path, but moving to a professional PCB will be necessary to achieve the full $5$MHz bandwidth without breadboard parasitic noise. We recommend implementing a 4-layer stackup with a dedicated analog ground plane and using **guard rings** around the high-impedance $1$M$Omega$ input nodes to prevent surface leakage. Swapping the anti-aliasing capacitor ($"C2"$) for a high-stability **C0G/NP0** dielectric is also recommended to ensure consistent filter performance across varying temperatures.

= Block 1 References <block-1-references>
[1] Texas Instruments, "OPA320 Precision, 20MHz, RRIO CMOS Op-Amp Datasheet," Rev. D, 2023. \
[2] Toshiba, "TLP3441 VSON4 Photorelay Datasheet," Rev. 11.0, 2025. \
[3] Onsemi, "BAT54T1G Schottky Barrier Diodes Datasheet," Rev. 8, 2021. \
[4] Analog Devices, "ADG621 CMOS $plus.minus 5$V / $+5$V $4 Omega$ Dual SPST Switch Datasheet," Rev. B. \
[5] Raspberry Pi Ltd, "RP2350 Datasheet," 2024. [Online]. Available: https://datasheets.raspberrypi.com/rp2350/rp2350-datasheet.pdf
[6]“• NCV Prefix for Automotive and Other Applications Requiring Unique Site and Control Change Requirements; AEC−Q100 Qualified and PPAP Capable.” Available: https://www.onsemi.com/pdf/datasheet/ncp1117-d.pdf

// #bibliography("./my-block-references.yaml")