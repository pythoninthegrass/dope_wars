# AGENTS.md

## What this repo is

Research, planning, and a **playable web prototype** for a Godot reference implementation of Dope Wars. There is no Godot source code yet.

`CLAUDE.md` is a symlink to this file (`AGENTS.md`); edit `AGENTS.md`, not `CLAUDE.md`.

## Playable prototype — `index.html`

Single-file, no-build-step, no-dependency game. Open directly in a browser (`open index.html`). Append `?seed=<n>` for a reproducible run. Keyboard shortcuts: `1`–`6` travel, `B`/`S`/`F` buy/sell/finances, `N` new game, `Enter`/`Esc` confirm/cancel.

**Two `<script>` blocks, each with a distinct role:**

- `<script id="engine">` — pure simulation, zero DOM access, exposed as `window.DopeWarsEngine`. Every function that needs randomness accepts an explicit `rng` argument (mulberry32 PRNG) so an entire run is deterministic from a seed. This maps directly onto the eventual GDScript port. Ruleset: Keymash/Beermat "Dope Wars for Windows" 1.2.0.0 (1999) as primary, falling back to `docs/gameplay.md` for anything Keymash never revealed.
- `<script id="ui">` — rendering and input only. Maintains two selection variables (`selectedBuyDrug`, `selectedSellDrug`) that stay in sync bidirectionally when the user clicks either table. Coat rows whose drug is absent from the current market get a `selected-unavailable` (dark-red) CSS class; the Sell button stays disabled in that state.

**Key engine exports:** `newGame`, `generatePrices`, `buy`, `sell`, `travel`, `finances`, `rollArrivalEvent`, `shouldStartChase`, `startChase`, `runFromChase`, `fight`, `finish`, `rollCoatDealerOffer`, `acceptCoatOffer`, `rollGunDealerOffer`, `acceptGunOffer`, `serializeState`, `deserializeState`.

**Persistence:** `localStorage` under keys `dopewars.save` (game state) and `dopewars.highscores` (top-10 list).

**Tests** cover the engine only (no DOM harness exists for the UI):

```sh
node --test tests/engine.test.mjs
```

The test file extracts `<script id="engine">` from `index.html` and runs it in `node:vm` — no separate module to drift out of sync.

## Source documents

- `docs/gameplay.md` — mechanics of `benmwebb/dopewars` (the C reference implementation on GitHub), extracted directly from source at a pinned commit, with `src/<file>:<line>` citations for every rule (turn structure, pricing formulas, combat math, random-event tables, antique mode, etc.). This is the most rigorously sourced document and should be treated as authoritative over the others when mechanics conflict.
- `docs/mechanics-notes.md` — observational notes from a scripted 31-day playthrough of the Keymash web port (`https://keymash.com/games/dopewars/`), played via the `chrome-devtools-axi` skill. Describes UI flow and behavior *observed*, not sourced from code — flag it explicitly when it conflicts with `gameplay.md`.
- `docs/playthrough.md` — the raw playthrough script/log that produced `mechanics-notes.md` and the numbered `screenshots/` (gitignored, not checked in).
- `docs/dopewars_sourceforge_faq.md` — upstream FAQ covering the broader Dope Wars family tree (many independent, non-interoperable reimplementations). Useful for lineage/history context only.
- `docs/drug_wars_calc_to_phone_wired_20210628.md` — historical background on the original Drug Wars/Dope Wars lineage.

**Important distinction preserved throughout the docs**: Beermat Software's "Dope Wars for Windows" 1.2.0.0 (1999) — the version most familiar to pythoninthegrass — is a separate, closed-source codebase whose exact numbers are *not* derivable from `benmwebb/dopewars`. Don't conflate the two when citing mechanics; `gameplay.md` says explicitly which implementation each fact comes from.

## Conventions

- Markdown is linted with `markdownlint-cli` using `.markdownlint.jsonc` (`markdownlint -f -c .markdownlint.jsonc .`); `.markdownlintignore` excludes `.claude/**` and `backlog/**`. Line length (MD013) is disabled — do not hard-wrap prose.
- Screenshots referenced by `docs/mechanics-notes.md` live in `screenshots/` but are gitignored and not committed; don't assume they're present in a fresh clone.

## Context7 Libraries

- astral-sh/docs
- godotengine/godot-docs
- j178/prek
- mrlesk/backlog.md
- websites/taskfile_dev
- websites/mojolang

<!-- BACKLOG.MD MCP GUIDELINES START -->
<!-- backlog.md-instructions-version: 1.48.0 -->

<CRITICAL_INSTRUCTION>

## BACKLOG WORKFLOW INSTRUCTIONS

This project uses Backlog.md MCP for all task and project management activities.

**CRITICAL GUIDANCE**

- If your client supports MCP resources, read `backlog://workflow/overview` to understand when and how to use Backlog for this project.
- If your client only supports tools or the above request fails, call `backlog.get_backlog_instructions()` to load the tool-oriented overview. Use the `instruction` selector when you need `task-creation`, `task-execution`, or `task-finalization`.

- **First time working here?** Read the overview resource IMMEDIATELY to learn the workflow
- **Already familiar?** You should have the overview cached ("## Backlog.md Overview (MCP)")
- **When to read it**: BEFORE creating tasks, or when you're unsure whether to track work

These guides cover:

- Decision framework for when to create tasks
- Search-first workflow to avoid duplicates
- Links to detailed guides for task creation, execution, and finalization
- MCP tools reference

You MUST read the overview resource to understand the complete workflow. The information is NOT summarized here.

</CRITICAL_INSTRUCTION>

<!-- BACKLOG.MD MCP GUIDELINES END -->
