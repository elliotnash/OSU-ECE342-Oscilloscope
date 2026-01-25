#import "@preview/cetz:0.3.2": draw
#import "@preview/circuiteria:0.2.0": *

// --- BLOCK DEFINITIONS ---
#let analog-block = (x, y) => {
  element.block(
    id: "analog", w: 10, h: 8, x: x, y: y,
    name: [Analog \ _Oliver_],
    ports: (
      west: ((id: "asig-in", name: text(0.55em)[outside_analog_asig]),),
      east: (
        (id: "to-mcu", name: text(0.55em)[analog_mcu_asig]), 
        (id: "to-trig", name: text(0.55em)[analog_trigger_asig])
      ),
      south: ((id: "pwr-in", name: ""),),
      north: ((id: "dsig-in", name: ""),),
    ),
    fill: util.colors.green
  )
}

#let power-block = (x, y) => {
  element.block(
    id: "power", w: 10, h: 8, x: x, y: y,
    name: [Power \ _Yahir_],
    ports: (
      west: ((id: "dc-in", name: text(0.55em)[outside_power_dcpwr]),),
      north: ((id: "dc-analog-out", name: text(0.55em)[power_analog]),),
      east: ((id: "dc-mcu-out", name: text(0.55em)[power_mcu_dcpwr]),),
    ),
    fill: util.colors.yellow
  )
}

#let trigger-block = (x, y) => {
  element.block(
    id: "trigger", w: 10, h: 8, x: x, y: y,
    name: [Trigger \ _Yahir_],
    ports: (
      west: ((id: "asig-in", name: ""),),
      north: (
        (id: "comm", name: ""), 
        (id: "dsig-out", name: text(0.55em)[trigger_mcu_dsig]), 
      )
    ),
    fill: util.colors.orange
  )
}

#let mcu-block = (x, y) => {
  element.block(
    id: "mcu", w: 10, h: 8, x: x, y: y,
    name: [MCU \ _Oliver_],
    ports: (
      west: (
        (id: "asig-in", name: ""),
        (id: "pwr-in", name: ""),
      ),
      north: ((id: "dsig-out", name: text(0.55em)[mcu_analog_dsig]),),
      south: (
        (id: "trig-comm", name: text(0.55em)[mcu_trigger_comm]), 
        (id: "trig-dsig-in", name: ""),
      ),
      east: ((id: "comm", name: text(0.55em)[mcu_backend_comm]),),
    ),
    fill: util.colors.blue
  )
}

#let backend-block = (x, y) => {
  element.block(
    id: "backend", w: 10, h: 8, x: x, y: y,
    name: [Backend \ _Elliot_],
    ports: (
      west: ((id: "comm", name: ""),),
      south: ((id: "data", name: text(0.55em)[backend_frontend_data]),),
    ),
    fill: util.colors.pink
  )
}

#let frontend-block = (x, y) => {
  element.block(
    id: "frontend", w: 10, h: 8, x: x, y: y,
    name: [Frontend \ _Elliot_],
    ports: (
      north: ((id: "data", name: ""),),
      south: ((id: "usrout", name: text(0.55em)[frontend_outside_usrout]),),
      west: ((id: "usrin", name: text(0.55em)[outside_frontend_usrin]),),
    ),
    fill: red.lighten(35%)
  )
}

#let system-diagram = circuit({
    // 1. PLACEMENT
    analog-block(0, 15)
    power-block(0, 0)
    mcu-block(22, 15)      
    trigger-block(22, 0)   
    backend-block(44, 15)  
    frontend-block(44, 0)   

    // 2. DIRECT STRAIGHT LINES
    wire.wire("in-ana", ((rel: (-3,0), to: "analog-port-asig-in"), "analog-port-asig-in"), directed: true)
    wire.wire("in-pwr", ((rel: (-3,0), to: "power-port-dc-in"), "power-port-dc-in"), directed: true)
    wire.wire("in-front", ((rel: (-3,0), to: "frontend-port-usrin"), "frontend-port-usrin"), directed: true)
    wire.wire("pwr-ana", ("power-port-dc-analog-out", "analog-port-pwr-in"), directed: true)
    wire.wire("back-front", ("backend-port-data", "frontend-port-data"), directed: true)
    wire.wire("tr-comm", ("mcu-port-trig-comm", "trigger-port-comm"), directed: true)
    wire.wire("tr-dsig", ("trigger-port-dsig-out", "mcu-port-trig-dsig-in"), directed: true)
    wire.wire("ana-mcu", ("analog-port-to-mcu", "mcu-port-asig-in"), directed: true)
    wire.wire("mcu-back", ("mcu-port-comm", "backend-port-comm"), directed: true)

    // 3. PERFECT MANHATTAN ROUTING

    // MCU -> Analog Feedback (TOP LOOP)
    let fb-y = 25
    wire.wire("fb1", ("mcu-port-dsig-out", (27, fb-y)))
    wire.wire("fb2", ((27, fb-y), (5, fb-y)))
    wire.wire("fb3", ((5, fb-y), "analog-port-dsig-in"), directed: true)

    // Power -> MCU (Rise Up)
    // Power East port at y=4. Elbow must be exactly y=4 for a horizontal segment.
    let p-elbow-x = 12
    wire.wire("pm1", ("power-port-dc-mcu-out", (p-elbow-x, 4))) 
    wire.wire("pm2", ((p-elbow-x, 4), (p-elbow-x, 16.5)))
    wire.wire("pm3", ((p-elbow-x, 16.5), "mcu-port-pwr-in"), directed: true)

    // Analog -> Trigger (Drop Down)
    // Analog East port 2 is at y=16.33 approx. Elbow must be y=16.33.
    let a-elbow-x = 15
    wire.wire("at1", ("analog-port-to-trig", (a-elbow-x, 16.33)))
    wire.wire("at2", ((a-elbow-x, 16.33), (a-elbow-x, 4)))
    wire.wire("at3", ((a-elbow-x, 4), "trigger-port-asig-in"), directed: true)

    // Output
    wire.wire("f-out", ("frontend-port-usrout", (rel: (0,-3), to: "frontend-port-usrout")), directed: true)
})

#set page(height: auto, width: auto, margin: 1cm)
#system-diagram