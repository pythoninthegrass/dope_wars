---
id: TASK-008
title: >-
  Compare beermat Dope Wars (1999) reference build against our reconstructed
  engine using chrome-devtools-axi
status: To Do
assignee: []
created_date: '2026-09-28 23:35'
labels: []
dependencies: []
references:
  - CLAUDE.local.md
priority: medium
type: spike
ordinal: 17000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
We have a playable web prototype (`index.html`) reconstructing Beermat Software's "Dope Wars for Windows" 1.2.0.0 (1999) mechanics, backed by `docs/gameplay.md` (sourced from the `benmwebb/dopewars` C reference) and `docs/mechanics-notes.md` (observed from a different web port, Keymash, which is a *separate* codebase — see the "Important distinction" note in AGENTS.md). Neither source document is derived from the actual 1999 beermat binary's real behavior.

A Windows 11 container is available with the actual beermat 1.2.0.0 executable installed (pinned to taskbar, desktop shortcut, name "Dope Wars"), reachable over noVNC in a browser. Connection details (URL, SSH, file transfer path) are **not written here** — read them from `CLAUDE.local.md` at the repo root before starting (gitignored, local-only, holds infra addresses that must not appear in commits/PRs/tasks).

Known quirks of this container build, useful context for the executing agent:

- The game window cannot be resized.
- Startup asks for a player name and a city to trade in, via a dropdown.
- The container's `C:\dopewars\cities.txt` has been overwritten with our non-standard version (NY boroughs prepended to the original 6-city list) — see repo `vendor/dopewars-1999/cities.txt` (gitignored) for the exact non-standard content. This affects available start-city choices and travel destination names, not core mechanics; account for it when interpreting screenshots/behavior tied to city names.

Use the `chrome-devtools-axi` skill to drive the noVNC session in a real browser: play through a run (or several short runs) of the beermat build, and systematically compare its observed behavior against our `index.html` engine (`<script id="engine">`, exposed as `window.DopeWarsEngine`) and against what `docs/gameplay.md` / `docs/mechanics-notes.md` currently claim. Since this is a live GUI app in a VM (not a web page with inspectable DOM/console), driving it will mean visual navigation, screenshots, and reading rendered text/state rather than DOM snapshots — budget for that.

Goal: produce a concrete list of gaps/mismatches between our reconstruction and the real 1999 beermat behavior — pricing/event mechanics, combat, coat/gun dealer offers, finances/loan shark behavior, turn structure, city list handling, anything else observed — each one citing what the beermat build actually did vs. what our engine/docs currently say.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 A written comparison report (as a task note/attachment, not code) covering at minimum: pricing/event mechanics, combat, coat dealer offers, gun dealer offers, finances/loan shark behavior, and turn/day structure
- [ ] #2 Each identified gap cites the specific observed beermat behavior (with a screenshot or transcript excerpt) alongside the corresponding claim in index.html's engine, docs/gameplay.md, or docs/mechanics-notes.md that it contradicts or is missing from
- [ ] #3 Report explicitly flags any case where the container's non-standard cities.txt (NY boroughs) affected what could be observed, so findings aren't misattributed to city-list differences
- [ ] #4 No infra connection details (hostnames, ports, SSH targets) are written into the task, report, or any commit — only a reference to CLAUDE.local.md
- [ ] #5 Report distinguishes gaps that are genuine mechanic mismatches from gaps that are just UI/presentation differences not relevant to the engine port
<!-- AC:END -->
