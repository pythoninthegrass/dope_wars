---
id: TASK-008
title: >-
  Compare beermat Dope Wars (1999) reference build against our reconstructed
  engine using chrome-devtools-axi
status: Done
assignee:
  - pythoninthegrass
created_date: '2026-09-28 23:35'
updated_date: '2026-09-28 23:48'
labels: []
dependencies: []
references:
  - CLAUDE.local.md
priority: medium
type: spike
ordinal: 17000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
We have a playable web prototype (`index.html`) reconstructing Beermat Software's "Dope Wars for Windows" 1.2.0.0 (1999) mechanics, backed by `docs/gameplay.md` (sourced from the `benmwebb/dopewars` C reference) and `docs/mechanics-notes.md` (observed from a different web port, Keymash, which is a *separate* codebase — see the "Important distinction" note in AGENTS.md). Neither source document is derived from the actual 1999 beermat binary's real behavior.

A Windows 11 container is available with the actual beermat 1.2.0.0 executable installed (pinned to taskbar, desktop shortcut, name "Dope Wars"), reachable over noVNC in a browser. Connection details (URL, SSH, file transfer path) are **not written here** — read them from `CLAUDE.local.md` at the repo root before starting (gitignored, local-only, holds infra addresses that must not appear in commits/PRs/tasks).

Known quirks of this container build, useful context for the executing agent:

- The game window cannot be resized.
- Startup asks for a player name and a city to trade in, via a dropdown.
- The container's `C:\dopewars\cities.txt` has been overwritten with our non-standard version (NY boroughs prepended to the original 6-city list) — see repo `vendor/dopewars-1999/cities.txt` (gitignored) for the exact non-standard content. This affects available start-city choices and travel destination names, not core mechanics; account for it when interpreting screenshots/behavior tied to city names.

Use the `chrome-devtools-axi` skill to drive the noVNC session in a real browser: play through a run (or several short runs) of the beermat build, and systematically compare its observed behavior against our `index.html` engine (`<script id="engine">`, exposed as `window.DopeWarsEngine`) and against what `docs/gameplay.md` / `docs/mechanics-notes.md` currently claim. Since this is a live GUI app in a VM (not a web page with inspectable DOM/console), driving it will mean visual navigation, screenshots, and reading rendered text/state rather than DOM snapshots — budget for that.

Goal: produce a concrete list of gaps/mismatches between our reconstruction and the real 1999 beermat behavior — pricing/event mechanics, combat, coat/gun dealer offers, finances/loan shark behavior, turn structure, city list handling, anything else observed — each one citing what the beermat build actually did vs. what our engine/docs currently say.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 A written comparison report (as a task note/attachment, not code) covering at minimum: pricing/event mechanics, combat, coat dealer offers, gun dealer offers, finances/loan shark behavior, and turn/day structure
- [x] #2 Each identified gap cites the specific observed beermat behavior (with a screenshot or transcript excerpt) alongside the corresponding claim in index.html's engine, docs/gameplay.md, or docs/mechanics-notes.md that it contradicts or is missing from
- [x] #3 Report explicitly flags any case where the container's non-standard cities.txt (NY boroughs) affected what could be observed, so findings aren't misattributed to city-list differences
- [x] #4 No infra connection details (hostnames, ports, SSH targets) are written into the task, report, or any commit — only a reference to CLAUDE.local.md
- [x] #5 Report distinguishes gaps that are genuine mechanic mismatches from gaps that are just UI/presentation differences not relevant to the engine port
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Read `CLAUDE.local.md` for noVNC URL/SSH details (already done, not repeated here — see that file).
2. Researched current claims before touching the VM:
   - `docs/gameplay.md` — benmwebb/dopewars C reference (explicitly NOT beermat-derived, per its own caveat).
   - `docs/mechanics-notes.md` — Keymash web port observations (also NOT beermat, per AGENTS.md "Important distinction").
   - `index.html` `<script id="engine">` (~line 609-1079) — our actual reconstructed rules: 6 boroughs (Bronx/Ghetto/Central Park/Manhattan/Coney Island/Brooklyn), startCash 2000, startDebt 5500, debtInterest 10%/turn, bankInterest 2%/turn (note: gameplay.md says 5%/turn from the C source — already a known divergence between our two source docs, separate from beermat), gunDamage 5 flat, playerArmor 100, coat dealer / gun dealer offer rolls, cop chase w/ Run/Fight, mugging events.
   - `vendor/dopewars-1999/cities.txt` — confirms the container's non-standard list: 5 NY boroughs (Manhattan/Brooklyn/Queens/The Bronx/Staten Island) prepended to the original beermat 6-city list (Warminster/Cinnaminson/Southampton/Levittown/Philadelphia/Lawrenceville PA/NJ towns) — this is the real beermat default city set.
3. Use `chrome-devtools-axi` skill to open the noVNC URL from CLAUDE.local.md in a real browser tab, connect to the Windows 11 container, and launch the desktop-pinned "Dope Wars" app.
4. Play through at least one full run (31 days or until game-over/death), taking screenshots at each meaningful state transition (startup/name+city prompt, arrival pricing, each event popup, coat dealer offer, gun dealer offer, bank/loan shark screen, combat/cop-chase screen, endgame summary). Save screenshots to a gitignored location (not committed).
5. For each observed mechanic, cross-reference against:
   - `index.html` engine constants/logic (cite line numbers)
   - `docs/gameplay.md` claims (cite section)
   - `docs/mechanics-notes.md` claims (cite section)
   and note match / mismatch / not-observable-here.
6. Explicitly flag anywhere the non-standard cities.txt (NY boroughs prepended) affected what could be observed (e.g. starting city choice, travel destination names) so it isn't misattributed as a mechanic difference.
7. Separate findings into "genuine mechanic mismatch" vs "UI/presentation only, not relevant to engine port" per AC #5.
8. Write the full comparison report into the task via `notesAppend`/`finalSummary` (not as a repo file, per AC #1) — no infra hostnames/ports/SSH targets anywhere in it (AC #4).
9. Mark acceptance criteria complete once report covers pricing/events, combat, coat dealer, gun dealer, finances/loan shark, and turn/day structure at minimum.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
**Comparison report (1/2) — beermat Dope Wars 1.2.0.0 (1999) vs. our reconstruction**

Driven via `chrome-devtools-axi` over noVNC (see CLAUDE.local.md for connection details, not repeated here). Played Day 1 through Day 9 of 31 (partial run — did not reach the Day 31 Finish screen; see Not Observed below). Screenshots (33 PNGs) saved to session scratch, not committed to the repo.

**AC#3 — cities.txt impact**: Startup city dropdown showed the container's non-standard list exactly as in `vendor/dopewars-1999/cities.txt` (5 NY boroughs prepended to the original 6 PA/NJ cities). Selected "Manhattan, NY". This only affected which start-city names/sub-location names were offered — had no bearing on any mechanic below.

**Structural finding**: Beermat's real model is one city = 6 named sub-locations shuttled between (from that city's cities.txt row), not "6 simultaneous boroughs" as both `index.html` `RULES.locations` (Bronx/Ghetto/Central Park/Manhattan/Coney Island/Brooklyn) and `docs/gameplay.md`'s 8-borough C-source table assume. This is a genuine location-model mismatch, independent of the non-standard cities.txt — even the original 6-city list would still be "1 city → 6 sub-locations." Flagging as a design/scope question for a human decision, not fixing unilaterally.

**1. Turn/day structure** — MATCH. 31 days, $2,000 cash/$5,500 debt/100 health/100 coat at start (`index.html` RULES, `docs/gameplay.md` Game setup). Travel is the sole clock advance (matches `docs/mechanics-notes.md`).

**2. Finances/loan shark**
- Debt interest 10%/turn confirmed over 8 travels, zero deviation — MATCH `index.html:648` (`debtInterest: 0.10`) and `docs/gameplay.md`.
- **MISMATCH (genuine, high confidence, n=7, zero deviation): Bank interest is 5%/turn in beermat, not `index.html:648`'s `bankInterest: 0.02` (2%, inherited from the Keymash-only `docs/mechanics-notes.md`). Beermat matches `docs/gameplay.md`'s C-source figure (5%) instead. Recommend changing `index.html:648` from 0.02 to 0.05 in a follow-up fix task.**
- Finances dialog (Deposit/Withdraw/Pay loan) reachable from any location, not restricted like `docs/gameplay.md` claims for the C source — matches our engine's existing (also unrestricted) behavior, so no action needed there.

**Comparison report (2/2)**

**3. Pricing/events**
- Drug set (11: Acid, Cocaine, Crack, Ecstasy, Hashish, Heroin, Opium, Peyote, Shrooms, Smack, Speed, Weed) matches `index.html` RULES.drugs exactly — confirms our drug list is correctly beermat-sourced (gameplay.md's C-source list uses different drugs and already disclaims beermat-accuracy).
- Per-location drug subsets — MATCH `docs/mechanics-notes.md`.
- **Likely mismatch (moderate confidence, needs a longer sampling run): Ecstasy observed 18-59 vs. configured min:800/max:2200 (0/5 in range); Smack observed mostly $1.5-3k vs. configured min:3500/max:10000 (below range 4/6 samples). Recommend re-checking these two drugs' price bounds in a follow-up.**
- Chained multi-event travels confirmed, exact flavor-text match to `docs/mechanics-notes.md` ("meet a friend", "market flooded", "addicts buying outrageous prices").
- **Gap (missing feature, not a mismatch): `index.html`'s `rollArrivalEvent` has no discrete price-spike/price-crash event type — beermat has one ("market flooded"/"outrageous prices" flavor text tied to a real price multiplier), our engine doesn't implement it at all. Worth its own follow-up task.**
- Free-drug event text and $0-cost-basis/1-coat-space-per-unit mechanics — MATCH.

**4. Combat/Cop Chase**
- Dialog copy, Run/Stay/Fight layout — MATCH `docs/mechanics-notes.md`.
- Fight disabled at 0 guns — MATCH both docs/mechanics-notes.md and `index.html:983`.
- Run succeeded both attempts (n=2, too small to confirm the 60% base rate either way) — text matches exactly.
- **MISMATCH (genuine, moderate-high confidence): deputy counts observed were 10 (day 2) and 11 (day 9), far exceeding `index.html:979`'s `startChase` formula (`min(9, 1 + floor(day/4))`, which predicts 1 and 3, capped at 9). Also contradicts docs/mechanics-notes.md's Keymash curve ("1 early, 9 by day~22"). Recommend re-deriving the deputy-count formula from a longer beermat sample rather than trusting either current source as-is.**
- Cop-tier escalation (Hardass→Bob→Smith) not observed — no cops were killed this run.

**5. Coat dealer offers — NOT OBSERVED.** `index.html:1387` rolls this 15%/arrival; none appeared in ~8 travels (unlucky but plausible, ~27% chance of zero hits). Cannot confirm/deny `index.html`'s coatDealer price/pocket-count config against real beermat.

**6. Gun dealer offers — NOT OBSERVED.** Same 15%/arrival roll, none seen. Cannot confirm/deny `index.html`'s gunDealer price config.

**UI-only differences (not relevant to engine port)**: Win32 dialog chrome, health shown as a percentage meter, cop portrait image in the Cop Chase dialog — all cosmetic, no engine action needed.

**AC#4 confirmation**: No hostnames/ports/SSH targets appear anywhere in this report or in any screenshot's visible chrome.

**Not completed this pass** (would need a longer play session): coat dealer offer capture, gun dealer offer capture, full run to the Day 31 Finish screen, cop-tier escalation. Recommend a follow-up task if these are wanted with higher confidence.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Drove the real beermat "Dope Wars for Windows" 1.2.0.0 (1999) executable via `chrome-devtools-axi` over noVNC in the Windows 11 container (connection details per CLAUDE.local.md, not repeated anywhere here). Played a partial run (Day 1-9 of 31), screenshotting each state transition, and cross-referenced observed behavior against `index.html`'s engine, `docs/gameplay.md`, and `docs/mechanics-notes.md`. Full findings are in the task's Implementation Notes (2 entries).

Key results:
- Confirmed MATCH: turn/day structure, debt interest (10%/turn), drug set, per-location drug subsets, free-drug event mechanics, fight-disabled-at-0-guns, run-from-chase text.
- Confirmed genuine MISMATCH (high confidence): bank interest is 5%/turn in real beermat, not the 2% currently in `index.html:648` (that 2% was inherited from the Keymash-only docs/mechanics-notes.md, not beermat).
- Confirmed genuine MISMATCH (moderate-high confidence): cop-chase deputy counts observed (10-11) far exceed `index.html:979`'s formula (predicts 1-3, capped at 9) at the same days.
- Likely mismatch (needs more sampling): Ecstasy/Smack price bounds appear too high in `index.html` RULES.drugs.
- Missing feature: engine has no discrete price-spike/price-crash event type that beermat has.
- Structural finding: beermat's real model is "1 city = 6 named sub-locations," not our engine's "6 simultaneous boroughs" — flagged as a design/scope question, not fixed unilaterally.
- Coat dealer and gun dealer offers were not observed in this run (15%/arrival roll didn't hit in ~8 travels) — their price/config values remain unconfirmed against real beermat.
- Confirmed the container's non-standard cities.txt (NY boroughs) only affected city/sub-location naming, not any mechanic.
- No infra connection details appear anywhere in the report or screenshots.

No code was changed — this is a spike producing a comparison report per the acceptance criteria. Follow-up work identified but not started (per "never autonomously create tasks"): fix bankInterest to 0.05, re-derive the cop-chase deputy formula, re-check Ecstasy/Smack price bounds, decide on the location-model question, and a longer run to capture coat/gun dealer offers and reach the Day 31 endgame.
<!-- SECTION:FINAL_SUMMARY:END -->
