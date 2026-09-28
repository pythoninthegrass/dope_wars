# game/

The Godot 4.7.1 project. `presentation/main.tscn` holds a single `Control` with
`presentation/main.gd` on it; the window, the modal layer and the input router
are all assembled in code from there. Split into four layers, matching
`~/git/jumpnbump/game/`'s convention:

- `simulation/` — the only layer allowed to reference the GDExtension class
- `presentation/` — the game window, tables, dialogs, and the arrival flow
- `platform/` — keyboard routing, save files, high scores
- `content/` — palette, Win95 chrome, and every display string

## The boundary

`tools/validate_game_boundary.py`, wired into `task game:boundary-check` (part
of `task check`), fails if any script outside `simulation/` names
`DopeWarsWorld` — the GDExtension class registered in
`extension/src/register_types.cpp`. `simulation/world.gd` (`class_name SimWorld`)
is the single pass-through wrapper: every method forwards to exactly one
extension method and does nothing else, and it re-exports all 31 `DW_*`
constants so a caller never names the extension class merely to compare a
result code.

The one sanctioned exception is `ClassDB.class_exists("DopeWarsWorld")`, which
names the class without depending on its API. `tools/test_validate_game_boundary.py`
self-checks the gate itself.

This is the Godot-layer edge of the same boundary `scripts/check-core-boundaries.sh`
enforces at the core: that one says `core/src/*.mojo` never touches Godot or
file I/O, this one says nothing outside `simulation/` reaches past the wrapper
into the extension. See `docs/layer-boundaries.md` for the full rules.

## What each layer may not do

- **simulation/** — no game logic, no caching of world values. It is a wire.
- **presentation/** — no game rules and no mirrored world state. Every display
  re-reads `state_get()` / `prices_copy()` / `inventory_copy()` at render time;
  the two selected-drug indices and the last-day-warning flag are UI state with
  no counterpart in the world, which is why they may live in a field.
- **platform/** — no game rules. `SaveStore` and `HighscoreStore` move opaque
  bytes and JSON; ordering and truncation of a high-score table is the core's
  job (`insert_highscore`), not the store's.
- **content/** — no game data. Drug and borough tables come from
  `SimWorld.rules_drugs()` / `rules_locations()`; duplicating them here would be
  both a rule computation and a second source of truth. What lives here is
  presentation: colors, chrome, and `tr()` keys.

## Display strings

Every player-visible string is a `tr()` key. The English text lives in
`translations/strings.csv`, which Godot's importer compiles into the
`.translation` that `project.godot` registers. **A key with no CSV row renders
as the key itself**, and a value containing a comma has to be quoted or the
import splits it into extra columns — both failure modes are guarded by
`game/godot_tests/ui_flow_test.tscn`'s translation case.

## Running it

```sh
task run                       # build the stack, then launch
godot --path game              # already built
godot --path game -- --seed=42 # a reproducible run
```

`--seed=<n>` replaces the JS prototype's `?seed=<n>`.

## Tests

```sh
task game:boundary-check       # the DopeWarsWorld boundary + its own self-test
task bridge:test               # generated pointer-free surface, scene-driven
task bridge:test:script        # full forwarded ABI, script-driven
task game:ui-test              # presentation-layer regression suite
```

`game/godot_tests/ui_flow_test.tscn` drives the real `Main` scene through the
same entry points the keyboard and the buttons use, and asserts on rendered
widget state: boot and price rendering, a buy/sell round trip, travel with the
arrival sequence draining, a mid-game save round-tripping through a cold start,
the finances dialog, the new-game form, the keyboard shortcut table, and that
every `tr()` key resolves.

Any `godot` invocation that is not wrapped in a Taskfile target must run under
`timeout`: a scene whose `_ready()` aborts on a script error prints the error
and then keeps spinning the main loop forever.
