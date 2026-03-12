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

= Frontend Video Link <frontend-video-link>

https://photos.app.goo.gl/96qs8vVBkN8Uo1rw8

= Frontend Description <frontend-description>
// #TODO[{Create a block diagram of your individual block. Write a detailed description of #emph[what your block does];. What is its role in the system? How does its role relate to the overall system requirements? What is coming into the block? What does the block do to that input? What is created and then delivered as an output? This is where your deep dive into functionality goes. Make sure to include the names and functions of all interfaces related to this block and that they match your top-level architecture above.}]

#figure(frontend-diagram, caption: [Frontend Black Box Diagram]) <frontend-blackbox>

The frontend block serves as the graphical user interface (GUI) and data visualization layer of the system. It is designed to process the JSON data sent from the backend block into waveforms on the GUI, as well as translate user input into JSON data that can be sent to the backend block. The frontend is written in React/Typescript, using the Tanstack Router framework and Tailwind V4 for styling. Waveform rendering is handled via the visx library, which allows the frontend to render large amounts of data while maintaining performance, as well as easily allowing custom interactions and styling. 

#figure(image("./frontend-flow.png", height: 55%), caption: [Frontend Internal Flow Diagram])

== Functionality

The frontend consists of of two distinct data paths:

1. *Waveform Visualization (RX):* The frontend establishes a persistent Tauri channel for incoming events from the backend. Incoming frame data payloads are moved into a frame store which is accessed in the render loop. The `requestAnimationFrame` API is used to synchronize the render loop with the monitors refresh rate, and inside the render loop the frame data is processed and mapped to pixel coordinates using the visx library @request_anim.

2. *User Input (TX):* The frontend accepts user commands (such as toggling channels or adjusting voltage scales). The interactions are captured by standard UI elements from the IntentUI library, which use react-aria to provide intuitive and accessible components. In each event handler, the associated Tauri command is invoked, sending the input command to the backend which can then trigger hardware changes.

== Interfaces

The frontend block interfaces with the user and backend through three interfaces:

1. *`outside_frontend_usrin`:* This interface represents the inputs provided by the user. It encompasses all physical interactions with the GUI including mouse clicks on UI elements and keyboard input to text inputs. It is used to capture user intent and translate it into state changes in the application.

2. *`frontend_outside_usrout`:* This interface functions as the visual ouptut to the user. It consists primarily of a graph that renders the waveform as a line plot (voltage vs. time). It includes waveforms for both channels A and B, as well as a virtualized waveform for the math channel.

3. *`frontend_backend_data`:* This interface represents the Inter-Process Communication (IPC) between the Rust backend and the React frontend. It functions as a bridge, allowing the UI to invoke backend functions asynchronously while simultaneously subscribing to processed data events for real-time visualization.

= Frontend Design Details <frontend-design-details>
// #TODO[{Write a detailed description of #emph[how your block works];. Demonstrate your learning by explaining clearly what the inputs are and where they come from. Explain how those inputs become outputs through your block. Design details must include in-text citations in IEEE format. Cite resources from prior coursework, module resources lists from this class, or resources you have found externally.}]

The two highest priorities when developing the frontend are performance and user experience. An oscilloscope frame can consist of thousands of data points, and the frames need to be refreshed at 60Hz to support a smooth display. Since the frontend is run in a webview via Tauri, it is not nearly as performant out of the box as native UI toolkits. Thus, it is very important that the data visualization library is able to render frames efficiently. 

== Data Visualization

The visx library was chosen to as the data visualization library. While visx is not as fast as some Web Canvas based visualization libraries, it is significantly faster than most SVG based ones due to its use of the d3 computation library @visx_gh. To verify that the performance met our needs, before selecting it we built a test app with a 10,000 point line graph, which had no problem rendering at 60Hz in the Tauri webview environment. Since the frontend will never need to display 10000 points at once (frame segments can be downsampled to the pixel width of the graph), this is plenty performant. Where visx really shines is its customizability. Because SVGs remain part of the Document Object Model (DOM), we can leverage standard web event listeners for user interactions, significantly improving the UX and making custom styling much easier.

== UI Components

To design an app that feels intuitive to use, the styling and component interactions must be consistent throughout @input_ux. 

All UI components are built using IntentUI, a component library constructed on top of headless React Aria primitives @intentui. This ensures that all the controls are consistent with each other, as well as accessibility standards such as W3C @aria. This enables easy building of clean user interfaces, as seen in @frontend-ui.

#figure(image("frontend.png"), caption: [Frontend UI]) <frontend-ui>

When a user interacts with a control (i.e. changing the voltage scale), the frontend first validates the input against the hardware constraints. Many of these inputs are already validated as they use "safe" input types such as dropdowns and button groups @input_ux. Validated commands are then dispatched to the backend using Tauri’s Inter-Process Communication (IPC) @github[frontend/src/routes/home.tsx]. These IPC calls invoke Rust functions in the backend block directly from the JavaScript runtime, allowing for very low-latency inputs to be sent to the backend.

= Frontend Interface Validation <frontend-interface-validation>

#figure(table(
  columns: 3,
  table.header(
    [*Interface Property*],
    [*Why is this interface this value?*],
    [*How do you know your design details will meet or exceed this property? Cite your sources in IEEE.*]
  ),
  
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

  table.header(level: 2, table.cell(colspan: 3)[*backend_frontend_data: Input/Output*]),

  [*Communication Protocol*: Tauri IPC],
  [The oscilloscope generates a continuous stream of waveform data. Tauri channels allow the backend to establish a persistent connection to the frontend, streaming partial results (waveform chunks) as they arrive without the overhead of repeated command invocations @tauri_v2_channels. Tauri events allow easily sending one off events @tauri_v2_channels.],
  [The frontend code uses commands from the generated `bindings.ts` file, which use Tauri commands, channels, and events over Tauri IPC.],

  [*Type Generator*: Specta],
  [The React frontend is written in TypeScript. To maintain type safety, the data received from the Rust backend must match the expected frontend types exactly.],
  [The `specta` library is integrated into the `common` crate to automatically generate a `bindings.ts` file from the Rust `Message` structs @beaumont_specta. This guarantees that if the Rust data model changes, the TypeScript build will fail, ensuring that the design strictly meets the property of type safety at compile time.],

  [*Serialization Format*: JSON],
  [The Tauri WebView uses JavaScript Object Notation (JSON) @tauri_ipc. Converting Rust structs to JSON ensures the data is immediately usable by the JavaScript engine without manual parsing logic on the frontend.],
  [The `serde_json` library is used strictly for serializing the payload sent through the `Channel`. This is the default serialization method for Tauri IPC @tauri_ipc.],
), caption: [Interface Property Table])

= Frontend Verification Process <frontend-verification-process>

#set enum(numbering: "1.a.")

= Verification Process <block-2-verification-process>

== Interface: `outside_frontend_usrin`

+ *Verify Input Types, Actions, and Data Ranges*
  + Build and run the frontend application using `cargo tauri dev`.
  + Navigate to the main oscilloscope dashboard.
  + Click the "Coupling" switch (AC/DC) and "Attenuation" toggle (1x/10x).
  - *PASS:* The UI element updates immediately to reflect the new state (e.g., "AC" becomes highlighted).
  - *FAIL:* The UI element remains unresponsive or stuck in the previous state.
  + Select the "1x" attenuation mode
  + Select the "Voltage Scale" dropdown for Channel A.
  + Observe the available options in the list.
    - *PASS:* The dropdown is visible, and the options match the defined data ranges: { $plus.minus 1.5V, plus.minus 0.36V, dots, plus.minus 0.07V$ }. No invalid values are present.
    - *FAIL:* The dropdown is missing, or contains values not supported by the hardware interface.
  + Select the "10x" attenuation mode
  + Select the "Voltage Scale" dropdown for Channel A.
  + Observe the available options in the list.
    - *PASS:* The dropdown is visible, and the options match the defined data ranges: { $plus.minus 15V, plus.minus 3.6V, dots, plus.minus 0.07V$ }. No invalid values are present.
    - *FAIL:* The dropdown is missing, or contains values not supported by the hardware interface.
  + Click the "Math Channel" toggle to Enable it, then select the "Custom" tab.
    - *PASS:* A text input field appears, allowing the user to type a free-form equation (i.e. `(A+B)/2`).
    - *FAIL:* No text input appears, or the user is restricted to a preset list in Custom mode.

== Interface: `frontend_outside_usrout`

+ Verify Output Type, and Channel Colors
  + Build and run the frontend application using `cargo tauri dev`.
  + Navigate to the main oscilloscope dashboard.
  + Ensure Channel A, Channel B, and the Math Channel are enabled.
  + Observe the waveform graph area.
    - *PASS:* A 2D Cartesian graph is rendered. The Channel A waveform is drawn in *Purple*, Channel B is *Red*, and the Math channel (if enabled) is *Green*.
    - *FAIL:* The graph is blank, or the channel colors do not match the defined spec (e.g., Channel A is red).

+ Verify Waveform Interpolation
  + Open the `frontend/src/routes/home.tsx` file in a code editor
  + Observe the property passed to the `curve` field of the `LinePath` in the `Plot` component
    - *PASS:* `allCurves.curveStep` is passed to the `curve` field.
    - *FAIL:* `allCurves.curveStep` is not passed to the `curve` field.

+ Verify Refresh Rate (> 55Hz)
  // + Open the Chrome Developer Tools (Right Click -> Inspect) within the Tauri window.
  // + Press `Ctrl+Shift+P` (Cmd+Shift+P on Mac) and type "Show Rendering".
  // + Enable the "Frame Rendering Stats" checkbox to view the FPS meter overlay.
  + Build and run the frontend application using `cargo tauri dev`.
  + Navigate to the main oscilloscope dashboard.
  + Click the menu button in the top left, and enable debug information.
  + Observe the Frame Rate displayed while the graph is animating.
    - *PASS:* The FPS meter consistently reads above 55 fps.
    - *FAIL:* The FPS meter consistently reads below 55 fps.

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
  
= Frontend Artifacts <frontend-artifacts>
// #TODO[{Populate this section with the miscellaneous but important findings that got you to your final block design. This means anything you had to learn in order to make choices about your design details. This might be prior coursework, examples found online, reference schematics, pseudocode, previous or prior version block diagrams, etc. Think of this section as a repository of your progress on this block. Do not include what is in your design details.}]

== UI Layout

The UI has evolved considerably from the first frontend iteration. One thing that was particularly challenging to solve was how to ensure the layout was responsive to any screen resolution/size. While early designs used a fixed sidebar, this proved ineffective for portrait aspect ratios, where the sidebar eats into the already limited horizontal real estate. Instead, an adaptive approach was chosen where for portrait aspect ratios, the control bar moves to the bottom. This leaves a lot more horizontal room for the graph. To implement this, all the child components needed to be updated to work in either layout, however this was made easy with the `landscape` and `portrait` tailwind selectors. The result of this bottom bar configuration can be seen in @portrait-bar.

#figure(image("frontend-portrait.png", width: 80%), caption: [Portrait mode bottom bar layout.]) <portrait-bar>

= Frontend Future Recommendations <frontend-future-recommendations>
// #TODO[{This was a lot of work. Take some time to reflect on how far you have come from starting to understand the design process last term, to creating a novel block for a unique, custom system. What went well? What would you tell yourself at the beginning of the term given what you know now?}]

The shared data model architecture worked really well for the frontend block -- in past projects a very large portion of the debugging time has been on issues with model synchronization, but I did not encounter a single model related error. Tanstack Router was also a highlight of the tech stack, the file based routing worked well, and its type-safety fit in well with the approach to typings used throughout the rest of the project.

Something that could be very useful to implement is a signal frequency analysis tool. This would take some thought as to how much of the computation would go in the backend block and how much in the frontend, as well as some research on the sorts of tools that are commonly used when analyzing frequency domain signals. 

#bibliography("./frontend-ref.bib", title: [Frontend References]) <frontend-references>
