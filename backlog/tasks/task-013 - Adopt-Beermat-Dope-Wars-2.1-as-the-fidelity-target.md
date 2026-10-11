---
id: TASK-013
title: Adopt Beermat Dope Wars 2.1 as the fidelity target
status: To Do
assignee: []
created_date: '2026-10-11 04:01'
labels:
  - beermat-2.1
milestone: m-4
dependencies: []
references:
  - vendor/CHANGELOG.md
  - CLAUDE.local.md
  - TASK-010
documentation:
  - docs/beermat-2.1-re.md
  - docs/beermat-re.md
  - docs/parity-deltas.md
priority: medium
ordinal: 46000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
The Godot port currently matches Beermat "Dope Wars for Windows" 1.2.0.0 (1999). Lance found the 2.1.0.0 (2001) installer, `vendor/dopewars-2001/dw21.exe` (gitignored). `docs/beermat-2.1-re.md` records what is known so far: it is a Wise installer around a PC Guard-protected Delphi `DopeWars.exe`, so none of the 1.2 virtual addresses or constants in `docs/beermat-re.md` can be assumed to hold, and the numeric rules must come from a decrypted process dump. The 2.1 form resources show the features the port lacks: multiple loan sharks, hospital, Super Store, weapon choice in chases, kidneys and the nasty doctor, dialysis, infection, Old Lady, price history, end-of-game statistics and 15/30/60/90 day games. `vendor/CHANGELOG.md` (cleaned Wayback capture of the Beermat release history) is the feature baseline.

Decisions already made (Lance):
- 2.1 replaces 1.2 as the fidelity target wherever they conflict.
- Skip airport flights and multi-city travel; `docs/parity-deltas.md` section 5 stands.
- Mojo-first: `index.html` stays frozen at 1.2 parity and is not extended. New rules are written test-first in `core/`.
- The 2.2 changelog items get tasks too, labelled `changelog-only`, because the binary has no evidence for them.
- The binary is unpacked by running it in a CrossOver bottle, registering it with the license key, and dumping the decrypted process.

Out of scope: registration and license keys, online scores and cartels, update check, proxy settings, the city editor, skins, LCD font and layout polish, anti-cheat.

Constraints: never commit the binary, the wavs, the license key, or anything from CLAUDE.local.md (refer to "CLAUDE.local.md" instead). Every engine rule change found needs Lance's approval before it is applied, as in TASK-010. Never run the bundled Gator adware stub.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [ ] #1 Subtasks .01 (recover 2.1 rules), .02 (implement 2.1 features) and .03 (2.2 changelog items) are Done
- [ ] #2 Every difference between the 2.1 binary and the port is either fixed under its own approved subtask or recorded as intentional in docs/parity-deltas.md
- [ ] #3 docs/beermat-2.1-re.md documents the 2.1 findings with evidence for every constant used
- [ ] #4 No binary, wav, license key or CLAUDE.local.md infra detail appears in any committed file or backlog task
<!-- AC:END -->
