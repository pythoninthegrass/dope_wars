# Mojo Windows Cross-Compile Probe

Research spike for `TASK-012.04`: can `core/src/abi.mojo` cross-compile toward a
Windows target, and what exactly blocks a Windows `libdopewars.dll`?

Date: 2026-10-20. Toolchain: Mojo 1.1.0 (8189361e), PyPI package, venv at
`core/.venv`. Host: AlmaLinux. LLVM inspection tools: LLVM 28.1.13356709 NDK
(`llvm-nm`, `llvm-objdump`).

## Summary

`mojo build --emit object` **does** produce valid Windows COFF object files for
both the MSVC (`x86_64-pc-windows-msvc`) and GNU (`x86_64-w64-windows-gnu`)
triples. Compilation is not the blocker. The blocker is downstream: the installed
Mojo PyPI package ships only Linux/ELF runtime support libraries, and they are
stripped, so the undefined symbols in the Windows object cannot be resolved by the
shipped toolchain alone. A Windows `.dll` would still require a Windows linker and
a Windows build of the Mojo runtime libraries.

This contradicts the "expected" outcome in the task (missing Windows runtime libs
blocking compilation). Compilation succeeds; linking does not — and it never did,
even natively, because `--emit object` only produces a relocatable object.

## 1. Baseline (native build)

```bash
mojo build --emit object -o abi.native.o core/src/abi.mojo
```

Result: exit 0 (a benign "Failed to initialize Crashpad" warning is printed).

```
abi.native.o: ELF 64-bit LSB relocatable, x86-64, version 1 (SYSV), not stripped
```

Symbol table (322 symbols): all ABI symbols are **defined** (`dw_abi_version`,
`dw_buy`, `dw_sell`, `dw_travel`, `dw_finances`, `dw_generate_prices`,
`dw_roll_arrival_event`, `dw_mulberry32_seed`, etc.), plus `KGEN_CompilerRT_*`
symbols as **undefined** (10 undefined symbols total).

## 2. Windows target triples

Both triples compile and produce Windows COFF objects.

### 2.1 `x86_64-pc-windows-msvc`

```bash
mojo build --emit object --target-triple x86_64-pc-windows-msvc \
    -o abi.win-msvc.o core/src/abi.mojo
```

Result: exit 0.

```
abi.win-msvc.o: Intel amd64 COFF object file, not stripped, 50 sections,
343 symbols, 1st section name ".text"
```

Undefined symbols (12):

| Symbol | Category |
|--------|----------|
| `KGEN_CompilerRT_AlignedAlloc` | Mojo runtime |
| `KGEN_CompilerRT_AlignedFree` | Mojo runtime |
| `KGEN_CompilerRT_GetStackTrace` | Mojo runtime |
| `KGEN_CompilerRT_fprintf` | Mojo runtime |
| `__chkstk` | CRT (MSVC) |
| `_fltused` | CRT (MSVC) |
| `dup`, `fclose`, `fdopen`, `fflush` | libc (MSVC) |
| `memcpy`, `write` | libc (MSVC) |

### 2.2 `x86_64-w64-windows-gnu`

```bash
mojo build --emit object --target-triple x86_64-w64-windows-gnu \
    -o abi.win-gnu.o core/src/abi.mojo
```

Result: exit 0.

```
abi.win-gnu.o: Intel amd64 COFF object file, not stripped, 6 sections,
210 symbols, 1st section name ".text"
```

Undefined symbols (11): identical to the MSVC object except the CRT symbols are
GNU-flavored (`___chkstk_ms` instead of `__chkstk`; no `_fltused`).

### 2.3 Comparison

The only differences between the native and Windows objects' undefined symbol
sets are the CRT symbols native to each target (`__chkstk`/`_fltused` for MSVC,
`___chkstk_ms` for GNU). The `KGEN_CompilerRT_*` symbols — the Mojo runtime
dependencies — are **identical** across native and both Windows objects. The
compiler frontend and backend handle the Windows target correctly; the object
emission is target-appropriate (COFF, correct CRT symbols).

## 3. Venv inventory (the blocker)

The Mojo PyPI package ships runtime support libraries under
`core/.venv/lib/python3.13/site-packages/modular/lib/`:

| Library | Size | Type |
|---------|------|------|
| `libKGENCompilerRTShared.so` | 1.2 MB | ELF x86-64 shared object (stripped) |
| `libAsyncRTRuntimeGlobals.so` | 685 KB | ELF x86-64 shared object (stripped) |
| `libMSupportGlobals.so` | 49 KB | ELF x86-64 shared object (stripped) |

No Windows builds exist anywhere in the package:

- No `.lib` files.
- No `.dll` files.
- No `.o`/`.obj` (COFF) files.
- No files with `win` in the name.

All three runtime libraries are ELF (Linux) shared objects, and all three are
**stripped** — `llvm-nm` reports "no symbols" for them, so their exact exported
symbol names cannot be inspected directly. But the Windows objects' undefined
`KGEN_CompilerRT_*` symbols match the symbol names the native object needs, and
the native object links against these same libraries natively, so the libraries
*would* export the needed symbols — if they were Windows builds.

## 4. Conclusion

**Compilation to a Windows object succeeds.** The blocker is not compilation; it
is linking. Specifically:

1. `mojo build --emit object` produces valid Windows COFF objects for both MSVC
   and GNU triples, with only standard CRT/libc symbols undefined.
2. The Mojo runtime support libraries shipped in the PyPI package are Linux ELF
   only and stripped. They cannot be linked into a Windows `.dll` by a Windows
   linker, and no Windows builds ship with the toolchain.
3. Even natively, `--emit object` only produces a relocatable object; linking
   requires a separate toolchain (the Linux build already does this via SCons).
   For Windows, that toolchain would be MSVC or MinGW, plus a Windows build of the
   three runtime libraries above — none of which ship with Mojo 1.1.0.

**What would be needed for a viable Windows build:**

- A Windows build of `libKGENCompilerRTShared`, `libAsyncRTRuntimeGlobals`, and
  `libMSupportGlobals` (either from Modular, or by cross-compiling the Mojo
  runtime to Windows). These are the symbols the object cannot resolve.
- A Windows linker (MSVC `link.exe` or MinGW `x86_64-w64-gcc`) to combine the
  object with the Windows runtime libs into `libdopewars.dll`.
- Wiring into `extension/SConstruct` and the taskfiles (out of scope for this
  spike).

**Dead end (recorded as such):** the assumption that "no native Windows Mojo
toolchain means compilation fails" is wrong for `--emit object`. Compilation works;
the missing artifact is a Windows build of the runtime libraries and a Windows
linker, not the Mojo compiler itself.

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

## Overall conclusion (both phases)

Windows is **blocked** for the simulation core, at two independent points:

1. **Package distribution (Phase B, decisive):** the pinned `mojo==1.1.0`
   publishes only `manylinux_2_34_{x86_64,aarch64}` and `macosx_13_0_arm64`
   wheels. There is no Windows wheel, so the toolchain cannot even be installed
   natively on Windows.
2. **Linking (Phase A):** even cross-compiling from Linux, `--emit object`
   succeeds and emits valid Windows COFF, but the Mojo runtime libraries ship
   only as Linux ELF and the object's `KGEN_CompilerRT_*` symbols are
   unresolvable without Windows builds of them plus a Windows linker.

**What would be needed** to make Windows viable: Windows builds of
`libKGENCompilerRTShared`, `libAsyncRTRuntimeGlobals` and `libMSupportGlobals`,
distributed as a `win_amd64` wheel (or built by cross-compiling the runtime),
plus a Windows linker (MSVC `link.exe` / MinGW) to produce `libdopewars.dll`,
plus wiring into `extension/SConstruct` and the taskfiles — all out of scope for
this spike.

### Note on probe mechanics

- Host `llvm-nm`/`llvm-objdump` came from an unrelated mise shim that was
  misconfigured (`mise ERROR No version is set for shim`); the working
  inspection binaries are documented per-invocation, and no build artifact of
  this repo depends on them.
- The container's SSH port mapping changed from `0.0.0.0:2222` to a LAN-bound
  address after the container was restarted, so `ssh -p 2222 ...@localhost`
  refused while the LAN address connected. See `docs/windows.md`.
