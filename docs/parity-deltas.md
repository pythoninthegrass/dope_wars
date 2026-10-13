# Parity deltas

Behavioral differences between the Godot port (`core/` + `extension/` +
`game/`) and the JS prototype (`index.html`), approved by Lance. This is not
a list of bugs — every fixture in `tests/fixtures/*.jsonl` replays
against the compiled Mojo core (`task core:test`, AC#1), so every *simulation*
rule a fixture pins is exact parity with the prototype, seed for seed. The
fixtures hold only rules Beermat 2.1 keeps (section 8). What's below is where
the port's behavior is deliberately not a literal copy of the prototype's,
because the prototype's choice was an artifact of running in a browser tab
rather than a game rule.

## 1. Corrupt or truncated save file: reject instead of silently misplaying

**JS (`index.html:1539-1553`):** `localStorage.getItem('dopewars.save')` is
`JSON.parse`d with no shape validation. A hand-edited or truncated value
either throws (uncaught, breaks the page) or parses into a partial object
that plays through with `undefined` fields.

**Godot (`game/platform/save_store.gd`):** `world_load()` validates the
loaded buffer's length against `dw_world_size()` before handing it to the
core. A corrupt or length-mismatched save deletes the file and returns
`null`, which `main.gd` treats as "no save" and starts a new game — the same
outcome a first-ever launch gets.

**Approved because:** the core's opaque byte dump is not human-editable the
way JSON was, so a mismatch is corruption, not a valid state the game should
attempt to render. Failing closed (new game) is strictly safer than the JS
behavior it replaces, never worse.

## 2. High-score date is platform metadata, not a core field

**JS (`index.html:1594`):** the high-score table's Date column is a plain
JS `Date` stamped into the same object the score/day/dead fields live on.

**Godot:** `dw_highscore_entry` (the ABI struct) has no date field —
`core/` has no wall-clock access by design
(`docs/layer-boundaries.md`, "Forbidden": "File I/O, network I/O,
environment reads"). `game/platform/highscore_store.gd` keeps the date as
JSON-only metadata alongside the four core-owned fields
(`name`, `score`, `day`, `dead`), re-attached after `SimWorld.insert_highscore()`
returns the ranked table by matching the `(name, score, day, dead)` tuple. A
row whose tuple doesn't match (which cannot happen in practice, since the
core is the sole author of that tuple) falls back to an empty date rather
than inventing one.

**Approved because:** a wall-clock read is explicitly forbidden inside the
core boundary (`docs/layer-boundaries.md`), and the date is not a game fact
that a parity fixture could pin regardless — it's "when this machine's clock
said the game ended," which is meaningless to compare across a seeded run.

## 3. Persistence store and format

**JS:** `localStorage` under `dopewars.save` (JSON-serialized state) and
`dopewars.highscores` (JSON array).

**Godot:** `user://dopewars.save` (the core's opaque `dw_world_dump()` byte
buffer, not JSON) and `user://dopewars.highscores.json`.

**Approved because:** `localStorage` doesn't exist outside a browser;
`user://` is the Godot-idiomatic equivalent, and dumping the core's own
binary layout (rather than re-deriving a JSON shape from it) is what makes
the save/load round-trip byte-identical (`game:ui-test` case 4) instead of a
second, independently-maintained serialization.

## 4. Chase escape RNG draw order — not a delta, called out because it looks like one

`core/src/dealers.mojo:roll_dealer_visit` and the JS `rollDealerVisit` draw
one value on a miss and two on a visit, and only on a non-chase arrival.
The offer price is drawn when the dealer is presented, the cosmetic gun name
only when the offer is made, and the coat pocket count only when the player
accepts (pinned by `tests/fixtures/05-dealers.jsonl`; the combined visit draw
itself was pinned by `12-dealer-visits.jsonl`, retired in section 8). Listed here only because it is the kind of thing that
looks like a plausible optimization (draw everything up front) that would in
fact desync the RNG stream for the rest of the run; it is not an approved
deviation, it is a documented non-deviation.

## Not a delta: the TASK-009 constant corrections

TASK-009 changed `bankInterest` (0.02 -> 0.05), the `startChase` deputy-count
formula (day-scaled -> `randInt(2, 11)`), and the Ecstasy/Smack price bounds.
These are not JS-vs-Mojo deltas: `index.html`'s `RULES` table was corrected in
the same change (see the inline comment at `index.html:648`,
"beermat-verified (TASK-009)"), so the JS prototype and the Mojo core agree on
the corrected values. What changed is the prototype's own agreement with the
Beermat Windows reference (`docs/gameplay.md`) versus the earlier
Keymash-web-port-derived guess; see `docs/architecture.md`'s "ABI version
history" for why that bump was breaking (`DW_ABI_VERSION` 1 -> 2) rather than
additive.

## 5. City names and the location model

**Beermat (`docs/beermat-re.md`):** one city is six named sub-locations, read from `cities.txt` at startup (`TForm1.ReadCities`, `0x0045c6d8`), and the real game has no per-location rules at all: drug availability and chase odds are location-independent.

**Port:** six fixed New York boroughs (`index.html` `RULES.locations`), kept as the port's own setting.

**Approved because:** the borough and city names and the one-city-six-sub-locations model are not fidelity targets, so differences in them are not attributed to rule mismatches and are not ported. The per-borough police weights the engine used to hang off that model were a rule difference (M-04 in `docs/beermat-re.md`) and have been removed.

## 6. New Game available at any time, not gated

**Beermat 1.2 (`docs/beermat-re.md`, M-11):** the New Game button and the File > New menu item are disabled from the start of a game until the first travel made on day 5, so a restart is only possible from day 6. Finances is enabled from day 1.

**Beermat 2.1 (`docs/beermat-2.1-re.md`):** the same lockout, one day earlier. `TDWForm_EnableNewGameButton` (`0x004b7f48`) disables the button and File > New while `day <= 4` (the day counter at `DAT_004e20e0`), so it unlocks on day 5 rather than day 5. The port still does not gate it.

**Prototype and Godot port:** New Game is available on every day, including day 1.

**Approved because:** Lance prefers being able to start a new game at any time rather than reproducing Beermat's restart lockout. This is a deliberate divergence, not an unported rule — `docs/beermat-re.md` M-11 and the 2.1 equivalent stay recorded as Beermat behavior for reference, but the port will not gate New Game to match either build.

## 7. Sound is Godot-only

**Prototype (`index.html`):** the `#engine` script has no sound at all — a deliberate scope decision for that pass (`README.md`), not a fidelity gap.

**Godot port (`game/platform/sound_player.gd`, TASK-010.03):** plays Beermat's ten wav cues (`docs/beermat-re.md`, "Sounds") at the documented trigger points, and the Sounds menu is a checkable Allow Sound item mirroring `AllowSound`'s on-by-default behavior. The wavs themselves are copyrighted and never committed (`task game:sounds` copies them from gitignored `vendor/dopewars-1999/`); the game runs silently, without error, when they are absent.

**Approved because:** the prototype's silence was a scoping choice for `index.html` specifically, not a rule the Godot port needs to preserve — nothing in `docs/gameplay.md` ties sound to a game rule, and the fidelity target here is Beermat's cue table, which the prototype was never meant to match.

**Approved because:** Lance prefers being able to start a new game at any time rather than reproducing Beermat's restart lockout. This is a deliberate divergence, not an unported rule — `docs/beermat-re.md` M-11 stays recorded as the Beermat behavior for reference, but the port will not gate New Game to match it.

## 8. The fidelity target is Beermat 2.1, and `index.html` is frozen at 1.2

**Before:** the prototype's 1.2 rules were the parity target, and every fixture recorded from `index.html` gated the Mojo core.

**Now:** Beermat 2.1.0.0 (2001) is the target (`docs/beermat-2.1-re.md`), and 2.1 wins wherever it differs from 1.2. Development is Mojo-first: rule changes are written test-first in `core/`, `index.html` stays frozen at 1.2 and is not extended, and so the JS oracle can only vouch for rules 2.1 keeps. `docs/parity-fixture-classification.md` records the outcome per fixture: 02, 05, 07 and 11 keep their unchanged steps, 03 and 10 keep a few, and 01, 04, 06, 08, 09 and 12 are retired. Kept fixtures compare only the state fields they exercise (`stateFields` in each `.meta.json`), so a state-shape change in a field they do not exercise does not fail them. A rule 2.1 replaces is pinned by a Mojo-native test; one the core has not implemented yet is a skipped test in `tests/mojo/pending_2_1_test.mojo` that the implementing slice un-skips.

**Skipped by decision:** airport flights and multi-city travel (section 5 stands), registration and license keys, online scores and cartels, the update check, proxy settings, the city editor, skins, LCD font and layout polish, and anti-cheat. The 2.2 changelog items are tracked separately under TASK-013.03 because the binary has no evidence for them.

**Approved because:** Lance decided that 2.1 replaces 1.2 as the fidelity target (TASK-013), and a gate that fails on a correct 2.1 rule would block the work it exists to protect.

## 9. All four game lengths are available, with no registration gate

**Beermat 2.1:** the new-game form offers 15, 30, 60 and 90 days, and only 30 is available to an unregistered copy.

**Godot port (`game/presentation/dialogs/new_game_dialog.gd`):** the new-game form offers all four lengths (`NewGameDialog.GAME_LENGTHS`), and the core default is 30 (`rules.NUM_DAYS`). The core accepts any `num_days`, since its tests and ABI callers use short games, so the four-length set is a presentation rule. A high-score row records its game length (`dw_highscore_entry.num_days`, carved from the old padding without changing the struct size) and the Scores dialog shows it in a Length column. The per-length score pages (N-20) and the 30-entry list (N-19) are separate slices.

**Approved because:** registration and license keys are out of scope (section 8), and gating three of four lengths would only lock out features the port already implements.
