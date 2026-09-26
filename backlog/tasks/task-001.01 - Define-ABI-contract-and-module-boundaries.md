---
id: TASK-001.01
title: Define ABI contract and module boundaries
status: Done
assignee:
  - claude
created_date: '2026-09-26 04:33'
updated_date: '2026-09-26 05:11'
labels:
  - godot
  - mojo
  - ffi
  - migration
milestone: m-0
dependencies: []
references:
  - ~/git/jumpnbump/include/
  - >-
    ~/git/jumpnbump/backlog/tasks/task-012.01 -
    Write-include-jumpnbump.h-with-frozen-ABI-discipline.md
documentation:
  - index.html
  - AGENTS.md
parent_task_id: TASK-001
priority: high
ordinal: 1000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Design and document the complete ABI surface that Mojo will export and C++ will consume. Every engine operation from `index.html:1049-1077` maps to a C-callable function. Establish ownership, memory, and error-handling conventions following the discipline in `~/git/jumpnbump/include/jumpnbump.h` (caller-owned opaque world pointer, `uint8_t`-typedef'd result codes never bare C enums, static-asserted struct sizes, two-call length-then-fill convention for every buffer output).

Deliverables:
1. `include/dopewars.h` — draft header (C11-clean, compiles with `cc -std=c11 -Wall -Wextra` with zero warnings)
2. `docs/abi-contract.md` — conventions document: ownership model, error codes, buffer contract, versioning policy
3. `docs/layer-boundaries.md` — what each layer is and is not allowed to do, with rationale

Cross-reference `~/git/jumpnbump/backlog/tasks/task-012.01` for the ABI discipline pattern and `~/git/jumpnbump/include/` for a concrete worked example.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 ABI header draft covers all engine exports from index.html:1049-1077: RULES accessors, mulberry32/randInt, newGame, coatUsed, generatePrices, buy, sell, travel, finances, rollArrivalEvent, rollCoatDealerOffer, acceptCoatOffer, rollGunDealerOffer, acceptGunOffer, shouldStartChase, startChase, getFightRatings, runFromChase, fight, applyDamage, finish, insertHighScore, findDrug, findLocation, serializeState, deserializeState
- [x] #2 Memory and error conventions are written and consistent: no bare C enums across the boundary, caller-owned world opaque pointer, two-call length-then-fill for all variable-length buffers, static_assert on every ABI struct size
- [x] #3 Boundary rules document specifies what is forbidden in each layer: no Godot/FFI imports in Mojo core; no game logic in C++ shim; GDScript calls simulation only through the GDExtension class
- [x] #4 AGENTS.md is updated to describe the four-layer architecture and directory layout
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
## Approved plan

Deliverables:
1. `docs/abi-contract.md` — conventions (ownership, error model, buffer contract, versioning, struct discipline, string handling, RNG exposure).
2. `docs/layer-boundaries.md` — four-layer rules with explicit forbidden lists per layer (core/Mojo, include/, extension/C++, game/GDScript).
3. `include/dopewars.h` — C11-clean frozen ABI header modeled on `~/git/jumpnbump/include/jumpnbump.h`:
   - `DW_ABI_VERSION 1u`, dimensional constants (DW_NUM_LOCATIONS=6, DW_NUM_DRUGS=12, DW_MAX_HIGHSCORES=10, name/message length caps).
   - `dw_result` = int32_t + anonymous enum constants (OK, INVALID_ARGUMENT, BUFFER_TOO_SMALL, ABI_VERSION_MISMATCH, UNKNOWN_LOCATION, UNKNOWN_DRUG, NOT_TRADED_HERE, INSUFFICIENT_CASH/BANK/INVENTORY/SPACE, GAME_OVER, DEAD, SERIALIZATION_FAILED).
   - uint8_t-typedef'd kinds: `dw_arrival_event_kind`, `dw_price_event_kind`, `dw_finances_action`.
   - Opaque `dw_world` + size/align/init/reset lifecycle, no destroy.
   - View structs with `_pad` fields + `DW_STATIC_ASSERT` on every sizeof: dw_config, dw_state_view, dw_location_view, dw_drug_view, dw_inventory_slot, dw_price_slot, dw_price_event, dw_arrival_event, dw_coat_offer, dw_gun_offer, dw_chase, dw_fight_ratings, dw_fight_result, dw_finish_result, dw_highscore_entry.
   - One C function per JS engine export (index.html:1049-1077): rules accessors, mulberry32/randInt (exposed for oracle parity), lifecycle, state/prices/inventory queries, buy/sell/travel/finances, event rolls (arrival, coat dealer, gun dealer), chase/combat (should_start_chase, start_chase, get_fight_ratings, run_from_chase, fight, apply_damage), finish/insert_highscore, find_drug/find_location, and serialize/load (JS oracle needs bidirectional round-trip, documented as intentional divergence from jumpnbump).
   - Two-call length-then-fill for every variable-length output (prices, inventory, price_events, dumps, highscore list, drug/location tables).
   - Messages carried as structured (kind + drug_index + qty + amount) payloads; presentation strings live in GDScript.
4. Update `AGENTS.md` with a four-layer architecture section and directory layout.

Sequencing:
1. Write `docs/abi-contract.md`.
2. Write `docs/layer-boundaries.md`.
3. Write `include/dopewars.h`.
4. Verify with `cc -std=c11 -Wall -Wextra -c` against a scratch `#include`-only .c — zero warnings.
5. Update `AGENTS.md`.
6. Check AC #1–#4 and finalize.

Key decisions locked at plan approval:
- Include `dw_world_load` alongside `dw_world_dump` (JS round-trips; divergence from jumpnbump documented in the header top comment).
- Structured event payloads, no English strings across ABI.
- RULES exposed via accessor functions, not one mega-struct, so additive extensions don't bump ABI version.
<!-- SECTION:PLAN:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Defined the frozen C ABI contract and layer boundaries for the Godot/Mojo port.

**Files added:**
- `include/dopewars.h` (C11-clean, compiles with `cc -std=c11 -Wall -Wextra -Wpedantic` and `c++ -std=c++17 -Wall -Wextra -Wpedantic` with zero warnings). Declares one C-callable function per JS engine export at `index.html:1049-1077`: RULES accessors (`dw_rules_*` + `dw_rules_locations_copy` / `dw_rules_drugs_copy`), mulberry32/randInt free functions, world lifecycle (`dw_world_size/align/init/reset`), state/prices/inventory queries, `dw_buy` / `dw_sell` / `dw_travel` / `dw_finances`, `dw_generate_prices` + `dw_price_events_drain`, `dw_roll_arrival_event`, coat/gun dealer roll+accept, `dw_should_start_chase` / `dw_start_chase` / `dw_get_fight_ratings` / `dw_run_from_chase` / `dw_fight` / `dw_apply_damage`, `dw_finish` / `dw_insert_highscore`, `dw_find_drug_index` / `dw_find_location_index`, and `dw_world_dump` / `dw_world_load`.
- `docs/abi-contract.md` — conventions: ownership (caller-owned opaque `dw_world`, no destroy), error model (`dw_result` = `int32_t`, `uint8_t`-typedef'd kind enums, never bare C enum), two-call length-then-fill buffer contract, struct discipline (`_pad` fields, `DW_STATIC_ASSERT` on every sizeof), fixed-length UTF-8 strings, structured (not English) event payloads, `DW_ABI_VERSION` bump policy.
- `docs/layer-boundaries.md` — explicit allowed/forbidden lists per layer: `core/` (Mojo) forbids Godot/FFI imports, file I/O, global mutable state outside the handle, and English strings; `include/dopewars.h` forbids Mojo/Godot type leakage and bare C enums; `extension/` (C++ shim) forbids game logic and non-handle state; `game/` (GDScript) forbids direct Mojo imports and rule computation.

**Files modified:**
- `AGENTS.md` — added a "Target architecture (Godot port, TASK-001)" section describing the four-layer stack and cross-linking the two new docs, plus the >=43% Mojo LOC target lifted from the parent task.

**Key decisions:**
- Included `dw_world_load` alongside `dw_world_dump` (JS oracle round-trips through JSON at `index.html:1033-1047`; save-slot feature depends on it). Documented as an intentional divergence from `~/git/jumpnbump/include/jumpnbump.h`, which is dump-only.
- Exposed mulberry32/randInt as free functions in the ABI so TASK-001.02's oracle fixtures can drive identical draw sequences against the JS `<script id="engine">` and the eventual Mojo core.
- Structured event payloads (drug_index + qty + amount + damage) instead of English strings across the ABI — presentation strings live in GDScript with `tr()` keys.
- RULES accessors are per-field free functions, not one mega-struct, so additive rule extensions don't have to bump `DW_ABI_VERSION`.
- Interest rates and the bank purchase fee are basis-point uint32 (e.g. 1000 = 10.00%) so the ABI carries no floating-point.
- `int64_t` for bank/debt/score fields — compound interest can plausibly exceed int32 over 31 days at 10%/turn.

**Verification:** header compiles clean with C11 `-Wall -Wextra -Wpedantic` and C++17 `-Wall -Wextra -Wpedantic`; markdownlint passes on all three new/modified markdown files under `.markdownlint.jsonc`.

**Not in scope (deferred to later TASK-001.x subtasks):** oracle fixtures (001.02), Godot project + C++ shim + Mojo build wiring (001.03), Mojo core implementation (001.04), ABI conformance test binary (001.05).
<!-- SECTION:FINAL_SUMMARY:END -->
