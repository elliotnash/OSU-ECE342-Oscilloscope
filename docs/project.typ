#import "template.typ": *
#import "@preview/subpar:0.2.2"
#import "@preview/zebraw:0.6.1": zebraw
#import "@preview/oxifmt:1.0.0": strfmt
#import "block-diagram.typ": *
#import "authors.typ": authors

// Take a look at the file `template.typ` in the file panel
// to customize this template and discover how it works.
#show: project.with(
  title: "ESP32 Distance Sensor",
  authors: authors,
  team-number: "Team Number: 21"
)

#show: zebraw

#set enum(numbering: "1.a.i.")

#show outline.entry.where(level: 1): strong
#show outline.entry.where(level: 3): emph
#outline(title: [Table of Contents], depth: 3)

#pagebreak()

= Video link <video-link>

https://media.oregonstate.edu/media/t/1_xdrbok90

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
  [Designed and built the power block hardware, implementing the LiPo charging and voltage regulation. Designed the 3d printed external case to house the internal skeleton.],
  [20], 
  
  wd-name("oliver"),
  [Designed and built the distance sensor block and wrote the code to communicate with the sensor over #i2c and filter the data with an exponential moving average filter.],
  [20],
  
  wd-name("elliot"),
  [Designed and built the display and dashboard blocks and associated software, and wrote the MCU $<->$ dashboard communication protocol using websockets. Designed the 3d printed internal skeleton for component mounting.],
  [20],
)) <work-dist-table>

= System Level Block Diagram <system-level-block-diagram>

// Create a system level block diagram with all system level interfaces labeled.

// Fig. 1: System level block diagram for the portable sensor.

#figure(system-black-box-diagram, caption: [System level black box diagram.]) <sys-bb-fig>

= System Description <system-description>

// Describe what the system does, make sure to include the names and functions of all system level interfaces. Make sure the system level interfaces are created directly from the functionality described in the engineering requirements.

The system is a self-contained, real-time distance monitoring device. The core function is to measure the distance to an object using a time-of-flight (ToF) sensor and display the live data to both an on-device OLED display and a web dashboard. The device is designed to be portable and battery operated. The system interacts with the outside environment through five system-level interfaces:

== System Inputs

*outside_power_dcpwr:* This interface is designed as the external energy source to the system, accepting 5V DC power over USB C. Its function is to charge the internal LiPo battery and provide power during wired operation.

*outside_distance_envin:* This interface is the environmental input. It represents the physical distance between the sensor and the closest object to it. The VL53L0X constantly measures this distance.

*outside_dashboard_usrin:* This interface corresponds to inputs from the web interface. It allows the user to select the display units (mm, cm, m, ft, or in). This controls how the distance data is formatted before it is displayed.

== System Outputs

*display_outside_usrout:* This is the output displayed on the OLED screen. It displays the measured distance and selected unit in real-time.

*dashboard_outside_usrout:* This is the output displayed on the web dashboard. It mirrors the real-time distance and unit, allowing the user to remotely monitor it.

= System Design Details and Validation <system-design-details-and-validation>
== Top Level Architecture <top-level-architecture>

#figure(scale(system-diagram, reflow: true, 70%), caption: [Top level block diagram.]) <top-block-fig>
The system is structured into five interacting blocks designed for real-time distance monitoring and web-based user interaction. The centralized control is managed by the MCU Block (ESP32-C6 SuperMini), which coordinates data acquisition, processing, and communication across all modules.

The system starts with the Power Block, which includes the LiPo battery, charger, boost converter, and LDO logic. Power flows from the battery (or external source) and is boosted to 7.5V, stepped down to 5V via a Buck converter, and finally routed to the ESP32-C6's internal LDO to generate the stable 3.3V rail. The MCU receives its power via the power_mcu_dcpwr interface. The MCU then distributes regulated 3.3V power to the sensor and display blocks using the mcu_distance_dcpwr and mcu_display_dcpwr interfaces, respectively.

The MCU Block initiates and manages all activity. It uses public C++ libraries to interact with the #i2c devices and handles all data processing. The MCU interfaces for the sensor are mcu_distance_dcpwr and mcu_distance_comm. The interfaces for the display are mcu_display_dcpwr and mcu_display_comm. These send regulated 3.3V DC power to each device, and use #i2c for the communication between the blocks and the MCU. The MCU gets its power from the power block, through the interface power_mcu_dcpwr. The MCU also takes an input from the dashboard, which is the units the user has selected the distance to be displayed in. This interface is mcu_dashboard_rf. The MCU also runs all the processing on the raw input data from the sensor, and hosts the dashboard.

The Distance Sensor Block (VL53L0X on a GY-530 board) takes environmental input--the distance to an object--via the outside_distance_envin interface. It sends the raw measurement data back to the MCU via the mcu_distance_comm #i2c link. The MCU processes this raw input, applying calibration and running the EWMA filter algorithm, and concurrently hosts the web-based dashboard.

The Display Block includes an OLED display, and a display controller. The display controller interacts with the MCU via an #i2c connection, called mcu_display_comm. The display is powered via an internal interface called power_display_dcpwr, which supplies it with 3.3V of DC power. The display block also has an external output, called display_outside_usrout, which is the information that is actually shown on the OLED display. 

The Dashboard Block is served directly from the ESP32-C6. The dashboard data and live readings are served over http via the mcu_dashboard_rf interface. The dashboard allows for user interaction through the external input outside_dashboard_usrin (which dictates distance units) and displays the distance and selected unit to the user through the dashboard_outside_usrout interface.

== Power Block Design Details, Yahir Raygoza Cortez <block-1-design-details-name-of-block-owner>

// Insert Block Design Document details for block 1 here. Include at a minimum the block diagram, description, interface validation table, and artifacts.

#figure(scale(power-diagram, 120%, reflow: true), caption: [Power block black box diagram.]) <power-block-fig>

=== Description
The Power Block is a highly customized, multi-stage energy management system designed for robust operation with a 1-cell LiPo battery. This circuitry guarantees stable power delivery across the system while safely managing the battery charge cycle. 

=== Theory of Operation
The block begins with a dedicated LiPo Charger that safely manages the incoming 5V external input (typically from USB) to control the voltage and current flow for the battery. For system operation, the varying voltage of the 1-cell LiPo battery (approx. 3.7V to 4.2V) is first sent through a Boost Converter that actively upconverts the voltage to an intermediate 7.5V. This 7.5V is then fed into a highly efficient Buck Converter that downconverts the voltage to a stable 5V, which is supplied as the primary input to the ESP32 development board. Finally, the 5V is channeled through the ESP32's internal Linear Voltage Regulator (LDO), which performs the final regulation step to produce the required, highly stable 3.3V operating rail. This intricate, stepped conversion process ensures the 3.3V rail remains constant (within the 3.0V to 3.6V tolerance) and possesses sufficient current capacity to reliably power the ESP32-C6 MCU—which demands up to 354 mA peak current—along with the external sensor and display loads @esp32_wroom_32_datasheet.

=== Artifacts
#figure(image("images/LinearRegulator.svg", width: 107%), caption: [Linear Voltage Regulator Circuit Layout. ]) <linreg-schem>

@linreg-schem shows the circuit used to regulate the voltage down to 5V to output towards the MCU. It utilizes a schottky diode, two capacitors, an LED and resistor, and an NCP1117 IC. The schottky diode prevents any reverse polarity from occurring. The two capacitors are meant to smooth out any potential ripples that could appear. The resistor and LED are just to indicate whether the regulator is on or off. The NCP1117 IC is what regulates the voltage down to 5V.

=== Interface Validation Table

#figure(table(
  columns: 3,
  table.header(
    [*Interface Property*],
    [*Why is this interface this value?*],
    [*Why do you know that your #underline[system] design details meet or exceed each property (reference block details as needed)?*]
  ),
  
  table.header(level: 2, table.cell(colspan: 3)[*outside\_power\_dcpwr: Input*]),
  
  [Vmin: 4.75V],
  [The tolerance range for input voltages of usb 1.0 is 5v +/- 5% @usb_spec_1_0],
  [This is a well-verified property of the usb 1.0 standard @usb_spec_1_0],
  
  [Vmax: 5.25V],
  [The tolerance range for input voltages of usb 1.0 is 5v +/- 5% @usb_spec_1_0],
  [This is a well-verified property of the usb 1.0 standard @usb_spec_1_0],
  
  [Inominal: 425mA],
  [The standard charging rate of our 850mAh battery is 0.5C @lipo_battery_803035],
  [We set our battery charging board to charge our 850mAh battery at 0.5C],
  
  [Ipeak: 500mA],
  [The maximum current draw for high power usb 1.0 decives is 500mA @usb_spec_1_0],
  [This is a well-verified property of the usb 1.0 standard @usb_spec_1_0],

  
  table.header(level: 2, table.cell(colspan:3)[*regulator_mcu_dcpwr: Output*]),
  
  [Vmin: 4.9V],
  [The minimum voltage output of the ncp1117 voltage regulator is 5v - 2% @ncp1117_datasheet],
  [The voltage regulator utilizes an NCP1117 IC that takes an input voltage of 6.5V to 12V which will convert it to a fixed output voltage of 4.9V minimum. This was verified through testing and is also specified in the datasheet @ncp1117_datasheet],
  
  [Vmax: 5.1V],
  [The maximum voltage output of the ncp1117 voltage regulator is 5v + 2% @ncp1117_datasheet],
  [The voltage regulator utilizes an NCP1117 IC that takes an input voltage of 6.5V to 12V which will convert it to a fixed output voltage of 5.1V maximum. This was verified through testing and is also specified in the datasheet @ncp1117_datasheet],
  
  [Inominal: 100mA],
  [The esp32 board draws an average current of 100mA @esp32_wroom_32_datasheet],
  [The ncp1117 can supply a maximum current of 800mA @ncp1117_datasheet, and the lipo battery can supply a maximum of 1C of discharge (850mA) @lipo_battery_803035, which will be used by the buck converter to increase the voltage from 5v to 7v, and decrease the current by the same ratio (1.4), so the power block supplies 600mA], 
  
  [Ipeak: 354mA],
  [The esp32 board draws a maximum current of 354mA @esp32_wroom_32_datasheet],
  [The ncp1117 can supply a maximum current of 800mA @ncp1117_datasheet, and the lipo battery can supply a maximum of 1C of discharge (850mA) @lipo_battery_803035, which will be used by the buck converter to increase the voltage from 5v to 7v, and decrease the current by the same ratio (1.4), so the power block can supply 600mA, which is greater than 354mA]
))

=== Verification

*Interface: outside_power_dcpwr (Input)*
+ *Vmin (4.75V) & Vmax (5.25V):* Connect the system to a USB power source. Using a multimeter, probe the VBUS and GND pads on the USB-C connector breakout. Verify the voltage reading is between 4.75V and 5.25V.
+ *Inominal (425mA) & Ipeak (500mA):* Place a multimeter in series with the positive VBUS line (or use a USB power meter). Operate the device in its nominal state (charging) and peak state (charging + Wi-Fi active). Verify the current draw aligns with the expected values.

*Interface: regulator_mcu_dcpwr (Output)*
+ *Vmin (4.9V) & Vmax (5.1V):* With the system powered, use a multimeter to measure the voltage at the output terminal of the 5V regulator (Buck Converter). Verify the voltage reads between 4.9V and 5.1V relative to the system ground.
+ *Inominal (100mA) & Ipeak (354mA):* Place a multimeter in series between the 5V regulator output and the ESP32-C6 5V input pin. Measure the current draw during normal operation and during peak load (Wi-Fi transmission) to confirm it stays within the supplied limits.

== MCU Block Design Details, Oliver Siemens <block-2-design-details-name-of-block-owner>

// Insert Block Design Document details for block 2 here.Include at a minimum the block diagram, description, interface validation table, and artifacts.

#figure(scale(mcu-diagram, 120%, reflow: true), caption: [MCU block black box diagram.]) <mcu-block-fig>

=== Description
The MCU block (ESP32-C6) is the central processing unit and control system for the application. Its core function is to manage data acquisition, processing, and output. 

=== Theory of Operation

To better facilitate collaborative development, a class based approach was used, drawing inspiration from the Adafruit Mult-tasking the arduino guide @multitasking_aurdino. This allows better encapsulation, reducing merge conflicts when working simultaneously.

==== Software Architecture 

The firmware is architected around a non-blocking multitasking model. Instead of a monolithic script that pauses execution using delay(), the system is divided into three primary C++ classes: DistanceSensor, Display, and Dashboard. Each class encapsulates its own hardware drivers, state variables, and timing logic. To communicate between subsystems, a callback system is employed, allowing an event driven approach.

==== Main Loop and Scheduling 

The system execution is driven by a main loop() that continuously cycles through the update() methods of each object. These methods utilize the system clock (millis()) to track time intervals, executing their specific tasks only when necessary:

- The Sensor object polls the VL53L0X every 20ms.

- The Display object refreshes the OLED screen only when new data is available or a flash is scheduled.

- The Dashboard object handles network traffic asynchronously.

This architecture ensures that the high-latency operations of one component (such as waiting for a sensor measurement) do not block the responsiveness of others (such as serving the web dashboard).

==== Subsystem Implementation

*Sensor Subsystem:* The DistanceSensor class manages the #i2c communication with the VL53L0X ToF sensor. It handles the raw data acquisition and internally applies the Exponential Weighted Moving Average (EWMA) filter. The class exposes the final filtered distance via a public getter method, ensuring other parts of the system always access stable data.

*Display Subsystem:* The Display class abstracts the specific drawing commands for the SSD1306. It observes the system's shared state and handles the unit conversion logic (e.g., converting millimeters to inches) before rendering the frame. This separation of concerns allows the unit preferences to be changed globally without rewriting display logic.

*Dashboard Subsystem:* Unlike the sensor and display which run in the main loop, the Dashboard class leverages the ESPAsyncWebServer library. This allows the MCU to handle HTTP requests and WebSocket handshakes asynchronously on a separate FreeRTOS task, preventing network latency from affecting the sensor reading timings. Real-time data is pushed to connected clients via WebSocket frames triggered by the sensor's update cycle.

==== Data Processing

In order to ensure our output distances are as accurate as possible, a series of transformations are run on our data. First, the raw sensor data is calibrated to known distance values, removing any fixed offsets the sensor may read. This calibrated data is fed into a filtering algorithm that acts as a low-pass filter, removing random noise from the sensor while keeping movements of the target object (lower frequencies).

*Calibration Algorithm:* The calibration algorithm is a linearly interpolating lookup table for distance offsets. First, a test rig was created with marks every 0.1m from 0.1m to 1m. A flat board was placed at each of the marks, recording the actual distance in the `distance` column and the uncalibrated measured value in the `value` column (all values in mm as the sensor library uses unsigned integers).


#let cal-data = csv("data/calibration.csv")

#figure(table(
  columns: 2,
  table.header([*distance*], [*value*]),
  ..cal-data.slice(1).flatten()
), caption: [Sensor calibration table.]) <cal-table>

This table -- shown in @cal-table -- is embedded into the MCU flash memory as a CSV. The calibration subsystem parses this CSV and exposes a `getCalibratedValue` function which linearly interpolates between offsets in the calibration table. The algorithm goes as follows (where `distances` and `values` are arrays corresponding to the calibration table) #cite(<gh_repo>, supplement: [src/calibration.cpp]):

If the distance is smaller than any calibration entry (`distance < distances[0]`), then the offset for distance `100` is used (@cal-case1).

#figure(```cpp
float offset = values[0] - distances[0];
return distance - offset;
```, caption: [Calibration case 1]) <cal-case1>

If the distance is between the min and max calibration entries, the offsets of the distance before and after it are calculated, and the effective offset is interpolated between the two (@cal-case2).

#figure(```cpp
float range = distances[i] - distances[i-1];
float offset1Weight = (distance - distances[i-1]) / range;
float offset2Weight = 1 - offset1Weight;

float offset = offset1Weight * (values[i-1] - distances[i-1]) + offset2Weight * (values[i] - distances[i]);

return distance - offset;
```, caption: [Calibration case 2]) <cal-case2>

Otherwise, the distance is greater than any calibration entry, and the offset for distance `1000` is used (@cal-case3).

#figure(```cpp
float offset = values[rows-1] - distances[rows-1];
return distance - offset;
```, caption: [Calibiration case 3]) <cal-case3>


*Filtering Algorithm:* The filtering algorithm is an exponential moving average (EMA) algorithm that cleans up the noisy data from the distance sensor block. The algorithm starts by generating an array to store the last x number of data points, we call the array the window. Then we must generate weights, which will be multiplied by each data point in the window and then added to find the current value. To generate the weights, we create a weights array where the weight exponentially decreases as you move to less recent data points:

#v(0.7em)

#figure(```cpp
for(int k=0; k<EMA_DATA; k++){
  weights[k] = pow(e,k-EMA_DATA);
}
```, caption: [EMA weight generation.]) 

The weights are then normalized as follows:
#figure(```cpp
float weight_sum = 0.0;
for(int k=0; k<EMA_DATA; k++){
  weight_sum += weights[k];
}
for(int k=0; k<EMA_DATA; k++){
  weights[k] /= weight_sum;
}
```, caption: [EMA weight normalization])

This algorithm sums the weights and then divides each weight by the sum, ensuring all the weights add up to 1. By ensuring the weights all add up to 1, we guarantee that the filtered output stays on the same scale as the raw sensor data, maintaining unity gain so that the output represents a true average of the distance without amplification or attenuation #cite(<gh_repo>, supplement: [src/distance.cpp]).

// The MCU begins by initializing the #i2c communication bus and acting as the 3.3V power source for the external sensor and display modules. The MCU continuously runs a data loop: it communicates with the sensor to read the raw distance measurement, applies custom calibration factors, and then feeds the resulting value into the Exponentially Weighted Moving Average (EWMA) filter to generate a stable, smooth reading. This final, polished data is then sent to the OLED display for visualization and simultaneously distributed to other software components via registered callbacks for real-time responsiveness.

=== Artifacts
#figure(```cpp 
/* This example shows how to use continuous mode to take
range measurements with the VL53L0X. It is based on
vl53l0x_ContinuousRanging_Example.c from the VL53L0X API.

The range readings are in units of mm. */

#include <Wire.h>
#include <VL53L0X.h>

VL53L0X sensor;

void setup()
{
  Serial.begin(9600);
  Wire.begin();

  sensor.setTimeout(500);
  if (!sensor.init())
  {
    Serial.println("Failed to detect and initialize sensor!");
    while (1) {}
  }

  // Start continuous back-to-back mode (take readings as
  // fast as possible).  To use continuous timed mode
  // instead, provide a desired inter-measurement period in
  // ms (e.g. sensor.startContinuous(100)).
  sensor.startContinuous();
}

void loop()
{
  Serial.print(sensor.readRangeContinuousMillimeters());
  if (sensor.timeoutOccurred()) { Serial.print(" TIMEOUT"); }

  Serial.println();
}
```, caption: [Sensor library code example #cite(<pololu_vl53l0x_lib>, supplement: [Examples/Continuous/Continuous.ino])]) <sensorlibrary-code>

@sensorlibrary-code is example code taken from the Pololu VL53L0X library, and was used as inspiration for the continuous ranging components of our DistanceSensor subsystem. 

#figure(```c
#include <Adafruit_SSD1306.h>

#define SCREEN_WIDTH 128 // OLED display width, in pixels
#define SCREEN_HEIGHT 32 // OLED display height, in pixels

Adafruit_SSD1306 display(SCREEN_WIDTH, SCREEN_HEIGHT) display;

void setup() {
  if(!display.begin()) {
    // Display initialization fail logic
  }

  // Draw text on display
  display.clearDisplay();

  display.setTextSize(1);       // Normal 1:1 pixel scale
  display.setCursor(0, 0);      // Start at top-left corner
  display.setTextColor(WHITE);   // White text
  display.print("Hello, World"); // Write text to display

  display.display();
}

void loop() {}
```, caption: [Display library code example, adapted from #cite(<adafruit_ssd1306_lib>, supplement: [Examples/ssd1306_128x32_i2c/ssd1306_128x32_i2c.ino])]) <displaylibrary-code>

@displaylibrary-code is an adapted version of the more complicated example in the Adafruit SSD1306 display driver library. A modified version of this was used in our Display subsystem to draw display output.

=== Interface Validation Table

#figure(table(
  columns: 3,
  table.header(
    [*Interface Property*],
    [*Why is this interface this value?*],
    [*Why do you know that your #underline[system] design details meet or exceed each property (reference block details as needed)?*]
  ),
  
  table.header(level: 2, table.cell(colspan: 3)[*regulator_mcu_dcpwr: Input*]),
  [Vmin: 4.9V],
  [The minimum voltage output of the ncp1117 voltage regulator is 5v - 2% @ncp1117_datasheet],
  [The voltage regulator utilizes an NCP1117 IC that takes an input voltage of 6.5V to 12V which will convert it to a fixed output voltage of 4.9V minimum. This was verified through testing and is also specified in the datasheet @ncp1117_datasheet],
  
  [Vmax: 5.1V],
  [The maximum voltage output of the ncp1117 voltage regulator is 5v + 2% @ncp1117_datasheet],
  [The voltage regulator utilizes an NCP1117 IC that takes an input voltage of 6.5V to 12V which will convert it to a fixed output voltage of 5.1V maximum. This was verified through testing and is also specified in the datasheet @ncp1117_datasheet],
  
  [Inominal: 100mA],
  [The esp32 board draws an average current of 100mA @esp32_wroom_32_datasheet],
  [The ncp1117 can supply a maximum current of 800mA @ncp1117_datasheet, and the lipo battery can supply a maximum of 1C of discharge (850mA) @lipo_battery_803035, which will be used by the buck converter to increase the voltage from 5v to 7v, and decrease the current by the same ratio (1.4), so the power block supplies 600mA], 
  
  [Ipeak: 354mA],
  [The esp32 board draws a maximum current of 354mA @esp32_wroom_32_datasheet],
  [The ncp1117 can supply a maximum current of 800mA @ncp1117_datasheet, and the lipo battery can supply a maximum of 1C of discharge (850mA) @lipo_battery_803035, which will be used by the buck converter to increase the voltage from 5v to 7v, and decrease the current by the same ratio (1.4), so the power block supplies 600mA],

  
  table.header(level: 2, table.cell(colspan: 3)[*mcu_dashboard_rf: I/O*]),
  [RF Protocol: Wi-Fi 802.11 b/g/n/ax],
  [This is is a commonly supported protocol by clients as it uses the 2.4GHz band and supports backwards compatibility with Wi-Fi 5 and earlier.],
  [The ESP32 natively supports 802.11 b/h/n/ax (Wi-Fi 6 with backwards compatibility), activated by the esp32 `WiFi` library @esp32_c6_sm.],
  
  [Data Protocol: HTTP + WS],
  [HTTP is the widely supported protocol to server webpages. WebSockets support real-time bi-directional data transfer, allowing low latency distance updates.], 
  [The `ESP32AsyncWebServer` library uses http and supports websocket handlers @esp_async_ws_wiki.],

  [Port: 80],
  [This is the default HTTP port, which allows clients to omit the port when connecting.],
  [The code initializes the `AsyncWebServer` on port 80 #cite(<gh_repo>, supplement: [src/dashboard.cpp]).],

  [Update Rate: 50Hz], [20ms polling allows low-latency measurements with smooth visual updates.], [The distance sensor code uses 20ms polling, and a websocket frame is pushed immediately after polling #cite(<gh_repo>, supplement: [src/distance.cpp])],
  
  
  table.header(level: 2, table.cell(colspan: 3)[*sensor_mcu_comm: I/O*]),
  [Protocol: #i2c],
  [#i2c is the only communication protocol that the GY-530 supports @gy530_datasheet],
  [Our code defines the communication protocol that the esp32 c6 supermini uses, which we have set to be #i2c #cite(<gh_repo>, supplement: [src/distance.cpp])],
  
  [Baud rate: 100kHz],
  [This is the default baud rate for the arduino wire library],
  [Our code uses the default baud rate defined by the arduino wire library #cite(<gh_repo>, supplement: [src/distance.cpp])],

  
  table.header(level: 2, table.cell(colspan: 3)[*mcu_sensor_dcpwr: Output*]),
  [Vmin: 3.234v],
  [The 3.3v voltage regulator on the esp32 c6 supermini has a range of - 2% @me6211_datasheet],
  [The onboard voltage regulator on the esp32 c6 supermini board is a ME6211C33. The ME6211C33 has an output range of +/- 2% when the regulated output voltage is greater than 2v.@me6211_datasheet],
  
  [Vmax: 3.366v],
  [The 3.3v voltage regulator on the esp32 c6 supermini has a range of + 2% @me6211_datasheet],
  [The onboard voltage regulator on the esp32 c6 supermini board is a ME6211C33. The ME6211C33 has an output range of +/- 2% when the regulated output voltage is greater than 2v.@me6211_datasheet],
  
  [Inominal: $5 mu$A],[The GY-530 has a nominal current draw of $5 mu$A when it is idle @gy530_datasheet],[The onboard voltage regulator on the esp32 c6 supermini board can supply up to 500mA @me6211_datasheet, and the maximum current draw for board is 354mA @esp32_c6_sm, leaving plenty of current headroom for the sensor.],
  
  [Ipeak: 6mA],[The GY-530 has a peak current draw of 6mA when it is reading data @gy530_datasheet],[The onboard voltage regulator on the esp32 c6 supermini board can supply up to 500mA @me6211_datasheet, and the maximum current draw for board is 354mA @esp32_c6_sm, leaving plenty of current headroom for the sensor.],

  
  table.header(level: 2, table.cell(colspan: 3)[*mcu_display_comm: I/O*]),
  [Protocol: #i2c],
  [The ssd1306 display driver we used supports #i2c @ssd1306_datasheet],
  [Our code defines the communication protocol that the esp32 c6 supermini uses, which we have set to be #i2c #cite(<gh_repo>, supplement: [src/display.cpp])],
  
  [Baud rate: 100kHz],
  [This is the default baud rate for the arduino wire library],
  [Our code uses the default baud rate defined by the arduino wire library #cite(<gh_repo>, supplement: [src/display.cpp])],

  
  table.header(level: 2, table.cell(colspan: 3)[*mcu_display_dcpwr: Output*]),
  [Vmin: 3.234v],
  [The 3.3v voltage regulator on the esp32 c6 supermini has a range of - 2% @me6211_datasheet],
  [The onboard voltage regulator on the esp32 c6 supermini board is a ME6211C33. The ME6211C33 has an output range of +/- 2% when the regulated output voltage is greater than 2v.@me6211_datasheet],
  
  [Vmax: 3.366v],
  [The 3.3v voltage regulator on the esp32 c6 supermini has a range of + 2% @me6211_datasheet],
  [The onboard voltage regulator on the esp32 c6 supermini board is a ME6211C33. The ME6211C33 has an output range of +/- 2% when the regulated output voltage is greater than 2v.@me6211_datasheet],
  
  [Inominal: 4.73mA],[The typical current draw for the display at 50% illuminated is 4.3mA @ug2832_datasheet. The typical current draw for the display controller is $430mu$A @ssd1306_datasheet, so the total nominal current is 4.73mA],[The onboard voltage regulator on the esp32 c6 supermini board can supply up to 500mA @me6211_datasheet, and the maximum current draw for board is 354mA @esp32_c6_sm, leaving plenty of current headroom for the display.],
  
  [Ipeak: 6.18mA],[The max current draw for the display at 50% illuminated is 5.4mA @ug2832_datasheet. The max current draw for the display controller is $780mu$A @ssd1306_datasheet, so the total peak current is 6.18mA],[The onboard voltage regulator on the esp32 c6 supermini board can supply up to 500mA @me6211_datasheet, and the maximum current draw for board is 354mA @esp32_c6_sm, leaving plenty of current headroom for the display.],
))

=== Verification

*Interface: regulator_mcu_dcpwr (Input)*
+ *Verification:* This interface is verified by measuring the voltage at the 5V input pin of the ESP32-C6 SuperMini to ensure it falls within the 4.9V - 5.1V range supplied by the Power Block.

*Interface: sensor_mcu_comm (I/O)*
+ *Protocol (#i2c):* Connect a logic analyzer or oscilloscope to the SCL and SDA lines connecting the MCU and Sensor. Capture a transaction and decode the signals to verify standard #i2c protocol structure (Start bit, Address, ACK, Data, Stop bit).
+ *Baud Rate (100kHz):* Using the logic analyzer or oscilloscope, measure the frequency of the clock signal on the SCL line during a transmission to confirm it is approximately 100kHz.

*Interface: mcu_sensor_dcpwr (Output)*
+ *Vmin (3.234V) & Vmax (3.366V):* Use a multimeter to measure the voltage between the 3V3 pin connected to the sensor and GND. Verify the reading is within the specified tolerance.
+ *Current (Inominal 5uA, Ipeak 6mA):* Place a multimeter in series with the sensor's power line to measure the current draw during idle and active ranging states.

*Interface: mcu_display_comm (I/O)*
+ *Protocol (#i2c) & Baud Rate (100kHz):* Similar to the sensor interface, use a logic analyzer on the display's SCL/SDA lines to confirm #i2c protocol compliance and a 100kHz clock frequency.

*Interface: mcu_display_dcpwr (Output)*
+ *Vmin (3.234V) & Vmax (3.366V):* Use a multimeter to measure the voltage at the display's VCC pin relative to GND. Verify it is within the 3.3V +/- 2% range.
+ *Current (Inominal 4.73mA, Ipeak 6.18mA):* Place a multimeter in series with the display's power input. Measure the current with the screen at 50% brightness (typical text) and 100% brightness (full white pixels) to verify the current draw.

== Display Block Design Details, Elliot Nash <block-3-design-details-name-of-block-owner>

// Insert Block Design Document details for block 3 here.Include at a minimum the block diagram, description, interface validation table, and artifacts.

// #figure(scale(display-diagram, 120%, reflow: true), caption: [Display block black box diagram.]) <display-block-fig>

=== Description
The display block uses an OLED display board to display the distance and unit of measurement to the user. The display takes a user input (the unit to display the distance in), and gives a user output (it displays the measured distance and the units).

=== Theory of Operation
The display board is built around the SSD1306 driver IC. The boards operation is purely passive until commanded by the MCU block. The MCU acts as the graphics processor, first rendering the filtered distance data and interface elements, then transmitting this pixel data to the Display Block over #i2c. The display controller then displays the pixel data on the OLED display.

=== Interface Validation Table

#figure(table(
  columns: 3,
  table.header(
    [*Interface Property*],
    [*Why is this interface this value?*],
    [*Why do you know that your #underline[system] design details meet or exceed each property (reference block details as needed)?*]
  ),
  table.header(level: 2, table.cell(colspan: 3)[*mcu_display_dcpwr: Input*]),
  [Vmin: 3.234v],
  [The 3.3v voltage regulator on the esp32 c6 supermini has a range of - 2% @me6211_datasheet],
  [The onboard voltage regulator on the esp32 c6 supermini board is a ME6211C33. The ME6211C33 has an output range of +/- 2% when the regulated output voltage is greater than 2v.@me6211_datasheet],
  
  [Vmax: 3.366v],
  [The 3.3v voltage regulator on the esp32 c6 supermini has a range of + 2% @me6211_datasheet],
  [The onboard voltage regulator on the esp32 c6 supermini board is a ME6211C33. The ME6211C33 has an output range of +/- 2% when the regulated output voltage is greater than 2v.@me6211_datasheet],
  
  [Inominal: 4.73mA],[The typical current draw for the display at 50% illuminated is 4.3mA @ug2832_datasheet. The typical current draw for the display controller is $430mu$A @ssd1306_datasheet, so the total nominal current is 4.73mA],[The onboard voltage regulator on the esp32 c6 supermini board can supply up to 500mA @me6211_datasheet, and the maximum current draw for board is 354mA @esp32_c6_sm, leaving plenty of current headroom for the display.],
  [Ipeak: 6.18mA],[The max current draw for the display at 50% illuminated is 5.4mA @ug2832_datasheet. The max current draw for the display controller is $780mu$A @ssd1306_datasheet, so the total peak current is 6.18mA],[The onboard voltage regulator on the esp32 c6 supermini board can supply up to 500mA @me6211_datasheet, and the maximum current draw for board is 354mA @esp32_c6_sm, leaving plenty of current headroom for the display.],
  table.header(level: 2, table.cell(colspan: 3)[*mcu_display_comm: I/O*]),
  [Protocol: #i2c],[The ssd1306 display driver we used only supports #i2c @ssd1306_datasheet],[Our code defines the communication protocol that the esp32 c6 supermini uses, which we have set to be #i2c #cite(<gh_repo>, supplement: [src/display.cpp])],
  [Baud rate: 100kHz],[This is the default baud rate for the arduino wire library],[Our code uses the default baud rate defined by the arduino wire library #cite(<gh_repo>, supplement: [src/display.cpp])],
  table.header(level: 2, table.cell(colspan: 3)[*display_outside_usrout: Output*]),
    [Units: mm, cm, m, ft, in],
  [These are common units the user may want the distance displayed in], [Our code allows for the distance to be displayed in these units #cite(<gh_repo>, supplement: [src/units.cpp])],
  
  [Maximum distance: $1200m m plus.minus 10%$],
  [The project instructions document specified an engineering requirement that the device must measure distances from 0.1m-1.2m with smaller than a 10% margin of error @esp32_project_instructions],
  [The VL53L0x datasheet specifies a 1.2m and 5% accuracy in high speed ranging mode #cite(<vl53l0x_datasheet>, supplement: [Table 14])],
  
  [Minimum distance: $100m m plus.minus 10%$],
  [The project instructions document specified an engineering requirement that the device must measure distances from 0.1m-1.2m with smaller than a 10% margin of error @esp32_project_instructions], [The VL53L0x datasheet specifies a 1.2m and 5% accuracy in high speed ranging mode #cite(<vl53l0x_datasheet>, supplement: [Table 14])],
))

=== Verification

*Interface: mcu_display_dcpwr (Input)*
+ *Verification:* Verified by measuring the voltage across the VCC and GND pins on the OLED module to ensure it receives the regulated 3.3V from the MCU block.

*Interface: mcu_display_comm (I/O)*
+ *Protocol (#i2c):* Verify that the display acknowledges #i2c commands by checking for valid ACK signals on the bus using a logic analyzer, or functionally by observing that the display successfully initializes and shows content.

*Interface: display_outside_usrout (Output)*
+ *Units (mm, cm, m, ft, in):* Cycle through the unit options on the dashboard. Visually verify that the unit text on the OLED display changes to match the selection (e.g., "mm" changes to "in").
+ *Max Distance (1200mm) & Min Distance (100mm):* Place an object at 1200mm and 100mm from the sensor. Visually verify that the number displayed on the screen corresponds to these distances within the allowable error margin.

== Distance Sensor Block Design Details, Oliver Siemens <block-4-design-details-name-of-block-owner>

// Insert Block Design Document details for block 4 here.Include at a minimum the block diagram, description, interface validation table, and artifacts.

// #figure(scale(distance-diagram, 120%, reflow: true), caption: [Distance sensor block black box diagram.]) <distance-block-fig>

=== Description

The sensor block encompasses the distance measurement sensor and the corresponding code for initialization, control, and communication. Data transfer to the microcontroller is handled through the #i2c communication protocol, utilizing the SCL and SDA lines. Power for the sensor is sourced from the MCU block via the stable 3.3V output pin on the ESP32-C6 SuperMini board. Its primary function is to measure and provide external environmental data (distance).

=== Theory of Operation

The Sensor Block operates using time-of-flight (ToF) measurement, which uses emitted light to calculate the distance to an object. The core function is initiated by the microcontroller Unit (mcu) through the #i2c interface, utilizing the SCL (clock) and SDA (data) lines for command and control. First, the sensor emits an invisible light pulse, then it precisely measures the time until the reflected light pulse returns to the receiver. Using the known speed of light, the sensor's internal circuitry calculates the raw distance to the target. This raw measurement is then immediately stored in the sensor's internal memory registers and is concurrently accessed by the MCU via a standard #i2c read transaction. The entire process is continuous and periodic, driven by the sampling rate configured during initialization, allowing the block to provide real-time environmental data to the main system.

=== Interface Validation Table

#figure(table(
  columns: 3,
  table.header(
    [*Interface Property*],
    [*Why is this interface this value?*],
    [*Why do you know that your #underline[system] design details meet or exceed each property (reference block details as needed)?*]
  ),
  
  table.header(level: 2, table.cell(colspan: 3)[*mcu_sensor_dcpwr: Input*]),
  
  [Vmin: 3.234v],
  [The 3.3v voltage regulator on the esp32 c6 supermini has a range of - 2% @me6211_datasheet],
  [The onboard voltage regulator on the esp32 c6 supermini board is a ME6211C33. The ME6211C33 has an output range of +/- 2% when the regulated output voltage is greater than 2v.@me6211_datasheet],
  
  [Vmax: 3.366v],
  [The 3.3v voltage regulator on the esp32 c6 supermini has a range of + 2% @me6211_datasheet],
  [The onboard voltage regulator on the esp32 c6 supermini board is a ME6211C33. The ME6211C33 has an output range of +/- 2% when the regulated output voltage is greater than 2v.@me6211_datasheet],
  
  [Inominal: $5 mu$A],[The GY-530 has a nominal current draw of $5 mu$A when it is idle @gy530_datasheet],[The onboard voltage regulator on the esp32 c6 supermini board can supply up to 500mA @me6211_datasheet, and the maximum current draw for board is 354mA @esp32_c6_sm, leaving plenty of current headroom for the sensor.],
  [Ipeak: 6mA],[The GY-530 has a peak current draw of 6mA when it is reading data @gy530_datasheet],[The onboard voltage regulator on the esp32 c6 supermini board can supply up to 500mA @me6211_datasheet, and the maximum current draw for board is 354mA @esp32_c6_sm, leaving plenty of current headroom for the sensor.],
 
  table.header(level: 2, table.cell(colspan: 3)[*mcu_sensor_comm: I/O*]),
  
  [Protocol: #i2c],[#i2c is the only communication protocol that the GY-530 supports @gy530_datasheet],[Our code defines the communication protocol that the esp32 c6 supermini uses, which we have set to be #i2c #cite(<gh_repo>, supplement: [src/distance.cpp])],
  [Baud rate: 100kHz],[This is the default baud rate for the arduino wire library],[Our code uses the default baud rate defined by the arduino wire library #cite(<gh_repo>, supplement: [src/distance.cpp])],
  
  table.header(level: 2, table.cell(colspan: 3)[*outside_sensor_envin: Input*]),

  [Maximum distance: $1200m m plus.minus 10%$],
  [The project instructions document specified an engineering requirement that the device must measure distances from 0.1m-1.2m with smaller than a 10% margin of error @esp32_project_instructions],
  [The VL53L0x datasheet specifies a 1.2m and 5% accuracy in high speed ranging mode #cite(<vl53l0x_datasheet>, supplement: [Table 14])],
  
  [Minimum distance: $100m m plus.minus 10%$],
  [The project instructions document specified an engineering requirement that the device must measure distances from 0.1m-1.2m with smaller than a 10% margin of error @esp32_project_instructions],
  [The VL53L0x datasheet specifies a 1.2m and 5% accuracy in high speed ranging mode #cite(<vl53l0x_datasheet>, supplement: [Table 14])],
))

=== Verification

*Interface: mcu_sensor_dcpwr (Input)*
+ *Verification:* Measure the voltage at the VIN pin of the GY-530 breakout board to ensure it receives the regulated 3.3V from the MCU.

*Interface: mcu_sensor_comm (I/O)*
+ *Protocol (#i2c):* Verify the sensor responds to its #i2c address (default 0x29) by scanning the #i2c bus with the MCU or a logic analyzer and checking for an ACK response.

*Interface: outside_sensor_envin (Input)*
+ *Max Distance (1200mm) & Min Distance (100mm):* Set up a test fixture with a target at exactly 100mm and 1200mm. Capture the raw data readings printed to the serial monitor from the MCU to verify the sensor is detecting objects at these limits.


== Dashboard Block Design Details, Elliot Nash <block-5-design-details-name-of-block-owner>

// Insert Block Design Document details for block 5 here.Include at a minimum the block diagram, description, interface validation table, and artifacts.

// #figure(scale(dashboard-diagram, 120%, reflow: true), caption: [Dashboard block black box diagram.]) <dashboard-block-fig>

=== Description

The Dashboard Block is a lightweight web-based user interface hosted directly on the ESP32-C6 microcontroller. It serves as the wireless interaction point for the system, allowing users to remotely monitor real-time distance measurements and configure the device's unit of measurement (mm, cm, m, ft, in). It is developed using the Preact framework, and is designed as a single-page application (SPA) that can run on any device with a web-browser connected to the system's Wi-Fi network.

=== Theory of Operation

==== Build Pipeline

Due to both the space constraints on the microcontroller flash and the high costs associated with transferring large amounts of data over WiFi, a small bundle size was needed. However, the ergonomics of React make the developer experience much better, and its large ecosystems allows taking advantage of libraries such as shadcn and chartist. Thus, Preact was chosen due to its drop-in React compatibility but much smaller bundle size. To build and bundle the dashboard, Vite is used. It is then fed into the `vite-plugin-singlefile` plugin, which inlines all HTML/JS/CSS into a single index.html, drastically simplifying the microcontroller implementation as it only needs to serve one file. `vite-plugin-compression` is then used to gzip `index.html`, resulting in a final bundle size around 60kB.

==== Runtime Operation

During operation, the interface relies on a hybrid HTTP and WebSocket architecture:

1. *Initialization (HTTP)*: When a user navigates to the ESP32's IP address, the microcontroller serves the static, Gzipped HTML payload. The client's browser automatically decompresses, parses, and executes the Preact application.

2. *Real-Time Data (WebSocket)*: Immediately upon loading, the application establishes a persistent, bi-directional WebSocket connection with the MCU.

  1. *MCU to Client events:* The MCU broadcasts distance updates to the client as soon as they are processed by the sensor algorithm. Because the connection is persistent, this avoids the overhead of repeated HTTP headers, allowing for a smooth, low-latency visualization of data. On unit updates, the MCU broadcasts the new unit to all connected clients, allowing them to stay in sync.

  2. *Client to MCU events:* When the user selects a new unit on the dashboard, the dashboard transmits a frame over the WebSocket. The MCU reads this message, parses the requested unit, and updates the global system state.

The user interface then displays these updates distance readings, storing the last 10 seconds of data to be displayed in a graph.
  
=== Artifacts

#subpar.grid(
  figure(image("images/dashboard/dash_light.png")),
  figure(image("images/dashboard/dash_dark.png")),
  columns: (1fr, 1fr),
  caption: [Dashboard user interface.],
  label: <dash-ui>,
)


@dash-ui shows the dashboard's display of the real-time sensor data. The layout consists of a large numerical readout for the current distance and a dynamic line chart that visualizes the stability and history of the measurements over the last 10 seconds. The application uses shadcn for the components, and automatically detects the client device's system preference to render in either light or dark mode.

=== Interface Validation Table

#figure(table(
  columns: 3,
  table.header(
    [*Interface Property*],
    [*Why is this interface this value?*],
    [*Why do you know that your #underline[system] design details meet or exceed each property (reference block details as needed)?*]
  ),

  table.header(level: 2, table.cell(colspan: 3)[*mcu_dashboard_rf: I/O*]),
  [RF Protocol: Wi-Fi 802.11 b/g/n/ax],
  [This is is a commonly supported protocol by clients as it uses the 2.4GHz band and supports backwards compatibility with Wi-Fi 5 and earlier.],
  [The ESP32 natively supports 802.11 b/h/n/ax (Wi-Fi 6 with backwards compatibility), activated by the esp32 `WiFi` library @esp32_c6_sm.],
  
  [Data Protocol: HTTP + WS],
  [HTTP is the widely supported protocol to server webpages. WebSockets support real-time bi-directional data transfer, allowing low latency distance updates.], 
  [The `ESP32AsyncWebServer` library uses http and supports websocket handlers @esp_async_ws_wiki.],

  [Port: 80],
  [This is the default HTTP port, which allows clients to omit the port when connecting.],
  [The code initializes the `AsyncWebServer` on port 80 #cite(<gh_repo>, supplement: [src/dashboard.cpp]).],

  [Update Rate: 50Hz], [20ms polling allows low-latency measurements with smooth visual updates.], [The distance sensor code uses 20ms polling, and a websocket frame is pushed immediately after polling #cite(<gh_repo>, supplement: [src/distance.cpp])],

  
  table.header(level: 2, table.cell(colspan: 3)[*outside_dashboard_usrin : Input*]),
  [Units: mm, cm, m, ft, in],
  [These are common units the user may want the distance displayed in], [Our code allows for the distance to be displayed in these units #cite(<gh_repo>, supplement: [dashboard/src/lib/units.ts])],

  
  table.header(level: 2, table.cell(colspan: 3)[*dashboard_outside_usrout : Output*]),
  [Units: mm, cm, m, ft, in],
  [These are common units the user may want the distance displayed in], [Our code allows for the distance to be displayed in these units #cite(<gh_repo>, supplement: [dashboard/src/lib/units.ts])],
  
  [Maximum distance: $1200m m plus.minus 10%$],
  [The project instructions document specified an engineering requirement that the device must measure distances from 0.1m-1.2m with smaller than a 10% margin of error @esp32_project_instructions],
  [The VL53L0x datasheet specifies a 1.2m and 5% accuracy in high speed ranging mode #cite(<vl53l0x_datasheet>, supplement: [Table 14])],
  
  [Minimum distance: $100m m plus.minus 10%$],
  [The project instructions document specified an engineering requirement that the device must measure distances from 0.1m-1.2m with smaller than a 10% margin of error @esp32_project_instructions],
  [The VL53L0x datasheet specifies a 1.2m and 5% accuracy in high speed ranging mode #cite(<vl53l0x_datasheet>, supplement: [Table 14])],
))

=== Verification

*Interface: outside_dashboard_usrin (Input)*
+ *Units Selection:* Open the web dashboard in a browser. Click the unit selection dropdown menu. Select different units (mm, cm, m, ft, in) and verify that the request is sent to the MCU (observable via serial debug logs or immediate change in displayed values).

*Interface: dashboard_outside_usrout (Output)*
+ *Units Display:* Verify that the "Current Unit" label on the web dashboard updates immediately to reflect the unit selected by the user.
+ *Max/Min Distance Display:* With the sensor measuring an object at 100mm and then 1200mm, verify that the large distance number on the dashboard updates to reflect these values correctly (e.g., reads "0.1 m" and "1.2 m" if meters are selected).

*Interface: mcu_dashboard_rf (Input)*
+ *Verification:* Verify that the dashboard loads on a client device (phone/laptop) connected to the ESP32's Wi-Fi network, confirming the RF link and HTTP server are functional.

= System Level Interface Validation Table <system-level-interface-validation-table>

// Be sure to include only system-level interfaces. System-level interface values and properties must match their corresponding block-level interfaces.

#figure(table(
  columns: 3,
  table.header(
    [*Interface Property*],
    [*Why is this interface this value?*],
    [*Why do you know that your #underline[system] design details meet or exceed each property (reference block details as needed)?*]
  ),
  
  table.header(level: 2, table.cell(colspan: 3)[*outside\_power\_dcpwr: Input*]),
  
  [Vmin: 4.75V],
  [The tolerance range for input voltages of usb 1.0 is 5v +/- 5% @usb_spec_1_0],
  [This is a well-verified property of the usb 1.0 standard @usb_spec_1_0],
 
  [Vmax: 5.25V],
  [The tolerance range for input voltages of usb 1.0 is 5v +/- 5% @usb_spec_1_0],
  [This is a well-verified property of the usb 1.0 standard @usb_spec_1_0],
  
  [Inominal: 425mA],
  [The standard charging rate of our 850mAh battery is 0.5C @lipo_battery_803035],
  [We set our battery charging board to charge our 850mAh battery at 0.5C],
  
  [Ipeak: 500mA],
  [The maximum current draw for high power usb 1.0 decives is 500mA @usb_spec_1_0],
  [This is a well-verified property of the usb 1.0 standard @usb_spec_1_0],

  
  table.header(level: 2, table.cell(colspan:3)[*outside_sensor_envin*]),
  
  [Maximum distance: $1200m m plus.minus 10%$],
  [The project instructions document specified an engineering requirement that the device must measure distances from 0.1m-1.2m with smaller than a 10% margin of error @esp32_project_instructions],
  [The VL53L0x datasheet specifies a 1.2m and 5% accuracy in high speed ranging mode #cite(<vl53l0x_datasheet>, supplement: [Table 14])],
  
  [Minimum distance: $100m m plus.minus 10%$],
  [The project instructions document specified an engineering requirement that the device must measure distances from 0.1m-1.2m with smaller than a 10% margin of error @esp32_project_instructions],
  [The VL53L0x datasheet specifies a 1.2m and 5% accuracy in high speed ranging mode #cite(<vl53l0x_datasheet>, supplement: [Table 14])],

  
  table.header(level: 2, table.cell(colspan:3)[*display\_outside\_usrout: Output*]),
  
  [Units: mm, cm, m, ft, in],
  [These are common units the user may want the distance displayed in], [Our code allows for the distance to be displayed in these units #cite(<gh_repo>, supplement: [src/units.cpp])],
  
  [Maximum distance: $1200m m plus.minus 10%$],
  [The project instructions document specified an engineering requirement that the device must measure distances from 0.1m-1.2m with smaller than a 10% margin of error @esp32_project_instructions],
  [The VL53L0x datasheet specifies a 1.2m and 5% accuracy in high speed ranging mode #cite(<vl53l0x_datasheet>, supplement: [Table 14])],
  
  [Minimum distance: $100m m plus.minus 10%$],
  [The project instructions document specified an engineering requirement that the device must measure distances from 0.1m-1.2m with smaller than a 10% margin of error @esp32_project_instructions],
  [The VL53L0x datasheet specifies a 1.2m and 5% accuracy in high speed ranging mode #cite(<vl53l0x_datasheet>, supplement: [Table 14])],

  
  table.header(level: 2, table.cell(colspan:3)[*dashboard_outside_usrout: Output*]),
  
  [Units: mm, cm, m, ft, in],
  [These are common units the user may want the distance displayed in], [Our code allows for the distance to be displayed in these units #cite(<gh_repo>, supplement: [dashboard/src/lib/units.ts])],
  
  [Maximum distance: $1200m m plus.minus 10%$],
  [The project instructions document specified an engineering requirement that the device must measure distances from 0.1m-1.2m with smaller than a 10% margin of error @esp32_project_instructions],
  [The VL53L0x datasheet specifies a 1.2m and 5% accuracy in high speed ranging mode #cite(<vl53l0x_datasheet>, supplement: [Table 14])],
  
  [Minimum distance: $100m m plus.minus 10%$],
  [The project instructions document specified an engineering requirement that the device must measure distances from 0.1m-1.2m with smaller than a 10% margin of error @esp32_project_instructions],
  [The VL53L0x datasheet specifies a 1.2m and 5% accuracy in high speed ranging mode #cite(<vl53l0x_datasheet>, supplement: [Table 14])],
))

= Engineering Requirements <engineering-requirements>

+ The system must be battery operated.

+ The system must sense distances from 0.1m to 1.2m with a margin of error no greater than $plus.minus 10%$.

+ The system will visually display the current distance value and unit.

= Verification Process <verification-process>

// Enumerate a verification process here that any junior in the class could follow. Be as specific and expository as possible. Use prior lab documentation to guide your verification process. Imagine this process was handed to another team to complete who did not design your system. Write instructions they could follow

== ER 1 Verification

=== Requirement

The system must be battery operated.

=== Objective 

Confirm the device functions without external power delivery.

=== Process

1. Disconnect Power: Visually inspect the sensor and ensure all USB cables are unplugged. The device should be completely isolated from grid power.

2. Engage Power Switch: Flip the power switch to the ON position.

3. Observe Boot Sequence: Watch the display.

=== Pass Condition 

The screen illuminates and displays the text "Booting", followed by a transition to the measurement screen where the current distance and unit are displayed.

=== Fail Condition

The screen remains black or does not display the current distance and unit.

== ER 2 Verification:

=== Requirement

The system must sense distances from 0.1m to 1.2m with a margin of error no greater than $plus.minus 10%$.

=== Objective

Quantify the accuracy of the sensor across the required range.

=== Procedure

+ Unfold the paper ruler with markings every 0.05m and place it on a flat surface.

+ Place the distance sensor on a box to ensure the ground is not in its field of view, and line up the front with the 0m mark.

+ Attach an item to prop up the soldering station board and place it on the paper ruler so its face is exactly at the 0.1m mark. 

+ Ensure the board is perpendicular (90 degrees) to the sensor.

+ Wait 5 seconds for the reading to stabilize.

+ Record the value displayed on the screen in the table below.

+ Repeat steps 3-6 for the 1.2m mark. 


=== Calculation

For each test point, calculate the Percent Error using the following formula:

$ "%Error" = abs(("Measured Value" - "Actual Distance")/"Actual Distance") times 100  $

=== Data Table

#let ver2-table = (data) => {
  let calc-data = data.map(e => {
    let error = (e.at(2) - e.at(1))/e.at(1) * 100
    let pass-color = red
    if (calc.abs(error) <= 10) {
      pass-color = green
    }
    (e.at(0), str(e.at(1)), strfmt("{:.2}", e.at(2)), strfmt("{:.2}", error), table.cell(fill: pass-color)[])
  })
  table(
    columns: 5,
    table.header([*Test Point*], [*Actual Distance (m)*], [*Measured Distance (m)*], [*% Error*], [*Pass / Fail*]),
    ..calc-data.flatten()
  )
}

#figure(ver2-table((
  ([Min Range], 0.1, 0.1),
  // ([Mid Range 1], 0.5, 0),
  // ([Mid Range 2], 0.8, 0),
  ([Max Range], 1.2, 1.22),
)), caption: [Distance accuracy verification table.])

=== Pass Condition

The calculated % Error for all test points is ≤10%.

=== Fail Condition

Any test point exceeds 10% error.

== ER 3 Verification:

=== Requirement 

The system will visually display the current distance value and unit.

=== Objective 

Confirm the user interface provides distance data to the user.

=== Procedure 

+ Powered on the system and place a target in range:

+ Verify that a numeric value is visible and a unit of measurement (e.g., "cm", "mm", "m", or "in") is displayed next to the number.

+ Slowly move the target closer/farther from the sensor

+ Observe the screen while moving the target.

=== Pass Condition

The numeric value is visible and updates in real-time to reflect the movement, and the unit label remains visible.

=== Fail condition

Either the numeric value is not displayed or updated, or the unit label is not visible.

= System Artifacts <artifacts>

== 3D Printed Case

// Populate this section with the miscellaneous but important findings that got you to your final system. This can be prior lab work, examples found online, reference schematics, pseudocode, previous or prior version block diagrams, etc.

#figure(image("images/External Assembly.png", width: 95%), caption: [Exploded View of 3D printed case.]) <exp-case>

#figure(image("images/skeleton.jpeg", width: 80%), caption: [Assembled sensor skeleton.]) <ass-skel>

@exp-case shows an exploded view of the 3D printed case we designed to hold our sensor. The structure consists of a:

- *Internal Skeleton:* This is designed to hold all the components together into one block. It is constructed of 3 primary layers, with each layer have standoffs for circuit boards to attach. Each layer can be assembled independently, stacked, and wired together. Once the core of the skeleton is made, the distance sensor and display are attached perpendicularly on the front and side respectively. An assembled internal skeleton can be seen in @ass-skel.

- *External Case:* This holds the skeleton, protecting the internal components and providing rigidity. It is designed so the internal skeleton can simply be slid in, and a faceplate is attached to seal it.

// Include all relevant IEEE citations.

// Cite everything you did not create yourself for this document. This includes but is not limited to diagrams, schematics, pseudocode/code, pinout visuals, etc.

== Source Code

Our full source code for this project is available at https://github.com/elliotnash/OSU-ECE-341-Project. The documentation on the github has more in-depth code documentation, plus testing tools for the dashboard and the source code for this document.

#colbreak()

#bibliography("references.yaml", title: [References]) <references>
