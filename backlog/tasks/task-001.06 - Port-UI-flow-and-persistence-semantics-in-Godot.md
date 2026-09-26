---
id: TASK-001.06
title: Port UI flow and persistence semantics in Godot
status: To Do
assignee: []
created_date: '2026-09-26 04:34'
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
- [ ] #1 All player-facing flows are implemented: new game, buy/sell with quantity selection, travel with arrival-event display, finances dialog (deposit/withdraw/pay loan), coat-dealer and gun-dealer dialogs, chase/combat (run/fight loop), and end-of-game score screen with highscore entry
- [ ] #2 Keyboard shortcuts work: 1-6 travel, B/S/F buy/sell/finances, N new game, Enter/Esc confirm/cancel (matching index.html keyboard handling)
- [ ] #3 Save/load on travel and highscores persistence match JS prototype semantics: auto-save on travel (index.html:1541), load on boot (index.html:1546), top-10 highscores (index.html:1561); stored in Godot user:// instead of localStorage
- [ ] #4 No simulation logic appears in GDScript: all game-state mutations go through the GDExtension class; a boundary check script fails if any .gd file outside simulation/ references the GDExtension class fields directly
- [ ] #5 Regression tests cover: new game boots and renders prices; buy/sell round-trip updates UI state; travel advances day and shows arrival event; persistence round-trips a mid-game save
<!-- AC:END -->
