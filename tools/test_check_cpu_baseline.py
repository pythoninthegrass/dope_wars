#!/usr/bin/env -S uv run --script

# /// script
# requires-python = ">=3.13,<3.14"
# ///

"""
Self-check for tools/check_cpu_baseline.py (TASK-012.05 AC#3).

Feeds the scanner synthetic objdump disassembly: AVX2 on ymm registers (inside
the x86-64-v3 baseline, must pass), plain SSE, and each AVX-512 marker that must
fail: a zmm register, a k-mask register, a masked destination, and the
xmm16-31/ymm16-31 registers only EVEX can encode.

Usage: uv run tools/test_check_cpu_baseline.py
"""

import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import check_cpu_baseline as baseline


def main() -> int:
    failures: list[str] = []

    def expect(name: str, disassembly: str, violations: int) -> None:
        found = len(baseline.avx512_violations(disassembly))
        if found != violations:
            failures.append(f"{name}: expected {violations} violation(s), got {found}")

    expect("empty", "", 0)
    expect("scalar", "  1000:\tmov    %rax,%rbx\n", 0)
    expect("sse", "  1000:\tpaddq  %xmm1,%xmm0\n", 0)
    expect("avx2 ymm", "  1000:\tvpaddq %ymm1,%ymm0,%ymm2\n", 0)
    expect("avx2 fma", "  1000:\tvfmadd231pd %ymm1,%ymm0,%ymm2\n", 0)
    expect("zmm", "  1000:\tvpaddq %zmm1,%zmm0,%zmm2\n", 1)
    expect("k mask register", "  1000:\tkmovw  %k1,%eax\n", 1)
    expect("masked destination", "  1000:\tvmovdqu8 %xmm1,%xmm0{%k1}\n", 1)
    expect("extended xmm", "  1000:\tvpxord %xmm16,%xmm1,%xmm2\n", 1)
    expect("extended ymm", "  1000:\tvmovdqa64 %ymm31,%ymm0\n", 1)
    expect("register name only substring", "  1000:\tmov    %xmm160x,%rax\n", 0)
    expect(
        "two bad lines",
        "  1000:\tvpaddq %zmm1,%zmm0,%zmm2\n  1005:\tkmovw  %k1,%eax\n",
        2,
    )

    if failures:
        for failure in failures:
            print(f"FAIL: {failure}", file=sys.stderr)
        return 1
    print("check_cpu_baseline self-check: ok (12 cases)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
