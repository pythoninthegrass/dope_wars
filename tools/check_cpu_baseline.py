#!/usr/bin/env python3
"""CPU-baseline gate (TASK-012.05 AC#3).

The Linux x86-64 core is built with `--target-cpu x86-64-v3` (AVX2, FMA, BMI2;
see docs/build-and-test.md) so the exported game runs on any machine from about
2013 on, not only on a CPU like the one that built it. Mojo defaults to the host
CPU, so a build host with AVX-512 silently emits instructions that trap with
SIGILL elsewhere.

This disassembles a built artifact and fails if any instruction uses an AVX-512
marker: a zmm register, a k-mask register, or the xmm16-31/ymm16-31 registers
that only EVEX can encode. ymm and VEX instructions are inside the baseline and
are allowed.

Usage:
  check_cpu_baseline.py <artifact> [<artifact>...]
  check_cpu_baseline.py core/build-output/lib/libdopewars.a --objdump objdump
"""

from __future__ import annotations

import argparse
import re
import subprocess
import sys

AVX512_MARKER = re.compile(r"%zmm|%k[0-7]\b|%[xy]mm(?:1[6-9]|2[0-9]|3[01])\b")


def avx512_violations(disassembly: str) -> list[str]:
    """Disassembly lines that use an AVX-512 register."""
    return [line for line in disassembly.splitlines() if AVX512_MARKER.search(line)]


def disassemble(artifact: str, objdump: str) -> str:
    return subprocess.run(
        [objdump, "-d", "--no-show-raw-insn", artifact],
        check=True,
        capture_output=True,
        text=True,
    ).stdout


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("artifacts", nargs="+")
    parser.add_argument("--objdump", default="objdump")
    args = parser.parse_args()

    failed = False
    for artifact in args.artifacts:
        violations = avx512_violations(disassemble(artifact, args.objdump))
        if violations:
            failed = True
            print(
                f"check_cpu_baseline: {artifact}: {len(violations)} AVX-512 instruction(s) "
                "outside the x86-64-v3 baseline; first few:",
                file=sys.stderr,
            )
            for line in violations[:5]:
                print(f"  {line.strip()}", file=sys.stderr)
        else:
            print(f"check_cpu_baseline: {artifact}: ok")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
