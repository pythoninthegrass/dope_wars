---
id: TASK-006.03
title: 'Finances loan shark rows: hover grey and invisible selection'
status: Done
assignee: []
created_date: '2026-10-19 03:42'
updated_date: '2026-10-19 03:46'
labels: []
milestone: TASK-013 - Adopt Beermat Dope Wars 2.1 as the fidelity target
dependencies: []
parent_task_id: TASK-006
priority: medium
type: bug
ordinal: 83000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
The Finances dialog's two Trees (outstanding loans and loan shark offerings) mis-render selection and hover. Hovering a loan shark name shows a barely-visible grey bar; clicking a row makes its name turn invisible and unselectable. The main window's market/coat tables paint their navy selection per-cell, but FinancesDialog never does, and the shared theme suppresses Tree hover.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 - [x] #1 Selecting a loan shark row in either Finances table renders the same navy highlight (Palette.ROW_SELECTED bg / ROW_SELECTED_TEXT fg) as the main window tables, per-cell across all columns
- [x] #2 - [x] #2 No grey hover highlight appears on hover in any game table (prototype styles no table-row hover)
- [x] #3 - [x] #3 A ui-flow regression in game/godot_tests/ui_flow_test.gd pins the selected-row colors and the suppressed hover theme setting
<!-- AC:END -->

## Definition of Done
<!-- DOD:BEGIN -->
- [x] #1 Hover is suppressed globally at the theme level (hovered stylebox empty, font_hovered_color black), not just for Finances
- [x] #2 Finances selection is painted via a small _paint_selection helper mirroring market_table.gd:120-137
- [x] #3 task check is green
- [ ] #4 - [ ] #1 Hover is suppressed globally at the theme level (hovered stylebox empty, font_hovered_color black), not just for Finances
- [ ] #5 - [ ] #2 Finances selection is painted via a small _paint_selection helper mirroring market_table.gd:120-137
- [ ] #6 - [ ] #3 task check is green
<!-- DOD:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
"## Root cause\n\nTwo separate engine-default styleboxes leaked through the shared theme for the Finances dialog's two Trees.\n\n1. **Hover grey** — Godot's default Tree theme supplies a `hovered` stylebox (translucent grey) and `font_hovered_color`. The Win98 theme deliberately suppresses table-row hover (the prototype `index.html` styles no table-row hover; the theme docstring says \"only the menubar and the dropdowns highlight on hover\"), but never overrode `hovered`, so the faint grey bar showed on every Tree.\n\n2. **Invisible selection** — `Win98Theme._tree()` sets the Tree `selected`/`selected_focus` styleboxes to `StyleBoxEmpty` on purpose: the main-window market/coat tables paint their navy selection per-cell (`Palette.ROW_SELECTED` bg / `ROW_SELECTED_TEXT` fg, market_table.gd:120-137, coat_table.gd:120-134). FinancesDialog's `_loans_tree`/`_offers_tree` never painted per-cell, so a selected row got no background and Godot's engine-default `font_selected_color` (white) on the white table body = invisible text with no visual feedback (reads as \"unselectable\").\n\n## Fix\n\n- `game/content/win98_theme.gd` `_tree()`: `hovered` stylebox -> `StyleBoxEmpty`, `font_hovered_color` -> black. Suppresses the grey hover on *all* game tables (the main-window tables leaked it too), matching the prototype.\n- `game/presentation/dialogs/finances_dialog.gd` `_paint_selection(tree, selected)`: per-cell navy/white on the selected row, transparent/black elsewhere, mirroring market_table. Called from `_on_loan_selected`, `_on_offer_selected`, and once at build (after adding the connection) so an initially-selected row renders.\n\n## Tests\n\n`game/godot_tests/ui_flow_test.gd` finances section: asserts the selected loans/offers row carries `Palette.ROW_SELECTED` bg + `ROW_SELECTED_TEXT` fg per-cell, and that the Tree `hovered` stylebox is `StyleBoxEmpty`. Wrote the assertions first (red: 17 failures, all new), then implemented, then green (866 assertions). Full `task check` green.\n\n## Environment note\n\n`task check` reports `Failed to initialize Crashpad` before every test suite summary — Godot's crash-reporter, unrelated to this change (present on a clean checkout).",
<!-- SECTION:NOTES:END -->
