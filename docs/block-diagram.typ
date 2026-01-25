#import "@preview/cetz:0.3.2": draw
#import "@preview/circuiteria:0.2.0": *

#let hw-color = red
#let rf-color = blue

#let analog-block = (x, y) => {
  element.block(
    id: "analog",
    w: 10,
    h: 7,
    x: x,
    y: y,
    name: [Analog \ (Oliver) #v(10em) ],
    ports: (
      west: (
        (id: "asig-in", name: [outside_analog_asig]),
        (id: "vsys-in", name: [power_analog_dcpwr(vsys)]),
        (id: "1v65-in", name: [power_analog_dcpwr(1v65)]),
        (id: "-1v65-in", name: [power_analog_dcpwr(-1v65)]),
        (id: "dsig-in", name: [mcu_analog_dsig]),
      ),
      east: (
        (id: "asig-out", name: [analog_mcu_asig]),
        (id: "asig-trig-out", name: [analog_trigger_asig]),
      ),
    ),
    ports-margins: (
      west: (15%, 0%),
      east: (35%, 0%),
    ),
    fill: util.colors.green
  )
}

#let analog-diagram = circuit({
  analog-block(0,0)
  // Inputs
  wire.wire("outside-to-analog", ((rel: (-1,0), to: "analog-port-asig-in"), "analog-port-asig-in"), directed: true)
  wire.wire("vsys-to-analog", ((rel: (-1,0), to: "analog-port-vsys-in"), "analog-port-vsys-in"), directed: true)
  wire.wire("1v65-to-analog", ((rel: (-1,0), to: "analog-port-1v65-in"), "analog-port-1v65-in"), directed: true)
  wire.wire("-1v65-to-analog", ((rel: (-1,0), to: "analog-port--1v65-in"), "analog-port--1v65-in"), directed: true)
  wire.wire("mcu-to-analog", ((rel: (-1,0), to: "analog-port-dsig-in"), "analog-port-dsig-in"), directed: true)
  // Outputs
  wire.wire("analog-to-adc", ("analog-port-asig-out", (rel: (1,0), to: "analog-port-asig-out")), directed: true)
  wire.wire("analog-to-trigger", ("analog-port-asig-trig-out", (rel: (1,0), to: "analog-port-asig-trig-out")), directed: true)
})

#let adc-block = (x, y) => {
  element.block(
    id: "adc",
    w: 9,
    h: 4,
    x: x,
    y: y,
    name: [ADC #v(4em) ],
    ports: (
      west: (
        (id: "asig-in", name: [analog_adc_asig]),
        (id: "dcpwr-in", name: [power_adc_dcpwr])
      ),
      east: (
        (id: "comm-out", name: [adc_mcu_comm]),
      )
    ),
    fill: util.colors.purple
  )
}

#let adc-diagram = circuit({
  adc-block(0,0)
  wire.wire("analog-to-adc", ((rel: (-1,0), to: "adc-port-asig-in"), "adc-port-asig-in"), directed: true)
  wire.wire("power-to-adc", ((rel: (-1,0), to: "adc-port-dcpwr-in"), "adc-port-dcpwr-in"), directed: true)
  wire.wire("adc-to-mcu", ("adc-port-comm-out", (rel: (1,0), to: "adc-port-comm-out")), directed: true)
})

#let power-block = (x, y) => {
  element.block(
    id: "power",
    w: 10,
    h: 5,
    x: x,
    y: y,
    name: [Power \ (Yahir) #v(6em)],
    ports: (
      west: (
        (id: "dc-in", name: [outside_power_dcpwr]),
      ),
      east: (
        (id: "dc-out", name: [power_all_dcpwr(vsys)]),
        (id: "ref-out", name: [power_all_dcpwr(vref)]),
        (id: "1v65-out", name: [power_all_dcpwr(1v65)]),
        (id: "-1v65-out", name: [power_all_dcpwr(-1v65)]),
      )
    ),
    ports-margins: (
      west: (15%, 0%),
      east: (25%, 0%),
    ),
    fill: util.colors.yellow
  )
}

#let power-diagram = circuit({
  power-block(0,0)
  wire.wire("outside-to-power", ((rel: (-1,0), to: "power-port-dc-in"), "power-port-dc-in"), directed: true)
  wire.wire("power-to-mcu", ("power-port-dc-out", (rel: (1,0), to: "power-port-dc-out")), directed: true)
  wire.wire("power-to-mcu", ("power-port-ref-out", (rel: (1,0), to: "power-port-ref-out")), directed: true)
  wire.wire("power-to-mcu", ("power-port-1v65-out", (rel: (1,0), to: "power-port-1v65-out")), directed: true)
  wire.wire("power-to-mcu", ("power-port--1v65-out", (rel: (1,0), to: "power-port--1v65-out")), directed: true)
})

#let trigger-block = (x, y) => {
  element.block(
    id: "trigger",
    w: 10,
    h: 5,
    x: x,
    y: y,
    name: [Trigger \ (Yahir) #v(6em)],
    ports: (
      west: (
        (id: "comm-in", name: [mcu_trigger_comm]),
        (id: "asig-in", name: [analog_trigger_asig]),
        (id: "vref-in", name: [power_trigger_dcpwr(vref)]),
        (id: "vsys-in", name: [power_trigger_dcpwr(vsys)]),
      ),
      east: (
        (id: "dsig-out", name: [trigger_mcu_dsig]),
      )
    ),
    ports-margins: (
      west: (20%, 0%),
    ),
    fill: util.colors.orange
  )
}

#let trigger-diagram = circuit({
  trigger-block(0,0)
  // Inputs
  wire.wire("mcu-to-trigger", ((rel: (-1,0), to: "trigger-port-comm-in"), "trigger-port-comm-in"), directed: true)
  wire.wire("analog-to-trigger", ((rel: (-1,0), to: "trigger-port-asig-in"), "trigger-port-asig-in"), directed: true)
  wire.wire("mcu-to-trigger", ((rel: (-1,0), to: "trigger-port-vref-in"), "trigger-port-vref-in"), directed: true)
  wire.wire("analog-to-trigger", ((rel: (-1,0), to: "trigger-port-vsys-in"), "trigger-port-vsys-in"), directed: true)
  // Outputs
  wire.wire("trigger-to-mcu", ("trigger-port-dsig-out", (rel: (1,0), to: "trigger-port-dsig-out")), directed: true)
})

#let mcu-block = (x, y) => {
  element.block(
    id: "mcu",
    w: 10,
    h: 6,
    x: x,
    y: y,
    name: [MCU \ (Oliver) #v(8em)],
    ports: (
      west: (
        (id: "dcpwr-in", name: [power_mcu_dcpwr(vsys)]),
        (id: "vref-in", name: [power_mcu_dcpwr(vref)]),
        (id: "asig-in", name: [analog_mcu_asig]),
        (id: "dsig-in", name: [trigger_mcu_dsig]),
      ),
      east: (
        (id: "dsig-out", name: [mcu_analog_dsig]),
        (id: "trig-out", name: [mcu_trigger_comm]),
        // (id: "comm-out", name: [mcu_backend_comm]),
      )
    ),
    ports-margins: (
      west: (15%, 0%),
      east: (15%, 0%),
    ),
    fill: util.colors.blue
  )
}

#let mcu-diagram = circuit({
  mcu-block(0,0)
  wire.wire("adc-to-mcu", ((rel: (-1,0), to: "mcu-port-asig-in"), "mcu-port-asig-in"), directed: true)
  wire.wire("adc-to-mcu", ((rel: (-1,0), to: "mcu-port-vref-in"), "mcu-port-vref-in"), directed: true)
  wire.wire("power-to-mcu", ((rel: (-1,0), to: "mcu-port-dcpwr-in"), "mcu-port-dcpwr-in"), directed: true)
  wire.wire("trigger-to-mcu", ((rel: (-1,0), to: "mcu-port-dsig-in"), "mcu-port-dsig-in"), directed: true)

  // draw.mark("mcu-port-comm-out", (rel: (-1,0), to: "mcu-port-comm-out"), symbol: ">", fill: black)
  // wire.wire("mcu-to-backend", ("mcu-port-comm-out", (rel: (1,0), to: "mcu-port-comm-out")), directed: true)

  wire.wire("mcu-to-trigger", ("mcu-port-trig-out", (rel: (1,0), to: "mcu-port-trig-out")), directed: true)
  wire.wire("mcu-to-trigger", ("mcu-port-dsig-out", (rel: (1,0), to: "mcu-port-dsig-out")), directed: true)
})

#let backend-block = (x, y) => {
  element.block(
    id: "backend",
    w: 11,
    h: 5,
    x: x,
    y: y,
    name: [Backend \ (Elliot) #v(6em)],
    ports: (
      // west: (
      //   (id: "comm-in", name: [mcu_backend_comm]),
      // ),
      east: (
        (id: "comm-out", name: [backend_frontend_data]),
      )
    ),
    ports-margins: (
      west: (15%, 0%),
      east: (15%, 0%),
    ),
    fill: util.colors.pink
  )
}

#let backend-diagram = circuit({
  backend-block(0,0)
  // wire.wire("mcu-to-backend", ((rel: (-1,0), to: "backend-port-comm-in"), "backend-port-comm-in"), directed: true)
  // draw.mark((rel: (-1.1,0), to: "backend-port-comm-in"), (rel: (-2,0), to: "backend-port-comm-in"), symbol: ">", fill: black)
  wire.wire("backend-to-frontend", ("backend-port-comm-out", (rel: (1,0), to: "backend-port-comm-out")), directed: true)
  draw.mark("backend-port-comm-out", (rel: (-1,0), to: "backend-port-comm-out"), symbol: ">", fill: black)
})

#let frontend-block = (x, y) => {
  element.block(
    id: "frontend",
    w: 11,
    h: 5,
    x: x,
    y: y,
    name: [Frontend \ (Elliot) #v(6em)],
    ports: (
      west: (
        (id: "usrin", name: [outside_frontend_usrin]),
      ),
      east: (
        (id: "comm-out", name: [frontend_backend_data]),
        (id: "usrout", name: [frontend_outside_usrout]),
      )
    ),
    ports-margins: (
      west: (15%, 0%),
      east: (15%, 0%),
    ),
    fill: red.lighten(35%)
  )
}

#let frontend-diagram = circuit({
  frontend-block(0,0)
  // Inputs
  wire.wire("outside-to-frontend", ((rel: (-1,0), to: "frontend-port-usrin"), "frontend-port-usrin"), directed: true)
  // Outputs
  wire.wire("backend-to-frontend", ("frontend-port-comm-out", (rel: (1,0), to: "frontend-port-comm-out")), directed: true)
  draw.mark("frontend-port-comm-out", (rel: (-1,0), to: "frontend-port-comm-out"), symbol: ">", fill: black)
  wire.wire("outside-to-frontend", ("frontend-port-usrout", (rel: (1,0), to: "frontend-port-usrout")), directed: true)
})

#let hardware-group = (x, y) => {
  analog-block(x,y - 7)

  power-block(x,y + 2)

  // adc-block(x+12,y)

  trigger-block(x+12,y - 7)

  mcu-block(x + 12,y)

  // Analog to MCU
  wire.wire("analog-to-mcu", ("analog-port-asig-out", "mcu-port-asig-in"), style: "zigzag", zigzag-ratio: 33.3%, directed: true)

  // MCU to Analog
  wire.wire("mcu-to-analog", ("mcu-port-dsig-out", "analog-port-dsig-in"), dodge-margins: (1, 0.5), style: "dodge", dodge-y: y - 7.5, directed: true)
  
  // Triger to MCU
  wire.wire("trigger-to-mcu", ("trigger-port-dsig-out", "mcu-port-dsig-in"), dodge-margins: (0.5, 0.75), style: "dodge", dodge-y: y - 0.75, directed: true)

  // Analog to Trigger
  wire.wire("analog-to-trigger", ("analog-port-asig-trig-out", "trigger-port-asig-in"), style: "zigzag", directed: true)

  // MCU to Trigger
  wire.wire("mcu-to-trigger", ("mcu-port-trig-out", "trigger-port-comm-in"), style: "dodge", dodge-y: y - 1.5, dodge-margins: (0.75, 0.75), directed: true)

  // Analog Inputs
  wire.wire("vsys-to-analog", ((rel: (-0.75,0), to: "analog-port-vsys-in"), "analog-port-vsys-in"), directed: true)
  wire.wire("1v65-to-analog", ((rel: (-0.75,0), to: "analog-port-1v65-in"), "analog-port-1v65-in"), directed: true)
  wire.wire("-1v65-to-analog", ((rel: (-0.75,0), to: "analog-port--1v65-in"), "analog-port--1v65-in"), directed: true)

  // Power Outputs
  wire.wire("power-to-mcu", ("power-port-dc-out", (rel: (0.75,0), to: "power-port-dc-out")), directed: true)
  wire.wire("power-to-mcu", ("power-port-ref-out", (rel: (0.75,0), to: "power-port-ref-out")), directed: true)
  wire.wire("power-to-mcu", ("power-port-1v65-out", (rel: (0.75,0), to: "power-port-1v65-out")), directed: true)
  wire.wire("power-to-mcu", ("power-port--1v65-out", (rel: (0.75,0), to: "power-port--1v65-out")), directed: true)

  // Trigger Inputs
  wire.wire("mcu-to-trigger", ((rel: (-0.75,0), to: "trigger-port-vref-in"), "trigger-port-vref-in"), directed: true)
  wire.wire("analog-to-trigger", ((rel: (-0.75,0), to: "trigger-port-vsys-in"), "trigger-port-vsys-in"), directed: true)

  // MCU Inputs
  wire.wire("adc-to-mcu", ((rel: (-0.75,0), to: "mcu-port-vref-in"), "mcu-port-vref-in"), directed: true)
  wire.wire("power-to-mcu", ((rel: (-0.75,0), to: "mcu-port-dcpwr-in"), "mcu-port-dcpwr-in"), directed: true)
}

#let application-group = (x, y) => {
  backend-block(x,y)

  frontend-block(x,y - 6)

  // backend to frontend connection
  wire.wire("backend-to-frontend1", ((rel: (1, 0), to: "backend-port-comm-out"), "backend-port-comm-out"), directed: true)
  wire.wire("backend-to-frontend2", ((rel: (1, 0), to: "backend-port-comm-out"), (rel: (1, 0), to: "frontend-port-comm-out")))
  wire.wire("backend-to-frontend3", ((rel: (1,0), to: "frontend-port-comm-out"), "frontend-port-comm-out"), directed: true)
}

#let system-diagram = circuit({
  element.group(id: "system", name: [System], stroke: (dash: "dashed"), {
    element.group(id: "application", name: [Application], stroke: (dash: "dashed", paint: rf-color), {
      application-group(5.25,-14)
    })

    element.group(id: "hardware", name: [Hardware], stroke: (dash: "dashed", paint: hw-color), {
      hardware-group(0,0)
    })
    

    // MCU to backend connection
    // wire.wire("mcu-to-backend", ("mcu-port-comm-out", "backend-port-comm-in"), style: "zigzag", zigzag-ratio: 90%, directed: true)
  })

  // Hardware System Inputs
  wire.wire("outside-to-analog", ((rel: (-1.75,0), to: "analog-port-asig-in"), "analog-port-asig-in"), directed: true)
  wire.wire("outside-to-power", ((rel: (-1.75,0), to: "power-port-dc-in"), "power-port-dc-in"), directed: true)

  // Application stubs
  wire.wire("outside-to-frontend", ((rel: (-7,0), to: "frontend-port-usrin"), "frontend-port-usrin"), directed: true)
  wire.wire("frontend-to-outside", ("frontend-port-usrout", (rel: (8,0), to: "frontend-port-usrout")), directed: true)
})


#set page(height: auto, width: auto, margin: 1cm)

#let system-black-box-diagram = circuit({
  element.block(
    id: "distance",
    w: 12,
    h: 6,
    x: 0,
    y: 0,
    name: [Oscilloscope System #v(7em)],
    ports: (
      west: (
        (id: "asig", name: [outside_analog_asig]),
        (id: "dcpwr", name: [outside_power_dcpwr]),
        (id: "frontend-usrin", name: [outside_frontend_usrin]),
      ),
      east: (
        (id: "frontend-usrout", name: [frontend_outside_usrout]),
      )
    ),
    ports-margins: (
      west: (20%, 0%),
      east: (20%, 0%),
    ),
    fill: gray.lighten(65%)
  )
  wire.wire("outside-to-power", ((rel: (-1,0), to: "distance-port-asig"), "distance-port-asig"), directed: true)
  wire.wire("outside-to-distance", ((rel: (-1,0), to: "distance-port-dcpwr"), "distance-port-dcpwr"), directed: true)
  wire.wire("outside-to-dashboard", ((rel: (-1,0), to: "distance-port-frontend-usrin"), "distance-port-frontend-usrin"), directed: true)
  wire.wire("distance-to-display", ("distance-port-frontend-usrout", (rel: (1,0), to: "distance-port-frontend-usrout")), directed: true)

})

#system-black-box-diagram
#colbreak()

#system-diagram
#colbreak()

#analog-diagram
#colbreak()

#adc-diagram
#colbreak()

#power-diagram
#colbreak()

#trigger-diagram 
#colbreak()

#mcu-diagram
#colbreak()

#backend-diagram
#colbreak()

#frontend-diagram
