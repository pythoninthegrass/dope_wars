# dope_wars

Research and planning for a Godot reference implementation of Dope Wars. See `AGENTS.md` for the source documents and how they're weighted.

## Playable prototype

`index.html` is a single-file, no-build-step, no-dependency playable prototype, true to the spirit of Beermat Software's "Dope Wars for Windows" 1.2.0.0 (1999), with the Keymash web port (<https://keymash.com/games/dopewars/>) as the close reference implementation. Ruleset details and citations are documented inline in the `#engine` script block.

Open it directly from disk:

```sh
open index.html            # macOS
xdg-open index.html        # Linux
```

Append `?seed=<number>` to the URL for a reproducible run (e.g. `index.html?seed=1`).

Keyboard shortcuts: `1`-`6` travel to a borough, `B`/`S`/`F` for Buy/Sell/Finances, `N` for New Game, `Enter`/`Esc` confirm/cancel the focused dialog.

The game logic lives in `<script id="engine">` and is DOM-free by design — it's the near-1:1 reference the eventual GDScript port should match. `<script id="ui">` handles rendering and input only.

### Running the tests

```sh
node --test tests/engine.test.mjs
```

The test file extracts `#engine` from `index.html` and evaluates it in `node:vm`, so it tests exactly what ships in the page — no separate module to drift out of sync.

### Deliberately out of scope for this pass

- The Godot port itself (macOS/Linux/Windows desktop + wasm web build).
- Sound.
- Beermat's Discord menu button (Keymash-specific, dropped).
- Server-authoritative multiplayer / leaderboards — high scores are local-only (`localStorage`).
