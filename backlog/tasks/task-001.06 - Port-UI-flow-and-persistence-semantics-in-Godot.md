---
id: TASK-001.06
title: Port UI flow and persistence semantics in Godot
status: Done
assignee: []
created_date: '2026-09-26 04:34'
updated_date: '2026-09-28 01:06'
labels:
  - godot
  - migration
  - parity
milestone: m-3
dependencies:
  - TASK-001.05
references:
  - ~/git/jumpnbump/game/presentation/
  - ~/git/jumpnbump/tools/validate_game_boundary.py
  - ~/git/jumpnbump/game/README.md
documentation:
  - index.html
  - AGENTS.md
parent_task_id: TASK-001
priority: high
ordinal: 6000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Implement the Godot presentation layer in GDScript, recreating all player-facing UI flows from `<script id="ui">` (lines 1081-1710 of `index.html`). All game state lives in the Mojo core; GDScript is responsible only for rendering, input routing, and persistence orchestration.

**Layer structure (mirrors `~/git/jumpnbump/game/`):**
- `game/simulation/` — the only layer allowed to reference the GDExtension class `DopeWarsWorld`
- `game/presentation/` — UI scenes, drug/coat tables, status LEDs, dialog overlays
- `game/platform/` — input routing, settings persistence, app lifecycle
- `game/content/` — data-driven config (drug definitions, borough names, tuning constants)

**Key UI flows to port (all state-mutation calls must go through `simulation/`):**
- Main game HUD: cash/bank/debt/guns LEDs, health bar, drug market table, inventory table, travel panel
- Buy/sell dialogs with quantity input (bidirectional selection sync between buy and sell tables)
- Finances dialog (deposit/withdraw/pay loan)
- Arrival event display (mugged/freeDrugs/dogChase/mamasBrownies/freeWeedDeath/flavor messages)
- Chase/combat dialog (run or fight loop, deputy count, damage messages)
- Coat dealer and gun dealer offer dialogs
- End-of-game score screen and highscore display

**Persistence:** replace `localStorage` with `FileAccess` to `user://dopewars.save` and `user://dopewars.highscores.json`.

Reference: `~/git/jumpnbump/game/` for scene/script layering and boundary-check tooling.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 All player-facing flows are implemented: new game, buy/sell with quantity selection, travel with arrival-event display, finances dialog (deposit/withdraw/pay loan), coat-dealer and gun-dealer dialogs, chase/combat (run/fight loop), and end-of-game score screen with highscore entry
- [x] #2 Keyboard shortcuts work: 1-6 travel, B/S/F buy/sell/finances, N new game, Enter/Esc confirm/cancel (matching index.html keyboard handling)
- [x] #3 Save/load on travel and highscores persistence match JS prototype semantics: auto-save on travel (index.html:1541), load on boot (index.html:1546), top-10 highscores (index.html:1561); stored in Godot user:// instead of localStorage
- [x] #4 No simulation logic appears in GDScript: all game-state mutations go through the GDExtension class; a boundary check script fails if any .gd file outside simulation/ references the GDExtension class fields directly
- [x] #5 Regression tests cover: new game boots and renders prices; buy/sell round-trip updates UI state; travel advances day and shows arrival event; persistence round-trips a mid-game save
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
## Gap analysis (done before planning)

Read `index.html:1081-1710` (the `<script id="ui">` block) and mapped every call onto the
registered GDExtension surface. Three things the prototype's UI layer reads that the
frozen ABI does not expose:

1. **`state.prevPrices`** — the market table's ▲/▼ trend glyph (index.html:1176-1184). The
   core *holds* `prev_price_value` / `prev_price_present` / `prev_price_order`
   (`core/src/world.mojo:78-82`) and serializes them (`core/src/serialize.mojo:137-141`),
   but no ABI function exposes them.
2. **The two `state.rng() < 0.15` dealer-visit rolls** (index.html:1387-1388). The draw
   lives in the JS *UI* layer but off the *world* RNG. GDScript cannot draw from the
   world's stream (`docs/abi-contract.md:95-98`) and cannot read the seed back
   (`dw_config.rng_seed` is write-only). Per `docs/layer-boundaries.md:104-105` this is a
   game rule and may not live in GDScript.
3. **`dw_highscore_entry` has no date field** — the prototype's Date column
   (index.html:1594) has nowhere to live in the ABI.

Also noted: `last_day_warned` is readable but not writable through the ABI (the JS UI
mutates it directly at index.html:1159). GDScript keeps it as UI-only state, which
`docs/layer-boundaries.md:100-101` explicitly permits, seeded from `state_get()` on load.

Decisions (Lance, this session): (1) add two additive ABI functions; (2) rewrite the two
existing bridge tests onto `SimWorld` so the boundary rule needs no test exclusion;
(3) keep the Date column as platform-layer metadata in the JSON, re-attached by tuple
match.

## Step 1 — two additive ABI functions (54 -> 56, no `DW_ABI_VERSION` bump)

`include/dopewars.h`:
- `dw_prev_prices_copy(const dw_world *, dw_price_slot *out, size_t cap, size_t *out_required)`
  — exact mirror of `dw_prices_copy` (include/dopewars.h:512) over `prev_price_*`. The
  drug set traded last turn need not match this turn's, so callers intersect.
- `dw_roll_dealer_visits(dw_world *, uint8_t *out_coat_visit, uint8_t *out_gun_visit)`
  — one call, both draws, in the order the turn produces them. Single call so the
  presentation layer cannot get the draw order wrong. The `!state.dead` guard in
  index.html:1387-1388 is evaluated *after* the draw (JS short-circuit), so the draw is
  consumed unconditionally and only the reported value is suppressed when dead.

`core/src/dealers.mojo`: `roll_dealer_visits(mut game) -> (Bool, Bool)` — the only place
the 15% constant lives.

`core/src/abi.mojo`: two `@export` functions modelled on `dw_prices_copy`
(core/src/abi.mojo:626-650) and the existing dealer exports (:865-930). Still the only
`@export` source (holds `task abi:check`).

`extension/src/dopewars_world.{hpp,cpp}`: `prev_prices_copy()` and `roll_dealer_visits()`
bound alongside the existing forwards; two more `BIND_CONSTANT`-free methods.

Both take pointer out-params, so `tools/gen_bridge_expectations.py` filters them out of
`bridge_expectations.gd` (`not d.takes_pointer`) — the generated file should not change;
`task gen:bridge-expectations:check` proves that rather than assuming it.

Docs: `docs/abi-contract.md` gains the two functions; the "54 declarations" counts in
`AGENTS.md:51`, `docs/mojo-1.1.0-abi-constraints.md:13,145` and
`core/abitest/abi_conformance_test.py:148` become 56.

`core/abitest/abi_conformance_test.py` derives its ctypes prototypes from the header, so
it picks both up with no hand-maintained table to edit.

## Step 2 — `game/simulation/` — the wrapper (AC#4's exception)

`game/simulation/world.gd`, `class_name SimWorld extends RefCounted`. The **only** `.gd`
file that names `DopeWarsWorld`. A complete pass-through: all 52 currently-registered
methods plus the two new ones, and all 31 `BIND_CONSTANT`s re-exported as named `const`s
(so callers never name `DopeWarsWorld` merely to compare a result code), modelled on
`~/git/jumpnbump/game/simulation/world.gd`. No logic — each method forwards to exactly
one extension method.

## Step 3 — `game/platform/`

- `save_store.gd` — `user://dopewars.save`, raw `PackedByteArray` from `world_dump()` /
  into `world_load()`. Semantics mirror index.html:1539-1553: a corrupt or
  length-mismatched load deletes the file and returns null (the core validates, so this
  is strictly tighter than the JS, which never validated).
- `highscore_store.gd` — `user://dopewars.highscores.json`, a JSON array of
  `{name, score, day, dead, date}`. Ordering and top-10 truncation come from
  `SimWorld.insert_highscore()`; the platform re-attaches dates by matching the
  `(name, score, day, dead)` tuple, falling back to `""`. Parse failure yields `[]`
  (index.html:1559-1563). The date is wall-clock metadata, not a game fact, so it never
  enters the ABI.
- `input_router.gd` — keyboard -> intent. `classify(event) -> StringName` is a pure
  static function (jumpnbump's `compute_masks` precedent) so the shortcut table is
  unit-testable without a live Input singleton. Intent set: `travel_0..travel_5`, `buy`,
  `sell`, `finances`, `new_game`, `confirm`, `cancel`. A dialog host, when open,
  consumes `confirm` / `cancel` and the HUD never sees them (index.html:1676-1698).
  Enter still confirms while a `SpinBox` / `LineEdit` has focus, matching the HTML form
  behaviour the JS gets for free.
- `app_lifecycle.gd` — owns the `state_changed` -> autosave subscription (index.html:1163
  saves at the end of every `render()`), and the exit action.

## Step 4 — `game/content/`

Presentation data only. **The drug and location tables are *not* duplicated here** — they
come from `SimWorld.rules_drugs()` / `rules_locations()`, and a second copy would be both
a rule computation and a second source of truth. The task description lists "drug
definitions, borough names, tuning constants" for this layer; I am putting the
*display* half there instead.

- `palette.gd` — the `:root` custom properties from index.html:8-24 as named constants.
- `copy.gd` — every display string behind `tr()`, plus `fmt()` (index.html:1085,
  round-and-comma). Formats the arrival-event payloads into the prototype's sentences
  (index.html:869-927) from the structured `dw_arrival_event` fields — `damage != 0`
  selects the "They beat you up instead" mugging branch, `amount` the dollar-loss branch.
- `win95_theme.gd` — a static `build() -> Theme` factory producing the outset/inset
  StyleBoxFlats and the titlebar gradient. Built in code, not a hand-written `.tres`,
  matching the reference repo's "everything assembled in code" convention.

## Step 5 — `game/presentation/`

`main.tscn` stays a single node with a script; the tree is assembled in code.

- `main.gd` — composition root. Owns the `SimWorld`, the stores, the flow controller, and
  the dialog host; wires the four layers together and boots (load save, else new game,
  index.html:1700-1706).
- `hud.gd` — titlebar, cash/bank/debt/guns LEDs, health bar, travel panel, borough
  buttons, action row, both table columns, footer.
- `market_table.gd` / `coat_table.gd` — the two tables. `market_table` intersects
  `prices_copy()` with `prev_prices_copy()` for the trend glyph; `coat_table` wears the
  `unavailable` styling when a held drug is not traded here (index.html:1205) and drives
  the bidirectional buy/sell selection sync (index.html:1186-1190, 1207-1211).
- `dialog_host.gd` — exactly one modal at a time; exposes `confirm` / `cancel` actions so
  the input router has a uniform target. Replaces the JS `openDialog` / `closeDialog` plus
  its `querySelector('[id$=...]')` key handling with real named actions.
- `dialogs/alert_dialog.gd`, `quantity_dialog.gd`, `finances_dialog.gd`,
  `dealer_dialog.gd` (coat + gun, one shape), `chase_dialog.gd`, `highscore_dialog.gd`,
  `scores_dialog.gd`, `new_game_dialog.gd`.
- `arrival_flow.gd` — the post-travel queue as an explicit state machine instead of the
  JS closure recursion (index.html:1378-1470). Enqueues price-event toasts, the arrival
  event, and the two dealer visits; the chase short-circuits both (index.html:1382-1383).
  Chase `was_aggressor` is passed as `false` throughout, exactly as the prototype always
  does (index.html:1474, 1499, 1506, 1511, 1523).

Every display re-reads `state_get()` / `prices_copy()` / `inventory_copy()` at render
time. Nothing caches world values in a GDScript field — `docs/layer-boundaries.md:102-103`.

## Step 6 — the boundary gate (AC#4)

`tools/validate_game_boundary.py`, a direct port of
`~/git/jumpnbump/tools/validate_game_boundary.py` with `DopeWarsWorld` substituted:
scans every `game/**/*.gd` outside `game/simulation/` (excluding `addons/`, `.godot/`,
`reports/`) for `\bDopeWarsWorld\b`, allowing only
`ClassDB.class_exists("DopeWarsWorld")` as a registration canary. Plus
`tools/test_validate_game_boundary.py` (the 79-line self-check from the reference repo:
one fixture that must fail, one clean, one canary, one inside `simulation/` that must
pass) so the gate itself is covered.

`taskfiles/game.yml`: `game:boundary-check` and `game:ui-test`. Root `Taskfile.yml`:
`check` gains both.

## Step 7 — regression tests (AC#5)

- Rewrite `game/godot_tests/bridge_test.gd` and `game/tests/test_bridge.gd` onto
  `SimWorld` (Lance's decision — no test exclusion in the boundary tool), keeping only
  the `ClassDB.class_exists` canary. Add coverage for `prev_prices_copy` and
  `roll_dealer_visits`.
- **Fix a live defect found on the way in:** `bridge_test.gd:200-212` nests the
  minimum-assertion floor inside `for note in _skipped:`, and `_skipped` is never
  appended to anywhere in the file — the anti-false-pass guard documented at :18-20 and
  :26-35, and required by `AGENTS.md`, never executes. It gets un-nested and made real.
- New `game/godot_tests/ui_flow_test.gd` + `.tscn` (scene-driven, so it has a live
  SceneTree to build UI in; `timeout 300` per the headless-hang discipline). Cases:
  1. new game boots — titlebar, all four LEDs, market table row count == `prices_copy().size()`, each row's price text == `fmt(price)`
  2. buy then sell round-trip — cash LED falls by `qty * price`, coat table gains a row, sell restores both
  3. travel advances the day and raises the arrival sequence — titlebar day increments, dialog host opens, queue drains to closed
  4. persistence round-trip — mid-game `save`, fresh `SimWorld`, `load`, dumps byte-identical, and the HUD rebuilt from the loaded world renders the same day and cash
  5. `InputRouter.classify` over all eight shortcuts plus dialog-open confirm/cancel routing

  Asserts a floor derived from the surface size and prints a one-line summary, per
  `AGENTS.md`.

## Step 8 — project wiring and docs

- `game/project.godot`: window size / stretch for the 44rem-wide design, and
  `[internationalization] locale/translations` pointing at `res://translations/strings.en.translation`
  so `tr()` resolves (`docs/layer-boundaries.md:113-114`).
- `game/translations/strings.csv` — the `keys,en` table backing every `tr()` key in
  `content/copy.gd`.
- `game/README.md` — the four-layer convention and what each layer may not do.
- `AGENTS.md` — new build targets (`game:ui-test`, `game:boundary-check`), the
  `game/` layer map, the 56-declaration count, and the new test command.

## Risks / notes

- **`tr()` resolution is the one thing with real unknown cost.** If Godot's headless CSV
  import does not produce a `.translation` the way I expect, `tr("KEY")` silently returns
  the key and the game is full of `DIALOG_BUY` instead of "Buy". I will verify the import
  end-to-end under `task game:import` before building the dialogs on top of it, and the
  ui_flow test asserts resolved text so a regression is caught.
- **`fmt()` rounding.** The JS shows `avgPrice` as a whole dollar; the ABI gives
  `avg_price_cents`. The coat table will show cents/100 rounded — a deliberate precision
  gain, noted in the summary.
- **The new ABI functions are untested by the fixture replay** (`tests/fixtures/*.jsonl`
  has no step for them), so their parity is covered by the bridge test, not by
  `task core:test`. `prev_prices_copy` is a read-only mirror of an already-parity-gated
  accessor; `roll_dealer_visits` is new RNG consumption, which is the one that would need
  a fixture to be airtight. Flagging it rather than silently leaving it.
- **Out-of-order arrival events.** The ABI mutates the world inside
  `roll_arrival_event()`, so the dialogs display post-event state. Identical to the JS,
  which also mutates before rendering. No action.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
## What shipped

ABI (additive, `DW_ABI_VERSION` stays 1; `check_abi_exports.py` reports 56/56):
- `dw_prev_prices_copy` — mirror of `dw_prices_copy` over `prev_price_*`. `was_event` is always 0: the world does not keep a per-slot flag for the previous turn, and the JS `prevPrices` is a bare id -> price map.
- `dw_roll_dealer_visits` — both 15% draws in one call, coat then gun, consumed unconditionally.

`game/` (27 `.gd` files outside `simulation/`, all gate-clean):
- `simulation/world.gd` — `SimWorld`, 56 methods, 31 constants re-exported, all instance.
- `presentation/` — `main.gd` + `hud.gd` + `market_table.gd` + `coat_table.gd` + `health_bar.gd` + `roster.gd` + `arrival_flow.gd` + `dialog_host.gd` + 8 dialogs. One scene.
- `platform/` — `input_router.gd`, `save_store.gd`, `highscore_store.gd`.
- `content/` — `palette.gd`, `copy.gd`, `win95_theme.gd`, plus `translations/strings.csv` (106 rows).

Gates: `tools/validate_game_boundary.py` + its self-test, both new. `task check` runs them plus `game:ui-test`.

## Three real bugs the work surfaced

1. **The shim could not resume a save.** `world_load` was gated on `is_ready()`, and `world_` was only ever set by `init()` -- so a fresh process refused its own save and silently started a new game. The core's `dw_world_load` builds the world from the payload alone and needs no prior init, so the gate was pure shim convenience. Fixed by splitting `ensure_storage()` (allocate the over-aligned backing store) from `ready_` (a world has been written), and calling `ensure_storage()` from both `init` and `world_load`. `game/godot_tests/ui_flow_test.gd` now asserts the cold-load path directly, since nothing else would have caught it.

2. **`bridge_test.gd`'s anti-false-pass floor never ran.** It was nested inside `for note in _skipped:`, over a list nothing ever appends to. Un-nested, it immediately failed: the constant assumed every row of the generated ABI table carries a pinned value, but `abi_version`, `world_size`, `world_align` and `world_dump_len` do not. The floor is now derived from the value-carrying rows (20, which is what actually runs).

3. **Five translation keys silently lost their text.** `Dope Wars, Day {0} of {1}` and four others contain commas and were unquoted, so the CSV importer split them into extra columns and the titlebar rendered as "Dope Wars". Fixed by round-tripping the file through `csv.writer`, and the ui_flow test now parses `copy.gd` and asserts every declared key both has a CSV row and resolves -- so a missing row and an unquoted comma are both failures rather than on-screen noise.

## Deviations from the plan

- **No `platform/app_lifecycle.gd`.** It would have been a three-line wrapper around `state_changed -> SaveStore.save` plus a `NOTIFICATION_WM_CLOSE_REQUEST` handler, and `main.gd` is already the root node that receives that notification. YAGNI; the behavior is in `Main._refresh` and `Main._notification`.
- **`SimWorld`'s `dw_rules_*` accessors are instance methods, not `static func`.** The shim binds them statically, but a GDScript `static func` never appears in `get_method_list()`, which would put 18 of the ABI's methods permanently outside the reach of the bridge test's completeness check. Documented in `world.gd` and `docs/layer-boundaries.md`. This cost three call sites (`DealerDialog` and `NewGameDialog` now take the world or the defaults as parameters instead of reaching for a static).
- **The tables are `Tree`, not columns of `Button`s.** A `Tree` is a real two-column table with a header, and Godot 4 removed `Tree.set_column_align` in favour of a per-cell `TreeItem.set_text_alignment`.
- **`Tree.set_selected` emits `item_selected`,** so applying a selection programmatically would re-enter the selection handler forever. Both tables carry an `_applying` guard; without it the first table click hangs the UI.
- **`DialogHost` closes before invoking the action handler,** matching the prototype's `closeDialog(); opts.onConfirm(qty)` (index.html:1277-1278). Closing afterwards slammed shut the replacement dialog that the finances dialog opens on itself after a deposit (index.html:1348).

## Verified by screenshot, not just by assertion

Rendered the real scene to a PNG and checked the pixels: Win95 chrome, the four LEDs, health bar, borough grid, both tables, the buy dialog, and the modal scrim. That caught three layout bugs the assertions could not -- the titlebar StyleBox had no content margins (so a `Label` sized itself to zero height), the table columns had no vertical expand flag (so the tables were one row tall in a 620px window), and the scrim was 0x0 because `DialogHost` never got anchors.

## Still open

- **`task loc` reports 27.1% Mojo against a 43% target** (35.3% before this task). The denominator now contains 2783 lines of `game/`, and `game/presentation/` is GDScript *by rule* -- `docs/layer-boundaries.md` forbids game rules in GDScript and `core/` may contain no Godot import, so no part of a UI layer can move to Mojo. The target needs re-baselining against the simulation stack (`core/` + `include/` + `extension/`) or an explicit scope statement. Flagged in `AGENTS.md`; not silently re-baselined here.
- **`roll_dealer_visits` has no fixture coverage.** `tests/fixtures/*.jsonl` has no step for it, so the new RNG consumption is pinned only by `test_bridge.gd` (determinism, stream advance, dead-player suppression). A fixture would make it airtight. `prev_prices_copy` is a read-only mirror of an already-parity-gated accessor, so that one is lower risk.
<!-- SECTION:NOTES:END -->
