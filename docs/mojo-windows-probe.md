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

## Phase B: Native Mojo build in the dockurr/windows container (in progress)

> Last updated 2026-10-20. This section is a work in progress; the container was
> stopped mid-run. See "Handoff" for the exact next steps.

### Environment

- Container: `dockurr/windows`, image `de1f5a165879`, name `windows`.
- Access from mf: `ssh -p 2222 lance@localhost` (PowerShell; SSH keys work).
- Chocolatey 2.7.4 was already installed.
- Python: installed via `choco install python312`, then switched to **python 3.13.16**
  at `C:\Python313` (to match `.tool-versions`; the host's `core/.venv` is python3.13,
  so `mojo==1.1.0` is a python3.13 wheel). pip 26.2.1 confirmed working.
- uv: **not installed** in the container. `choco install uv` was started but the
  agent tool call was interrupted before it completed.

### Results so far

- `& C:\Python313\python.exe -m pip install 'mojo==1.1.0'` → **FAILED**:
  `ERROR: Could not find a version that satisfies the requirement mojo==1.1.0
  (from versions: none)` / `No matching distribution found`.
  This is the decisive Phase B result: pip found **no win_amd64 wheel** for
  `mojo==1.1.0`. (For comparison, the host installs `mojo==1.1.0` fine via uv, so
  the linux_amd64 wheel exists — the blocker is Windows-specific.)
- `uv pip install mojo` was not yet attempted; uv is not installed.

### Handoff (next agent)

1. Confirm the container is running (`docker ps --filter name=windows`).
2. Install uv into the container: `choco install uv -y --no-progress` (retry the
   interrupted install).
3. Retry the decisive test: `& C:\Python313\python.exe -m uv pip install 'mojo==1.1.0'`
   (and, if it fails, bare `uv pip install mojo`). Capture exact output.
4. If the wheel installs, build `core/src/abi.mojo` natively
   (`mojo build --emit object`) and note whether the wheel ships Windows
   runtime libs. If it does not install, the "no win_amd64 wheel" result above
   is conclusive — record it and stop.
5. Append findings to this doc and verify the Beermat 2.1 oracle
   (`C:\dopewars21\DopeWars.exe`) still launches.
