#let project(title: "", authors: (), team-number: "", body) = {
  // Set the document's basic properties.
  set document(author: authors.values().map(a => a.at("name")), title: title)
  set page(
    paper: "us-letter",
    numbering: "1",
    number-align: center,
    header: [
      #authors.values().map(a => a.at("name") + " " + a.at("id")).join("\n")
      \
      #team-number
    ],
    header-ascent: 2em,
    margin: (top: 10em)
  )
  set text(font: "Libertinus Serif", lang: "en")

  v(6em)
  
  // Title row.
  align(center)[
    #block(text(weight: 700, 2.5em, title))
  ]

  // Main body.
  set par(justify: true)
  show figure: set block(breakable: true)
  
  // align(center + horizon, )

  align(center + horizon)[
    #move(image("images/OscopeBoard.png", width: 111%), dx: 5pt)
    #move(image("images/OscopeCaseTop.png", width: 100%), dy: -30pt)
  ]

  colbreak()

  show highlight: it => {
    show math.equation: box.with(fill: rgb("#fffe69"))
    it
  }

  body
}

#let block-project(title: "", authors: (), team-number: "", body) = {
  // Set the document's basic properties.
  set document(author: authors.values().map(a => a.at("name")), title: title)
  set page(
    paper: "us-letter",
    numbering: "1",
    number-align: center,
    // header: [
    //   #authors.values().map(a => a.at("name") + " " + a.at("id")).join("\n")
    //   \
    //   #team-number
    // ],
    // header-ascent: 2em,
    // margin: (top: 10em)
  )
  set text(font: "Libertinus Serif", lang: "en")

  // Title row.
  align(center)[
    #block(text(weight: 700, 1.75em, title))

    #authors.values().map(a => a.at("name") + " " + a.at("id")).join("\n")

    #v(0em)

    #team-number

    #v(0.5em)
  ]

  // Main body.
  set par(justify: true)
  show figure: set block(breakable: true)

  body
}

#let TODO = (body) => text(fill: red, body)

#let i2c = [I#super[2]C]
