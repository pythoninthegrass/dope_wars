# dope_wars

A Godot reference implementation of Dope Wars — a Mojo simulation core behind a frozen C ABI (`include/dopewars.h`), a C++ GDExtension shim (`extension/`), and a GDScript presentation layer (`game/`). See `AGENTS.md` for the architecture, source documents, and build/test runbook.

`index.html` is a single-file playable web prototype (`open index.html`), true to Beermat Software's "Dope Wars for Windows" 1.2.0.0 (1999), and the near-1:1 reference the Godot port is verified against.

## Minimum requirements

- macOS 13+ or Linux (x86_64 or arm64)
- [`mise`](https://mise.jdx.dev/) — installs every pinned tool from `.tool-versions` (Godot, Python, Node, uv, Task, SConstruct, Mojo via uv)

```sh
mise install
git submodule update --init --recursive
```

## Recommended

- Godot editor at the pinned version (`.tool-versions`) for scene and resource editing
- VS Code or Cursor with the [godot-tools extension](https://marketplace.visualstudio.com/items?itemName=geequlim.godot-tools) for GDScript LSP

## Quickstart

Build the full stack (Mojo core → GDExtension shim) and launch the game:

```sh
task run
```

`task check` runs the full gate set: parity tests, static ABI gates, conformance drivers, bridge tests, presentation tests, and a headless Godot smoke test.

`task dev` watches `core/src/`, `include/`, `extension/src/`, and `game/` and restarts `task run` on every change.

<!--
Pre-built releases are available on the [releases page](https://github.com/pythoninthegrass/dope_wars/releases).
Download the archive for your platform, unzip, and run the `dope_wars` binary.
-->

## Credits

- [Beermat Software](https://www.beermatsoftware.com/dopewars/): first iteration of Drug Wars I played and modeled this repo after!
- [TI-83+](https://www.wired.com/story/history-drug-wars-calculator-game/): along with a simple SMB clone, the BASIC version of Drug Wars was a great distraction during AP Calc
- [Drug Wars](https://en.wikipedia.org/wiki/Drug_Wars_(video_game)): OG by John E. Dell
- [DSEG](https://github.com/keshikan/DSEG) by keshikan: the Godot HUD's LED value font (`game/assets/fonts/dseg7-classic/`), SIL Open Font License 1.1
- [Oldschool PC Font Pack](https://int10h.org/oldschool-pc-fonts/) by VileR: the Godot HUD's LED label font, Px437 IBM VGA 8x16 (`game/assets/fonts/px437-ibm-vga/`), CC BY-SA 4.0
- [Dong Gyu Yang Avatar - Syringe Icon](https://thenounproject.com/icon/syringe-8463548/)
