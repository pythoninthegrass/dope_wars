---
id: TASK-005
title: Pin the window size; drop resizing entirely
status: Done
assignee:
  - '@claude'
created_date: '2026-09-28 06:53'
updated_date: '2026-09-30 04:38'
labels: []
dependencies: []
documentation:
  - game/presentation/main.gd
  - game/presentation/hud.gd
  - game/project.godot
  - game/godot_tests/ui_flow_test.gd
modified_files:
  - game/project.godot
  - game/presentation/main.gd
  - game/godot_tests/ui_flow_test.gd
  - AGENTS.md
priority: medium
ordinal: 12000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
The window's height was resizable by dragging the native OS window edge, and dragging it caused visible jitter across the whole HUD.

Investigation established two things that invalidate the original framing of this task.

**1. The jitter is not Godot's deferred container sort, and it is not fixable from our code.** A live view/layer dump of the running window (Godot 4.7.1, Metal 4.0, Forward+) shows Godot renders into a `CAMetalLayer` on an *unflipped* content view (`AccessKitSubclassOfGodotContentView`, `flipped=false`, so the origin is bottom-left):

```
view  AccessKitSubclassOfGodotContentView  flipped=false  redraw=.duringViewResize
layer CAMetalLayer  gravity=resize  needsDisplayOnBoundsChange=true
```

When the window grows downward AppKit keeps the existing Metal drawable pinned to the bottom edge, so one frame composites with the entire HUD displaced by the full size delta and undrawn black under the title bar. This is Godot's own view/layer configuration, it affects the native drag and any programmatic resize equally, and replacing the native drag with an in-game control could never have fixed it.

Measured over twelve keyboard-driven 16px steps, from a 30fps screen recording, counting frames whose content is displaced:

| resize path | displaced frames /12 | max displacement |
| --- | --- | --- |
| `Window.size` | 7 | 16px |
| AppKit `animator()`, duration 0 | 5 | 16px |
| AppKit `animator()`, duration 0.017 | 2 | 2px |
| AppKit `animator()`, duration 0.05 | 3 | 2px |
| AppKit `animator()`, duration 0.10 | 5 | 2px |
| AppKit `animator()`, duration 0.20 | 0 | 0 |
| `CATransaction` wrapping `RenderingServer.force_draw` | 11 | 16px |
| the same plus `CAMetalLayer.presentsWithTransaction` | 5 | 16px |

Only AppKit's ~0.2s animated resize is clean, and it blocks the event loop for twelve frames per step, so a continuous drag cannot use it. A flash-free resize and a pointer-tracking drag are mutually exclusive here.

**2. There is nothing to resize for.** Both tables cap at the twelve drugs of `DW_NUM_DRUGS`: four boroughs (Bronx, Ghetto, Central Park, Coney Island) carry `maxDrugs: 12` and can trade every drug at once, and the coat table holds at most one row per drug. Measured against the real scene and theme, twelve rows occupy 236px inside the 329px the tables already get at the base 620px window, with no scroll. The base window already covers the largest state the game can reach; `project.godot`'s header said so all along.

So the fix is to make the window a fixed size and remove resizing from the game entirely: `window/size/resizable=false` and `window/size/maximize_disabled=true`, and no in-game height control.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 The window cannot be resized by the player: the native OS drag edge is off (window/size/resizable=false) and the maximize/full-screen button is disabled (window/size/maximize_disabled=true)
- [x] #2 No in-game height control ships: no drag handle or edge strip, no +/- height keys in game/platform/input_router.gd, and no window-height persistence
- [x] #3 Both tables render the maximum twelve drugs (DW_NUM_DRUGS) at the fixed window height with no scrolling and no clipping, verified against the real scene rather than from layout rects alone
- [x] #4 game/godot_tests/ui_flow_test.gd covers the twelve-row case and no longer carries window-height cases
- [x] #5 The project.godot header, game/README.md and docs/layer-boundaries.md describe a fixed window and carry no in-game resize control
- [x] #6 The extension is 1:1 ABI forwarding again: no platform glue, no Swift, and extension/SConstruct builds no non-C++ sources
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Revert the in-game resize feature: delete `game/presentation/height_edge.gd`, `game/platform/window_chrome.gd`, `game/platform/window_store.gd` and their `.uid` files; drop the `DopeWarsPlatform` C++ class, `extension/platform/macos_window.swift` and the Swift rule in `extension/SConstruct`; restore `main.gd`, `input_router.gd`, `ui_flow_test.gd`, `game/README.md`, `docs/layer-boundaries.md` and `.gitignore`.
2. Keep only `window/size/resizable=false` and `window/size/maximize_disabled=true` in `project.godot`, and rewrite its header to describe a fixed window.
3. Add a ui_flow_test case that boots a seed trading all twelve drugs (seed 1 does) and asserts both tables show twelve rows with no scroll, so the fixed height stays honest if a row's height ever changes.
4. Verify with `task check`.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Implemented on branch feat/task-005-height-handle (uncommitted). New: game/presentation/height_grip.gd, game/platform/window_store.gd. Changed: main.gd, hud.gd (footer row: grip + spacer), input_router.gd (+/= and -), project.godot (window/size/resizable=false), game/README.md, ui_flow_test.gd (window_resize_bounds replaced by five window_height_* cases). task check exits 0; ui-test 518 assertions.

Deviations from the approved plan: focused Up/Down on the grip dropped (global +/- covers keyboard, YAGNI). Unresizable is set declaratively via project.godot rather than window.unresizable, because a headless root window cannot report window flags, so a runtime flag cannot be asserted. _constrain_window now derives the base size from ProjectSettings instead of window.size so a second Main (cold start) does not inherit an already-grown window.

Live macOS verification (real windowed run, osascript via Bash since the osascript MCP was not loaded this session; Quartz CGEvent for mouse): keyboard steps 652->700->745 (cap)->652 (base); AX set-size refused on both axes (a max_size clamp alone would have returned 745 for a 900 request); real mouse drag on the grip moved height in monotonic 3px steps tracking the pointer; height persisted on release and on close, and a relaunch restored it.

AC#4 (no visible jitter) left unchecked: there is no OS live-resize loop in the path any more and sampled sizes were monotonic, but jitter is a visual property and nobody has watched it. Needs an eyeball pass by Lance.

Round 2 (Lance's feedback + dw_resize.mp4). Done: invisible 8px HeightEdge along the whole bottom (presentation/height_edge.gd, child of Main, no overlap with the footer, asserted in ui-test); grip removed; maximize/full-screen disabled (display/window/size/maximize_disabled, AX shows the full screen button enabled=false); task check exit 0, ui-test 520 assertions.

Jitter root cause (measured, not the task description's deferred container sort): every Window.size change on macOS gives exactly one frame with all content displaced by the step (down on grow, up on shrink, black gap under the title bar). Godot's window/viewport/HUD sizes are already correct in that frame (logged per frame). Reproduced with a keyboard-step screen recording (scratchpad harness: ffmpeg avfoundation + per-frame LED-row offset). Ruled out by measurement, all still 16px: stretch mode disabled, GL compatibility renderer, vsync off, RenderingServer.force_draw after the resize, CALayer contentsGravity (topLeft and center), NSView.layerContentsPlacement, setFrame display:false. Fixed: AppKit-driven resize, setFrame(display:true, animate:true), via a Swift shim (extension/platform/macos_window.swift, DopeWarsPlatform.set_window_content_height, WindowChrome). Discrete +/- steps: 0 displaced frames over 12 steps in the recording. Documented in docs/layer-boundaries.md (Platform glue).

OPEN: the continuous drag still uses the plain Window.size path, so it still shows the displaced frame per resize, because animate:true blocks the event loop (a fast scripted drag only registered +8px). AC#4 and AC#12 stay unchecked until the drag path is resolved; Lance to decide the approach.

Root-cause and revert session (2026-09-29). Superseded the earlier REVISION plan, which attributed the jitter to Godot's deferred container sort and to macOS showing the previous frame bottom-anchored. The first attribution is wrong; the second is right about the symptom but was chased through the wrong knobs. `CALayer.contentsGravity` and `NSView.layerContentsPlacement` are dead ends because the stale pixels are a Metal drawable, not layer `contents`. `CATransaction` is a dead end because a Metal present is asynchronous and does not join the transaction; opting the layer in with `presentsWithTransaction` did not change that, because Godot's present path does not cooperate.

The measurement harness is a 30fps `avfoundation` screen capture cropped to the window, with a Python/numpy pass that tracks the HUD LED's y position per frame and counts frames deviating from the modal position. Twelve `+`/`-` keypresses per run. The `ffmpeg` screen device index is not stable across sessions; resolve it from `ffmpeg -f avfoundation -list_devices true -i ''`.

Twelve-row measurement: booted the real `main.tscn` headless, swept seeds until `MarketTable.row_count() == 12` (seed 1), then read the Tree geometry -- `tree size=(336, 329)`, `content_bottom=236`, `scroll=(0, 0)`. The coat table is the same Tree at the same size and caps at the same twelve rows.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Pins the window at one fixed size and removes resizing from the game entirely.

## Why

Two findings, both measured, retired the feature this task originally asked for.

The HUD jitter on resize is Godot's macOS renderer, not our layout. A live dump of the running window shows Godot rendering into a `CAMetalLayer` on an unflipped content view, so a window growing downward keeps the old Metal drawable pinned to the bottom edge and composites one frame with the whole HUD displaced by the size delta and undrawn black under the title bar. It hits the native drag and any programmatic resize equally, so replacing the native edge with an in-game control — the task's original premise — could never have fixed it. Eight resize paths were measured over twelve 16px steps from a screen recording; only AppKit's ~0.2s animated resize is clean, and it blocks the event loop for twelve frames per step, so a flash-free resize and a pointer-tracking drag are mutually exclusive.

And there was nothing to resize for. Both tables cap at the twelve drugs of `DW_NUM_DRUGS`, and twelve rows measure 236px inside the 329px the tables already get at the base 620px height, with no scroll. `project.godot`'s header had said the height shows all twelve drugs without scrolling since the port began; it was correct.

## What changed

- `game/project.godot`: keeps `window/size/resizable=false` and `window/size/maximize_disabled=true` from the reverted work; header rewritten to state why the size is fixed and to record the macOS rendering defect so it is not "fixed" back later.
- `game/presentation/main.gd`: `MAX_HEIGHT_GROWTH` removed and `_constrain_window` now sets `max_size == min_size`, pinning both axes instead of allowing 15% of growth that nothing needs.
- `game/godot_tests/ui_flow_test.gd`: `window_resize_bounds` replaced by `window_pinned` (both axes pinned, both project settings asserted) and `tables_fit_twelve_drugs`, which boots a seed trading all twelve drugs and asserts the last row ends inside the table with zero scroll — the assertion that keeps the pinned height honest if a row's height ever changes.
- `AGENTS.md`: `SimWorld` re-exports the ABI constants with the `DW_` prefix dropped (the old wording implied otherwise), and a test scene naming a missing identifier fails at load and burns the whole `timeout` rather than failing fast.
- Reverted in full: `height_edge.gd`, `window_chrome.gd`, `window_store.gd`, the `DopeWarsPlatform` C++ class, `extension/platform/macos_window.swift` and the Swift rule in `extension/SConstruct`. The extension is 1:1 ABI forwarding again, and `docs/layer-boundaries.md` no longer needs its platform-glue exception.

## Tests

`task check` exits 0. `task game:ui-test` reports 459 assertions. `task lint` clean. The built framework was confirmed to carry no `dw_platform`/`DopeWarsPlatform` symbols, no Swift link and no `/usr/lib/swift` rpath.

## Risk

The fixed height is now load-bearing, which is why `tables_fit_twelve_drugs` asserts it rather than trusting the measurement. If the Win98 theme's row height or font ever grows, that case fails rather than the tables silently scrolling.
<!-- SECTION:FINAL_SUMMARY:END -->
