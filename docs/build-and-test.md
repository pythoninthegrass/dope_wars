# Build and test runbook

Every command below assumes the mise-pinned toolchain from `.tool-versions`
(`godot`, `uv`, `scons`, `task`, `python`, `watchexec`) is on `PATH`. `mise
install` (or letting a task's `_install-mise-tools` dependency run) installs
anything missing. Mojo itself is not a mise tool: `task core:_install-venv`
creates `core/.venv` and installs the exact pinned Mojo release
(`MOJO_VERSION` in `taskfiles/core.yml`) into it via `uv pip install`; every
`core:*` task depends on it, so it runs on demand rather than needing a
separate setup step. Ghidra (reverse-engineering only, not needed to build or
run the game) is not a mise tool: `re:_install-ghidra` in `taskfiles/re.yml`
runs `brew install ghidra` on macOS, and on Linux (no distro package exists)
unpacks the checksum-pinned upstream release into `~/.local/opt/ghidra`. Both
use a mise-managed Temurin 21 JDK (`re:_install-java`), and every `re:*` task
depends on them.

```sh
git clone <repo>
cd dope_wars
git submodule update --init --recursive   # or: task submodules
task check                                 # builds everything and runs every tier
```

`task check` is the single command a new contributor needs to prove the tree
is sound. Everything else in this document is what it runs, broken out so a
single tier can be re-run in isolation while iterating.

## Tier 1 — Mojo unit tests

```sh
task core:test
```

Runs every `tests/mojo/*_test.mojo` file
(`parity_test.mojo`, `prices_test.mojo`, `rng_test.mojo`, `rules_test.mojo`,
`world_test.mojo`) via `mojo run`. `mojo test` does not exist in this Mojo
release; each file's `main()` calls
`TestSuite.discover_tests[__functions_in_module()]().run()` over its own
`def test_*() raises` functions.

`parity_test.mojo` is also Tier 5 (the JS-oracle replay) — it is listed again
below because it is the tier that actually answers AC#1 of TASK-001.07.
Narrow it with a fixture-name substring: `task core:test -- 04 05` runs only
the fixtures whose filename contains `04` or `05`.

## Tier 2 — ABI static gates

```sh
task abi:check
```

Three checks, none of which build or run anything:

- `tools/validate_abi_exporter.py` — only `core/src/abi.mojo` declares
  `@export` symbols.
- `tools/validate_abi_test_purity.py` — Tier-C conformance tests reach the
  simulation only through `include/dopewars.h`, never a core import.
- `tools/abi_symbols.py --check` — the header parses as C and its
  declarations are unique.

## Tier 3 — ABI conformance (Tier-C)

```sh
task abi:conformance
```

Three independent drivers against the same built library, so a binding bug
in one cannot hide behind another:

- `task core:abitest` — `core/abitest/abi_conformance_test.py`, ctypes,
  prototypes derived from the header.
- `task core:abitest:mojo` — `core/abitest/abitest.mojo`, a std-only
  `external_call` driver built against the static library.
- `task core:abi:header-check` — `core/abitest/abi_header_check.c` compiles
  as C11 against the header and asserts `DW_ABI_VERSION` and the `DW_NUM_*`
  constants at compile time (`DW_STATIC_ASSERT`) — proof the header is
  internally self-consistent, independent of what the Mojo side computes.

## Tier 4 — Bridge integration (Godot -> C++ -> Mojo)

```sh
task bridge:test          # game/godot_tests/bridge_test.gd, value-checking assertions
task bridge:test:script   # game/tests/test_bridge.gd, full forwarded-ABI script test
```

`bridge:test` first runs `task gen:bridge-expectations:check`, which fails if
`game/bridge_expectations.gd` is stale with respect to `include/dopewars.h`
(regenerate with `task gen:bridge-expectations` — never hand-edit that file).
It then drives `game/godot_tests/bridge_test.tscn` headlessly and checks the
generated pointer-free surface against those expectations. `bridge:test:script`
drives `game/tests/test_bridge.gd` (`godot --script`, no scene) over the whole
forwarded ABI: lifecycle, buy/sell/travel/finances, a dump-load-dump
byte-identical round-trip, and determinism.

Both require `task game:import` (headless asset import — populates
`.godot/`, including the compiled `translations/strings.en.translation` and
the global script-class cache the `SimWorld` type resolves from). `task
build` (Mojo core + GDExtension shim) must be current first; both bridge
tasks pull it in as a dependency.

## Tier 5 — Parity / differential (the JS oracle)

```sh
task core:test                        # replays every tests/fixtures/*.jsonl fixture
node tests/fixtures/run.mjs            # replays the same fixtures against the JS engine itself (self-check)
```

`tests/fixtures/*.jsonl` are seed-stable traces recorded from
`<script id="engine">` in `index.html` (see `tests/fixtures/README.md` for the
format and the coverage table). `task core:test` is the actual differential
test: it replays every fixture step against the compiled Mojo core and
deep-compares both the return value and the full state snapshot. Regenerating
the fixtures after an *intentional* engine change:

```sh
node tests/fixtures/generate.mjs
shasum tests/fixtures/*.jsonl   # run twice, confirm byte-identical regeneration
```

`core/tests/mojo/fixtures.mojo` is generated from the same fixtures
(`node tests/fixtures/gen-mojo.mjs`); `task core:test:check-generated` fails
if it is stale.

## Tier 6 — Godot regression

```sh
task game:boundary-check   # the DopeWarsWorld layer boundary, plus its own self-test
task game:ui-test          # game/godot_tests/ui_flow_test.tscn, the presentation-layer suite
task game:smoke-test       # headless boot of the real main scene, --quit-after 2
```

`game:boundary-check` runs `tools/validate_game_boundary.py` (fails if any
`.gd` file outside `game/simulation/` names the `DopeWarsWorld` GDExtension
class) and its self-test, `tools/test_validate_game_boundary.py`.
`game:ui-test` drives the real `Main` scene through the same entry points the
keyboard and buttons use and asserts on rendered widget state: boot and price
rendering, a buy/sell round trip, travel with the arrival sequence draining, a
mid-game save round-tripping through a cold start, the finances dialog, the
new-game form, the keyboard shortcut table, and that every `tr()` key
resolves.

## Everything together

```sh
task check
```

Runs, in order: `core:test`, `abi:check`, `abi:conformance`,
`game:boundary-check`, `bridge:test`, `bridge:test:script`, `game:ui-test`,
`game:smoke-test`. Non-zero exit on any failure.

## Other useful commands

- `task run` — build the full stack and launch the game interactively.
- `task dev` — watchexec loop: rebuild and relaunch on any change under
  `core/src`, `include/`, `extension/src`, or `game/`. Godot has no hot
  reload outside the editor, so this is a restart loop; `user://dopewars.save`
  survives it.
- `task loc` — non-vendor, non-generated SLOC by language and the Mojo share
  (see `docs/architecture.md`'s "Mojo LOC share" section for the current
  numbers and how to read them).
- `task lint` — markdownlint over the whole repo plus
  `scripts/check-core-boundaries.sh` (no Godot/FFI imports, no I/O, no global
  mutable state, no logging in `core/src`).

## Headless Godot runs — gotchas

- Any `godot` invocation not wrapped by a Taskfile target must run under
  `timeout` (e.g. `timeout 300 godot --headless --path game ...`). A scene
  whose `_ready()` aborts on a script error prints the error and then keeps
  spinning the main loop forever — it never exits on its own
  (godotengine/godot#111048).
- Every test scene calls `get_tree().quit(0)` / `quit(1)` on every path and
  prints a one-line result summary. A test that exits 0 having run zero
  assertions is a false pass — each one asserts a floor derived from the
  surface size.
- `task game:import`'s `status:` gate checks for both `.godot/` and the
  compiled `translations/strings.en.translation` file. A `.godot/` directory
  left over from an interrupted or older import can exist without the
  translation resource ever having been generated; without the second check,
  every downstream Godot task fails with
  `Cannot open file 'res://translations/strings.en.translation'` and a
  `SimWorld` "not declared in the current scope" parse error, and `task
  check` reports the failure two layers down (in `bridge:test` or
  `smoke-test`) rather than at the actual missing-import root cause. If you
  hit that failure directly, `rm -rf game/.godot && task game:import` forces
  a clean reimport.

## Live inspection with gda

`gda` and the `godot` MCP server need `GDA_GODOT` (path to the Godot binary)
and `GDA_PROJECT=game` in the environment. Pair `gda daemon start --windowed`
with `gda daemon stop` + `gda daemon uninstall` when done — the start step
writes an autoload into `game/project.godot` and
`game/addons/gda_harness/`, and skipping the teardown leaves that dirty.
