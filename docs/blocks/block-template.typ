#import "../block-diagram.typ": *
#import "../template.typ": *
#import "../authors.typ": authors

#show: block-project.with(
  title: [Dual Channel RP2350 USB Oscilloscope],
  authors: authors,
  team-number: "Team Number: 15"
)

#outline(title: none)

#pagebreak()

= Top-Level Architecture Block Diagram <top-level-architecture-block-diagram>

#figure(scale(system-diagram, reflow: true, 80%), caption: [Top-Level Architecture Block Diagram]) <tla-block>

= Block 1 Video Link <block-1-video-link>
#TODO[{Create a record of your block working even if you plan to retest and improve the design. Update this link with the most-recent working verification process. The expectation is you iterate on your designs, but keeping a record will ensure you can show \*something\* to the instructional team even if everything falls apart at the last minute. This will be your backup verification if something goes wrong or breaks between design, build, and final block testing. Make sure the instructional team has access to view the video.}]

= Block 1 Description <block-1-description>
#TODO[{Create a block diagram of your individual block. Write a detailed description of #emph[what your block does];. What is its role in the system? How does its role relate to the overall system requirements? What is coming into the block? What does the block do to that input? What is created and then delivered as an output? This is where your deep dive into functionality goes. Make sure to include the names and functions of all interfaces related to this block and that they match your top-level architecture above.}]

= Block 1 Design Details <block-1-design-details>
#TODO[{Write a detailed description of #emph[how your block works];. Demonstrate your learning by explaining clearly what the inputs are and where they come from. Explain how those inputs become outputs through your block. Design details must include in-text citations in IEEE format. Cite resources from prior coursework, module resources lists from this class, or resources you have found externally.}]

= Block 1 Interface Validation <block-1-interface-validation>

#figure(table(
  columns: 3,
  table.header(
    [*Interface Property*],
    [*Why is this interface this value?*],
    [*How do you know your design details will meet or exceed this property? Cite your sources in IEEE.*]
  ),
  
  table.header(level: 2, table.cell(colspan: 3)[*#TODO[interface_name: Input]*]),
  [#TODO[Property 1]],
  [#TODO[{Fill in each section of this table. Include citations, simulation results, calculations, and validation materials in each column that address the column prompt above.}]],
  [...],
  
  [#TODO[Property 2]],
  [...],
  [...],

  [#TODO[Property 3]],
  [#TODO[{Make sure you have a minimum of three properties per interface.}]],
  [...],

  
  table.header(level: 2, table.cell(colspan: 3)[*#TODO[interface_name: Output]*]),
  [#TODO[Property 1]],
  [#TODO[{Fill in each section of this table. Include citations, simulation results, calculations, and validation materials in each column that address the column prompt above.}]],
  [...],
  
  [#TODO[Property 2]],
  [...],
  [...],

  [#TODO[Property 3]],
  [#TODO[{Make sure you have a minimum of three properties per interface.}]],
  [...],
))

= Block 1 Verification Process <block-1-verification-process>

#TODO[
  + {Enumerate a verification process here that any junior in the class could follow.

  + Be as specific and expository as possible and #emph[demonstrate each interface property] from the validation table. Imagine this process will be handed to another team to complete who did not design your system.
  
  + Write instructions they could follow.}
]

= Block 1 Artifacts <block-1-artifacts>
#TODO[{Populate this section with the miscellaneous but important findings that got you to your final block design. This means anything you had to learn in order to make choices about your design details. This might be prior coursework, examples found online, reference schematics, pseudocode, previous or prior version block diagrams, etc. Think of this section as a repository of your progress on this block. Do not include what is in your design details.}]

= Block 1 Future Recommendations <block-1-future-recommendations>
#TODO[{This was a lot of work. Take some time to reflect on how far you have come from starting to understand the design process last term, to creating a novel block for a unique, custom system. What went well? What would you tell yourself at the beginning of the term given what you know now?}]

= Block 1 References <block-1-references>
#TODO[
  + Include all relevant IEEE citations here. Be sure to cite them within the text. To get help with this you can search for “IEEE in-text citations” to understand how to cite in-text.

  + Cite everything you did not create yourself for this document. This includes but is not limited to diagrams, schematics, pseudocode/code, pinout visuals, etc.
]

#TODO[Uncomment this to use references for this block]
// #bibliography("./my-block-references.yaml")

= Block 2 Video Link <block-2-video-link>
#TODO[{Create a record of your block working even if you plan to retest and improve the design. Update this link with the most-recent working verification process. The expectation is you iterate on your designs, but keeping a record will ensure you can show \*something\* to the instructional team even if everything falls apart at the last minute. This will be your backup verification if something goes wrong or breaks between design, build, and final block testing. Make sure the instructional team has access to view the video.}]

= Block 2 Description <block-2-description>
#TODO[{Create a block diagram of your individual block. Write a detailed description of #emph[what your block does];. What is its role in the system? How does its role relate to the overall system requirements? What is coming into the block? What does the block do to that input? What is created and then delivered as an output? This is where your deep dive into functionality goes. Make sure to include the names and functions of all interfaces related to this block and that they match your top-level architecture above.}]

= Block 2 Design Details <block-2-design-details>
#TODO[{Write a detailed description of #emph[how your block works];. Demonstrate your learning by explaining clearly what the inputs are and where they come from. Explain how those inputs become outputs through your block. Design details must include in-text citations in IEEE format. Cite resources from prior coursework, module resources lists from this class, or resources you have found externally.}]

= Block 2 Interface Validation <block-2-interface-validation>

#figure(table(
  columns: 3,
  table.header(
    [*Interface Property*],
    [*Why is this interface this value?*],
    [*How do you know your design details will meet or exceed this property? Cite your sources in IEEE.*]
  ),
  
  table.header(level: 2, table.cell(colspan: 3)[*#TODO[interface_name: Input]*]),
  [#TODO[Property 1]],
  [#TODO[{Fill in each section of this table. Include citations, simulation results, calculations, and validation materials in each column that address the column prompt above.}]],
  [...],
  
  [#TODO[Property 2]],
  [...],
  [...],

  [#TODO[Property 3]],
  [#TODO[{Make sure you have a minimum of three properties per interface.}]],
  [...],

  
  table.header(level: 2, table.cell(colspan: 3)[*#TODO[interface_name: Output]*]),
  [#TODO[Property 1]],
  [#TODO[{Fill in each section of this table. Include citations, simulation results, calculations, and validation materials in each column that address the column prompt above.}]],
  [...],
  
  [#TODO[Property 2]],
  [...],
  [...],

  [#TODO[Property 3]],
  [#TODO[{Make sure you have a minimum of three properties per interface.}]],
  [...],
))

= Block 2 Verification Process <block-2-verification-process>
#TODO[
  + {Enumerate a verification process here that any junior in the class could follow.

  + Be as specific and expository as possible and demonstrate each interface property from the validation table. Imagine this process will be handed to another team to complete who did not design your system.

  + Write instructions they could follow.}
]

= Block 2 Artifacts <block-2-artifacts>
#TODO[{Populate this section with the miscellaneous but important findings that got you to your final block design. This means anything you had to learn in order to make choices about your design details. This might be prior coursework, examples found online, reference schematics, pseudocode, previous or prior version block diagrams, etc. Think of this section as a repository of your progress on this block.}]

= Block 2 Future Recommendations <block-2-future-recommendations>
#TODO[{You have completed the individual technical challenges in this course. Take some time to reflect on how far you have come. How was this different from the Block 1 design cycle? What resources and skills did you utilize to improve during this second design-cycle? What would you tell yourself at the beginning of the term given what you know now? How will you use what you learned in this round in future classes or internships?}]

= Block 2 References <block-2-references>
#TODO[
  + Include all relevant IEEE citations here. Be sure to cite them within the text. To get help with this you can search for “IEEE in-text citations” to understand how to cite in-text.

  + Cite everything you did not create yourself for this document. This includes but is not limited to diagrams, schematics, pseudocode/code, pinout visuals, etc.
]

#TODO[Uncomment this to use references for this block]
// #bibliography("./my-block-references.yaml")
