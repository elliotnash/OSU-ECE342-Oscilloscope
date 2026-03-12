#import "../../block-diagram.typ": *
#import "../../template.typ": *
#import "../../authors.typ": authors

#show: block-project.with(
  title: [Dual Channel RP2350 USB Oscilloscope Power Block],
  authors: authors,
  team-number: "Team Number: 15"
)

#outline(title: none)

#pagebreak()

= Top-Level Architecture Block Diagram <top-level-architecture-block-diagram>

#figure(scale(system-diagram, reflow: true, 80%), caption: [Top-Level Architecture Block Diagram]) <tla-block>

= Block 1 Description <block-1-description>

= Power Block Video Link <backend-video-link>
https://media.oregonstate.edu/media/t/1_zcpy5qh8

== Analog Block Design Details <block-3-design-details-name-of-block-owner>

#figure(power-diagram, caption: [Power block diagram]) 
 
#figure(image("./power-blocks.svg", height: 38%), caption: [Power internal flow diagram])

The power block converts an external USB-C [1] power supply into a group of stable low noise rails required by the rest of the system. It will accept a 5V input from an outside source into the USB-C and distribute it as the primary supply rail. From there it will generate power in four different rails due to the system needing different voltages for analog and digital components as well as a highly stable voltage reference output.

The analog portion of the oscilloscope will be powered by the LM27762 [2] and will be able to supply a voltage of $plus.minus 1.65$V. The digital portion of the oscilloscope will be powered by an [3] NCP1117 as it will take the USB-C input power and output 3.3V. This output will be used by the digital components of the oscilloscope. As for the voltage reference, it will take the USB-C input power and output a very precise voltage with low noise to be used as reference for the built-in ADC of the RP2350 [5].


= Block 1 Design Details <block-1-design-details>

The Power Block is designed to supply power to three major sections of the oscilloscope using voltage regulators and voltage reference IC. 

*USB-C:* A voltage will enter the system through the USB-C and is essentially the raw system voltage supply. It will have two resistors attached to the CC1 and CC2 pin to indicate that it will be a power sink device in use [1]. 

*LM27762:* The LM2772 is a voltage regulator that can take an input of 2.7V to 5.5V that has an internal charge pump inverter to be able to create a negative supply rail [2]. This allows for two low noise low dropout regulators. At the input there is a capacitor that provides decoupling to reduce any ripple for the the charge pump. This IC also has the ability to adjust the output voltage using a feedback loop for both positive and negative rails. In this case I use a voltage divider for both outputs to ensure a $plus.minus 1.65$V output. There is a capacitor in parallel with each of the voltage dividers to ensure stability and reduce output noise for any sudden changes. The output will be used to power the analog portion of the oscilloscope

*NCP1117:* The NCP1117 is a linear regulator that takes in the voltage from the USB-C output and drops it down to a 3.3V output [3]. It also provides current limiting and thermal protection. It can take an input of maximum 20V but it there is a maximum dropout of around 1.2V at 800 mA. For our case this means the voltage input needs to be 4.75V to 10V. There is a capacitor at both the input and output to provide decoupling and ensure stability. The output will be used to power any digital components. 

*REF3533:* The REF3533 is a voltage reference IC that has high precision, is low power, and has incredibly low noise in its output [4]. The goal is to take the voltage output of the USB-C and output an accurate, low drift, low noise voltage that will be used by the built in ADC of the RP2350 [5] for accurate measurements for the analog input signals.  There is a capacitor at the input supply to decouple and keep any noise from modulating the IC. There is a capacitor near the output to filter out any output noise. 


= Block 1 Interface Validation <block-1-interface-validation>

#figure(table(
  columns: 3,
  table.header(
    [*Interface Property*],
    [*Why is this interface this value?*],
    [*How do you know your design details will meet or exceed this property? Cite your sources in IEEE.*]
  ),
  
  table.header(level: 2, table.cell(colspan: 3)[*outisde_power_dcpwr: Input*]),
  [Vmin: 4.75V ],
  [The input will be from a USB connection to a laptop which is usually around 5V.],
  [This is the common rated voltage for the USB 1.0 specification [1]. ],
  
  [Vmax: 5.25V ],
  [The input will be from a USB connection to a laptop which is usually around 5V.],
  [This is the common rated voltage for the USB 1.0 specification [1].],

  [Inominal: 129 mA ],
  [The current draw from all components from the oscilloscope under normal operating conditions is 117 mA.  ],
  [For the USB 1.0, it has the ability to handle up to 500 mA of current draw which is high enough to support the system's needs [1]. ],

  [Ipeak: Less than 188mA],
  [The current draw from all components from the oscilloscope under max current draw conditions is 187.8 mA meaning the system will have to support up to 188mA.],
  [For the USB 1.0, it has the ability to handle up to 500 mA of current draw which is high enough to support the system's needs [1]. ],

  table.header(level: 2, table.cell(colspan: 3)[*power_all_dcpwr(vref): Output*]),
  [Vmax: 3.3V $plus.minus 0.05%$],
  [This output will be fed into an ADC as a voltage reference point for the analog filtering. Because of this we have to ensure that the IC will not fluctuate in any capacity to reduce as much noise as possible. This IC allows has an output accuracy within 0.05% which is low enough to not cause any issues [4].  ],
  [The output variance of $plus.minus 0.05%$ is assumed to be in room temperature and it is specified in the data sheet [4].],
  
  [Vmin: 3.3V $plus.minus 0.05%$],
  [This output will be fed into an ADC as a voltage reference point for the analog filtering. Because of this we have to ensure that the IC will not fluctuate in any capacity to reduce as much noise as possible. This IC allows has an output accuracy within 0.05% which is low enough to not cause any issues [4].  ],
  [The output variance of $plus.minus 0.05%$ is assumed to be in room temperature and it is specified in the data sheet [4].],

  [Inominal: 650nA ],
  [Since this will be fed into an ADC we needed an output with virtually no current to ensure accuracy. ],
  [650nA is low enough to not cause any problems to the ADC and this is met by this IC as specified in the datasheet [4]. ],

  [Ipeak: 650nA ],
  [Since this will be fed into an ADC we needed an output with virtually no current to ensure accuracy. ],
  [650nA is low enough to not cause any problems to the ADC and this is met by this IC as specified in the datasheet [4]. ],
  
  table.header(level: 2, table.cell(colspan: 3)[*power_all_dcpwr(1v65): Output*]),
  [Vmax: 1.65V $plus.minus 1.5%$ ],
  [It was determined that parts of the analog portions would require a 1.65V input for measurement. Because of this we needed an IC that had an adjustable voltage output as there were no ICs that outputted 1.65V. ],
  [The output of this IC can be adjusted with a feedback loop. With the use of a 18.7k resistor and 50k resistor and placing them as a voltage divider, we can ensure that the output is 1.65V with little fluctuation [2]. ],
  
  [Vmin: 1.65V $plus.minus 1.5%$ ],
  [It was determined that parts of the analog portions would require a 1.65V input. Because of this we needed an IC that had an adjustable voltage output as there were no ICs that outputted 1.65V.],
  [The output of this IC can be adjusted with a feedback loop. With the use of a 18.7k resistor and 50k resistor and placing them as a voltage divider, we can ensure that the output is 1.65V with little fluctuation [2].],

  [Ipeak: 7.4mA ],
  [It was determined that the analog front end would require 7.4mA at its max draw.  ],
  [A max output of 250mA was specified in the datasheet for the LM27762 which is more than enough for what is required by the analog front end [2]. ],

  [Inominal: 6mA],
  [It was determined that the analog front end would require a nominal current of 6mA.],
  [A max output of 250mA was specified in the datasheet for the LM27762 which is more than enough for what is required by the analog front end [2].],

table.header(level: 2, table.cell(colspan: 3)[*pwr_all_dcpwr(-1v65): Output*]),
  [Vmax: -1.65V $plus.minus 1.5%$],
  [It was determined that parts of the analog portions would require a -1.65V input for measurement. Because of this we needed an IC that had an adjustable voltage output as there were no ICs that outputted 1.65V. ],
  [The output of this IC can be adjusted with a feedback loop. With the use of a 18.7k resistor and 50k resistor and placing them as a voltage divider, we can ensure that the output is -1.65V with little fluctuation [2].],
  
  [Vmin: -1.65V $plus.minus 1.5%$],
  [It was determined that parts of the analog portions would require a -1.65V input for measurement. Because of this we needed an IC that had an adjustable voltage output as there were no ICs that outputted 1.65V.],
  [The output of this IC can be adjusted with a feedback loop. With the use of a 18.7k resistor and 50k resistor and placing them as a voltage divider, we can ensure that the output is -1.65V with little fluctuation [2].],

  [Ipeak: 7.4mA],
  [It was determined that the analog front end would require 7.4mA at its max draw. ],
  [A max output of 250mA was specified in the datasheet for the LM27762 which is more than enough for what is required by the analog front end [2]. ],

  [Inominal: 6.0mA],
  [It was determined that the analog front end would require a nominal current of 6mA.],
  [A max output of 250mA was specified in the datasheet for the LM27762 which is more than enough for what is required by the analog front end [2].],

table.header(level: 2, table.cell(colspan: 3)[*pwr_all_dcpwr(3V3): Output*]),
  [Vmax: 3.3V $plus.minus 2%$],
  [For some parts of the analog portion of the oscilloscope and for all the digital components that will be used, they have to be provided a voltage of 3.3V for measurement and powering. This linear regulator will output the needed 3.3V. ],
  [This is a linear low dropout voltage regulator that can take an input voltage of 4.75V to 10V and output 3.3V as specified in the data sheet [3]. ],
  
  [Vmin: 3.3V $plus.minus 2%$],
  [For some parts of the analog portion of the oscilloscope and for all the digital components that will be used, they have to be provided a voltage of 3.3V for measurement and powering. This linear regulator will output the needed 3.3V.],
  [This is a linear low dropout voltage regulator that can take an input voltage of 4.75V to 10V and output 3.3V as specified in the data sheet [3].],

  [Inominal: 97mA],
  [This output will be fed into the digital components of the Oscilloscope such as the RP2350, DAC, etc. In total it was determined that in nominal operating conditions, there will be a total current draw of 96.9mA. ],
  [The NCP117 has a maximum output current of 1A as specified in the datasheet which is more than enough for what is required [3]. ],

  [Ipeak: Less than 128mA ],
  [This output will be fed into the digital components of the Oscilloscope such as the RP2350, DAC, etc. In total it was determined that in max current draw conditions, there will be a total current draw of 128mA. ],
  [The NCP117 has a maximum output current of 1A as specified in the datasheet which is more tan enough for what is required [3]. ],
))
  


= Block 1 Verification Process  <block-1-verification-process>
     *Setup with Power Supply*: In the case where the power block is being tested with a DC power supply, follow the steps below for all interfaces.
      + Get two alligator clips and attach the positive to the input pin of the type-C port and the negative to ground. 
      + Turn on the power supply and set it at 4.75V.
        + Measure all the interfaces with the steps below and confirm that everything is functioning as expected.
      + After measuring all interfaces with 4.75V, turn of the power supply and then set it at 5.25V.
        + Measure all the interfaces with the steps below and confirm that everything is functioning as expected. 
    *Setup with USB-A to Type-C port from a laptop*: In the case where the power block is being tested from a laptop with a USB-A to a Type-C cable, follow the steps below for a interfaces.
      + Get a laptop with a USB-A port and a cable that has goes from USB-A to Type-C. 
      + Plug the cable into the laptop and the Type-C port of the power block. 
      + Measure all the interfaces with the steps below and confirm that everything is function as expected. 
  + *Interface: outside_power_dcpwr input*
    + *Testing*
      + Measure the voltage directly with a digital multimeter or from the power supply.
      + Confirm that the measured voltage is 4.75V to 5.25V with slight variances.
      + Increase the current draw up to the expected system load and verify that there is no excessive voltage drop.  

  + *Interface: power_all_dcpwr(vref) output*
    + *Testing*
      + Measure the output of the REF3533 with a digital multimeter and ensure that it is stable at 3.3V.
      + Observe the output on an oscilloscope with AC coupling to check for any noise and ripple. 
      + Leave the circuit powered on for around for 2 minutes and remeasure to confirm stability.
  
  + *Interface: power_all_dcpwr(1v65) output*
    + *Testing*
       + Measure the output of the $plus 1.65V plus.minus 1.5%$ rail with a digital multimeter and ensure that it is stable. 
      + Apply a current load of 6mA for nominal current load and measure it with a digital multimeter to ensure it remains stable.
      + Change the current load to 7.4mA for max current load and measure it with a digital multimeter to ensure that it remains stable. 

  + *Interface: power_all_dcpwr(-1v65) output* 
    + *Testing*
      + Measure the the output of the $minus 1.65V plus.minus 1.5%$ rail with a digital multimeter and ensure that it is stable. 
      + Apply a current load of 6mA for nominal current load and measure it with a digital multimeter to ensure it remains stable.
      + Change the current load to 7.4mA for max current load and measure it with a digital multimeter to ensure that it remains stable.
  + *Interface: power_all_dcpwr(3V3)*
    + *Testing*
      + Measure the output of the NCP1117 with a digital multimeter and ensure there is a stable 3.3V output.
      + Apply a current load of 97mA for nominal current load and measure it with a digital multimeter to ensure it remains stable. 
      + Change the current load to  128mA for max current load and measure it with a digital multimeter to ensure that it remains stable. 


= Block 1 Artifacts <block-1-artifacts>
Finding the LM27762 was important for the system as some sections of the analog filtering required negative voltage inputs. Due to this I had to to learn about charge pump IC's and found that they can output both positive and negative voltage outputs. It was also ideal that the outputs for both rails could be adjusted through a feedback loop as the outputs required to be a very specific voltage that wasn't offered by any other IC's. 

For the digital components of the oscilloscope, I found that all of them would require a standard 3.3V volts and I remembered in Junior Design I that the voltage regulator used for our distance sensor project provided exactly what I needed. 

For the ADC, it required a highly stable no noise voltage reference input to ensure accurate measurements for the analog signal inputs. We found that the REF3533 provided this with a $plus.minus 0.05%$ accuracy and drew virtually no current at 650nA. 

= Block 1 Future Recommendations <block-1-future-recommendations>
For the future it would be good to document everything as the block continues to be designed. It would be a good way to fall back into the process of the design and be sure that any new additions would be compatible with what has been designed at that point. It will be necessary in the future to convert this design on a PCB as prototyping on a breadboard, while helpful, introduces other factors that could potentially affect both input and output signals of the oscilloscope which isn't ideal as the goal is for the most accurate measurements as possible. 

= Block 1 References <block-1-references>
  + [1] “UJ20-C-H-G-SMT-2-P16-TR,” Same Sky Devices, https://www.sameskydevices.com/product/interconnect/connectors/usb-connectors/uj20-c-h-g-smt-2-p16-tr (accessed Jan. 25, 2026). 

  + [2]“LM27762 Low-Noise Positive and Negative Output Integrated Charge Pump Plus LDO 1 Features.” Accessed: Jan. 26, 2026. [Online]. Available: https://www.ti.com/lit/ds/symlink/lm27762.pdf

  + [3]“• NCV Prefix for Automotive and Other Applications Requiring Unique Site and Control Change Requirements; AEC−Q100 Qualified and PPAP Capable.” Available: https://www.onsemi.com/pdf/datasheet/ncp1117-d.pdf

  + [4]“REF35 Ultra Low-Power, High-Precision Voltage Reference.” Accessed: Jan. 26, 2026. [Online]. Available: https://www.ti.com/lit/ds/symlink/ref35.pdf

  + [5]“Hardware design with RP2350 Using RP2350 microcontrollers to build boards and products.” Available: https://datasheets.raspberrypi.com/rp2350/hardware-design-with-rp2350.pdf
‌
// #bibliography("./my-block-references.yaml")
