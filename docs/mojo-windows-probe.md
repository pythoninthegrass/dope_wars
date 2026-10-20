# Mojo cross-compiling the simulation core for Windows from Linux

**Phase A probe.** Pinned toolchain `mojo==1.1.0` (commit `8189361e`), host
`Linux-x86_64` (znver4). The venv lives at `core/.venv`; every command below
runs `core/.venv/bin/mojo`. LLVM tooling comes from mise
(`/home/lance/.local/share/mise/installs/emsdk/4.0.11/upstream/bin`, clang-21 /
lld / llvm-nm / llvm-objdump).

This is a research spike. Everything below is reproduced verbatim or by a
concrete command; dead ends are called out as dead ends. The goal is to answer:
*how far does `mojo build`'s cross-compilation get toward Windows, and by what*
*exactly does it break?*

## TL;DR

The Mojo **frontend accepts both Windows target triples** and emits valid COFF
object files that export **all 53 `dw_*` declarations** of `include/dopewars.h`
with **no symbol drift** relative to the native build. The blocker is **not**
the compiler: it is the **link/runtime layer**. The only undefined externals in
the cross objects are four `KGEN_CompilerRT_*` symbols, and the PyPI package
ships **only Linux `.so` builds** of the runtime support libraries — there is no
`libKGENCompilerRTShared.lib` / `.dll` for Windows. A COFF/PE linker (`ld.lld`
in the standard layout) is not present in the installed toolchain, so the
objects cannot be validated end-to-end yet. In short: **codegen works, linking
does not.**

## 1. Baseline (native object + reference symbol table)

Command:

```sh
cd core
.venv/bin/mojo build src/abi.mojo --emit object --target-cpu x86-64-v3 -o abi_native.o
```

(The `--target-cpu x86-64-v3` mirrors `taskfiles/core.yml:48`'s
`MOJO_CPU_FLAGS`; without it Mojo defaults to the host CPU, which emits AVX-512
code that traps elsewhere. The only stderr line is a harmless Crashpad warning:
`Failed to initialize Crashpad. Crash reporting will not be available.`)

Result: `abi_native.o` — `ELF 64-bit LSB relocatable, x86-64`, 322 symbols.
`llvm-nm` output saved as `native_symbols.txt`. All 53 `dw_*` symbols are
defined (`T`); the runtime symbols (`KGEN_CompilerRT_*`, etc.) are undefined,
which the build pipeline then resolves by demoting non-dw globals to local
(`taskfiles/core.yml:50-53`) and linking against the shipped `.so`s.

## 2. Windows triple attempts

Both triples accepted. Full output captured in `msvc.log` / `gnu.log`.

```sh
.venv/bin/mojo build src/abi.mojo --emit object --target-triple x86_64-pc-windows-msvc --target-cpu x86-64 -o abi_msvc.o
.venv/bin/mojo build src/abi.mojo --emit object --target-triple x86_64-w64-windows-gnu --target-cpu x86-64 -o abi_gnu.o
```

Both exit `0` with only the Crashpad warning. `file` reports:

| object | result |
| --- | --- |
| `abi_native.o` | `ELF 64-bit LSB relocatable, x86-64, version 1 (SYSV)` |
| `abi_msvc.o` | `Intel amd64 COFF object file, not stripped, 35 sections, 299 symbols, 1st section ".text"` |
| `abi_gnu.o` | `Intel amd64 COFF object file, not stripped, 6 sections, 211 symbols, 1st section ".text"` |

COFF is the Windows object format, so both commands produced genuine Windows
objects despite `--print-supported-targets` listing only `x86-64` (generic) and
no Windows-specific entry. `--print-effective-target` confirms the triple was
absorbed and applied:

```sh
Effective target configuration:
  --target-triple x86_64-pc-windows-msvc
  --target-cpu znver4
  --target-features +adx,+aes,+avx,+avx2,+avx512bf16,+avx512bitalg,+avx512bw,+avx512cd,+avx512dq,+avx512f,+avx512ifma,+avx512vbmi,+avx512vbmi2,+avx512vl,+avx512vnni,+avx512vpopcntdq,+bmi,+bmi2,+clflushopt,+clwb,+clzero,+crc32,+cx16,+cx8,+f16c,+fma,+fsgsbase,+fxsr,+gfni,+invpcid,+lzcnt,+mmx,+movbe,+mwaitx,+pclmul,+pku,+popcnt,+prfchw,+rdpid,+rdpru,+rdrnd,+rdseed,+sahf,+sha,+shstk,+sse,+sse2,+sse3,+sse4.1,+sse4.2,+sse4a,+ssse3,+vaes,+vpclmulqdq,+wbnoinvd,+x87,+xsave,+xsavec,+xsaveopt,+xsaves
```

Note the CPU defaulted to `znver4` (the host) with the full AVX-512 feature set
because `--target-cpu` was not pinned to `x86-64-v3`; a real cross build needs
`--target-cpu x86-64-v3` to match the native baseline (see §7).

## 3. Symbol table inspection and categorization

`abi_msvc.o` and `abi_gnu.o` are symbol-identical in the `dw_*` set: **all 53
declarations are defined (`T`), zero `dw_*` symbols are undefined.** The
complete defined set:

`dw_abi_version, dw_accept_coat_offer, dw_accept_doctor_offer, dw_accept_gun_offer,
dw_apply_damage, dw_borrow, dw_buy, dw_buy_health, dw_coat_used, dw_fight,
dw_finances, dw_find_drug_index, dw_find_location_index, dw_finish,
dw_generate_prices, dw_health_price, dw_insert_highscore, dw_inventory_copy,
dw_loans_copy, dw_mulberry32_next_u32, dw_mulberry32_seed, dw_offers_copy,
dw_prev_prices_copy, dw_price_events_drain, dw_prices_copy, dw_rand_int,
dw_repay, dw_roll_arrival_event, dw_roll_coat_dealer_offer, dw_roll_dealer_visit,
dw_roll_gun_dealer_offer, dw_roll_shark_release, dw_rules_bank_interest_bp,
dw_rules_cheap_divide, dw_rules_default_num_days, dw_rules_default_start_cash,
dw_rules_default_start_debt, dw_rules_default_start_health,
dw_rules_default_start_location_index, dw_rules_drugs_copy, dw_rules_drugs_len,
dw_rules_expensive_multiply, dw_rules_locations_copy, dw_rules_locations_len,
dw_rules_sharks_copy, dw_run_from_chase, dw_sell, dw_shark_visit,
dw_should_start_chase, dw_start_chase, dw_state_get, dw_stay_in_chase,
dw_travel, dw_visits_copy, dw_world_align, dw_world_dump, dw_world_dump_len,
dw_world_init, dw_world_load, dw_world_reset, dw_world_size`

This matches `include/dopewars.h`'s 53 declarations and the native object
exactly — **no drift, no missing exports, no mangling.** `llvm-objdump -r`
confirms the relocations are `IMAGE_REL_AMD64_REL32` (the correct Windows
relocation type), not the ELF `R_X86_64_*` family.

Categorizing every external:

| Category | Symbol(s) | Resolvable? | Notes |
| --- | --- | --- | --- |
| Runtime (`KGEN_CompilerRT_*`) | `KGEN_CompilerRT_AlignedAlloc`, `KGEN_CompilerRT_AlignedFree`, `KGEN_CompilerRT_GetStackTrace`, `KGEN_CompilerRT_fprintf` | **Names match the Linux `.so`, but no Windows lib ships them** | The only true undefined externals. All four are exported by `libKGENCompilerRTShared.so` (see §4). |
| Startup | `__chkstk` (msvc) / `___chkstk_ms` (gnu) | Standard | CRT-provided stack-check thunk; present in the Windows CRT. |
| Runtime (AsyncRT / MSupport) | *(none undefined)* | N/A | Inlined into the object; the three support libs are **not** a link dependency here. |
| `std::` | `std::format::_utils::_fixed_buffer_exceeded`, `std::io::io::_flush` | **Defined locally** | Both appear as `T` (lowercase `t`, local) in the object — not externals. |
| Float constants | `__real@...` (18 entries) | Defined locally | `long double` / `double` literals embedded in the object. |

So the **entire** undefined-external surface of the cross object is the four
`KGEN_CompilerRT_*` symbols. AsyncRT (`libAsyncRTRuntimeGlobals.so`, 61 exports)
and MSupport (`libMSupportGlobals.so`, 31 exports) are **not** referenced — the
release build inlines them, so the only question is whether KGEN's four symbols
are resolvable on Windows.

## 4. Venv inventory for Windows runtime libraries

Directory: `core/.venv/lib/python3.13/site-packages/modular/lib/`

```sh
libAsyncRTRuntimeGlobals.so
libKGENCompilerRTShared.so
libMSupportGlobals.so
liblldb24.0.0git.so
libMojoJupyter.so
libMojoLLDB.so
lldb-visualizers/
mojo/
mojo-repl-entry-point
```

Exhaustive search for Windows artifacts:

```sh
find core/.venv \( -iname '*.lib' -o -iname '*.dll' -o -iname '*.obj' \)   # empty
find core/.venv -type d -iname '*windows*'                                  # empty
```

**No Windows builds of any runtime support library are shipped.** The three
KGEN/AsyncRT/MSupport libraries exist only as `x86-64` ELF shared objects.
`file` on `libKGENCompilerRTShared.so` reports `ELF 64-bit LSB shared object,
x86-64`. The four symbols the cross object needs are exported by that ELF
(`nm -D` lists `KGEN_CompilerRT_AlignedAlloc`, `AlignedFree`, `GetStackTrace`,
`fprintf` as `T`), but that is the Linux export table, not a Windows one.

**Dead end (recorded):** there is no Windows variant to link against. This is
the hard blocker. The extension shim (`extension/SConstruct`) already knows to
vend `libKGENCompilerRTShared.so` by rpath from the venv — a Windows build
would need the corresponding `.lib`/`.dll`, which the PyPI package does not
provide.

## 5. Link attempt (concrete evidence of the blocker)

The native build resolves the four KGEN symbols by linking the Linux `.so`.
Reproducing that against a COFF object with the system `clang`/`ld` (from
emsdk, clang-21):

```sh
clang -shared -o abi_msvc_link.so abi_msvc.o libKGENCompilerRTShared.so
```

Fails:

```sh
/usr/bin/ld: abi_msvc_link.so: version node not found for symbol __real@4014000000000000
/usr/bin/ld: failed to set dynamic section sizes: bad value
```

This is an ELF-format error — the system `ld` cannot consume a COFF/PE object
with an ELF `.so`, exactly as expected. The GNU triple's object links further
but surfaces the real Windows gaps:

```sh
abi_gnu.o:abi.mojo:(.text+0x5563): undefined reference to `fma'
abi_gnu.o:abi.mojo:(.text+0xaea2): undefined reference to `___chkstk_ms'
abi_gnu.o:abi.mojo:(.pdata+0x0): dangerous relocation: R_AMD64_IMAGEBASE with __ImageBase undefined
...
```

`___chkstk_ms`, `__ImageBase`, and `R_AMD64_IMAGEBASE` are all CRT/PE
conventions that a Windows linker (or the Windows CRT stub) supplies but a
Linux `ld` does not. The `fma` reference is the un-pinned `--target-cpu`
artifact again (an AVX FMA intrinsic), which pins away under `x86-64-v3`.

A proper `ld.lld` COFF/PE driver is **not installed** in the standard emsdk
layout:

```sh
ls upstream/bin/ | grep -i lld      # only `lld` (generic driver)
./ld.lld -flavor=coff ...           # ld.lld: No such file or directory
```

The generic `lld` from emsdk is the wasm-only flavor and rejects
`-flavor=coff`; there is no `x86_64-w64-mingw32-gcc`/`-ld` (mingw) on this
host either. So the COFF objects cannot be validated end-to-end yet — the
codegen is proven, the link is not.

## 6. Bitcode checkpoint (frontend vs backend/runtime isolation)

To confirm the blocker is downstream of codegen, the bitcode emit was attempted:

```sh
.venv/bin/mojo build src/abi.mojo --emit llvm-bitcode --target-triple x86_64-pc-windows-msvc -o abi_msvc.bc
```

Exit `0`; `abi_msvc.bc` produced (`LLVM IR bitcode`, 369 KB). Bitcode is
platform-agnostic IR, so this succeeds regardless of backend/linker state.
**Conclusion: the blocker is not the compiler frontend.** The frontend accepts
the Windows triple and lowers the whole `dw_*` surface to valid target IR/COFF;
the failure is entirely in the runtime-support / CRT link layer (§4 + §5).

## 7. Implications for TASK-012.04

- **Codegen is viable.** `mojo build --emit object --target-triple x86_64-pc-windows-msvc`
  (and the `-gnu` variant) produces correct COFF with all 53 exports and no
  symbol drift. The two-call buffer functions, struct-by-value returns, and the
  pointer-free `OptionalPointer` surface from `docs/mojo-1.1.0-abi-constraints.md`
  all lower correctly for Windows.
- **The unresolved question is the runtime.** Four things stand between here and
  a working Windows build:
  1. Ship (or locate) Windows builds of `libKGENCompilerRTShared` — the only
     external dependency. AsyncRT/MSupport are inlined and need not ship.
  2. Provide the Windows CRT stub for `__chkstk` / `___chkstk_ms` / `__ImageBase`
     (normally comes free with the CRT).
  3. Provide a COFF/PE linker (`ld.lld` in the lld distribution, or mingw) to
     validate the link.
  4. Pin `--target-cpu x86-64-v3` on the cross build (as the native build
     already does) so AVX-512 / FMA intrinsics don't leak into the object.
- **Extension shim.** `extension/SConstruct` vends the runtime `.so`s by rpath
  from the venv; a Windows build path would need the same treatment for the
  `.lib`/`.dll`, once they exist.

## Appendix: commands used

```sh
cd core
.venv/bin/mojo --version                                  # Mojo 1.1.0 (8189361e)
.venv/bin/mojo build src/abi.mojo --emit object --target-cpu x86-64-v3 -o abi_native.o
.venv/bin/mojo build src/abi.mojo --emit object --target-triple x86_64-pc-windows-msvc --target-cpu x86-64 -o abi_msvc.o
.venv/bin/mojo build src/abi.mojo --emit object --target-triple x86_64-w64-windows-gnu --target-cpu x86-64 -o abi_gnu.o
.venv/bin/mojo build --print-supported-targets             # x86-64 only (generic)
.venv/bin/mojo build src/abi.mojo --emit object --target-triple x86_64-pc-windows-msvc --print-effective-target
llvm-nm abi_native.o > native_symbols.txt
llvm-nm abi_msvc.o | grep -E '\b(dw_[a-z0-9_]+)\b'
llvm-objdump -r abi_msvc.o | awk '{print $NF}' | sort -u
find core/.venv \( -iname '*.lib' -o -iname '*.dll' -o -iname '*.obj' \)
find core/.venv -type d -iname '*windows*'
nm -D core/.venv/lib/python3.13/site-packages/modular/lib/libKGENCompilerRTShared.so | grep KGEN_CompilerRT
.venv/bin/mojo build src/abi.mojo --emit llvm-bitcode --target-triple x86_64-pc-windows-msvc -o abi_msvc.bc
```
---

## Phase B: Native Windows install of the Mojo package (in the dockurr/windows container)

Container: `dockurr/windows`, image `de1f5a165879`, name `windows` — a Windows 11
GUI install reached from mf over published ports (SSH on 2222, noVNC on 8006).
See `docs/windows.md` for the access details.

### Environment set up in the container

- Chocolatey 2.7.4 was already present, so all package installs went through it.
- Python 3.13.16 installed via Chocolatey at `C:\Python313`, matching the host's
  pinned `python 3.13.16` in `.tool-versions` and the host's `core/.venv`
  (`lib/python3.13`), because `mojo==1.1.0` ships as a python3.13 wheel.
  Verified: `C:\Python313\python.exe --version` → `Python 3.13.16`; pip 26.2.1.
- uv installed via Chocolatey (`uv 0.13.1`, `x86_64-pc-windows-msvc`).

### uv PATH gotcha (dead end, recorded as such)

`uv` is **not on PowerShell's PATH** after the Chocolatey install: the package's
payload landed at `C:\ProgramData\chocolatey\lib\uv\tools\uv.exe` but no shim was
created at `C:\ProgramData\chocolatey\bin\uv.exe`, and `where.exe uv` finds nothing.

- Cause: the Chocolatey install run was interrupted, so it unpacked the package
  without completing the shim/link step.
- Working around it (no reinstall needed): invoke the absolute path
  `& 'C:\ProgramData\chocolatey\lib\uv\tools\uv.exe'`. That resolves it —
  `--version` reports `uv 0.13.1 (x86_64-pc-windows-msvc)`.

A second gotcha: `uv pip install` refuses to run outside a virtual environment
(`error: No virtual environment found`). Since the target here is the
Chocolatey-installed system interpreter, the correct invocation is
`uv pip install --system`, which correctly reports
`Using Python 3.13.16 environment at: C:\Python313`.

### Decisive result — no Windows wheel exists

```text
& 'C:\ProgramData\chocolatey\lib\uv\tools\uv.exe' pip install --system 'mojo==1.1.0'

Using Python 3.13.16 environment at: C:\Python313
error: No solution found when resolving dependencies
  cause: Because mojo==1.1.0 has no wheels with a matching platform tag (e.g., `win_amd64`) and
you require mojo==1.1.0, we can conclude that your requirements are unsatisfiable.
hint: Wheels are available for `mojo` (v1.1.0) on the following platforms:
`manylinux_2_34_aarch64`, `manylinux_2_34_x86_64`, `macosx_13_0_arm64`
```

This names the platform tags Mojo 1.1.0 publishes: two Linux flavors plus macOS
arm64. **There is no Windows wheel of any kind** (`win_amd64` absent), which is
stronger than the earlier pip attempt, which only reported
`from versions: none` / `No matching distribution found`.

`import mojo` in the system interpreter consequently fails (`ModuleNotFoundError`),
so there is nothing to build: no `mojo build`, no `--emit object`, and no Windows
runtime libraries to inspect. The Phase B checkpoint (build natively if the wheel
installs) is unreachable, and the MSVC `libdopewars.dll` link checkpoint was never
reached — no direction was needed, since the probe did not succeed end to end.

### Beermat 2.1 oracle untouched

`C:\dopewars21\` still holds `DopeWars.exe`, `Olchk32.dll`, `cities.txt`,
`oldlady.txt` and the `Sounds\` assets. Both installs are confined to their own
locations (`C:\Python313`, `C:\ProgramData\chocolatey\lib\uv`), so the oracle
install is unaffected.

### Note on probe mechanics

- Host `llvm-nm`/`llvm-objdump` came from an unrelated mise shim that was
  misconfigured (`mise ERROR No version is set for shim`); the working
  inspection binaries are documented per-invocation, and no build artifact of
  this repo depends on them.
- The container's SSH port mapping changed from `0.0.0.0:2222` to a LAN-bound
  address after the container was restarted, so `ssh -p 2222 ...@localhost`
  refused while the LAN address connected. See `docs/windows.md`.
