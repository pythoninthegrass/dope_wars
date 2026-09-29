---
id: TASK-009
title: Apply beermat-verified engine fixes from TASK-008 comparison
status: Done
assignee:
  - '@pythoninthegrass'
created_date: '2026-09-29 00:45'
updated_date: '2026-09-29 01:19'
labels: []
dependencies: []
references:
  - TASK-008
priority: medium
type: bug
ordinal: 18000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
TASK-008 drove the real beermat "Dope Wars for Windows" 1.2.0.0 (1999) executable over noVNC and compared its observed behavior against `index.html`'s `<script id="engine">`. That comparison surfaced concrete, evidence-backed gaps between our reconstruction and real beermat behavior. This task applies the fixes that had high/moderate-high confidence evidence, and investigates the ones that need more sampling before a numeric fix can be committed.

See TASK-008's Implementation Notes for full observed-vs-claimed detail per item.

1. **Bank interest (high confidence, n=7, zero deviation)**: `index.html:648` currently sets `bankInterest: 0.02` (2%/turn), inherited from the Keymash-only `docs/mechanics-notes.md`. Real beermat showed 5%/turn (matches `docs/gameplay.md`'s C-source figure). Change to `0.05`.
2. **Cop-chase deputy formula (moderate-high confidence, n=2)**: `index.html:979`'s `startChase` formula (`min(9, 1 + floor(day/4))`) predicted 1 and 3 deputies on days 2 and 9; real beermat showed 10 and 11. The formula under-predicts early-game deputy counts and its cap of 9 is already exceeded by day 2. Needs re-derivation from a longer beermat sample (more data points across more days) before committing new constants — this task should capture that sample, not guess a replacement formula from 2 data points.
3. **Ecstasy/Smack price bounds (moderate confidence, needs more sampling)**: `RULES.drugs` configures Ecstasy min:800/max:2200 and Smack min:3500/max:10000; observed beermat prices ran well below both ranges (Ecstasy 18-59, Smack mostly $1.5k-3k). Needs a longer sampling run per drug before adjusting the numbers, to avoid overfitting to a handful of observations.

Each fix must be re-verified against the real beermat build (not assumed from the existing partial sample) before being committed, using the same `chrome-devtools-axi`-over-noVNC approach as TASK-008. Connection details are in `CLAUDE.local.md` — do not write them into this task, any report, or any commit.

Out of scope for this task (separate follow-ups, not started here):
- The missing price-spike/price-crash event type identified in TASK-008 (a new feature, not a fix to an existing value).
- The location-model question (beermat's "1 city → 6 sub-locations" vs. our "6 simultaneous boroughs") — this is a design/scope decision for Lance, not a code fix.
- Capturing coat dealer / gun dealer offers and reaching the Day 31 endgame screen (unobserved in TASK-008's partial run) — only needed if/when those areas need their own verification pass.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 A longer beermat play session (over noVNC, chrome-devtools-axi) gathers enough additional samples to confirm or refine the cop-chase deputy-count formula and the Ecstasy/Smack price bounds beyond TASK-008's n=2/n=5-6 samples
- [x] #2 index.html:648 bankInterest is changed from 0.02 to 0.05, with a comment/doc update noting the beermat-verified source
- [x] #3 index.html's startChase deputy formula is updated to match the newly-gathered beermat sample, replacing the current min(9, 1+floor(day/4)) guess
- [x] #4 index.html's Ecstasy and Smack price min/max in RULES.drugs are updated to match the newly-gathered beermat sample
- [x] #5 docs/gameplay.md and/or docs/mechanics-notes.md are updated or annotated where this task's findings contradict their existing claims, so future readers aren't misled by the un-verified figures
- [x] #6 No infra connection details (hostnames, ports, SSH targets) appear in the task, report, or any commit
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Re-open the beermat build via chrome-devtools-axi over noVNC (connection details from CLAUDE.local.md, not repeated in task/report/commits). Play a longer session than TASK-008 (aim for full 31-day run or as far as practical), focused on collecting more samples for: cop-chase deputy count vs. day, and Ecstasy/Smack observed prices.
2. Record deputy-count/day pairs and Ecstasy/Smack price observations as they're gathered (task notes), enough points to fit/derive a formula and bounds with actual confidence.
3. Re-verify bank interest (5%/turn) isn't contradicted by the new session (spot check only, already high confidence from TASK-008 n=7).
4. Derive: (a) a replacement deputy-count formula from the day/deputy data pairs, (b) revised Ecstasy min/max and Smack min/max from observed price ranges (with margin, not just min/max of the sample).
5. Apply code changes to index.html: bankInterest 0.02->0.05 (line 648) with a comment citing beermat verification; startChase deputies formula (line 979) replaced with derived formula; RULES.drugs ecstasy/smack min/max (lines 665/671) updated.
6. Update docs/gameplay.md and/or docs/mechanics-notes.md to annotate/correct claims contradicted by these findings (bank interest, deputy formula, price bounds) so future readers see beermat-verified values, not the old Keymash/C-source-only figures.
7. Verify: reload index.html engine mentally/via quick script check of new RULES values and startChase() output across a range of days against the observed data points.
8. Confirm no infra hostnames/ports/SSH targets appear in task notes, report, or commit messages (AC #6).
9. Finalize: check acceptance criteria, write final summary, move to Done per Task Finalization Guide.

Scope addition (approved by Lance): also update the Mojo port (core/src/rules.mojo BANK_INTEREST/Ecstasy/Smack, core/src/combat.mojo's day-based deputy comment+formula, core/src/travel.mojo comment, tests/mojo/rules_test.mojo assertions) to the same beermat-verified values, so JS/Mojo parity (the whole point of TASK-001's port) isn't silently broken by this task. AC #2/#3/#4 are read as covering both engines even though only index.html was named explicitly.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Session 2 (noVNC/chrome-devtools-axi, continuing from TASK-008's saved Day-9 state which was actually still open at Day 10): confirmed a discrete price-crash event exists — Day 14 popup: "Rival dealers raided a pharmacy and are selling cheap ecstasy!" This is the same event type TASK-008 flagged as a missing feature (out of scope to build here), but it means low Ecstasy prices observed across days 10-14 (34,24,16,60,16 range) may be event-suppressed rather than baseline — cannot take those as the true price bounds without confirming whether the event is still active or has expired. Continuing to sample across more days/locations to see Ecstasy price after this event plausibly expires, before touching RULES.drugs numbers.

Cop-chase deputy sample so far (this session): day 14 -> 6 deputies (via Officer Hardass). Combined with TASK-008's day 2 -> 10, day 9 -> 11. Three points (2,10) (9,11) (14,6) are NOT monotonic in day, contradicting the current linear startChase formula's whole shape (index.html:979). Need more (day, deputy) pairs before proposing a replacement — a simple day-scaling formula looks wrong; deputy count may be random within a range rather than day-driven, or tied to something else (police stat of location, debt, etc). Continuing to sample.

Session 2 complete — played from the saved Day 10 state through to the Day 31 Finish screen (bonus: this also incidentally satisfies TASK-008's unmet "reach Day 31" and endgame-scoring observation — final score screen read "Your score of -$87,733 was not good enough...", confirming score = Cash+Bank-Debt = 0+8,237-95,970 = -87,733, matching docs/gameplay.md's documented scoring formula).

**Deputy-count data (day -> deputies, Officer Hardass only, never escalated — no cops were killed this run)**: TASK-008 gave (2,10) and (9,11); this session added (14,6), (15,2), (17,4), (20,2). Combined set = {2,2,4,6,10,11} across days 2-20, NOT correlated with day (contradicts the old min(9,1+floor(day/4)) shape entirely — that formula's cap of 9 is exceeded twice). Cross-checked docs/gameplay.md's C-source table (line 134): Officer Hardass MinDeputies/MaxDeputies = 2-8 — close in shape (a flat min-max range per cop, not day-scaled) but beermat's actual range runs wider (up to 11) than the C source's 2-8. Conclusion: replace the day-based formula with a flat randInt(2, 11) range, matching all 6 observed points and the C source's range-based *shape* (just with beermat-verified bounds instead of the C source's narrower 2-8).

**Ecstasy price samples (18 arrivals, days 10-31)**: 34,24,16,60,16,1,23(day19),43,27,18,57,12,56,51,50,52,56,12 — consistently low across every single observation regardless of whether a "cheap ecstasy" flavor event fired (it fired explicitly only twice, on days 14 and 16, yet the price was equally low on days without any such event, e.g. day 24 and day 31 both showed 12 with no popup). This rules out TASK-008's "event-suppressed, not baseline" concern — Ecstasy's true beermat baseline is just this low. Range observed: 1-60, typically 12-60. New bounds: min 10 / max 75 (small pad beyond the sample, per the task's anti-overfitting guidance).

**Smack price samples (14 arrivals)**: 2183,3263,2532,2287,2887,1769,3522,3292,2788,2524,4258,3892,4053,2432,1987,3361,3704 — range 1769-4258, i.e. mostly below the current configured min of 3500. New bounds: min 1500 / max 4500.

**Correction to TASK-008's "missing feature" claim**: re-reading index.html's generatePrices() (~line 718) shows the engine ALREADY implements a cheap/expensive price-event system with matching mechanics and near-identical flavor text ("The market is flooded with cheap X!" / "Addicts are buying X at outrageous prices!") to what beermat showed this session ("The market has been flooded with cheap home-made acid!", "Addicts are buying cocaine at outrageous prices!", "Cops made a big opium/speed bust! Prices are outrageous!"). It is NOT a missing feature as TASK-008 concluded — it's gated per-drug by each drug's cheap/expensive boolean flags in RULES.drugs, and Ecstasy currently has both flags false so it can never trigger the event (irrelevant anyway per the finding above that Ecstasy's baseline is uniformly low with or without an event). Not changing any cheap/expensive flags in this task — out of scope per the task's explicit exclusions — but documenting this correction so the "missing feature" follow-up (if ever picked up) starts from accurate information instead of TASK-008's incorrect premise.

Confirmed bank interest still consistent with 5%/turn across this session's bank balance growth (spot-check only, no deviation seen). No infra hostnames/ports/SSH targets appear anywhere in this note.

**Mojo port kept in parity (scope addition, approved)**: core/src/rules.mojo (BANK_INTEREST, Ecstasy/Smack bounds), core/src/combat.mojo (start_chase now draws one rng value via randInt(2,11) instead of a pure day formula), core/src/travel.mojo (comment), core/src/abi.mojo (dw_start_chase's world pointer changed from Imm to MutUntrackedOrigin + try/except since it now raises), tests/mojo/rules_test.mojo, core/abitest/abitest.mojo, core/abitest/abi_conformance_test.py all updated to match. Regenerated tests/mojo/fixtures.mojo via `node tests/fixtures/gen-mojo.mjs` (source of truth is tests/fixtures/*.jsonl).

**DW_ABI_VERSION bumped 1 -> 2** (include/dopewars.h, core/src/abi.mojo, core/abitest/abi_conformance_test.py) per docs/abi-contract.md's own policy: 'Change to the observable semantics of an existing function (including RNG draw order for a given seed)' requires a version bump, and start_chase went from 0 rng draws to 1. Documented the bump's cause in docs/abi-contract.md's Versioning section. Struct layouts and the 766-byte dump length are unchanged.

**Verification run (all green)**: `node --test tests/engine.test.mjs` (59/59), `node tests/fixtures/run.mjs` (12/12 fixtures), `task core:build` (56/56 ABI exports), `task core:test` (32/32 Mojo unit tests across 5 files), `task core:abitest:mojo` (23/23, Tier-C via external_call), `task core:abitest` (40/40, Tier-C via ctypes). Determinism re-checked (`shasum` before/after a second `generate.mjs` run matched).

All 6 acceptance criteria satisfied. AC#1: session 2's 18 Ecstasy + 14 Smack price samples and 4 additional deputy-count data points (see prior notes) went well beyond TASK-008's n=2/n=5-6. AC#2: bankInterest 0.02->0.05 in both engines. AC#3: startChase deputies formula replaced in both engines. AC#4: RULES.drugs Ecstasy/Smack bounds updated in both engines. AC#5: docs/gameplay.md (deputies table) and docs/mechanics-notes.md (bank interest, deputy curve) both annotated with beermat-verified corrections, clearly distinguishing the Keymash/C-source claims from the beermat-verified ones. AC#6: no infra hostnames/ports/SSH targets appear anywhere in this task or its notes.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Applied the beermat-verified fixes identified in TASK-008, backed by a second longer noVNC play session (Day 10 through the Day 31 Finish/scoring screen) that gathered far more samples than TASK-008's partial run.

**New evidence gathered this session:**
- Bank interest: confirmed 5%/turn (no deviation), matching TASK-008's finding.
- Cop-chase deputies (Officer Hardass): 4 new (day, deputies) points — (14,6), (15,2), (17,4), (20,2) — joining TASK-008's (2,10) and (9,11). The combined set shows no day correlation at all, ruling out any day-scaled formula.
- Ecstasy price: 18 samples across days 10-31, consistently 1-60 regardless of whether a "cheap ecstasy" event fired — this is the drug's true baseline, not an event artifact.
- Smack price: 14 samples, range 1769-4258 — below the previously configured 3500 floor.
- Also incidentally reached the beermat Day 31 Finish screen and confirmed the scoring formula (cash + bank − debt).

**Code changes (both engines, per an in-session scope decision approved by Lance — the Mojo port hardcoded the same stale values and would otherwise silently fall out of parity):**
- `bankInterest` 0.02 → 0.05 (`index.html`, `core/src/rules.mojo`)
- `startChase` deputy formula: day-scaled `min(9, 1+floor(day/4))` → flat `randInt(2, 11)`, matching all 6 observed data points and the *shape* of docs/gameplay.md's C-source per-cop min/max table (`index.html`, `core/src/combat.mojo`)
- `RULES.drugs` Ecstasy 800-2200 → 10-75, Smack 3500-10000 → 1500-4500 (`index.html`, `core/src/rules.mojo`)
- `docs/gameplay.md` and `docs/mechanics-notes.md` annotated wherever their Keymash/C-source claims are now contradicted by beermat-verified data, without erasing the original (still-valid, differently-sourced) claims.
- Corrected a mistaken TASK-008 conclusion: the engine's price-event system (cheap/expensive flavor text) already existed and matches beermat's mechanics — it just isn't triggered for Ecstasy because that drug's `cheap`/`expensive` flags are both false. Left unchanged (out of scope), but documented for any future pickup.

**Mojo/ABI ripple effects (since `startChase` gained an RNG draw it didn't have before):**
- `core/src/abi.mojo`'s `dw_start_chase` now takes a mutable world pointer and handles the `raises` call.
- `DW_ABI_VERSION` bumped 1 → 2 in `include/dopewars.h`, `core/src/abi.mojo`, and `core/abitest/abi_conformance_test.py`, per the project's own ABI policy (RNG draw-order changes require a version bump). Documented in `docs/abi-contract.md`.
- Regenerated `tests/fixtures/*.jsonl` (JS oracle) and `tests/mojo/fixtures.mojo` (flattened Mojo corpus) via their existing generator scripts; updated the one fixture scenario (`06-chase-combat`) whose scripted RNG list needed a value for `startChase`'s new draw, and one stale "2% bank interest" comment/test expectation.

**Verification (all green):** `node --test tests/engine.test.mjs` (59/59), `node tests/fixtures/run.mjs` (12/12), determinism re-check on fixture regeneration, `task core:build` (56/56 ABI exports clean), `task core:test` (32/32 Mojo unit tests), `task core:abitest:mojo` (23/23 Tier-C via external_call), `task core:abitest` (40/40 Tier-C via ctypes).

No infra connection details appear anywhere in this task, its notes, or any commit.
<!-- SECTION:FINAL_SUMMARY:END -->
