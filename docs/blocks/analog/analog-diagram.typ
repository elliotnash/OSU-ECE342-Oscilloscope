#import "@preview/cetz:0.3.2": draw
#import "@preview/circuiteria:0.2.0": *

#let analog-color = util.colors.green

// --- GLOBAL FONT SETTINGS ---
#let port-size = 10pt 
#let port-text(content) = text(size: port-size, content)
// Helper for rotated text
#let rotated-port(content) = rotate(-90deg, reflow: true, port-text(content))
// ----------------------------

// --- Sub-Block 1: Input Coupling ---
#let coupling-block = (x, y) => {
  element.block(
    id: "coupling",
    w: 10, h: 6, x: x, y: y,
    name: [Input Coupling \ & Protection \ (TLP3441)],
    ports: (
      // Rotated the West port label by 90 degrees
      west: ((id: "in", name: rotated-port([outside_analog_asig])),),
      east: ((id: "out", name: port-text([Buffered Sig])),),
      north: ((id: "ctrl", name: port-text([mcu_analog_dsig])),),
    ),
    fill: analog-color.lighten(60%)
  )
}

// --- Sub-Block 2: Gain Stage ---
#let gain-block = (x, y) => {
  element.block(
    id: "gain",
    w: 10, h: 6, x: x, y: y,
    name: [Prog. Gain Amp \ (OPA320 + ADG621)],
    ports: (
      east: ((id: "in", name: port-text([Buffered Sig])),),
      west: ((id: "out", name: port-text([Amplified Sig])),),
      north: ((id: "ctrl", name: port-text([mcu_analog_dsig])),),
      south: ((id: "pwr", name: port-text([power_analog_dcpwr(vsys)(1v65)(-1v65)])),) 
    ),
    fill: analog-color.lighten(40%)
  )
}

// --- Sub-Block 3: Level Shifter ---
#let shifter-block = (x, y) => {
  element.block(
    id: "shifter",
    w: 10, h: 6, x: x, y: y,
    name: [Level Shifter \ & AA Filter \ (OPA320)],
    ports: (
      west: ((id: "in", name: port-text([Amplified Sig])),),
      east: (
        (id: "adc-out", name: port-text([analog_mcu_asig])),
        (id: "trig-out", name: port-text([analog_trigger_asig]))
      ),
      south: ((id: "ref", name: port-text([power_analog_dcpwr(vsys)(1v65)(-1v65)])),)
    ),
    fill: analog-color.lighten(20%)
  )
}

#let analog-internal-diagram = circuit({
  coupling-block(0, 20)
  gain-block(0, 10)
  shifter-block(0, 0)

  // Wiring and Labels
  wire.wire("path1", ("coupling-port-out", "gain-port-in"), directed: true)
  wire.wire("path2", ("gain-port-out", "shifter-port-in"), directed: true)
  wire.wire("input", ((rel: (-2.5, 0), to: "coupling-port-in"), "coupling-port-in"), directed: true)
  wire.wire("out-adc", ("shifter-port-adc-out", (rel: (2.5, 0), to: "shifter-port-adc-out")), directed: true)
  wire.wire("out-trig", ("shifter-port-trig-out", (rel: (2.5, 0), to: "shifter-port-trig-out")), directed: true)

  wire.wire("ctrl-acdc", ((rel: (0, 2), to: "coupling-port-ctrl"), "coupling-port-ctrl"), directed: true)
  wire.wire("ctrl-gain", ((rel: (0, 2), to: "gain-port-ctrl"), "gain-port-ctrl"), directed: true)

  wire.wire("pwr-gain", ((rel: (0, -2), to: "gain-port-pwr"), "gain-port-pwr"), directed: true)
  wire.wire("pwr-shift", ((rel: (0, -2), to: "shifter-port-ref"), "shifter-port-ref"), directed: true)

})

#figure(
  scale(80%, reflow: true, analog-internal-diagram), 
  caption: [Block 1 Internal Design Diagram]
) <block-1-diagram>