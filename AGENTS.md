# AGENTS.md

## What this repo is

A Godot reference implementation of Dope Wars — a Mojo simulation core behind a frozen C ABI, a C++ GDExtension shim, and a GDScript presentation layer — ported from and verified against a **playable web prototype** (`index.html`). See `docs/architecture.md` for the four-layer structure and data flow, `docs/build-and-test.md` for the full build/test runbook, and `docs/parity-deltas.md` for the approved behavioral differences from the prototype.

`CLAUDE.md` is a symlink to this file (`AGENTS.md`); edit `AGENTS.md`, not `CLAUDE.md`.

## Playable prototype — `index.html`

Single-file, no-build-step, no-dependency game. Open directly in a browser (`open index.html`). Append `?seed=<n>` for a reproducible run. Keyboard shortcuts: `1`–`6` travel, `B`/`S`/`F` buy/sell/finances, `N` new game, `Enter`/`Esc` confirm/cancel.

**Two `<script>` blocks, each with a distinct role:**

- `<script id="engine">` — pure simulation, zero DOM access, exposed as `window.DopeWarsEngine`. Every function that needs randomness accepts an explicit `rng` argument (mulberry32 PRNG) so an entire run is deterministic from a seed. This maps directly onto the eventual GDScript port. Ruleset: Keymash/Beermat "Dope Wars for Windows" 1.2.0.0 (1999) as primary, falling back to `docs/gameplay.md` for anything Keymash never revealed.
- `<script id="ui">` — rendering and input only. Maintains two selection variables (`selectedBuyDrug`, `selectedSellDrug`) that stay in sync bidirectionally when the user clicks either table. Coat rows whose drug is absent from the current market get a `selected-unavailable` (dark-red) CSS class; the Sell button stays disabled in that state.

**Key engine exports:** `newGame`, `generatePrices`, `buy`, `sell`, `travel`, `finances`, `rollArrivalEvent`, `shouldStartChase`, `startChase`, `runFromChase`, `fight`, `finish`, `rollDealerVisit`, `rollCoatDealerOffer`, `acceptCoatOffer`, `rollGunDealerOffer`, `acceptGunOffer`, `serializeState`, `deserializeState`.

**Persistence:** `localStorage` under keys `dopewars.save` (game state) and `dopewars.highscores` (top-10 list). The Godot port writes `user://dopewars.save` (the core's opaque dump, not JSON) and `user://dopewars.highscores.json`; see `game/platform/save_store.gd` and `highscore_store.gd`.

**Seeding:** the prototype reads `?seed=<n>` from the URL. The Godot build takes `--seed=<n>` on the command line, so `godot --path game -- --seed=42` replays that seed.

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

## Target architecture (Godot port)

The Godot reference implementation is a four-layer stack, one direction of dependency, modeled on `~/git/jumpnbump/` (Zig core / C ABI / C++ GDExtension / GDScript game) with Mojo swapped in for Zig. See `docs/abi-contract.md` for the ABI conventions and `docs/layer-boundaries.md` for what each layer is and is not allowed to do.

- `core/` — Mojo simulation. Pure sim: RNG, pricing, trading, events, combat, scoring, serialization. Zero Godot imports, zero FFI imports, no file I/O, no global mutable state outside the `dw_world` handle. Where `<script id="engine">` (`index.html:609-1079`) ends up. `core/src/abi.mojo` is the sole `@export` source; `core/abitest/` is the Tier-C conformance suite, which reaches the built library only through the C header.
- `include/dopewars.h` — the frozen C ABI. The only cross-language contract. Opaque caller-owned `dw_world` handle, `dw_result` = `int32_t`, `uint8_t`-typedef'd kind enums, `DW_STATIC_ASSERT` on every struct sizeof, two-call length-then-fill for every variable-length buffer. `DW_ABI_VERSION` is bumped on any breaking change; additive changes do not bump it.
- `extension/` — C++ GDExtension shim. 1:1 forwarding from ABI functions to a Godot class. No game logic; no state other than the `dw_world` storage and transient marshalling scratch.
- `game/` — Godot / GDScript, in four sub-layers. Never imports Mojo directly; never duplicates core state; never computes game rules. Where `<script id="ui">` (`index.html:1081-1710`) ends up.
  - `game/simulation/` — `world.gd`, `class_name SimWorld`: the **only** `.gd` file allowed to name `DopeWarsWorld`. A complete pass-through (every bound method, all 32 `DW_*` constants re-exported **with the `DW_` prefix dropped** — `SimWorld.NUM_DRUGS`, not `SimWorld.DW_NUM_DRUGS`), no logic, no caching.
  - `game/presentation/` — the window (`main.tscn` + `main.gd` is the only scene; the tree is assembled in code), the HUD, both tables, the dialog layer, and `arrival_flow.gd` (the post-travel sequence as an explicit queue rather than the prototype's recursive closure chain).
  - `game/platform/` — `input_router.gd` (keyboard → intent, `classify()` pure so the shortcut table is testable), `save_store.gd` (`user://dopewars.save`, the core's opaque dump), `highscore_store.gd` (`user://dopewars.highscores.json`).
  - `game/content/` — palette, Win98 theme factory, and every `tr()` key. **Not** the drug/borough tables: those come from `SimWorld.rules_drugs()` / `rules_locations()`, and a second copy would be both a rule computation and a second source of truth.

  `game/README.md` documents the layer rules. `tools/validate_game_boundary.py` (wired into `task game:boundary-check`) fails if any script outside `game/simulation/` names `DopeWarsWorld`, with `ClassDB.class_exists("DopeWarsWorld")` as the only exemption; `tools/test_validate_game_boundary.py` self-checks that gate.

  Every player-visible string is a `tr()` key resolved from `game/translations/strings.csv` via the `.translation` that `project.godot` registers. A key with no row renders as the key itself, and a CSV value containing a comma must be quoted — `task game:ui-test` asserts both.

Mojo LOC target at parity: `>=43%` of non-vendor non-generated LOC, matching the Zig ratio in `~/git/jumpnbump/`. **This is reported, not gated, and it is currently missed against the whole repo: 25.70% (`task loc`, measured 2026-09-28).** The denominator contains `game/`'s 3526 GDScript lines, and `game/presentation/` is GDScript *by rule* — `docs/layer-boundaries.md` forbids game rules in GDScript and `core/` may contain no Godot import, so no part of a UI layer can move to Mojo. Scoped instead to the simulation stack the target is meant to compare (`core/` + `include/` + `extension/`), Mojo is 67.97% of that stack — comfortably past parity. See `docs/architecture.md`'s "Mojo LOC share" section for the full breakdown.

**The pinned Mojo toolchain (1.1.0, `MOJO_VERSION` in `taskfiles/core.yml`) exports all 54 declarations of `include/dopewars.h`.** `@export` refuses `ref` parameters and bare `Pointer`/`UnsafePointer` parameters, but accepts `OptionalPointer[T, origin=MutUntrackedOrigin]` / `ImmUntrackedOrigin` — an explicitly-bound untracked origin is not parametric, and the Optional wrapper maps onto the header's NULL-rejection discipline. `docs/mojo-1.1.0-abi-constraints.md` is the probe log: its dead ends are real dead ends, and its corrected "The spelling that works" section is the way through. `tools/check_abi_exports.py` compares the built artifact's global defined set against the header declarations in both directions (Mach-O underscores normalized); the "blocked on the toolchain" allowance is derived machinery that is currently empty, and it fails on any pointer-free regression.

### Build commands

- `task check` — the whole gate set: Mojo parity replay against the JS oracle fixtures, the static ABI gates, all conformance drivers, the game/simulation boundary check, both bridge tests, the presentation-layer test, the full build, and the headless Godot smoke test. Non-zero exit on any failure. See "Headless Godot runs" before running any of these steps by hand.
- `task abi:check` — the three static gates: only `core/src/abi.mojo` declares `@export` symbols, Tier-C conformance tests do not import core modules or drive the Mojo toolchain, and `include/dopewars.h` parses with unique declarations.
- `task abi:conformance` — Tier-C, three drivers: `core/abitest/abi_conformance_test.py` (ctypes, prototypes derived from the header), `core:abitest:mojo` (`core/abitest/abitest.mojo`, a std-only `external_call` driver built against the static library), and `core/abitest/abi_header_check.c` (compile-time proof the header is self-consistent as C11).
- `task bridge:test` — Godot → C++ → Mojo integration (`game/godot_tests/bridge_test.gd`), value-checking the generated pointer-free surface against `game/bridge_expectations.gd`, which is generated from the header. Runs the staleness check first. Drives `SimWorld`, so it also proves the wrapper forwards the whole surface — which is only possible because `SimWorld` re-exports the `dw_rules_*` accessors as instance methods: a GDScript `static func` never appears in `get_method_list()`.
- `task bridge:test:script` — the companion script-driven test (`game/tests/test_bridge.gd`, `godot --script`): full forwarded ABI — lifecycle, buy/sell/travel/finances, dump→load→dump byte-identical round-trip, determinism.
- `task gen:bridge-expectations` / `:check` — regenerate / verify `game/bridge_expectations.gd`. Never hand-edit that file; it reads `DW_ABI_VERSION` and `DW_NUM_*` out of the header so the constants have one definition.
- `task run` — build the full stack and launch the game interactively.
- `task dev` — watch `core/src`, `include/`, `extension/src`, and `game/` and rerun `task run` (rebuild + relaunch) on every change, via `watchexec`. Godot has no hot reload outside the editor, so this is a restart loop, not HMR: state is lost on every relaunch, though `user://dopewars.save` survives it.
- `task build` — build only, no smoke test.
- `task core:build` — build `core/build-output/lib/libdopewars.a` from `core/src/abi.mojo`, the only file declaring `@export` symbols.
- `task core:test` — replay `tests/fixtures/*.jsonl` against the Mojo core. This is the parity gate for the simulation; pass fixture-name substrings to narrow it (`task core:test -- 04 05`).
- `task extension:build` — build the GDExtension shim (`game/bin/libdopewars.*`).
- `task game:ui-test` — the presentation-layer regression suite (`game/godot_tests/ui_flow_test.tscn`): drives the real `Main` scene through the same entry points the keyboard and the buttons use, and asserts on rendered widget state — boot and price rendering, a buy/sell round trip, travel with the arrival sequence draining, a mid-game save round-tripping through a cold start, the finances dialog, the new-game form, the keyboard shortcut table, and that every `tr()` key resolves.
- `task game:boundary-check` — the `DopeWarsWorld` boundary plus its own self-test.
- `task game:import` / `task game:smoke-test` — headless Godot import and boot in isolation. `smoke-test` is `--quit-after 2` rather than a hand-rolled `quit()`: the main scene is the game now, so it has no reason to exit on its own.
- `task loc` — non-vendor, non-generated SLOC by language and the resulting Mojo share, split into `core/` and the parity harness.
- `task lint` — markdownlint plus the `core/src` boundary gate (no Godot/FFI imports, no I/O, no global mutable state, no logging). Installs the pinned `markdownlint-cli` via npm on demand (`core:_install-markdownlint`) when it is missing or the wrong version, so `task lint` never fails with "command not found".

### Live inspection with gda

- `gda`/the `godot` MCP server need `GDA_GODOT` (path to the Godot binary) and `GDA_PROJECT=game` in the environment — without them `daemon start` fails with `project_not_found`, including when called through the MCP tool. Always pair `gda daemon start --windowed` with `gda daemon stop` + `gda daemon uninstall` when done; the start step writes an autoload into `game/project.godot` and `game/addons/gda_harness/`, and skipping the teardown leaves that dirty.
- Driving input live: find a node's path with `gda game tree`, its screen rect with `gda game rect <path>`, then `gda input mouse-click <x> <y>` (center of the rect) to click it; `gda game get --property <name> <path>` reads back widget state (e.g. a `LineEdit`'s `text`, `select_all_on_focus`) to verify the effect. `gda input key <name>` / `--released` injects keycodes only (no unicode payload), so it drives shortcuts and `Delete`/`Backspace` fine but can't simulate typing printable characters into a field.

### Headless Godot runs

- Any `godot` invocation not wrapped by a Taskfile target must run under `timeout` (e.g. `timeout 300 godot --headless --path game ...`). A scene whose `_ready()` aborts on a script error prints the error and then keeps spinning the main loop forever — it never exits on its own, and a plain hang gives you no output to debug (godotengine/godot#111048 is the related import-crash case; `task game:import` already wraps its retry loop).
- A test scene that names a constant or identifier that does not exist fails at load, never reaches its `quit()`, and burns the whole `timeout` — a suite that normally takes seconds taking 300s is that, not slowness. Read the captured output for the GDScript error rather than re-running.
- Every test scene must call `get_tree().quit(0)` / `quit(1)` on *every* path and print a one-line result summary. A test that exits 0 having run zero assertions is a false pass — assert a floor derived from the surface size (see `game/godot_tests/bridge_test.gd`'s minimum-assertion check).

Toolchain: `godot`, `uv`, `scons`, `task`, `python`, `watchexec` (used by `task dev`) are pinned in `.tool-versions` and resolve via mise. Mojo is pinned to an exact version in `taskfiles/core.yml` (`MOJO_VERSION`) and installed from PyPI into `core/.venv`; the venv task's `status:` check is version-aware, so a stale venv is rebuilt rather than silently used. `markdownlint-cli` is pinned as `MARKDOWNLINT_VERSION` in the same file and installed globally on demand by `task lint`. `third_party/godot-cpp` is pinned via git submodule (SHA in `.gitmodules` history). The Mojo ABI's use of `List`/`Error` pulls in the Mojo runtime (`KGEN_CompilerRT_*`): `extension/SConstruct` locates `libKGENCompilerRTShared.{so,dylib}` under `core/.venv` and links it at build time, then vendors it — plus the sibling libraries it references by `@rpath`/`NEEDED` — into `game/bin` (inside the framework directory on macOS, next to the `.so` on Linux) with a self-relative rpath (`@loader_path` / `$ORIGIN`), so the built extension loads with no dependency on the venv path. `task core:abi:shared-lib` (conformance testing only) still links against the venv path by rpath, which is fine for a dev tool.

`mojo test` does not exist. Mojo tests are `def test_*() raises` functions run through `TestSuite.discover_tests[__functions_in_module()]().run()` in a `main()` that `mojo run` executes.

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
