#!/usr/bin/env -S uv run --script

# /// script
# requires-python = ">=3.13,<3.14"
# dependencies = []
# ///

"""
Map each AppEvents sound event to the decompiled functions that reference its name string (TASK-013.01.03).

Reads <re dir>/strings.txt, sounds.tsv and decompiled/ (all written by `task re:extract` and `task re:decompile`) and writes <re dir>/sound_handlers.tsv.

Usage: uv run tools/re/sound_handlers.py [--re vendor/dopewars-2001/re]
"""

import argparse
import re
import sys
from pathlib import Path

HIT_SUFFIX = "hit"


def load_strings(path: Path) -> list[tuple[int, str]]:
    rows = (
        line.split("\t", 1) for line in path.read_text(encoding="utf-8").splitlines()
    )
    return [(int(va, 16), text) for va, text in rows]


def handlers(
    strings: list[tuple[int, str]],
    sounds: list[tuple[str, str, str]],
    decompiled: Path,
) -> list[tuple[str, list[str]]]:
    """(event, files of functions referencing the event's string); <weapon>Hit events use the weapon's string."""
    vas: dict[str, list[int]] = {}
    for va, text in strings:
        vas.setdefault(text.lower(), []).append(va)
    files = [
        (f.name, f.read_text(errors="replace").lower())
        for f in sorted(decompiled.glob("*.c"))
    ]
    rows = []
    for event, _, _ in sounds:
        name = event.lower()
        wanted = vas.get(name) or vas.get(name.removesuffix(HIT_SUFFIX), [])
        needles = [re.compile(rf"0x{va:x}\b") for va in wanted]
        rows.append(
            (event, [fn for fn, text in files if any(n.search(text) for n in needles)])
        )
    return rows


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.split("\n\n")[0])
    parser.add_argument("--re", type=Path, default=Path("vendor/dopewars-2001/re"))
    args = parser.parse_args()

    sounds = [
        tuple(line.split("\t"))
        for line in (args.re / "sounds.tsv").read_text(encoding="utf-8").splitlines()
    ]
    rows = handlers(
        load_strings(args.re / "strings.txt"), sounds, args.re / "decompiled"
    )
    (args.re / "sound_handlers.tsv").write_text(
        "".join(f"{event}\t{','.join(funcs)}\n" for event, funcs in rows),
        encoding="utf-8",
    )
    unresolved = [event for event, funcs in rows if not funcs]
    print(f"{len(rows) - len(unresolved)}/{len(rows)} events resolved")
    for event in unresolved:
        print(f"error: no function references {event}", file=sys.stderr)
    return 1 if unresolved else 0


if __name__ == "__main__":
    sys.exit(main())
