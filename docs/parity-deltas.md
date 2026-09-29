# Parity deltas

Behavioral differences between the Godot port (`core/` + `extension/` +
`game/`) and the JS prototype (`index.html`), approved by Lance. This is not
a list of bugs — every fixture in `tests/fixtures/*.jsonl` replays
byte-identically against the compiled Mojo core (`task core:test`, AC#1), so
every *simulation* rule is exact parity, seed for seed. What's below is where
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

`core/src/dealers.mojo:roll_dealer_visits` and the JS
`state.rng() < 0.15` pair in `index.html:1387-1388` both draw twice
unconditionally, then suppress the *reported* result when the player is dead
— the `!state.dead` guard is evaluated after the draw, by JS's own
short-circuit order, and the Mojo port preserves that draw-then-suppress
sequencing exactly (pinned by `tests/fixtures/12-dealer-visits.jsonl`, added
in TASK-001.09). Listed here only because it is the kind of thing that looks
like a plausible optimization ("skip the draw when dead") that would in fact
desync the RNG stream for the rest of the run; it is not an approved
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
