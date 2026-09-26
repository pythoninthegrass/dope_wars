# Mojo 1.1.0 C-ABI surface — verified constraints

Every claim below was verified against the pinned toolchain (`mojo==1.1.0`,
`taskfiles/core.yml:7`) by compiling a probe and, where the claim is about
caller-visible behaviour, by linking the produced object against a real C
driver. This is the reason the ABI seam in `core/src/abi.mojo` is shaped the
way it is; read this before trying to "just add a pointer parameter".

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

### Pointer types are not reachable as `@export` parameters

`Pointer[T]` / `UnsafePointer[T]` carry an `origin` parameter. Binding it with
`origin=_` still counts as parametric and is refused. Leaving it unbound is a
hard error ("failed to infer parameter 'origin'"). So there is no spelling of
a pointer-typed exported function at all.

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
through caller-supplied memory, which is exactly what the header specifies and
what we cannot do without the int→pointer constructor above.

## Net consequence

On Mojo 1.1.0, an exported function can only receive and return *values*.
The frozen contract in `include/dopewars.h` is pointer-shaped throughout
(opaque handle in, out-params everywhere). Those two facts are irreconcilable
inside `core/src/abi.mojo` alone, which is why TASK-001.05 is blocked on this
toolchain rather than merely unfinished.

The two ways out, in order of preference:

1. **Upgrade Mojo** past the version where `@export` accepts an unbound
   `origin`/`ref` parameter (or exposes an int→pointer constructor). The whole
   frozen header then becomes directly exportable with no contract change.
2. **Hand-written assembly trampolines** in a separate translation unit
   compiled by `cc`/`as`, which read the pointer arguments per System V and
   call into Mojo with struct-by-value shims. This keeps the header intact but
   puts real ABI code outside `core/src/abi.mojo`, which violates the
   single-exporter discipline in `docs/abi-contract.md` and is the kind of
   thing that rots.

Option 1 is the recommendation; option 2 is viable but should be a deliberate
trade, not a silent workaround.
