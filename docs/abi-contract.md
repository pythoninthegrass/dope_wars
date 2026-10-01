# ABI contract

This document specifies the conventions that govern `include/dopewars.h`, the
frozen C ABI between the Mojo simulation core (`core/`) and every consumer
(the C++ GDExtension shim in `extension/`, any future native binding, and the
conformance tests). It is the discipline document; the header is the concrete
worked example. Modeled on `~/git/jumpnbump/include/jumpnbump.h` and its
companion `~/git/jumpnbump/backlog/tasks/task-012.01`.

## Ownership

- All state lives inside a caller-owned opaque handle: `dw_world`. The type is
  declared but never defined in the header; callers only ever hold a pointer.
- The caller allocates `dw_world_size()` bytes aligned to `dw_world_align()`
  and passes that storage to `dw_world_init(world, config)`. Nothing on the
  Mojo side of the ABI allocates on the caller's behalf.
- The internal `World` is plain data: every field is a fixed-width scalar or a
  fixed-size `Array`, with explicit length fields for the ordered maps. That is
  what makes the caller-owned-storage model work — `dw_world_size()` is
  `size_of[World]()`, the ABI placement-constructs a `World` into the caller's
  buffer, and plain `free()` on that buffer is a complete teardown.
- There is deliberately no `dw_world_destroy`. Adding a destroy function later
  is additive; removing one later is not, so the ABI does not commit to one
  until the core requires cleanup that plain `free()` on the caller's storage
  cannot express. The plain-data `World` does not require any.
- No pointer returned from the ABI outlives the call that produced it, and no
  buffer the caller passes in is retained past the call. Every cross-boundary
  buffer is either fully copied out (two-call length-then-fill, below) or
  fully consumed on the way in.

## Error model

- Every fallible function returns `dw_result`, a `typedef int32_t`. Never a
  bare C `enum` — a C enum's underlying integer width is unspecified, which
  is exactly the ambiguity a cross-language ABI cannot afford.
- Result codes are anonymous-enum constants (`DW_OK = 0`, `DW_ERR_*`) whose
  integer values are frozen from ABI v1 onward. New error codes are only ever
  appended; existing values are never renumbered.
- Kind enums that appear inside structs (arrival event kind, price event
  kind, finances action) are `typedef uint8_t` for the same reason — fixed
  width, named constants, no bare C enum.
- Precondition failures (unknown drug id, malformed handle, `abi_version`
  mismatch) return an error code without mutating world state.

## Buffer contract

Every variable-length output uses the two-call length-then-fill convention:

1. Call with `out_buf == NULL` (or `out_capacity == 0`) to learn the required
   length via `*out_required`. No data is written.
2. Allocate at least `*out_required` slots and call again with the real
   buffer. Data is written; `*out_required` is set to the actual length.

If a real buffer is passed but is too small, the function returns
`DW_ERR_BUFFER_TOO_SMALL` and still sets `*out_required` to the actual length
so the caller can retry. Nothing partial is written in the too-small case.

Fixed-length buffers (dimensional constants like `DW_NUM_LOCATIONS` or fixed
serialization sizes reported by `dw_world_dump_len()`) skip the length query
and return `DW_ERR_INVALID_ARGUMENT` on a wrong-sized buffer.

## Struct discipline

Every ABI struct:

- Uses only fixed-width types (`uint8_t`, `int32_t`, `uint32_t`, etc.) and
  fixed-size char arrays. No `int`, no `size_t` inside structs, no pointers.
- Names every padding slot `_pad0`, `_pad1`, ... and specifies that its value
  is zero. The Mojo side writes zero; the C++ side does not read padding.
- Has a `DW_STATIC_ASSERT(sizeof(T) == N, "...")` immediately after the
  struct definition. Any accidental layout change breaks the build on the
  first `#include`.
- Is a plain C struct — no bitfields, no unions, no flexible array members.

## String handling

- No heap-owned strings cross the ABI in either direction.
- Fixed-size UTF-8 char arrays inside structs carry short identifiers
  (location id, drug id, highscore name). The array is null-terminated within
  the buffer; content past the terminator is unspecified.
- Human-readable messages are **not** part of the ABI. The engine emits
  structured payloads (event kind + drug index + quantity + amount) and the
  GDScript presentation layer formats display strings from those. This keeps
  translation, punctuation, and copy edits out of the frozen contract.

## RNG exposure

- The core uses mulberry32 with a `uint32_t` state, the same PRNG the JS
  prototype at `index.html:624-635` uses.
- The ABI exposes `dw_mulberry32_seed`, `dw_mulberry32_next_u32`, and
  `dw_rand_int` as free-standing functions. These are exposed **only** so the
  JS oracle in `tests/engine.test.mjs` (see subtask TASK-001.02) can be
  compared against the Mojo core with identical seeds and identical draw
  order.
- The `dw_world` handle owns its own RNG stream, seeded from `dw_config`.
  Turn-driving functions (`dw_generate_prices`, `dw_travel`,
  `dw_roll_arrival_event`, `dw_roll_dealer_visit`, chase/combat rolls,
  dealer offers) draw from that stream; callers do not pass an RNG.
- The RNG state is included in the canonical dump so a saved game replays
  bit-for-bit on load.

### Why the draw-owning rules live in the core

The prototype's arrival sequence (`runArrivalSequence` in `index.html`) rolls
whether a dealer shows up on arrival. In the prototype that draw sits in the
*UI* layer but consumes the *world's* RNG, because the JS engine injects
one `rng` closure through the whole call graph. The Mojo world owns its stream
instead, so a presentation layer cannot reach it at all: there is no exported
draw, and `dw_config.rng_seed` is write-only, so a caller cannot even reseed a
private generator into agreement.

That makes the choice binary. Either the roll is a core rule — the only option
consistent with `docs/layer-boundaries.md`, which forbids GDScript from
computing event outcomes — or the dealer dialogs are unreachable. It is
therefore `dw_roll_dealer_visit`, which draws `Random(14)` and, on a visit,
`Random(4)` to pick the coat or gun dealer, in a single call.

The same reasoning applies, more weakly, to `dw_prev_prices_copy`. The JS UI
keeps `state.prevPrices` (`index.html:719`) purely to draw the market table's
▲/▼ glyph. The world already stores and serializes `prev_price_*` — dropping it
from the ABI would have meant a second price table living in GDScript, which is
the cached-mirror state `docs/layer-boundaries.md` rules out.

Both are additive, so `DW_ABI_VERSION` is unchanged at `1u`.

## Float projections

The core keeps `cash`, `bank`, `debt` and `avg_price` as `Float64` because the
JS oracle does (`cash` and `avg_price` carry fractions; since v9 `bank` and `debt` are always whole dollars but stay `Float64`, so the dump layout is unchanged). Several ABI view
fields are integers, so they are a lossy **display** projection:

- `dw_state_view.bank` / `.debt` (`int64_t`)
- `dw_inventory_slot.avg_price_cents` (`int64_t`, dollars × 100)
- `dw_finish_result.score` (`int64_t`)

The rule is **truncate toward zero** for every float64 → int64 projection.
Persistence is unaffected: `dw_world_dump` is opaque bytes and keeps the raw
float64, so save/load stays bit-exact.

## Versioning

- `DW_ABI_VERSION` is a `#define` starting at `1u`.
- `dw_abi_version()` is a runtime accessor for it, so a binding can assert the
  version of the core it actually linked against rather than the one it
  compiled its own copy of the header from. Additive; does not bump the
  version.
- `dw_config.abi_version` is checked on every `dw_world_init` call; mismatch
  returns `DW_ERR_ABI_VERSION_MISMATCH` before any other validation.
- Additive changes (new functions, new anonymous-enum constants, new
  dimensional `#define`s that don't invalidate existing struct sizes) do
  **not** bump the version.
- Any of the following bumps the version and requires every binding to
  rebuild and relink:
  - Change to any exported function's signature or calling convention.
  - Change to any struct's layout (including `_pad` renames).
  - Renumbering an existing anonymous-enum constant.
  - Change to the observable semantics of an existing function (including
    RNG draw order for a given seed).
- **v2 (TASK-009)**: `dw_start_chase` changed from a pure function of `day`
  (zero RNG draws) to `randInt(2, 11)` (one RNG draw), matching beermat-verified
  play data. Struct layouts and the dump byte count are unchanged from v1 —
  this bump is solely for the RNG-draw-order rule above.
- **v3 (TASK-010.02.02)**: `dw_generate_prices` rolls a 1-in-20 spike (x5) or
  crash (div 10) per traded flagged drug instead of the 70% / 40% / 5%
  event-count scheme, changing RNG draw order. `DW_PRICE_EVENT_BUST` (2) is a
  new kind for the cops-bust spike text. `MAX_PRICE_EVENTS` grew from 3 to 8,
  so the dump grew from 766 to 846 bytes.
- **v4 (TASK-010.02.03)**: `dw_generate_prices` rolls each drug's availability (1 in 8 absent, at every location) in place of the per-location shuffled subset, changing RNG draw order. `dw_location_view` lost `min_drugs`, `max_drugs` and `_pad0`, so it shrank from 80 to 68 bytes; `dw_rules_locations_copy` now reports only `id`, `name` and `police`. The dump length is unchanged.
- **v6 (TASK-010.02.05)**: one combined dealer visit, `dw_roll_dealer_visit` (`Random(14) == 0`, then `Random(4)` for coat or gun), replaces `dw_roll_dealer_visits`. `dw_coat_offer` is now `{price, offered}` (8 bytes) and `dw_gun_offer` is `{price, name_index, offered}` (16 -> 12 bytes); `offered` is 1 only when the price is strictly below cash. `dw_accept_coat_offer` draws the pocket count and returns it through `out_pockets`, `dw_accept_gun_offer` takes no result struct, and `dw_purchase_result`, `dw_rules_gun_space` and `dw_rules_bank_purchase_fee_bp` are removed. Dealers are paid from cash only, so `DW_ERR_INSUFFICIENT_BANK` is reserved and never returned, and a gun takes no coat space. `DW_DEALER_NONE`, `DW_DEALER_COAT` and `DW_DEALER_GUN` are new. The dump length is unchanged.
- **v5 (TASK-010.02.04)**: `dw_should_start_chase` is Beermat's `Random(6) == 0`, a flat 1 in 6 at every location, still one RNG draw. `dw_location_view` lost `police`, so it shrank from 68 to 64 bytes and `dw_rules_locations_copy` now reports only `id` and `name`. The dump length is unchanged.
- **v7 (TASK-010.02.06)**: `dw_roll_arrival_event` is Beermat's event: `Random(14) == 0` (always, as the mugging, once `cash + bank` exceeds 99,999,999), then `Random(4)` picks found drugs, mugging, drugs from a friend or police dogs, changing RNG draw order. `DW_ARRIVAL_MAMAS_BROWNIES`, `DW_ARRIVAL_FREE_WEED_DEATH` and `DW_ARRIVAL_FLAVOR` are removed, and `dw_arrival_event.damage` is replaced by `blocks` (the struct stays 24 bytes). `DW_ARRIVAL_DOG_CHASE` carries `blocks`, `qty` dropped and `drug_index` only when `qty > 0`; `DW_ARRIVAL_MUGGED` no longer takes health. Found and given drugs are drawn from the previous market. The dump length is unchanged.
- **v8 (TASK-010.02.07)**: Beermat's chase resolution (`docs/beermat-re.md`, M-07 to M-09). `dw_run_from_chase(world, out_result)` escapes on `Random(6) < 3` whatever the player carries and otherwise the cops fire (`Random(2)`, 1 hits for `Random(11) + 5`), changing RNG draw order; it no longer takes a `chase` or `is_aggressor`. `dw_stay_in_chase` is new: the cops fire. `dw_fight` needs a gun (`DW_ERR_INVALID_ARGUMENT` with no draw otherwise), the player's shot kills a deputy on `Random(2) == 1`, and `dw_chase.deputies` is now `int32_t` because the chase is won when it drops below 0. A win pays `+1` gun and `(Random(1000) + 1000) + Random(1500)` cash and returns the doctor offer in `dw_fight_result`; `dw_accept_doctor_offer` pays its price from cash (`DW_ERR_INSUFFICIENT_CASH` otherwise) and sets health to 100. `dw_run_result` is `{escaped, hit, dead, damage_taken}`, `dw_stay_result` is new, and `dw_fight_result` grew from 8 to 16 bytes (`{killed, cop_hit, dead, won, damage_taken, reward, doctor}`). `dw_get_fight_ratings`, `dw_fight_ratings`, `dw_rules_gun_damage` and `dw_rules_player_armor` are removed. The dump length is unchanged.
- **v9 (TASK-010.02.08)**: Beermat's interest rounding (`docs/beermat-re.md`, M-10). `dw_travel` rounds debt and bank interest to whole dollars with ties-to-even (computed in integers to match the binary's x87 product) and skips a balance of 0 or less, so `bank` is always integral. No signature, struct layout or dump length changes, but the observable result of `dw_travel` does, which the policy above counts as a bump.
- **v10 (TASK-010.02.11)**: Beermat only records a final score above 0 (`docs/beermat-re.md`, M-13). `dw_insert_highscore` now returns the new `DW_ERR_SCORE_TOO_LOW` (14) instead of `DW_OK` when `entry->score <= 0`, leaving `scores` and `*out_count` unchanged. The new enum constant is appended, not renumbered, but the function's observable behavior changes for that input, which the policy above counts as a bump. No struct layout or dump length changes.

## Serialization

- `dw_world_dump_len()` reports the exact byte count `dw_world_dump` will
  write. The count is fixed for a given ABI version (766 bytes at v1) and does
  not depend on inventory occupancy or price-table content.
- `dw_world_dump` writes the canonical byte sequence produced by
  `core/src/serialize.mojo`: the scalar state (seed, RNG state, day, num_days,
  cash, debt, bank, start_cash, health, coat capacity, guns, location, dead,
  last-day-warned), then each ordered map as a live count followed by all
  `DW_NUM_DRUGS` order slots (zero-padded past the live count) and all
  `DW_NUM_DRUGS` dense slots, then the price-event list as a count followed by
  `MAX_PRICE_EVENTS` slots. Floats are stored as an exact
  (sign, exponent, mantissa) decomposition, so a save/load cycle is bit-exact.
  Deterministic little-endian encoding, no compression, no framing.
- `dw_world_load` accepts exactly the byte sequence `dw_world_dump` produced
  at the same `DW_ABI_VERSION` and rehydrates the world in place. It validates
  the length and every location/drug index in the payload; on any
  inconsistency it returns `DW_ERR_SERIALIZATION_FAILED` and leaves the world
  unchanged. Bit-for-bit round-trip is a requirement, not an optimization.

### Divergence from jumpnbump

`~/git/jumpnbump/include/jumpnbump.h` deliberately omits a load/deserialize
function because the ported Zig core only implements `dumpTo()`. Dope Wars
differs: `index.html:1033-1047` round-trips through JSON with
`serializeState`/`deserializeState` and the game's save-slot feature depends
on that round-trip. The Mojo port must therefore implement both directions
from day one, and `dw_world_load` is part of the frozen ABI.

## Conformance and gates

Three gates keep the ABI honest, all wired into `task lint` / `task check`:

- `tools/validate_abi_exporter.py` — fails if any `core/src/*.mojo` file other
  than `abi.mojo` declares an `@export("dw_...")`. Source-level single-exporter
  discipline.
- `tools/validate_abi_symbols.py` — runs `nm -g --defined-only` on the built
  `libdopewars.a` and fails if any defined global symbol is not `dw_`-prefixed.
  Post-link, catches every symbol regardless of source file.
- `tools/validate_abi_test_purity.py` — fails if any `core/abitest/*.mojo`
  imports a non-`std` module, so the conformance tier cannot silently become a
  second copy of the parity suite.

`core/abitest/abitest.mojo` is the Tier-C conformance suite: it reaches the
compiled library exclusively through this header via `std.ffi.external_call`
(Mojo 1.1.0 has no `@cImport`), and asserts the struct sizes above against the
header's `DW_STATIC_ASSERT` values. `game/tests/test_bridge.gd` is the bridge
integration test: it drives the same ABI through the C++ GDExtension shim from
GDScript.
