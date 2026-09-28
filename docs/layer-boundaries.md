# Layer boundaries

Four layers, one direction of dependency: `game/` -> `extension/` ->
`include/dopewars.h` -> `core/`. Nothing depends upward; nothing skips a
layer. This mirrors the `~/git/jumpnbump/` split (Zig core / C ABI / C++
GDExtension / GDScript game) with Mojo swapped in for Zig.

Each layer has an explicit forbidden list. A change that would cross a
boundary is a design bug, not a shortcut.

## `core/` — Mojo simulation

The whole game rulebook lives here: RNG, pricing, trading, events, combat,
scoring, serialization. Every function in `include/dopewars.h` is
ultimately implemented by a Mojo function in this directory.

### Allowed

- Mojo standard library and `max` extensions.
- Pure computation over the `dw_world` handle's storage.
- Emitting `dw_result` codes and populating caller-supplied view structs.

### Forbidden

- Any `import godot` or Godot-related module. The core does not know Godot
  exists.
- Any FFI symbol imported from the C++ shim. The dependency arrow points
  from `extension/` to `core/`, not back.
- File I/O, network I/O, environment reads. All input arrives as function
  arguments; all output leaves as function returns or caller-owned buffers.
- Global mutable state that is not inside the `dw_world` handle. One process
  may host multiple `dw_world`s, and their state must not alias.
- `print`/logging at steady state. Debug logging is fine during development
  behind a compile-time flag; shipping code emits no side channels.
- Any English (or other natural-language) presentation string. See
  `docs/abi-contract.md` — messages are structured payloads.

## `include/dopewars.h` — frozen C ABI

The single cross-language contract. Every consumer depends only on this
header; no other file in `core/` or `extension/` is a public surface.

### Allowed

- C11 fixed-width types (`stdint.h`, `stddef.h`).
- Function declarations, opaque struct forward declarations, plain C struct
  definitions, `#define` constants, anonymous enums, `DW_STATIC_ASSERT`.

### Forbidden

- Any Mojo type name or Mojo-specific attribute leaking into a signature.
- Any Godot type name (`GDExtensionObjectPtr`, `Variant`, etc.) leaking into
  a signature. The header is language-neutral.
- Any function declaration that `core/` does not export, or any exported
  symbol from `core/` that is not declared here. The two sets are equal.
- Bare C `enum` types crossing the ABI (see `docs/abi-contract.md`).
- Struct fields without `DW_STATIC_ASSERT` on the containing struct's
  sizeof.

## `extension/` — C++ GDExtension shim

A thin bridge that exposes `dw_world` operations to Godot as a GDExtension
class. One method per ABI function, forwarding arguments and translating
return codes into Godot-idiomatic values (`Dictionary`, `PackedByteArray`,
`Error` codes).

### Allowed

- godot-cpp headers.
- `#include "dopewars.h"`.
- Type conversion between C ABI structs and Godot `Variant` / `Dictionary`
  representations.
- Owning the `dw_world` storage on behalf of the GDScript node that created
  the extension instance.

### Forbidden

- Any game logic. Pricing math, event probability, combat rolls, inventory
  bookkeeping, score calculation: none of it lives here. If a shim method
  computes anything beyond argument marshalling, it belongs in `core/`.
- Any state that is not either (a) the `dw_world` handle's storage or
  (b) transient marshalling scratch. No cached prices, no last-event
  buffers, no "convenience" mirrors of core state.
- Direct symbol import from `core/` other than the functions declared in
  `include/dopewars.h`.
- Any translation of ABI error codes into human-readable strings. The shim
  passes structured error codes up; GDScript renders them.

## `game/` — Godot / GDScript presentation

The Godot project: scenes, UI, input handling, autoloads, save-slot
orchestration, high-score list rendering, translation strings. Where the JS
prototype's `<script id="ui">` block (`index.html:1081-1710`) ends up. Split into
four sub-layers whose dependency direction is `presentation`/`platform`/
`content` → `simulation` → `extension`; `game/README.md` documents the whole map.

### The one exception: `game/simulation/`

`game/simulation/world.gd` (`class_name SimWorld`) is the single pass-through
wrapper over the GDExtension class, and the only `.gd` file allowed to name it.
`tools/validate_game_boundary.py`, wired into `task game:boundary-check` (part
of `task check`), fails if any other script does, with
`ClassDB.class_exists("DopeWarsWorld")` as the only exemption — naming the class
to assert it is registered is not the same as depending on its API.
`tools/test_validate_game_boundary.py` self-checks that gate.

This is the mirror image of the `core/src` gate. `scripts/check-core-boundaries.sh`
says the simulation never reaches up into Godot; this one says the Godot layer
never reaches past the wrapper into the extension.

`SimWorld` re-exports the `dw_rules_*` accessors as *instance* methods even
though the shim binds them statically, because a GDScript `static func` never
appears in `get_method_list()` and 18 of the ABI's methods would then be
permanently invisible to the bridge test's completeness check.

### Allowed

- Any Godot API.
- Calls to `SimWorld` from anywhere in `game/`.
- Local UI-only state: which button is focused, which drug row is selected,
  which panel is open, animation timers, tween state.
- Reading/writing save files via Godot's `FileAccess`, feeding the raw
  bytes to `dw_world_load`/`dw_world_dump` through the extension.

### Forbidden

- Any direct Mojo import. GDScript does not link against Mojo; the
  GDExtension class is the only entry point.
- Naming `DopeWarsWorld` outside `game/simulation/`, for any reason short of
  the `ClassDB.class_exists` canary.
- Any game rule computation. Prices, event outcomes, combat results,
  serialization format, dealer-visit chances — all come from the extension,
  never from GDScript. `include/dopewars.h:444-452` and
  `docs/abi-contract.md`'s "Why the draw-owning rules live in the core" section
  are the worked example: the prototype's two 15% dealer rolls read the world's
  RNG from its UI layer, and GDScript cannot reach that stream at all, so they
  had to become `dw_roll_dealer_visits`.
- Any duplicate-of-core state. UI mirrors of `dw_world` values are read
  fresh from the extension per-frame or per-event, not cached in GDScript
  fields. The static `dw_rules_*` tables are the sanctioned exception:
  `include/dopewars.h` explicitly says callers may cache them once at startup.
- Any hard-coded English strings in scene files or scripts. All display
  text goes through `tr()` with keys that map to structured event payloads.
