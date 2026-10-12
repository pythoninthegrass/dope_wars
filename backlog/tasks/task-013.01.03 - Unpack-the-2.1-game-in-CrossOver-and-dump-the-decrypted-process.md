---
id: TASK-013.01.03
title: Unpack the 2.1 game in CrossOver and dump the decrypted process
status: Done
assignee: []
created_date: '2026-10-11 04:02'
updated_date: '2026-10-12 16:05'
labels:
  - beermat-2.1
  - reverse-engineering
milestone: m-4
dependencies:
  - TASK-013.01.01
  - TASK-013.01.02
references:
  - CLAUDE.local.md
  - taskfiles/re.yml
documentation:
  - docs/beermat-2.1-re.md
parent_task_id: TASK-013.01
ordinal: 52000
---

## Description

<!-- SECTION:DESCRIPTION:BEGIN -->
The 2.1 game exe is encrypted by PC Guard and only decrypts in memory, so its code can be decompiled only from a process dump. Plan: create a dedicated 32-bit CrossOver bottle (CrossOver.app is installed on the dev Mac), copy in the files extracted by TASK-013.01.01 rather than running the installer (never run the Gator stub), start the game, enter the license key from the gitignored `vendor/dopewars-2001/key.txt`, and confirm the registered-only features unlock (15/60/90 day games, Price History). Dump the live process with Scylla x86 inside the bottle, with the import table rebuilt. Fallbacks, in order: a `winedbg` minidump, then the Windows oracle described in CLAUDE.local.md. Then make `task re:decompile` and `task re:disasm` accept the dump (via TASK-013.01.02's parameters) so the existing Ghidra pipeline produces a 2.1 `index.tsv`. The key and bottle path never go into committed files.
<!-- SECTION:DESCRIPTION:END -->

## Acceptance Criteria
<!-- AC:BEGIN -->
- [x] #1 The game runs in the CrossOver bottle and reports itself as registered
- [x] #2 A dump exists in gitignored vendor/dopewars-2001/ whose code sections are decrypted (readable x86, entropy well below 8.0) and which Ghidra imports
- [x] #3 task re:decompile and task re:disasm accept the dump and produce a 2.1 index.tsv plus per-function C files
- [x] #4 The 2.1 sound table (38 wavs) and the string table resolve to their handlers in the dump
- [x] #5 docs/beermat-2.1-re.md records the reproducible steps, the tool used and any fallback taken, with no key contents, bottle path or CLAUDE.local.md infra
<!-- AC:END -->

## Implementation Notes

<!-- SECTION:NOTES:BEGIN -->
From TASK-013.01.02: the 2.1 AppEvent sound table is not readable from the static exe (no AppEvents or .wav strings; the PC Guard sections are encrypted), so it can only be recovered from the dump. extract_beermat.py's EXPECTED_SOUNDS is the 10 cues of 1.2 and must be generalized to the 38-wav 2.1 table before parse_sounds can validate a 2.1 dump.

Deviation: the dump was taken with pe-sieve32 v0.4.1.1 (`/imp 3 /dmode 3`) instead of Scylla x86, because it is a CLI that rebuilds imports without GUI input. `/dmode 3` (realigned) is required; the default virtual layout leaves pefile unable to read the form resources. No fallback (winedbg, Windows oracle) was needed.

The dump has no import directory (pe-sieve lists about 530 recovered imports in a side file, 61 of them PC Guard redirect thunks) and its entry point is still in the PC Guard stub, which times out in the decompiler; all game functions decompile (about 4280).

The game also needs a `Registered` REG_DWORD value (0) in Settings that the Wise script does not seed. With that in place and the license key entered, the game reports itself registered and lists the 15/60/90 day, Price History and extra weapon features.

The 2.1 exe holds no wav records, so `sounds.tsv` joins `appevents.tsv` (event to wav and label, read from the Wise script by `task re:unwise`) with the event names in the dump, case-insensitively, with <weapon>Hit built at run time. `task re:sound-handlers` maps all 38 events to the functions that reference them.

IntroDlg and NMShow are orphan form resources (no VMT in the image); the extractor warns instead of failing. Ghidra scripts changed: DiscoverFunctions falls back to the first executable block when there is no CODE block, ApplyLabels clears an instruction straddling a labeled entry. The 1.2 pipeline was re-run with 0 failures.

Open for TASK-013.01.04: `TCityEditor_FormShow`-style functions are fine now, but the Binary Ninja MCP (added to .mcp.json) was not used here; the xref work was done on the decompiled C.

TASK-013.01.03 complete. All 5 ACs satisfied: game runs registered in the CrossOver bottle (#1), pe-sieve32 dump at vendor/dopewars-2001/dump/ has decrypted code sections and Ghidra-imports (#2), re:decompile/re:disasm produce the 2.1 index.tsv + ~4280 C files (#3), the 38-event sound table and string table resolve to handlers (#4), and docs/beermat-2.1-re.md records the reproducible steps with no key/bottle/CLAUDE.local.md infra (#5). Deviation from plan: pe-sieve32 v0.4.1.1 (/imp 3 /dmode 3) used instead of Scylla x86; no fallback needed.
<!-- SECTION:NOTES:END -->

## Final Summary

<!-- SECTION:FINAL_SUMMARY:BEGIN -->
All 5 acceptance criteria met. Dumped the decrypted 2.1 process with pe-sieve32 v0.4.1.1 (`/imp 3 /dmode 3`) instead of Scylla x86 (CLI rebuilds imports without GUI input). The dump's code entropy drops from ~8.0 to ~6.5 once decrypted, Ghidra imports it, and the existing pipeline produces a 2.1 index.tsv plus ~4280 per-function C files. All 38 sound events resolve to handlers. docs/beermat-2.1-re.md records the reproducible steps, tool, and fallbacks with no key, bottle path, or CLAUDE.local.md infra. No fallback was needed. Next up: TASK-013.01.04 (document 2.1 rules and re-check 1.2 findings).
<!-- SECTION:FINAL_SUMMARY:END -->
