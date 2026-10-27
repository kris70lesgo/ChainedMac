# REA observations — ChainYourMac reference

The public [ChainYourMac page](https://chainyourmac.com/) was inspected in the browser. REA CLI 6.7.0 then parsed its first-party `app.js` bundle as inert JavaScript; it did not execute the page or contact the reference service from the analysis process.

- Evidence ID: `ev_06a24b0e40ccde0e0a023e883d7c74b8e6c532d2376d5cfa120221d4f624c47a`
- Analyzed source SHA-256: `92f9d3c25fa1fb83d6f5d7a67e19d28e32f77180abadcbed8622f577af5dd65d`
- Main observed model: each strip contains columns; a column can hold multiple windows, a width fraction, a selected row, and a tabbed state.
- Main observed actions in `Strip.act`: focus left/right, reorder left/right, cycle/full width, center, stack/pop out, and toggle tabs (`app.js`, approximately lines 300–380).
- Pointer and wheel handlers implement title-bar reordering and horizontal strip travel (`app.js`, approximately lines 485–570).
- The inspected page presents a native SwiftUI frontend and Rust engine as the product architecture. No native app source or binary was available to analyze.

REA reported that this was a partial static analysis: two inventoried files were outside the selected source scope, JavaScript was parsed without execution, and dynamic paths remained unresolved. It found no Electron window, IPC, or native-addon architecture in the selected website bundle. Those limits mean the browser demo supports the interaction notes above, but does not establish how the reference's separate Mac application works internally.

This repository is an independent macOS and Windows desktop implementation, plus a standalone HTML landing page and browser-only simulator. Its implementation details, release process, and v1 scope are described in the root README.
