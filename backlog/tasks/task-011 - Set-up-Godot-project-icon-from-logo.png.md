---
id: TASK-011
title: Set up Godot project icon from logo.png
status: Done
assignee:
  - pythoninthegrass
created_date: '2026-10-01 19:12'
updated_date: '2026-10-01 19:22'
labels: []
dependencies: []
references:
  - logo.png
documentation:
  - >-
    https://docs.godotengine.org/en/stable/classes/class_projectsettings.html#class-projectsettings-property-application-config-icon
  - >-
    https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_windows.html
priority: low
type: chore
ordinal: 38000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
The repo root has `logo.png` (a syringe mark, used as the GitHub/repo logo) but the Godot project at `game/` has no `application/config/icon` set in `project.godot`, so it falls back to the default Godot robot icon in the editor, the taskbar/dock, and exported builds.

Wire `logo.png` up as the project's icon per Godot 4.5 docs (`godotengine/godot-docs` via context7): `ProjectSettings.application/config/icon` is the source icon Godot loads at startup and that exporters fall back to for per-platform icons; it must be an image resource reachable via a `res://` path inside `game/`, so the PNG needs to be imported into the Godot project tree (not referenced from outside `game/`), per `AGENTS.md`'s layer-boundary rules (icon/branding assets belong under `game/content/`).

Follow this repo's existing asset-pipeline convention instead of a manual one-off copy: `taskfiles/game.yml`'s `sounds:` task is the direct analog (copies a source asset from outside `game/` into `game/assets/sound/` via `mkdir -p` + `cp`, wired as a `deps` of `import`). Compared against `~/git/mt`'s `taskfiles/tauri.yml` `icons:` task (ignoring its Tauri-specific `@tauri-apps/cli icon` generation step), the reusable pattern worth adopting is: a dedicated Taskfile target with `sources: [logo.png]` / `generates: [game/content/icon.png]` so Task's up-to-date check skips the copy unless `logo.png` actually changed, rather than hand-editing the asset once and never revisiting it.

For higher-fidelity platform icons, optionally also set `application/config/windows_native_icon` (`.ico`) and `application/config/macos_native_icon` (`.icns`) — see "Manually changing application icon for Windows" and the macOS native icon docs — but this is optional polish, not required for the base task.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 taskfiles/game.yml gains an icon task (e.g. task game:icon) that copies logo.png into game/content/, following the sounds: task's mkdir -p + cp pattern, with sources: [logo.png] and generates: [game/content/icon.png] so Task skips the copy when logo.png is unchanged
- [x] #2 The icon task is wired as a deps of game:import, matching how sounds: is wired, so a fresh checkout always has the icon available before the project is imported
- [x] #3 project.godot sets application/config/icon to the game/content/ icon's res:// path
- [x] #4 Godot editor and a headless/windowed launch (task run or task game:smoke-test) show the syringe icon instead of the default Godot icon
- [x] #5 No file outside game/ is referenced by project.godot (layer-boundary rule from AGENTS.md)
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Add `icon:` task to taskfiles/game.yml, modeled on `sounds:` (mkdir -p + cp) but with `sources: [logo.png]` / `generates: [game/content/icon.png]` for Task's up-to-date skip.
2. Add `icon` to `import:`'s `deps` alongside `sounds`.
3. Set `config/icon="res://content/icon.png"` under `[application]` in game/project.godot.
4. Run `task game:icon` then `task game:import` to produce game/content/icon.png and reimport; verify via `task game:smoke-test` (no script errors) and check .godot import cache picked up the icon (or open editor/gda to confirm visually if easy).
5. Confirm no file outside game/ is referenced by project.godot (res://content/icon.png is inside game/, sourced via the copy task rather than referenced directly).
6. Finalize: update task notes/AC, run task finalization guide.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Discovered mid-implementation that application/config/icon alone never touches the macOS Dock icon; it is only the export-time icon source.

The live Dock icon needs application/config/macos_native_icon pointing at a .icns file, applied automatically on start via DisplayServer.set_native_icon().

This conflicted with the task description framing native icons as optional polish vs AC 4 requiring a windowed launch to visually show the icon; asked the user, who chose to add .icns generation rather than relax AC 4.

Verified AC 4 empirically: launched godot --path game directly, confirmed DisplayServer.has_feature(FEATURE_NATIVE_ICON) is true in windowed mode (false under --headless), then screenshotted the Dock (temporarily disabling autohide, restored after) and saw the syringe icon replace the default Godot robot.

task game:smoke-test and task game:boundary-check both pass clean after the change; git status confirms only game/project.godot, taskfiles/game.yml, and the new game/content/icon.* files are in this task's diff.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Wired logo.png (repo-root syringe mark) up as the Godot project's icon: editor/export icon source and the live macOS Dock icon.

Changes:
- taskfiles/game.yml: new `icon` task (sources: [logo.png], generates: [game/content/icon.png, game/content/icon.icns]) that copies logo.png to game/content/icon.png and builds game/content/icon.icns via sips + iconutil (16/32/128/256/512px + @2x), mirroring the sounds task's mkdir-p + cp pattern. Wired as a deps of import alongside sounds.
- game/project.godot: sets application/config/icon=res://content/icon.png and application/config/macos_native_icon=res://content/icon.icns.

Scope note: application/config/icon only feeds the editor UI and export-time icon generation on macOS; it does not change a running process's Dock icon. That required also setting macos_native_icon, which Godot applies at runtime via DisplayServer.set_native_icon(). The task description called native icons "optional polish" while AC #4 required the windowed launch to visually show the icon -- flagged this conflict to the user, who chose to add the .icns generation rather than relax the AC.

Verification:
- task game:icon / task game:import ran clean; icon.png imports normally (icon.png.import + .godot cache entry), icon.icns is read directly by DisplayServer as a raw res:// file.
- Confirmed DisplayServer.has_feature(FEATURE_NATIVE_ICON) is true in windowed macOS runs (false headless, as expected).
- Launched godot --path game directly and visually confirmed the syringe icon in the Dock (replacing the default Godot robot), via a screenshot with Dock autohide temporarily disabled and restored afterward.
- task game:smoke-test and task game:boundary-check both pass clean.
- git status confirms only game/project.godot, taskfiles/game.yml, and the three new game/content/icon.* files are part of this task's diff.
<!-- SECTION:FINAL_SUMMARY:END -->
