#import "../block-diagram.typ": *
#import "../template.typ": *

== Analog Block Design Details, Elliot Nash <block-3-design-details-name-of-block-owner>

// Insert Block Design Document details for block 3 here.Include at a minimum the block diagram, description, interface validation table, and artifacts.

#figure(scale(analog-diagram, 120%, reflow: true), caption: [Analog block black box diagram.]) <analog-block-fig>

=== Description


=== Theory of Operation


=== Interface Validation Table

#figure(table(
  columns: 3,
  table.header(
    [*Interface Property*],
    [*Why is this interface this value?*],
    [*Why do you know that your #underline[system] design details meet or exceed each property (reference block details as needed)?*]
  ),
  table.header(level: 2, table.cell(colspan: 3)[*outside_analog_sig: Input*]),
  [Vmin: -15v],
  [The 3.3v voltage regulator on the esp32 c6 supermini has a range of - 2% ],
  [We use 10x attenuation to downconvert input signal voltages,  clamp the input signal to 0-3.3v, and upconvert by 1.65v so our signal is between 0-3.3v],
  
  [Vmax: 15v],
  [The onboard adc on the rp2350 has an input range of 0-3.3v],
  [We use 10x attenuation to downconvert input signal voltages,  clamp the input signal to 0-3.3v, and upconvert by 1.65v so our signal is between 0-3.3v],

  [Fmin: 16Hz],
  [To allow for ac coupling, we needed to put a DC filtering capacitor],
  [The filtering capacitor acts as a high pass filter for any signal above 16hz],
  
  table.header(level: 2, table.cell(colspan: 3)[*analog_adc_asig: Output*]),
    [Vmin: 0v],
  [The adc requires a minimum input voltage of 0v], [I add 1.65v to the attenuated signal voltage so our center point is now at 1.65v and the range is 0v-3.3v],

  [Vmax: 3.3v],
  [The maximum input voltage for the adc is 3.3v], [I clamp the input to between 0 and 3.3v in the analog block],

  [Inominal: 10uA],
  [This is the typical current draw for the adc in the rp2350], [I have a buffer in the analog block that allows for high current draw without impacting the input signal],

))

=== Verification

*Interface: outside_analog_sig (Input)*

    Voltage Range (-15V to +15V): Apply a ±15V sine wave to the input using a function generator. Verify with an oscilloscope that the signal is successfully attenuated by a factor of 10 and that the op-amp rails do not clip the signal after the offset is applied.

    Input Protection: Apply a DC voltage of +25V to the input terminal. Verify with a multimeter that the voltage at the ADC input pin is clamped safely below 3.6V to prevent damage to the RP2350.

*Interface: analog_adc_asig (Output)*

    DC Offset (1.65V): With the input grounded (0V), measure the output voltage at the ADC input pin using a multimeter. Verify the voltage is 1.65V±2%, confirming the signal is centered for the 0V-3.3V ADC range.

    Gain Linearity: Toggle the ADG621 switch states (00,01,10) and measure the peak-to-peak voltage at the output for a known small input signal (e.g., 100mVpp​). Verify that the measured gains match the calculated values (1×,4.125×,20.6×) within a 5% tolerance.

    Signal Fidelity (200kHz): Input a 100kHz square wave. Observe the output on an oscilloscope to verify that the rise/fall times are sharp and that the anti-aliasing filter (160pF capacitor) does not excessively round the edges, ensuring sufficient bandwidth for the 200kHz sampling rate.
