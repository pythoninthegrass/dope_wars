#!/usr/bin/env -S uv run --script

# /// script
# requires-python = ">=3.13,<3.14"
# dependencies = []
# ///

"""
Self-test for tools/re/sound_handlers.py (TASK-013.01.03).

Usage: uv run tools/re/test_sound_handlers.py
"""

import sys
import tempfile
import traceback
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import sound_handlers

STRINGS = [
    (0x4A4BA8, "DWPeaShooter"),
    (0x4A4B94, "DWHandBag"),
    (0x47CE50, "DWSharkChainSaw"),
]
SOUNDS = [
    ("DWPeaShooter", "peashoot.wav", "Pea Shooter"),
    ("DWPeaShooterHit", "peashoothit.wav", "Cop Hit By Pea Shooter"),
    ("DWSharkChainsaw", "chainsaw.wav", "Chainsaw"),
    ("DWDump", "dump.wav", "Dump Drugs"),
]


def decompiled_dir(tmp: str) -> Path:
    out = Path(tmp)
    (out / "004a4a80_TCopChaseDlg_PlayWeaponSound.c").write_text(
        "void f(void){ play(0x4a4ba8); }"
    )
    (out / "0047cd00_TDWForm_Beat.c").write_text("void g(void){ play(0x47ce50); }")
    (out / "index.tsv").write_text("004a4a80\tx\t004a4a80_x.c\n")
    return out


def test_handlers_find_functions_referencing_the_event_string() -> None:
    with tempfile.TemporaryDirectory() as tmp:
        rows = sound_handlers.handlers(STRINGS, SOUNDS, decompiled_dir(tmp))
    by_event = {event: funcs for event, funcs in rows}
    assert by_event["DWPeaShooter"] == ["004a4a80_TCopChaseDlg_PlayWeaponSound.c"]


def test_hit_event_uses_the_weapon_string() -> None:
    with tempfile.TemporaryDirectory() as tmp:
        rows = sound_handlers.handlers(STRINGS, SOUNDS, decompiled_dir(tmp))
    assert dict(rows)["DWPeaShooterHit"] == ["004a4a80_TCopChaseDlg_PlayWeaponSound.c"]


def test_event_names_match_case_insensitively() -> None:
    with tempfile.TemporaryDirectory() as tmp:
        rows = sound_handlers.handlers(STRINGS, SOUNDS, decompiled_dir(tmp))
    assert dict(rows)["DWSharkChainsaw"] == ["0047cd00_TDWForm_Beat.c"]


def test_event_without_a_referencing_function_has_an_empty_list() -> None:
    with tempfile.TemporaryDirectory() as tmp:
        rows = sound_handlers.handlers(STRINGS, SOUNDS, decompiled_dir(tmp))
    assert dict(rows)["DWDump"] == []


def main() -> int:
    tests = [
        (n, f)
        for n, f in sorted(globals().items())
        if n.startswith("test_") and callable(f)
    ]
    failed = 0
    for name, fn in tests:
        try:
            fn()
        except Exception:
            failed += 1
            print(f"FAIL {name}", file=sys.stderr)
            traceback.print_exc()
    print(f"{len(tests) - failed}/{len(tests)} passed")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
