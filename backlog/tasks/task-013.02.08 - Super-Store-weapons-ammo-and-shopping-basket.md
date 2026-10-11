---
id: TASK-013.02.08
title: 'Super Store: weapons, ammo and shopping basket'
status: To Do
assignee: []
created_date: '2026-10-11 04:02'
labels:
  - beermat-2.1
milestone: m-4
dependencies:
  - TASK-013.02.01
documentation:
  - docs/beermat-2.1-re.md
  - docs/beermat-re.md
parent_task_id: TASK-013.02
ordinal: 61000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
2.0 added the Dope Wars Super Store for buying guns and ammo, replacing the random gun dealer visit of 1.2 (the 1.2 gun dealer offers one gun for 301 to 550). The 2.1 store dialog has a weapons list and an ammo list, each with an add-to-cart button, a shopping basket with remove, cash remaining, Checkout and Cancel. The main window shows a weapon rack (counts per weapon) and a Store button. Implement the catalogue (weapon and ammo names, prices, which weapons exist per the findings, including the joke or real weapon question), inventory of weapons and ammo in the core, checkout (atomic, from cash), the Store button and dialog, and the weapon rack on the HUD. Whether the 1.2 gun dealer visit disappears or remains is decided by the findings; this slice does the same. Do not implement combat use here; that is the chase slice.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 The core holds per-weapon counts and ammo and exposes the catalogue with prices as rules data
- [ ] #2 Checkout is atomic: it succeeds only if the whole basket is affordable, otherwise nothing changes
- [ ] #3 The Store button opens a dialog with weapon and ammo lists, basket, cash remaining, remove, checkout and cancel
- [ ] #4 The HUD shows the weapon rack from core state
- [ ] #5 The 1.2 gun dealer visit is removed or kept as the findings dictate, and affected fixtures or tests are updated
- [ ] #6 Mojo tests cover catalogue, basket totals, checkout success and failure; game:ui-test covers the dialog and rack; save round trip includes inventory
<!-- AC:END -->
