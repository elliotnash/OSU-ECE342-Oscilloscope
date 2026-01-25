#import "../block-diagram.typ": *
#import "../template.typ": *

== Analog Block Design Details, Elliot Nash <block-3-design-details-name-of-block-owner>

// Insert Block Design Document details for block 3 here.Include at a minimum the block diagram, description, interface validation table, and artifacts.

#figure(scale(power-diagram, 120%, reflow: true), caption: [Analog block black box diagram.]) <analog-block-fig>

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
  table.header(level: 2, table.cell(colspan: 3)[*outside_pwer_dcpwr: Input*]),
  [Vmin: -15v],
  [The 3.3v voltage regulator on the esp32 c6 supermini has a range of - 2% ],
  [The onboard voltage regulator on the esp32 c6 supermini board is a ME6211C33. The ME6211C33 has an output range of +/- 2% when the regulated output voltage is greater than 2v.],
  
  [Vmax: 15v],
  [The 3.3v voltage regulator on the esp32 c6 supermini has a range of + 2% ],
  [The onboard voltage regulator on the esp32 c6 supermini board is a ME6211C33. The ME6211C33 has an output range of +/- 2% when the regulated output voltage is greater than 2v.],
  
  table.header(level: 2, table.cell(colspan: 3)[*mcu_display_comm: I/O*]),
  [Protocol: #i2c],[The ssd1306 display driver we used only supports #i2c ],[Our code defines the communication protocol that the esp32 c6 supermini uses, which we have set to be #i2c],
  [Baud rate: 100kHz],[This is the default baud rate for the arduino wire library],[Our code uses the default baud rate defined by the arduino wire library],
  table.header(level: 2, table.cell(colspan: 3)[*display_outside_usrout: Output*]),
    [Units: mm, cm, m, ft, in],
  [These are common units the user may want the distance displayed in], [Our code allows for the distance to be displayed in these units],
  
  [Maximum distance: $1200m m plus.minus 10%$],
  [The project instructions document specified an engineering requirement that the device must measure distances from 0.1m-1.2m with smaller than a 10% margin of error],
  [The VL53L0x datasheet specifies a 1.2m and 5% accuracy in high speed ranging mode],
  
  [Minimum distance: $100m m plus.minus 10%$],
  [The project instructions document specified an engineering requirement that the device must measure distances from 0.1m-1.2m with smaller than a 10% margin of error], [The VL53L0x datasheet specifies a 1.2m and 5% accuracy in high speed ranging mode ],
))

=== Verification

*Interface: mcu_display_dcpwr (Input)*
+ *Verification:* Verified by measuring the voltage across the VCC and GND pins on the OLED module to ensure it receives the regulated 3.3V from the MCU block.

*Interface: mcu_display_comm (I/O)*
+ *Protocol (#i2c):* Verify that the display acknowledges #i2c commands by checking for valid ACK signals on the bus using a logic analyzer, or functionally by observing that the display successfully initializes and shows content.

*Interface: display_outside_usrout (Output)*
+ *Units (mm, cm, m, ft, in):* Cycle through the unit options on the dashboard. Visually verify that the unit text on the OLED display changes to match the selection (e.g., "mm" changes to "in").
+ *Max Distance (1200mm) & Min Distance (100mm):* Place an object at 1200mm and 100mm from the sensor. Visually verify that the number displayed on the screen corresponds to these distances within the allowable error margin.
