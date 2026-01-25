#import "@preview/cetz:0.3.2": draw
#import "@preview/circuiteria:0.2.0": *

#let hw-color = red
#let rf-color = blue

#let analog-block = (x, y) => {
  element.block(
    id: "analog",
    w: 9,
    h: 4,
    x: x,
    y: y,
    name: [Analog #v(4em) ],
    ports: (
      west: (
        (id: "asig-in", name: [outside_analog_asig]),
      ),
      east: (
        (id: "asig-out", name: [analog_adc_asig]),
      ),
    ),
    fill: util.colors.green
  )
}

#let analog-diagram = circuit({
  analog-block(0,0)
  wire.wire("outside-to-analog", ((rel: (-1,0), to: "analog-port-asig-in"), "analog-port-asig-in"), directed: true)
  wire.wire("analog-to-adc", ("analog-port-asig-out", (rel: (1,0), to: "analog-port-asig-out")), directed: true)
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
    w: 9,
    h: 4,
    x: x,
    y: y,
    name: [Power #v(4em)],
    ports: (
      west: (
        (id: "dc-in", name: [outside_power_dcpwr]),
      ),
      east: (
        (id: "ref-out", name: [power_adc_dcpwr]),
        (id: "dc-out", name: [power_mcu_dcpwr]),
      )
    ),
    ports-margins: (
      west: (25%, 0%),
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
})

#let trigger-block = (x, y) => {
  element.block(
    id: "trigger",
    w: 9,
    h: 5,
    x: x,
    y: y,
    name: [Trigger #v(6em)],
    ports: (
      west: (
        (id: "asig-in", name: [analog_trigger_asig]),
        (id: "comm-in", name: [mcu_trigger_comm]),
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
  wire.wire("mcu-to-trigger", ((rel: (-1,0), to: "trigger-port-comm-in"), "trigger-port-comm-in"), directed: true)
  wire.wire("analog-to-trigger", ((rel: (-1,0), to: "trigger-port-asig-in"), "trigger-port-asig-in"), directed: true)
  // draw.mark((rel: (-1.1,0), to: "distance-port-comm"), (rel: (-2,0), to: "distance-port-comm"), symbol: ">", fill: black)
  wire.wire("trigger-to-mcu", ("trigger-port-dsig-out", (rel: (1,0), to: "trigger-port-dsig-out")), directed: true)
})

#let mcu-block = (x, y) => {
  element.block(
    id: "mcu",
    w: 10,
    h: 6,
    x: x,
    y: y,
    name: [MCU #v(8em)],
    ports: (
      west: (
        (id: "dcpwr-in", name: [power_mcu_dcpwr]),
        (id: "comm-in", name: [adc_mcu_comm]),
        (id: "dsig-in", name: [trigger_mcu_dsig]),
      ),
      east: (
        (id: "trig-out", name: [mcu_trigger_comm]),
        (id: "comm-out", name: [mcu_backend_comm]),
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
  wire.wire("adc-to-mcu", ((rel: (-1,0), to: "mcu-port-comm-in"), "mcu-port-comm-in"), directed: true)
  wire.wire("power-to-mcu", ((rel: (-1,0), to: "mcu-port-dcpwr-in"), "mcu-port-dcpwr-in"), directed: true)
  wire.wire("trigger-to-mcu", ((rel: (-1,0), to: "mcu-port-dsig-in"), "mcu-port-dsig-in"), directed: true)

  draw.mark("mcu-port-comm-out", (rel: (-1,0), to: "mcu-port-comm-out"), symbol: ">", fill: black)
  wire.wire("mcu-to-backend", ("mcu-port-comm-out", (rel: (1,0), to: "mcu-port-comm-out")), directed: true)

  wire.wire("mcu-to-trigger", ("mcu-port-trig-out", (rel: (1,0), to: "mcu-port-trig-out")), directed: true)
})

#let backend-block = (x, y) => {
  element.block(
    id: "backend",
    w: 11,
    h: 5,
    x: x,
    y: y,
    name: [Backend #v(6em)],
    ports: (
      west: (
        (id: "comm-in", name: [mcu_backend_comm]),
      ),
      east: (
        (id: "comm-out", name: [backend_frontend_comm]),
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
  wire.wire("mcu-to-backend", ((rel: (-1,0), to: "backend-port-comm-in"), "backend-port-comm-in"), directed: true)
  draw.mark((rel: (-1.1,0), to: "backend-port-comm-in"), (rel: (-2,0), to: "backend-port-comm-in"), symbol: ">", fill: black)
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
    name: [Frontend #v(6em)],
    ports: (
      west: (
        (id: "usrin", name: [outside_frontend_usrin]),
      ),
      east: (
        (id: "comm-out", name: [backend_frontend_comm]),
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
  wire.wire("outside-to-frontend", ((rel: (-1,0), to: "frontend-port-usrin"), "frontend-port-usrin"), directed: true)
  wire.wire("backend-to-frontend", ("frontend-port-comm-out", (rel: (1,0), to: "frontend-port-comm-out")), directed: true)
  draw.mark("frontend-port-comm-out", (rel: (-1,0), to: "frontend-port-comm-out"), symbol: ">", fill: black)
})

#let hardware-group = (x, y) => {
  analog-block(x,y)

  power-block(x,y - 5)

  adc-block(x+12,y)

  trigger-block(x+12,y - 6)

  mcu-block(x + 6,y - 13)

  // Analog to ADC
  wire.wire("analog-to-adc", ("analog-port-asig-out", "adc-port-asig-in"), style: "zigzag", zigzag-ratio: 33.3%, directed: true)

  // Power to ADC
  wire.wire("power-to-adc", ("power-port-ref-out", "adc-port-dcpwr-in"), style: "zigzag", zigzag-ratio: 33.3%, directed: true)

  // Power to MCU
  wire.wire("power-to-mcu", ("power-port-dc-out", "mcu-port-dcpwr-in"), style: "dodge", dodge-y: y - 6, dodge-margins: (0.75, 0.75), directed: true)

  // Triger to MCU
  wire.wire("trigger-to-mcu", ("trigger-port-dsig-out", "mcu-port-dsig-in"), style: "dodge", dodge-y: y - 13.5, directed: true)

  // ADC to MCU
  wire.wire("adc-to-mcu", ("adc-port-comm-out", "mcu-port-comm-in"), style: "dodge", dodge-y: y - 14, dodge-margins: (1.25, 1.25), directed: true)

  // Analog to Trigger
  wire.wire("analog-to-trigger", ("analog-port-asig-out", "trigger-port-asig-in"), style: "zigzag", zigzag-ratio: 66.6%)

  // MCU to Trigger
  wire.wire("mcu-to-trigger", ("mcu-port-trig-out", "trigger-port-comm-in"), style: "dodge", dodge-y: y - 6.5, dodge-margins: (0.75, 0.75), directed: true)
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
    element.group(id: "application", name: [Application], stroke: (dash: "dashed", paint: rf-color), padding: (left: 1), {
      application-group(24,-4)
    })

    element.group(id: "hardware", name: [Hardware], stroke: (dash: "dashed", paint: hw-color), {
      hardware-group(0,0)
    })

    // MCU to backend connection
    wire.wire("mcu-to-backend", ("mcu-port-comm-out", "backend-port-comm-in"), style: "zigzag", zigzag-ratio: 90%, directed: true)

  //   // MCU to Dashboard connection
  //   wire.wire("mcu-to-dashboard", ("mcu-port-rf", "dashboard-port-rf"), style: "dodge", dodge-sides: ("west", "west"), dodge-margins: (0.5, 0.5), dodge-y: 1.5, directed: true)
  //   draw.mark("mcu-port-rf", (rel: (1,0)), symbol: ">", fill: black)
  })

  // // Dashboard Outside stubs
  // wire.wire("dashboard-to-outside", ("dashboard-port-usrout", (rel: (10,0), to: "dashboard-port-usrout")), directed: true)
  // wire.wire("outside-to-dashboard", ((rel: (-10,0), to: "dashboard-port-usrin"), "dashboard-port-usrin"), directed: true)

  // // Power Outside stubs
  // wire.wire("outside-to-power", ((rel: (-3,0), to: "power-port-dc-in"), "power-port-dc-in"), directed: true)

  // // Distance Outside stubs
  // wire.wire("outside-to-distance", ((rel: (-17,0), to: "distance-port-envin"), "distance-port-envin"), directed: true)

  // // Display Outside stubs
  // wire.wire("display-to-outside", ("display-port-usrout", (rel: (3,0), to: "display-port-usrout")), directed: true)
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
