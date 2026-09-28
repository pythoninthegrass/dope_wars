---
id: TASK-005
title: Replace native window live-resize with an in-game height control
status: To Do
assignee: []
created_date: '2026-09-28 06:53'
labels: []
dependencies: []
documentation:
  - game/presentation/main.gd
  - game/presentation/hud.gd
  - game/project.godot
  - game/godot_tests/ui_flow_test.gd
priority: medium
ordinal: 12000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
The window's height is currently resizable by dragging the native OS window edge: `game/project.godot`'s `window/stretch` settings plus `Main._constrain_window()` (`game/presentation/main.gd`) pin the width (`min_size.x == max_size.x`) and cap the height at 15% over the base 620px (`Main.MAX_HEIGHT_GROWTH`), so only `hud.gd`'s market/coat tables (`SIZE_EXPAND_FILL`) and the footer row below them (new game/exit) are meant to grow.

In practice, dragging the OS window edge causes visible jitter across the whole HUD — not just the tables and footer — before it settles into the correct layout. This was investigated in a prior session: `hud.gd`'s container tree is already correctly scoped (only `tables` carries `SIZE_EXPAND_FILL`; the menubar, LED row, subway/finish panel, and action row all keep their minimum size and never move), and there is no custom resize-handling code anywhere in `presentation/`, `platform/`, or `content/`. The jitter comes from Godot's `Container` using a deferred (`call_deferred`) child-sort rather than a synchronous one: a native live-resize drag (especially macOS's NSWindow tracking loop) can fire size-change notifications faster than Godot's idle/process cycle drains them, so the whole container tree renders against stale/partially-applied rects for a frame or two before the queued sorts catch up. There is no public GDScript API to force an immediate synchronous re-sort, so this can't be fixed by adjusting container flags — it requires not going through the OS's live-resize loop at all.

The fix is to stop using native OS window dragging for this and drive the height change ourselves: make the window non-resizable via the OS, and add an in-game control (e.g. a drag handle or +/− stepper) that grows/shrinks the window height between the base size and the existing +15% cap, one frame at a time, under our own code. Because we'd own every frame of the animation, only the tables and footer would ever need to repaint, and there's no OS tracking loop to race against.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 The window is no longer resizable by dragging a native OS window edge (both axes are pinned, e.g. min_size == max_size)
- [ ] #2 An in-game control (visible in the HUD) lets the player grow the window height from the base size up to +15% (Main.MAX_HEIGHT_GROWTH), and shrink it back down
- [ ] #3 Using the control changes only the two tables' and the footer row's (new game/exit) rendered size/position; the menubar, LED row, subway/finish panel, and action row stay pixel-fixed throughout the change
- [ ] #4 The height change shows no jitter or flash of an intermediate/incorrect layout at any point during the animation
- [ ] #5 The control cannot grow the window past +15% or shrink it below the base height
- [ ] #6 The control is reachable by both mouse and keyboard, consistent with the existing keyboard-shortcut coverage in game/platform/input_router.gd
- [ ] #7 task game:ui-test covers the new control: bounds enforcement, and that the fixed-vs-growing widget sets behave as specified above, replacing or extending the existing window_resize_bounds case in game/godot_tests/ui_flow_test.gd
- [ ] #8 Relevant doc comments (game/project.godot header, Main._constrain_window, or game/README.md) are updated to describe the in-game control instead of native OS live-resize
<!-- AC:END -->
