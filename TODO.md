# TODO

## Playable index.html (done, this pass)

- [x] Engine (`#engine`): rules table, seeded RNG, buy/sell, travel, finances, arrival events, cop chase/combat, finish + high scores.
- [x] Node tests (`tests/engine.test.mjs`) covering the above.
- [x] UI (`#ui`): Win95-styled game window, fluid/responsive layout, modal dialogs, keyboard shortcuts.

## Not done yet

- [ ] Godot port (macOS first, then Linux/Windows desktop, then wasm web build).
- [ ] Sound.
- [ ] Antique-mode ruleset (8 boroughs / 12-drug benmwebb set, Loan Shark + Bank + Gun Shop + Rough Pub locations, hired-help mechanics) — currently only the Keymash/Beermat 6-borough ruleset is implemented.
- [ ] Difficulty/gun variety (Keymash's Gun Dealer sells one undifferentiated gun; `docs/gameplay.md` documents 4 distinct stock guns and 3 cop tiers that could be modeled later).
