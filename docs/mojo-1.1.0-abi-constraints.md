# Mojo 1.1.0 C-ABI surface — verified constraints

Every claim below was verified against the pinned toolchain (`mojo==1.1.0`,
`taskfiles/core.yml:7`) by compiling a probe and, where the claim is about
caller-visible behaviour, by linking the produced object against a real C
driver. This is the reason the ABI seam in `core/src/abi.mojo` is shaped the
way it is; read this before trying to "just add a pointer parameter".

**Amended 2026-09-27.** The probe results below stand, but the original
"net consequence" (pointer-shaped exports impossible on 1.1.0) was wrong: the
probe never tried `OptionalPointer` with an explicitly bound *untracked* origin,
nor the lowercase `size_of[T]()` / `align_of[T]()` intrinsics (it probed only
`sizeof`/`alignof`). `core/src/abi.mojo` now exports all 54 declarations of
`include/dopewars.h` on the pinned toolchain. The spelling that works is in
"The spelling that works" below; everything above it documents the dead ends,
which are real dead ends.

## What `@export(...) abi("C")` can express

| Shape | Works? | Evidence |
| --- | --- | --- |
| Scalar in, scalar out | yes | `dw_abi_version` |
| Struct by value (≤ 16 B, two 8-byte classes) | yes | returned in `{ i64, i64 }`; C driver read the right fields |
| Struct by value (> 16 B, memory class) | yes | lowered to `ptr byval({ ... })`, exactly what clang emits |
| Struct return (≤ 16 B) | yes | returned in registers, matching clang's `ret { i64, i64 }` |
| Struct return (> 16 B) | yes | lowered to `void f(ptr sret({ ... }))`, matching clang |
| Mixed struct/scalar arguments | yes | registers and `byval` slots interleaved correctly; C driver read `t.a + f.c + n` back as 7 from `{3,4}`, 5, `{0,0,4,8}` |

So struct-by-value is a *correct* System V bridge in both directions, not an
approximation. A C caller written against the header reads exactly the fields
the Mojo side wrote.

## What `@export` rejects

**Any `ref` parameter makes the function parametric, and `@export` refuses
parametric functions.** This is the single constraint that dominates the
design:

```mojo
@export("dw_probe")
def dw_probe(inp: In, ref out: Out) abi("C") -> Int32: ...
# error: @export can not be applied on parametric functions
```

It is not about the struct being `Movable` rather than `Copyable`, and not
about the origin parameter being inferable. A bare `ref Int` is rejected with
the identical message. Consequences:

- `dw_world_init(dw_world *, const dw_config *)` cannot be written directly.
- `dw_state_get(const dw_world *, dw_state_view *)` cannot be written
  directly.
- Every two-call buffer function (`dw_prices_copy`, `dw_inventory_copy`,
  `dw_world_dump`, …) cannot be written directly: they all take a `*` out
  parameter.
- The free RNG functions (`dw_mulberry32_seed(uint32_t *, …)`) cannot be
  written directly either.

### Bare `Pointer` / `UnsafePointer` are not reachable as `@export` parameters

`Pointer[T]` / `UnsafePointer[T]` carry an `origin` parameter. Binding it with
`origin=_` still counts as parametric and is refused. Leaving it unbound is a
hard error ("failed to infer parameter 'origin'"). There is no spelling of a
*bare*-pointer-typed exported function — but see "The spelling that works":
`OptionalPointer` with an explicit untracked origin is accepted, and that is
what the whole ABI is built on.

### Mojo cannot synthesise a pointer from an integer

`include/dopewars.h`'s discipline (caller-owned storage, pointers in and out)
needs `address -> Pointer[T]`. No such constructor is reachable in 1.1.0:

| Attempt | Result |
| --- | --- |
| `Pointer[T](address=n)` | no matching initialisation |
| `Pointer[T](unsafe_from_address=n)` | candidate needs `mut` bound; `Pointer[T, False]` and `Pointer[T, mut=False]` are both rejected (`value passed to 'origin' cannot be converted from 'Bool'`) |
| `Pointer[T, origin=_](unsafe_from_address=n)` | no matching initialisation |
| `UnsafePointer[T](unsafe_from_address=n)` | no matching initialisation |
| `OpaquePointer(address=n)` | no matching initialisation |
| `pointer_from_int` / `ptr_from_int` / `int_to_ptr` / `address_to_pointer` / `reinterpret_pointer` (and ~30 further spellings) | `use of unknown declaration` |
| `asm[...]` / `inline_asm` / `llvm_asm` | `use of unknown declaration` |
| `sizeof` / `alignof` / `offset_of` / `address_of` | `use of unknown declaration` |

The reverse direction is missing too: `Pointer` exposes no `address`, `bits`,
`as_int`, `to_int`, `get_address` (or any comparable member), so Mojo cannot
even publish the address of memory it owns.

Two amendments from the merged implementation:

- The `sizeof` row above probed the wrong spellings. Mojo 1.1.0 has
  `size_of[T]()` and `align_of[T]()` (from `std.sys`), and they are usable in
  `@export` bodies: `dw_world_size` / `dw_world_align` return
  `size_of[World]()` / `align_of[World]()`. (`offset_of` / `address_of` remain
  absent.)
- No int→pointer constructor turned out to be needed. The contract's pointers
  enter through `OptionalPointer` parameters (below), which carry the caller's
  address across without Mojo ever spelling an integer-to-pointer conversion.
  On the calling side of an FFI probe, `Pointer(to=value)` materialises a
  pointer to a Mojo-owned value, which is all the conformance drivers need.

`std.builtin`, `std.memory`, `std.ffi`, `std.os`, `std.sys` were enumerated by
probing each candidate name; the only members that exist among the ones that
matter here are `Pointer`, `UnsafePointer`, `OpaquePointer`, `AddressSpace`
(`std.memory`) and `Pointer` (`std.ffi`).

### No globals

```mojo
var g_store: List[Int] = []
# error: global variables are not supported; move this into a function body
#        or use 'comptime' to declare a constant
```

So the world handle cannot live in a Mojo-side static; it has to be threaded
through caller-supplied memory, which is exactly what the header specifies.

## The spelling that works

`OptionalPointer[T, origin=MutUntrackedOrigin]` (mutable out-parameters) and
`OptionalPointer[T, origin=ImmUntrackedOrigin]` (const in-parameters) are
accepted by `@export(...) abi("C")` as parameters. The origin is bound to a
concrete (untracked) origin, so the function is not parametric; the Optional
wrapper gives NULL a first-class representation, which matches the header's
NULL-rejection discipline exactly:

```mojo
@export("dw_state_get")
def dw_state_get(
    world: OptionalPointer[world_mod.World, origin=ImmUntrackedOrigin],
    out_view: OptionalPointer[StateView, origin=MutUntrackedOrigin],
) abi("C") -> Int32:
    if not world or not out_view:
        return DW_ERR_INVALID_ARGUMENT
    ...
    out_view.value().unsafe_write(StateView(...))
    return DW_OK
```

Inside the body, `.value()[]` reads/writes the pointee, `.value()[i]` indexes
arrays, and `.unsafe_write(v)` placement-constructs — which is what the
caller-owned-storage contract needs: `dw_world_init` builds the `World` and
writes it into the caller's buffer, and `World` is plain data (fixed
`Array` + length fields, no heap) so the whole lifecycle crosses the seam
without a Mojo-side allocation the caller cannot free.

Evidence this is not a paper claim: `check_abi_exports.py` reports 56/56
declarations exported from `core/build-output/lib/libdopewars.a` with 0 leaked,
`core/abitest/` drives the pointer-shaped functions through ctypes and through
`std.ffi.external_call`, and both bridge tests cross them under Godot — all on
`mojo==1.1.0`.

One caveat the conformance suite records in `core/abitest/README.md`: an
`external_call` site cannot mix `Pointer` and `OptionalPointer` spellings for
the same symbol (signature conflict), so the Mojo driver passes every ABI
pointer argument as `OptionalPointer` and the NULL-guard paths are exercised
only by the ctypes tier and code inspection.

## Net consequence (corrected)

On Mojo 1.1.0 an exported function cannot take `ref` parameters or *bare*
`Pointer`/`UnsafePointer` parameters, but it can take `OptionalPointer` with an
explicit untracked origin — and that covers every pointer shape
`include/dopewars.h` declares. The frozen contract is exportable in full on the
pinned toolchain; the earlier conclusion that it was not was a probe gap, not a
toolchain limit.
