---
id: TASK-001.10
title: >-
  Match the Godot presentation chrome to index.html and drop the browser page
  framing
status: Done
assignee: []
created_date: '2026-09-28 02:30'
labels:
  - game
  - presentation
  - theme
dependencies: []
modified_files:
  - game/content/win95_theme.gd
  - game/content/palette.gd
  - game/content/copy.gd
  - game/presentation/hud.gd
  - game/presentation/main.gd
  - game/presentation/market_table.gd
  - game/presentation/health_bar.gd
  - game/presentation/dialogs/dope_dialog.gd
  - game/presentation/dialogs/finances_dialog.gd
  - game/translations/strings.csv
  - game/godot_tests/ui_flow_test.gd
  - game/project.godot
parent_task_id: TASK-001
priority: high
ordinal: 10000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
The Godot presentation layer shipped with a Win95 theme that never resolved: two theme lookups silently fell through to Godot's default dark styleboxes, so the window face, the titlebar and the menu strip rendered on a dark ground instead of the prototype's #c0c0c0, and the market table scrolled because its rows were a third taller than the prototype's. The browser page framing (a #2b2b2b backdrop with the 660px game window centered in it) was also wrong for a native app, as was an invented titlebar-blue button hover that index.html does not have.

The outcome is a native, full-bleed window whose chrome follows index.html: the OS draws the frame and the title, the HUD owns the client area, and every colour, font size, padding and row metric traces to a line in the prototype. All twelve drugs fit without scrolling at the default window size, and the price trend indicators read as the prototype draws them -- small, colored, and not tinting the price beside them.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Every frame the HUD draws resolves to a theme variation: a headless probe that puts each variation's consumer in the tree reports the Win95 colours, not Godot's defaults
- [ ] #2 A variation is filed under the theme item its consuming class reads (PanelContainer reads "panel", Label reads "normal"), so a PanelContainer titlebar and a PanelContainer window face both resolve
- [ ] #3 The window face, menu strip, table captions and dialog frames render on the prototype's #c0c0c0, and the table bodies are white with a 2px inset bevel
- [ ] #4 All twelve drugs are visible without a vertical scrollbar at the default 704x620 window, with rows at the prototype's ~20px pitch
- [ ] #5 The game is full-bleed: no page backdrop, no gutters, and no in-window titlebar, because the OS window draws the frame and the title
- [ ] #6 The day readout stays visible in the client area and reads "Day N of M" without repeating the game name
- [ ] #7 Buttons carry no hover colour change, which index.html does not define; only the menubar entries and dropdown items highlight, as the prototype styles those two
- [ ] #8 LED labels and values are bold monospace with the prototype's 8px side padding, the label dimmed and the value at full brightness
- [ ] #9 Price trend indicators are drawn in their own coloured cell at 0.75em, leaving the price itself black, and keep their colour when the row is selected
- [ ] #10 Every player-visible string resolves through tr(); a new or renamed copy key has a row in game/translations/strings.csv and the day string no longer contains an unquoted comma
- [ ] #11 task check passes end to end and task lint is clean
<!-- AC:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Brought the Godot presentation layer's chrome in line with index.html.

**Root cause of the dark UI.** A theme variation is looked up by name, under the theme item the consuming class reads: PanelContainer reads "panel", Label reads "normal". Two registrations broke that rule. The HUD's window face used the variation `Panel`, which was never registered as a variation at all, so a PanelContainer found nothing and fell through to Godot's default dark panel. The titlebar registered its gradient under "normal" (a Label's item) while the node wearing it was a PanelContainer. Confirmed with a headless probe that puts each variation's consumer in the tree and prints the resolved stylebox; everything else in the theme (Outset, Inset, the LEDs, TableTitle, the Tree items) was already resolving, which is why the LEDs looked right while the surrounding chrome did not.

**Native framing.** Dropped the #2b2b2b page, the 660px centered window and the in-window titlebar: a native app's frame and title are the OS's, so the HUD is now the whole client area. The day readout moved to the right of the menu strip and reads "Day N of M" rather than repeating the game name the title bar already carries.

**Row metrics.** The market table's rows were ~29px against the prototype's 20.5px, so twelve drugs scrolled. The table font is now 0.85rem, the vertical separation collapses and the cells carry the prototype's 6px side padding, which fits all twelve at the default window size.

**Fidelity items.** The window face, menu strip, table captions, white inset-framed tables and the gray column-title strip with its hairline all match; the top row sizes each panel to its own content like the prototype's `align-items: start`; buttons are 30px with the prototype's 5px/8px padding; LED text is the real Courier New Bold rather than a synthetic embolden, with 8px side padding and the label at 0.85 brightness; the health percentage is yellow on the blue fill; dialogs are capped at 26rem and their amount rows are bold.

**Two things the prototype's CSS could not express in a Tree cell.** A cell is one colour, so the trend indicator became its own narrow column: coloured green/red/gray, set at 0.75em in a family that actually carries those geometric shapes (Tahoma, Verdana and Godot's own fallback do not, and SystemFont resolves to one family without merging coverage), leaving the price black and the column wide enough for the glyph plus cell padding, without which the Tree drops the cell text. The indicator keeps its colour on a selected row, as the prototype's class-specific color outranks the row's white.

**Verification.** `task check` passes end to end (parity replay, ABI gates, conformance, boundary check, both bridge tests, 333-assertion ui flow test, build, headless smoke) and `task lint` is clean. Chrome DevTools captured the prototype at the same 704x620 for pixel comparison, and Godot's own frames were rendered with `--write-movie`; the market and prices match the prototype exactly for the same seed.
<!-- SECTION:FINAL_SUMMARY:END -->
