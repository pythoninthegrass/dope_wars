# Architecture

Four layers, one direction of dependency:

```text
game/  ->  extension/  ->  include/dopewars.h  ->  core/
```

Nothing depends upward and nothing skips a layer. The split mirrors
`~/git/jumpnbump/` (Zig core / C ABI / C++ GDExtension / GDScript game) with
Mojo swapped in for Zig. `docs/layer-boundaries.md` is the enforced rulebook
for what each layer may and may not do; this document is the map of what each
layer *is* and how a call travels through the stack. `docs/abi-contract.md`
covers the header's own conventions (opaque handle, two-call length-then-fill,
versioning).

## The four layers

- **`core/` — Mojo simulation.** The whole rulebook: RNG, pricing, trading,
  travel, arrival events, dealer offers, chase/combat, scoring, serialization.
  Pure computation over a caller-owned `dw_world` handle. Zero Godot imports,
  zero FFI imports, no file I/O, no global mutable state outside the handle.
  `core/src/abi.mojo` is the only file that declares `@export` symbols; every
  other module under `core/src/` (`world.mojo`, `prices.mojo`, `trade.mojo`,
  `travel.mojo`, `events.mojo`, `dealers.mojo`, `combat.mojo`, `finances.mojo`,
  `score.mojo`, `serialize.mojo`, `rules.mojo`, `rng.mojo`, `jsmath.mojo`,
  `floatbits.mojo`, `result.mojo`) implements one slice of it. This is where
  `<script id="engine">` (`index.html:609-1079`) ends up.
- **`include/dopewars.h` — the frozen C ABI.** The single cross-language
  contract; no other file in `core/` or `extension/` is a public surface.
  Opaque caller-owned `dw_world` handle (the caller allocates
  `dw_world_size()` bytes and calls `dw_world_init`), `dw_result` return
  codes, `uint8_t`-typedef'd kind enums, `DW_STATIC_ASSERT` on every struct
  sizeof, two-call length-then-fill for every variable-length buffer.
  `DW_ABI_VERSION` (currently 2 — see "ABI version history" below) bumps on
  breaking changes only; additive changes don't bump it.
- **`extension/` — C++ GDExtension shim.** 1:1 forwarding from ABI functions
  to a Godot class (`DopeWarsWorld`, registered in
  `extension/src/register_types.cpp`). No game logic — pricing, event odds,
  combat rolls, scoring: none of it lives here. No state beyond the
  `dw_world` storage and transient marshalling scratch (`Dictionary`,
  `PackedByteArray` conversions). No translation of ABI error codes into
  human-readable strings; it passes structured codes up and GDScript renders
  them.
- **`game/` — Godot / GDScript presentation.** Never imports Mojo directly,
  never duplicates core state, never computes a game rule. Where
  `<script id="ui">` (`index.html:1081-1710`) ends up. Four sub-layers, with
  dependency direction `presentation`/`platform`/`content` -> `simulation` ->
  `extension`:
  - `game/simulation/world.gd` (`class_name SimWorld`) — the *only* `.gd` file
    allowed to name `DopeWarsWorld`. A complete pass-through: every bound
    method forwards to exactly one extension method, plus all 32 `DW_*`
    constants re-exported so nothing outside this file needs to name the
    extension class.
  - `game/presentation/` — `main.tscn` + `main.gd` (the only scene; the tree
    is assembled in code), the HUD, market/coat/inventory tables, the dialog
    layer, and `arrival_flow.gd` (the post-travel event queue).
  - `game/platform/` — `input_router.gd` (keyboard -> intent), `save_store.gd`
    (`user://dopewars.save`, the core's opaque byte dump), `highscore_store.gd`
    (`user://dopewars.highscores.json`).
  - `game/content/` — palette, Win98 theme factory, and every `tr()` key. Not
    the drug/borough tables — those come from `SimWorld.rules_drugs()` /
    `rules_locations()`.

  `game/README.md` documents the layer rules in full;
  `tools/validate_game_boundary.py` (`task game:boundary-check`) enforces the
  `simulation/`-only boundary mechanically.

## Data flow: a buy call from keypress to redraw

```text
 keyboard event
       |
       v
 game/platform/input_router.gd      classify() -> intent (pure, testable)
       |
       v
 game/presentation/*.gd             dialog reads quantity, calls SimWorld
       |
       v
 game/simulation/world.gd           SimWorld.buy(drug, qty)
       |                             (the only .gd file naming DopeWarsWorld)
       v
 extension/src/dopewars_world.cpp   DopeWarsWorld::buy()
       |                             marshals GDScript args -> C types
       v
 include/dopewars.h                 dw_buy(dw_world*, ...)
       |                             the frozen ABI call
       v
 core/src/trade.mojo (via abi.mojo) mutates dw_world's cash/inventory fields,
       |                             returns a dw_result code
       v
 extension/src/dopewars_world.cpp   translates dw_result -> Godot Error /
       |                             Dictionary
       v
 game/simulation/world.gd           returns the result to the caller
       |
       v
 game/presentation/*.gd             re-reads state_get() / inventory_copy(),
                                     redraws the HUD and tables
```

Every read is a re-read: `game/presentation/` holds no mirrored copy of world
state between frames (the two selected-drug indices and a last-day-warning
flag are the only UI-only state, and neither has a counterpart in the world).
The call travels down through exactly one layer at a time and the result
travels back up the same path; nothing short-circuits a layer in either
direction.

## ABI version history

- **v1** — initial frozen surface (TASK-001.02 through TASK-001.06).
- **v2** — bumped by TASK-009 (`ca55d79`, "apply beermat-verified engine
  constants"): `bankInterest` 0.02 -> 0.05, the `startChase` deputy-count
  formula changed from day-scaled to `randInt(2, 11)` (now consumes an RNG
  draw it previously didn't), and the Ecstasy/Smack price bounds changed.
  These are breaking changes to values a caller may have cached, hence the
  bump rather than an additive change. See `docs/abi-contract.md`'s
  Versioning section for the policy, and `docs/parity-deltas.md` for the
  deltas against the JS prototype these constants correct.

## Mojo LOC share

`task loc` (`scripts/loc.sh`) reports non-vendor, non-generated SLOC by
language. Measured 2026-09-28:

```text
Mojo (core/src/)                   1948
Mojo (tests/mojo/)                 1115
C++ (extension/)                    690
C headers (include/)                228
GDScript (game/)                   3526
Python (scripts/)                  1351
JS harness (tests/*.mjs)           1103
Shell (scripts/)                    103
YAML (taskfiles)                    353
index.html (JS oracle + UI)        1500
TOTAL                             11917
Mojo % of non-vendor SLOC: 25.70%   (target >= 43%)
```

This misses the flat 43% target measured against the whole repo, and it will
keep missing it: the denominator includes `game/`'s 3526 GDScript lines, and
`docs/layer-boundaries.md` forbids game rules in GDScript while `core/` may
contain no Godot import — no line of the presentation layer can legally move
to Mojo. Scoped instead to the simulation stack the ratio is meant to compare
(`core/` + `include/` + `extension/`, excluding the harness in
`tests/mojo/`), Mojo is `1948 / (1948 + 228 + 690) = 67.97%` of that stack,
comfortably past parity with Jump'n'Bump's Zig share. `index.html` (1500
lines) is deleted at the end of TASK-001 and will shrink out of the
whole-repo denominator once that lands, which raises the flat ratio but does
not change this conclusion.
