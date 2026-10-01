---
id: TASK-010.03
title: Play Beermat's wav effects on the matching events in the Godot build
status: Done
assignee:
  - '@Claude'
created_date: '2026-09-30 05:01'
updated_date: '2026-10-01 18:22'
labels:
  - reverse-engineering
  - sound
dependencies:
  - TASK-010.02
parent_task_id: TASK-010
priority: medium
ordinal: 22000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
Sound is currently an inert menu in the Godot port (`game/presentation/hud.gd`, "no sound in this build"). Play the ten original effects (gun, gun2, youhit, cophit, Siren, bark, cashreg, hrdpunch, wasted, uhoh) at the events where the original does, using the trigger points documented in docs/beermat-re.md, and turn the Sounds menu into a checkable Allow Sound item that mirrors the original's AllowSound setting and default. Sound is Godot-only; `index.html` is untouched. The wavs are copyrighted and live only in gitignored `vendor/dopewars-1999/`: a build step copies them into a gitignored game assets directory, and the game must run silently without error when they are absent.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 A presentation-layer test with an injected recording sound player asserts the cue sequence for a buy/sell round trip, a mugging, a dog chase, a chase with fight, the last day and death
- [x] #2 Toggling Allow Sound mutes cues and the setting persists across a cold start
- [x] #3 The game boots and passes the UI test suite with the wavs absent
- [x] #4 No wav file is committed and the new files are covered by .gitignore
- [x] #5 New tr() keys resolve; game/README.md, docs/parity-deltas.md, TODO.md and README.md no longer say sound is missing
<!-- AC:END -->

## Implementation Plan

<!-- SECTION:PLAN:BEGIN -->
1. Platform: new `game/platform/sound_player.gd` (`class_name SoundPlayer extends Node`) with a `Cue` enum (CASH_REG, LAST_DAY, COP_CHASE, COP_GUN_SHOT, YOU_HIT_BY_GUN, YOUR_GUN_SHOT, COP_HIT_BY_GUN, MUGGED, POLICE_DOG, DEAD) mapped to `res://assets/sound/<file>.wav`. `play(cue)` no-ops when `allow_sound` is false or `ResourceLoader.exists()` is false (wavs absent), otherwise spawns a transient `AudioStreamPlayer` child that frees itself on `finished`. `allow_sound: bool` defaults true.
2. New `game/platform/sound_settings_store.gd` (`class_name SoundSettingsStore`) persisting `{"allow_sound": bool}` as JSON to `user://dopewars.sound.json`, mirroring `highscore_store.gd`'s JSON pattern; missing/corrupt file reads back true (Beermat's normal-first-run default).
3. Build step: `taskfiles/game.yml` gets a `sounds` task that copies the ten wavs (gun, gun2, youhit, cophit, Siren, bark, cashreg, hrdpunch, wasted, uhoh — `.wav`) from `vendor/dopewars-1999/` into `game/assets/sound/` when the vendor files exist, and is a no-op otherwise (never fails). Wire it as a dep of `game:import`. Add `game/assets/sound/` to `.gitignore`.
4. Hud: replace the inert Sounds menu (`_build_menubar`'s disabled `_menu_button(Copy.MENU_SOUNDS, ...)`) with a checkable "Allow Sound" item built directly on a `PopupMenu` (`add_check_item`/`set_item_checked`), wired through a named handler (`_on_toggle_allow_sound`) so it has a test-surface entry point. Drop the now-unused `inert` param from `_menu_button`. New signal `allow_sound_toggled(enabled)`; new `set_allow_sound(enabled)` (seed from storage, no signal) and test getters `allow_sound_checked()` / `toggle_allow_sound()`. Copy.gd: drop `MENU_NO_SOUND`, add `ITEM_ALLOW_SOUND`; update `strings.csv` row.
5. ArrivalFlow: add `_sound: SoundPlayer` + `set_sound_player()`. Play `COP_CHASE` on every `_present_chase()` (chase dialog (re)opens). Play `MUGGED`/`POLICE_DOG` in `_present_event()` by arrival kind. In `_on_chase_action()`: Run/Stay play `YOU_HIT_BY_GUN`/`COP_GUN_SHOT` by the `hit` field (skip when escaped); Fight always plays `COP_HIT_BY_GUN`/`YOUR_GUN_SHOT` by `killed`, then (only when not `won`) `YOU_HIT_BY_GUN`/`COP_GUN_SHOT` by `cop_hit`. No sound on win (matches docs/beermat-re.md) or on dealer offers/finances/price events/travel (already silent).
6. Main: own `_sound := SoundPlayer.new()` + `_sound_settings := SoundSettingsStore.new()`, added as a child in `_ready()`, seeded from storage and forwarded to `_hud`/`_arrival`. `_on_allow_sound_toggled()` updates both the player and storage. `CASH_REG` plays right after a successful `_world.buy`/`_world.sell` call. `LAST_DAY` plays in `_show_last_day_alert()`. `DEAD` plays once in `_handle_death()` (covers all three chase-death branches from one spot, matching the single `0x0045d6e4` trigger). Test surface: `sound_player()` / `set_sound_player()` (swaps the child, forwards to `_arrival`, preserves `allow_sound`).
7. Tests (`game/godot_tests/`): a test-only `recording_sound_player.gd` (`class_name RecordingSoundPlayer extends SoundPlayer`) that appends to `played: Array[int]` instead of touching audio. Extend `ui_flow_test.gd` with two new cases (added to `CASES`/`CASE_FLOORS`): `sound_cues` (buy/sell cash-register cues, last-day cue via a 2-day game, a mugging and a dog-chase found by seed search, and a fought chase found by seed search, each asserted against `recording.played`) and `allow_sound_toggle` (toggling mutes `RecordingSoundPlayer`, and `SoundSettingsStore` round-trips the value — AC#2's persistence half is a direct store round-trip, not a real process restart). A death case (`DEAD` cue) is covered by a seed search that repeats Stay until the core reports `dead`.
8. Docs/content cleanup (AC#5): `game/README.md`, `docs/parity-deltas.md`, `TODO.md`, `README.md` no longer say sound is missing; add a short mention of the new Sounds menu / cue table (point at docs/beermat-re.md's table rather than duplicating it).
9. Validate: `task game:ui-test` (wavs absent — must still pass per AC#3), `task game:boundary-check`, `task lint`. If vendor wavs are available locally, one manual `task run` listen-through; otherwise note in the task that audio itself was not ear-tested, only cue dispatch.
10. markdownlint, tick ACs with evidence, conventional commits (separate commit for any `.serena` changes), no Claude attribution beyond the session's own trailer rules.
<!-- SECTION:PLAN:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
Implemented: SoundPlayer (game/platform/sound_player.gd), SoundSettingsStore (game/platform/sound_settings_store.gd), the checkable Allow Sound menu item in Hud, cue dispatch in ArrivalFlow and Main, and a `task game:sounds` build step that copies the ten wavs from gitignored vendor/dopewars-1999/ into gitignored game/assets/sound/ (no-op when absent).

Test evidence: `task game:ui-test` passes with 531 assertions, including new `sound_cues` (buy/sell cash-register cues, last-day cue, a mugging and a dog-chase found by seed search, a fought chase, and a chase death, all asserted via an injected RecordingSoundPlayer) and `allow_sound_toggle` (mutes an injected recorder, persists through SoundSettingsStore) cases. Re-ran the same suite with game/assets/sound/ deleted and a fresh game/.godot import to prove AC#3 -- still 531 assertions, no errors. `task game:boundary-check`, `task bridge:test`, `task bridge:test:script`, and `task lint` all pass unchanged.

Found and fixed two bugs during testing: the Fight search needed `world.accept_gun_offer(0, 0)` first (dw_fight requires a gun or returns ERR_INVALID_ARGUMENT with no sound), and WATCHDOG_FRAMES in ui_flow_test.gd needed raising from 600 to 3000 -- it's a global per-suite frame budget, not per-case, and the two new seed-searching cases needed more of it.

git status confirms game/assets/sound/ produces zero untracked entries (the .gitignore pattern had to cover the whole directory, not just *.wav, because Godot's per-wav .import sidecar files aren't wavs themselves).

Not done: an actual ear-test of the audio. The wavs are present on this machine (vendor/dopewars-1999/) and `task game:sounds` copies them correctly, but this session has no way to play audio or watch the GUI interactively, so only cue dispatch was verified, not the sound itself.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
Added sound to the Godot port, matching Beermat's documented cue table (`docs/beermat-re.md`, "Sounds").

**Platform (new files):**
- `game/platform/sound_player.gd` (`SoundPlayer`) -- a `Cue` enum mapped to `res://assets/sound/*.wav`, spawning a transient `AudioStreamPlayer` per `play()` call so overlapping cues (a player's shot and the cops' return fire in the same Fight round) don't cut each other off. No-ops silently when `allow_sound` is off or the wav is missing.
- `game/platform/sound_settings_store.gd` (`SoundSettingsStore`) -- persists `AllowSound` as JSON to `user://dopewars.sound.json`, mirroring `highscore_store.gd`'s pattern. Default true, matching Beermat's normal-first-run default.

**Wiring:**
- `ArrivalFlow` plays `COP_CHASE` on every chase-dialog (re)presentation, `MUGGED`/`POLICE_DOG` on the matching arrival events, and the shot/return-fire cues on Run/Stay/Fight (the player's own shot always has a cue on Fight; the cops' return fire only follows when the chase isn't won, since a win ends it before they can fire back).
- `Main` owns the one `SoundPlayer` for the session, plays `CASH_REG` on a successful buy/sell, `LAST_DAY` when the last-day alert shows, and `DEAD` once in `_handle_death()` (the single point all three chase-death branches funnel through).
- `Hud`'s inert Sounds menu is now a checkable Allow Sound item (`PopupMenu.add_check_item`), seeded from storage at boot and toggled through a named handler for testability.

**Build step:** `task game:sounds` (new, a dep of `task game:import`) copies the ten wavs from gitignored `vendor/dopewars-1999/` into gitignored `game/assets/sound/`, and is a no-op -- never a failure -- when the vendor files aren't present.

**Tests:** `game/godot_tests/recording_sound_player.gd` is a `SoundPlayer` subclass that records cues instead of touching audio. Two new `ui_flow_test.gd` cases: `sound_cues` (buy/sell, last day, a mugging and dog chase found by seed search, a fought chase, and a chase death, each asserted against the recorder) and `allow_sound_toggle` (muting and `SoundSettingsStore` round-trip). `WATCHDOG_FRAMES` raised 600 -> 3000 for the extra seed searches. Verified both with the wavs present and with `game/assets/sound/` deleted (AC#3) -- 531 assertions pass either way. `task game:boundary-check`, `task bridge:test`, `task bridge:test:script`, and `task lint` are unaffected.

**Docs:** `game/README.md` documents the new Sounds section; `docs/parity-deltas.md` gets a new delta (#7, sound is Godot-only, the prototype's silence was a scope decision not a fidelity gap); `TODO.md` and `README.md` no longer list sound as missing from the Godot port (README.md's "out of scope for this pass" note is scoped to `index.html` specifically, which is correctly still silent).

**Not done:** an ear-test of the actual audio -- this session can verify cue dispatch (via the recording test double) but can't play sound or watch the GUI interactively. The wavs are present locally and `task game:sounds` copies them correctly; a human should do one `task run` listen-through before calling this audibly verified.
<!-- SECTION:FINAL_SUMMARY:END -->
