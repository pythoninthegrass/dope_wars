---
id: TASK-013.02.07
title: 'Hospital: buy back health points'
status: Done
assignee: []
created_date: '2026-10-11 04:02'
updated_date: '2026-10-19 03:29'
labels:
  - beermat-2.1
milestone: m-4
dependencies:
  - TASK-013.02.01
documentation:
  - docs/beermat-2.1-re.md
  - docs/beermat-re.md
parent_task_id: TASK-013.02
ordinal: 60000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
2.0 added a Hospital button ("Visit the hospital"). The dialog reads "Welcome to my surgery! Not feeling well, huh? I can fix you up for a MERE $300 per HEALTH POINT. You CAN afford to be fully restored at a cost of $N", with a "How many do you wish to buy?" quantity box. 1.2 only heals through the post-chase doctor offer (1,000 to 1,999 for a full restore). Add a hospital action to the core (price per point and any limits from TASK-013.01.04, health capped at 100, paid from cash), a Hospital button on the main window, and the dialog. Whether the post-chase doctor offer survives in 2.1 is decided by the findings; record the decision here in the implementation notes.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 The core lets the player buy health points at the documented price, capped at full health and at what cash allows
- [ ] #2 The Hospital button opens a dialog showing the per-point price and the cost of a full restore, and the quantity box validates input
- [ ] #3 Whether the 1.2 post-chase doctor offer is kept or removed follows the findings, and the 1.2 fixtures or tests that depended on it are updated
- [ ] #4 Mojo tests cover buying, capping and insufficient cash; game:ui-test covers the dialog
- [ ] #5 Strings are tr() keys
<!-- AC:END -->

## Implementation Notes
<!-- NOTES:BEGIN -->
- Core: `core/src/hospital.mojo` `buy_health` (price = `health_price_multiplier` * 50, cap at full health and cash, then nasty-doctor roll); `world.mojo` adds `health_price_multiplier` + `infected`; `serialize` DUMP_LEN 1285 -> 1294; ABI `dw_buy_health`/`dw_health_price`.
- Presentation: `HospitalDialog` (shows per-point price + cost to full restore, spinner caps at min(affordable, 100-health), Buy disabled at full health), hospital button in `hud.gd`, `_do_hospital` wired in `main.gd`, `BTN_HOSPITAL`/`DLG_HOSPITAL`/`MSG_HOSPITAL_OFFER` tr() keys.
- AC#3 decision: the 1.2 post-chase doctor offer is KEPT (unchanged). Beermat 2.1's chase-win reward is "cash only, no gun and no doctor offer" (`docs/beermat-2.1-re.md` M-09), but the doctor offer is a separate post-chase interaction, not the chase-win reward itself, and no 2.1 finding removes it. `doctor_dialog.gd`/`main.gd` are untouched. The 1.2 doctor fixtures/tests that depended on the offer still pass unchanged.
- AC#4: 11 Mojo tests (buy/cap/insufficient cash/nasty-doctor), `game:ui-test` covers the dialog.
- Docs: `docs/beermat-2.1-re.md` "Hospital" section records the price formula, nasty-doctor (N-31 partly decoded), and this doctor-offer decision.
<!-- NOTES:END -->
