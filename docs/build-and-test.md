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

Four checks, none of which build or run anything:

- `tools/validate_abi_exporter.py` — only `core/src/abi.mojo` declares
  `@export` symbols.
- `tools/validate_abi_test_purity.py` — Tier-C conformance tests reach the
  simulation only through `include/dopewars.h`, never a core import.
- `tools/abi_symbols.py --check` — the header parses as C and its
  declarations are unique.
- `tools/test_check_cpu_baseline.py` — self-check for the CPU-baseline gate that `core:build` runs on Linux x86-64 (see "CPU baseline" under Tier 7).

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

## Linux

`task check` is green on Linux (verified on AlmaLinux 10.2 x86_64, glibc
2.39), with no extra host packages beyond what the gate already needs:
`readelf`, `objcopy`, and `ar` (all part of `binutils`, present on a default
AlmaLinux/Fedora install) and a C++ toolchain (`g++`) for `extension/SConstruct`.
Mojo itself requires glibc 2.34 or later (see
[Mojo's system requirements](https://mojolang.org/docs/requirements)); this is
older than AlmaLinux 10's floor, so any mainstream current distro should clear
it.

`game:icon`'s `.icns` generation step (`sips`/`iconutil`) is macOS-only and is
skipped on Linux via `platforms: [darwin]` — `game/content/icon.icns` is
checked into git from the last macOS build and only matters to
`config/macos_native_icon`, which Godot reads on macOS alone.

`task extension:build-linux` builds both `template_debug` and
`template_release` `.so` files, mirroring `extension:build-macos`. The
vendored Mojo runtime libraries (`libKGENCompilerRTShared.so`,
`libAsyncRTRuntimeGlobals.so`, `libMSupportGlobals.so`) land next to
`libdopewars.linux.*.x86_64.so` in `game/bin/`, resolved at load time through
a self-relative `$ORIGIN` rpath — confirm with:

```sh
readelf -d game/bin/libdopewars.linux.template_debug.x86_64.so
```

which should show `RPATH: [$ORIGIN]` and `NEEDED: [libKGENCompilerRTShared.so]`.

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

## Tier 7 — Linux export (TASK-012.02)

```sh
task export:templates   # one-time: checksum-verified export-template download
task export:linux       # produces game/build/linux/dopewars.x86_64 + .pck + .so files
```

`export:templates` downloads the Godot export templates pinned in
`tools/game_toolchain.lock` (version-matched to `.tool-versions`' `godot`
entry), checksum-verifies them, and extracts them to
`.tools/game/xdg-data/godot/export_templates/<version>/` — gitignored and
never under the user's real `~/.local/share/godot`. `export:linux` points
Godot at that directory via `XDG_DATA_HOME` and runs `godot --headless
--export-release Linux` against the `Linux` preset in
`game/export_presets.cfg`. `game/bin/dopewars.gdextension`'s
`[dependencies]` section lists the three vendored Mojo/KGEN runtime `.so`
files (`libAsyncRTRuntimeGlobals.so`, `libKGENCompilerRTShared.so`,
`libMSupportGlobals.so`) for `linux.debug.x86_64` and `linux.release.x86_64`,
so Godot copies them into `game/build/linux/` alongside the exported binary
and `.pck` — without that section the export would ship
`libdopewars.linux.*.so` alone, and it would fail to `dlopen` its runtime
dependencies outside the dev tree.

**glibc floor** (measured on `mf`, AlmaLinux 10.2, glibc 2.39 — see
`CLAUDE.local.md` for connection details): `objdump -T` against
`game/bin/libdopewars.linux.template_release.x86_64.so` shows a floor of
`GLIBC_2.38`, higher than any of the three vendored Mojo/KGEN runtime `.so`
files (highest: `GLIBC_2.35`) and higher than Godot's own
`linux_release.x86_64` export template (`GLIBC_2.28`) — so the GDExtension
itself sets the overall floor. `mf`'s glibc 2.39 meets that floor, so no
container build (e.g. an Ubuntu 22.04 image, as `~/git/neo_snake`'s
`docker/linux/Dockerfile` does for its Zig core) is needed for distribution
from this host. Re-measure if the Mojo toolchain version changes.

Verified by copying `game/build/linux/`'s contents to a directory outside
the repo and running `./dopewars.x86_64 --headless --quit-after 2`: no
missing-library errors, exit code 0.

### CPU baseline (TASK-012.05)

On Linux x86-64, `core:build` passes `--target-cpu x86-64-v3` to `mojo build` (AVX2, FMA, BMI2; Intel Haswell and AMD Excavator/Zen onward, roughly 2013 and later). Older CPUs are deliberately not supported. macOS arm64 and any other host stay host-native, because the flag is only added when `uname` reports `Linux-x86_64`.

The reason is that `mojo build` defaults to the host CPU. The first Linux export was built on `mf` (Ryzen 7 7840HS, AVX-512) and its core library contained AVX-512 instructions (`%zmm` registers, `%k` masks); it died with SIGILL at startup on a Fedora 42 laptop with a Core Ultra 7 155H, which has AVX2 but no AVX-512. The kernel's `traps: ... trap invalid opcode ... in libdopewars.linux.template_release.x86_64.so` line (`journalctl -k`) is how that was pinned to our core library rather than the Mojo runtime.

`tools/check_cpu_baseline.py` is the gate: `core:build` disassembles `libdopewars.a` after the ABI export check and fails if any instruction uses a `%zmm` register, a `%k0-%k7` mask register, or `%xmm16-31`/`%ymm16-31` (registers only EVEX can encode). `ymm` and VEX instructions are inside the baseline and allowed. `tools/test_check_cpu_baseline.py` (run by `task abi:check`) proves the scanner catches each marker. Run it by hand on an exported library with `python3 tools/check_cpu_baseline.py game/build/linux/libdopewars.linux.template_release.x86_64.so`.

`task core:test` does not exercise the baseline codegen, since it runs through `mojo run`, which compiles for the host CPU. The bridge and ui tests do, because they load the rebuilt archive through the GDExtension.

The vendored `libKGENCompilerRTShared.so` (Modular's prebuilt runtime) still contains AVX-512 code, and that is safe on CPUs without it: a runtime feature probe (`cpuid` leaves 0, 1 and 7, then `xgetbv`) selects one row of a four-row function-pointer table (scalar, SSE2, AVX2, AVX-512) and copies it into globals, and the AVX-512 row is chosen only when AVX-512F is present and the OS has enabled all of the AVX-512 register state (`XCR0 & 0xe6`). The `%zmm` functions are reachable only through that table (no direct callers). The probe itself uses `vmovups %ymm0`, so the runtime needs AVX, which the v3 baseline already implies. Verified by disassembly and by running the export on the AVX2-only laptop above: `./dopewars.x86_64 --headless --quit-after 120 --seed=42` exits 0 with no invalid-opcode trap.

### Display driver and window scale on Linux (TASK-012.06)

`game/project.godot` sets `display_server/driver.linuxbsd="wayland"`. Godot defaults to X11, and on a GNOME or KDE Wayland desktop a terminal session has `DISPLAY` set, so the game ran under XWayland, which reports screen scale 1.0 to the client. `Main._constrain_window` (see its comment) scales the 704x620 window by `screen_get_scale()`, so under XWayland it did nothing and the window opened tiny on a HiDPI panel. Measured on a 3072x1920 panel at 1.5x: X11 driver gave scale 1.0 and a 704x620 window, native Wayland gave scale 2.0 and a 1409x1241 window. Godot only reports integer scales, so a fractional compositor scale is rounded up to 2 and the compositor scales the result down.

Godot falls back to X11 on its own when Wayland is unavailable (checked by pointing `WAYLAND_DISPLAY` at a nonexistent socket: it logs "falling back to x11" and starts at 704x620), so pure-X11 desktops still work. `task game:ui-test` asserts the setting; the window size itself cannot be asserted headless because headless has no screen scale, so it is checked by hand on a HiDPI Wayland machine. Release templates ignore `--path` and `--script`, so to measure the exported build, export a `.pck` with temporary `print` instrumentation (`godot --headless --path game --export-pack Linux <out>.pck`) and swap it next to an exported binary.

## Live inspection with gda

`gda` and the `godot` MCP server need `GDA_GODOT` (path to the Godot binary)
and `GDA_PROJECT=game` in the environment. Pair `gda daemon start --windowed`
with `gda daemon stop` + `gda daemon uninstall` when done — the start step
writes an autoload into `game/project.godot` and
`game/addons/gda_harness/`, and skipping the teardown leaves that dirty.
