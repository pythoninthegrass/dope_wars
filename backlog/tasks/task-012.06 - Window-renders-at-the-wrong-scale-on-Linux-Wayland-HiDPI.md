---
id: TASK-012.06
title: Window renders at the wrong scale on Linux Wayland HiDPI
status: Done
assignee:
  - '@claude'
created_date: '2026-10-04 00:41'
updated_date: '2026-10-04 01:27'
labels: []
dependencies:
  - TASK-012.05
parent_task_id: TASK-012
priority: medium
ordinal: 45000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
On a Fedora 42 laptop (GNOME on Wayland, 3072x1920 panel at 1.5x fractional scaling, libdecor-drawn title bar) the exported Linux build intermittently opens as a tiny window: sometimes correct, sometimes about half the intended on-screen size, with the same binary.

Known so far (measured with a temporary probe on the laptop): Godot reports `DisplayServer.screen_get_scale()` = 2.0 (an integer, although the compositor scale is 1.5) and the window is 704x620 before `Main._constrain_window()` runs. `_constrain_window()` (game/presentation/main.gd) already scales the window by `screen_get_scale()` and pins min_size == max_size to the result; that fix (commit 20789df) was measured only on a 2x Retina macOS panel. It runs once, in `_ready()`.

Working hypothesis, unverified: a race. The size is set once in `_ready()`, probably before the Wayland window's first configure, so the compositor may reset it to the initial 704x620, and the pinned max_size then holds it there. The same behavior was reported earlier on AlmaLinux.

The window must open at its intended on-screen footprint (704x620 logical points, the same as 1x displays) every launch on Linux Wayland with integer and fractional scaling, and macOS Retina behavior must not regress.

Scope note: headless Godot has no real screen scale, so the race itself cannot be reproduced in `task game:ui-test`; the final verification is manual on a HiDPI Wayland machine and must be recorded.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 The root cause of the intermittent tiny window on Linux Wayland HiDPI is identified with measured evidence (window size reported at boot and after the first frames), not assumed
- [x] #2 The exported Linux build opens at the intended on-screen size on every one of at least 10 consecutive launches on a HiDPI Wayland display with fractional scaling, launched from a terminal in the desktop session (X display present)
- [x] #3 A game:ui-test case asserts the Linux display-driver preference is Wayland, and the case fails without the setting
- [x] #4 macOS Retina (2x) window size is unchanged, verified by a launch on macOS
- [x] #5 The window-sizing rules and the Wayland finding are documented in game/README.md or docs/build-and-test.md, without duplicating the explanation already in the _constrain_window comment
- [x] #6 `task check` stays green on macOS and on mf
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
Root cause is measured (see implementation notes): under XWayland Godot uses its X11 driver, reports screen scale 1.0, and the 704x620 window is tiny on a HiDPI panel; native Wayland reports scale 2.0 and the existing 20789df scaling works.

Approach, TDD order:
1. Failing test first: a game:ui-test case asserting ProjectSettings `display/display_server/driver.linuxbsd` == "wayland" (fails today: unset). Run it red.
2. Set `display/display_server/driver.linuxbsd="wayland"` in game/project.godot. Godot docs (tutorials/platform/linux/wayland_x11) state a Wayland-configured project falls back to X11 when Wayland is unavailable, so pure-X11 desktops still start. macOS and Windows ignore the .linuxbsd override. Run the test green.
3. Verify on the Fedora laptop with the instrumented pack (temporary probe, not committed) exactly as the user launches it: with DISPLAY set (XWayland present), the driver must come up as Wayland, scale 2.0, window ~1409x1241, over 10 consecutive launches (AC#2). Also run once with Wayland unavailable (WAYLAND_DISPLAY unset) to confirm the X11 fallback still starts the game.
4. Re-export on mf, zip, scp to the laptop's ~/Downloads, and have Lance launch it as before (`./dopewars.x86_64 --seed=42` from a terminal).
5. task check on macOS and mf (AC#6); the macOS window-size path is untouched (AC#4) -- confirm by a macOS launch.
6. Document the XWayland/native-Wayland finding and the setting in docs/build-and-test.md (AC#5), short, pointing at the _constrain_window comment instead of repeating it.
7. Conventional commit on main, no Claude attribution; close the task per the finalization guide.

Proposed AC#3 change (needs Lance's approval): the original wording (pure scale-arithmetic function test) targeted a race that was not the cause. Replace with: a game:ui-test case asserts the Linux display-driver preference is Wayland, and it fails without the setting.

AC#3 replaced with Lance's approval (2026-10-04): driver-preference test instead of a scale-arithmetic test. AC#2 now states the launch must be from a terminal in the desktop session (X display present), the case that was failing. AC#4 now says verified by a macOS launch (the arithmetic test it referenced is gone). Plan approved.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Probe 2026-10-04 (instrumented .pck exported on mf, run six times in a row on the Fedora 42 laptop from a scratch dir, `WAYLAND_DISPLAY=wayland-0`, GNOME 1.5x, 3072x1920): every run printed the same sizes at three points -- right after `_constrain_window` scaling, after 3 frames, after 1 second: win=ds=min=max=(1409, 1241), scale=2.0 (integer, though the compositor scale is 1.5). No resize, no race observed; Lance confirmed by eye that all six windows looked correct. The race hypothesis is NOT supported by this data, and AC#1 is not yet met. Open: the tiny window was seen on launches that were not this probe (earlier real-build launches from ~/Downloads); what differed (launch method, display scale setting at the time, working directory) is unknown. Minor unexplained detail: 704x620 x 2.0 should be 1408x1240 but Godot reports 1409x1241 (+1px each axis).

ROOT CAUSE (measured 2026-10-04, same instrumented pack, same laptop): it is not a race, it is the display driver. With an X display available (what a terminal in the GNOME session has: DISPLAY=:0 via XWayland), Godot picks its X11 driver: `screen_get_scale()` = 1.0, window stays (704, 620) at boot, +3 frames and +1s, min=max=(704, 620) -- tiny on a 3072x1920 panel. With no X display (my earlier ssh runs), Godot falls back to native Wayland: scale=2.0, window (1409, 1241), correct. The earlier six 'good' launches all took the Wayland path. XWayland exposes no scale to the client, so the existing screen_get_scale() fix (20789df) cannot work there. Lance confirmed the tiny window with `./dopewars.x86_64 --seed=42` from a terminal in ~/Downloads/dw/linux.

Fix committed 0ffb2b9: `display_server/driver.linuxbsd="wayland"` in game/project.godot, asserted by the new game:ui-test case `linux_display_driver` (red before the setting with exactly that one failure, green after: 540 assertions, one more than before). task check exit 0 on macOS and mf (16/94/540 assertions on both). Laptop measurement with the instrumented pack and DISPLAY=:0 (XWayland present, as in a desktop terminal): 10 of 10 launches chose driver=Wayland, scale=2.0, window (1409, 1241); before the setting the same launch gave X11, scale=1.0, (704, 620). Fallback checked: WAYLAND_DISPLAY pointed at a nonexistent socket logs 'falling back to x11', starts at (704, 620), exit 0. macOS: windowed `godot --path game --quit-after 180` exits 0; the .linuxbsd override does not apply to macOS and window_pinned still passes, but I did not measure the macOS window size, so AC#4 is not checked. AC#2 is not checked either: those 10 launches were over ssh with DISPLAY set, not from a terminal in the desktop session; Lance's own launch of the new build from ~/Downloads/dw/linux is the confirmation still pending. Release md5 d055c0a94f57cdd39da2f6ca3d7ce4b5 sent to the laptop.

Closed 2026-10-04 on Lance's instruction. AC#2: closed on that instruction without an explicit 'window looks right' report from Lance; my own evidence is the 10/10 probe launches with DISPLAY set (over ssh, not from a desktop-session terminal). AC#4: macOS windowed launch measured via System Events at 704x652 points (704x620 content + 32pt title bar), the intended size; this Mac's display may not be 2x, so the Retina path itself was not separately exercised, though no macOS code path changed (the override is .linuxbsd only).
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Root cause of the tiny Linux window: in a desktop session Godot defaulted to X11 (XWayland), which reports screen scale 1.0, so Main._constrain_window's HiDPI scaling never applied. Fix: `display_server/driver.linuxbsd="wayland"` in game/project.godot (Godot falls back to X11 when Wayland is unavailable, verified). Added game:ui-test case `linux_display_driver` (red before, green after; 540 assertions) and a docs/build-and-test.md section with the measurements and the .pck-probe technique for release builds. task check green on macOS and mf. Commit 0ffb2b9.
<!-- SECTION:FINAL_SUMMARY:END -->
