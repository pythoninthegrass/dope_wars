#!/usr/bin/env -S uv run --script

# /// script
# requires-python = ">=3.13,<3.14"
# dependencies = ["pefile"]
# ///

"""
Self-test for tools/re/extract_beermat.py (TASK-010.01.01).

Builds a synthetic TPF0 blob in memory, so the decoder is checked without the
copyrighted exe being present.

Usage: uv run tools/re/test_extract_beermat.py
"""

import struct
import sys
import tempfile
import traceback
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

import extract_beermat as eb


def short(text: str) -> bytes:
    raw = text.encode("latin-1")
    return bytes([len(raw)]) + raw


def prop(name: str, value: bytes) -> bytes:
    return short(name) + value


def int8(n: int) -> bytes:
    return b"\x02" + struct.pack("<b", n)


def int16(n: int) -> bytes:
    return b"\x03" + struct.pack("<h", n)


def int32(n: int) -> bytes:
    return b"\x04" + struct.pack("<i", n)


def string(text: str) -> bytes:
    return b"\x06" + short(text)


def ident(text: str) -> bytes:
    return b"\x07" + short(text)


FALSE = b"\x08"
TRUE = b"\x09"


def collection(items: list[bytes]) -> bytes:
    body = b"".join(b"\x01" + item + b"\x00" for item in items)
    return b"\x0e" + body + b"\x00"


def obj(
    cls: str, name: str, props: list[bytes], children: list[bytes] | None = None
) -> bytes:
    return (
        short(cls)
        + short(name)
        + b"".join(props)
        + b"\x00"
        + b"".join(children or [])
        + b"\x00"
    )


def synthetic_blob() -> bytes:
    button = obj(
        "TButton", "BuyBtn", [prop("Caption", string("Buy")), prop("Enabled", FALSE)]
    )
    form = obj(
        "TForm1",
        "Form1",
        [
            prop("Left", int8(10)),
            prop("Width", int16(-300)),
            prop("Color", int32(0x7FFFFF)),
            prop("Caption", string("Dope Wars")),
            prop("Visible", TRUE),
            prop("OnClick", ident("BuyBtnClick")),
            prop(
                "Panels",
                collection([prop("Width", int16(50)) + prop("Text", string("Cash"))]),
            ),
        ],
        [button],
    )
    return b"TPF0" + form


def test_decode_root_names() -> None:
    root = eb.decode_tpf0(synthetic_blob())
    assert root.class_name == "TForm1", root.class_name
    assert root.name == "Form1", root.name


def test_decode_scalar_properties() -> None:
    props = dict(eb.decode_tpf0(synthetic_blob()).props)
    assert props["Left"] == 10
    assert props["Width"] == -300
    assert props["Color"] == 0x7FFFFF
    assert props["Caption"] == "Dope Wars"
    assert props["Visible"] is True


def test_decode_identifier_is_distinct_from_string() -> None:
    props = dict(eb.decode_tpf0(synthetic_blob()).props)
    assert isinstance(props["OnClick"], eb.Ident)
    assert props["OnClick"].text == "BuyBtnClick"
    assert not isinstance(props["Caption"], eb.Ident)


def test_decode_child_component() -> None:
    root = eb.decode_tpf0(synthetic_blob())
    assert [c.name for c in root.children] == ["BuyBtn"]
    child = root.children[0]
    assert child.class_name == "TButton"
    assert dict(child.props)["Enabled"] is False


def test_decode_collection_items() -> None:
    panels = dict(eb.decode_tpf0(synthetic_blob()).props)["Panels"]
    assert isinstance(panels, eb.Collection)
    assert len(panels.items) == 1
    assert dict(panels.items[0]) == {"Width": 50, "Text": "Cash"}


def test_decode_rejects_bad_magic() -> None:
    try:
        eb.decode_tpf0(b"NOPE" + b"\x00" * 8)
    except ValueError:
        return
    raise AssertionError("bad magic was accepted")


def test_render_dfm_text() -> None:
    text = eb.render_dfm(eb.decode_tpf0(synthetic_blob()))
    lines = text.splitlines()
    assert lines[0] == "object Form1: TForm1", lines[0]
    assert "  Left = 10" in lines
    assert "  Caption = 'Dope Wars'" in lines
    assert "  Visible = True" in lines
    assert "  OnClick = BuyBtnClick" in lines
    assert "  object BuyBtn: TButton" in lines
    assert "    Caption = 'Buy'" in lines
    assert "    Enabled = False" in lines
    assert lines[-1] == "end"


def test_render_dfm_escapes_quote() -> None:
    blob = b"TPF0" + obj("TForm1", "F", [prop("Caption", string("it's"))])
    text = eb.render_dfm(eb.decode_tpf0(blob))
    assert "  Caption = 'it''s'" in text.splitlines()


def test_collect_handlers() -> None:
    root = eb.decode_tpf0(synthetic_blob())
    assert eb.collect_handlers(root) == [("Form1", "OnClick", "BuyBtnClick")]


def test_main_missing_exe_exits_2() -> None:
    with tempfile.TemporaryDirectory() as tmp:
        missing = Path(tmp) / "nope.exe"
        assert eb.main(["--exe", str(missing), "--out", tmp]) == 2


SOUND_LABELS = {
    "DWCopGunShot": "Cops Gun",
    "DWYourGunShot": "Your Gun",
    "DWYouHitByGun": "You Hit By Bullet",
    "DWCopHitByGun": "Cop Hit By Bullet",
    "DWCopChase": "Cops Start Chasing You",
    "DWPoliceDog": "Police Dog",
    "DWCashReg": "Cash Register",
    "DWMugged": "Mugged",
    "DWDead": "Death Rattle",
    "DWLastDay": "Last Day Warning",
}
SOUND_WAVS = {
    "DWCopGunShot": "gun.wav",
    "DWYourGunShot": "gun2.wav",
    "DWYouHitByGun": "youhit.wav",
    "DWCopHitByGun": "cophit.wav",
    "DWCopChase": "siren.wav",
    "DWPoliceDog": "bark.wav",
    "DWCashReg": "cashreg.wav",
    "DWMugged": "hrdpunch.wav",
    "DWDead": "wasted.wav",
    "DWLastDay": "uhoh.wav",
}


def sound_entry(event: str, wav: str, label: str) -> list[str]:
    return [
        wav,
        rf"AppEvents\Schemes\Apps\DopeWars\{event}\.current",
        label,
        rf"AppEvents\EventLabels\{event}",
    ]


def sound_strings(skip: str | None = None) -> list[str]:
    out = ["AllowSound"]
    for event, wav in SOUND_WAVS.items():
        if event != skip:
            out += sound_entry(event, wav, SOUND_LABELS[event])
    return out


def pack_strings(texts: list[str]) -> bytes:
    return b"\x00\x01" + b"\x00".join(t.encode("latin-1") for t in texts) + b"\x00ZZ"


def test_scan_strings_min_length_and_offsets() -> None:
    blob = b"\x00abc\x00abcd\x00\xffxyz12\x01ab\x00"
    assert eb.scan_strings(blob) == [(5, "abcd"), (11, "xyz12")]


def test_parse_sounds_pairs_wav_with_following_event() -> None:
    strings = eb.scan_strings(pack_strings(sound_strings()))
    rows = eb.parse_sounds(strings)
    assert len(rows) == 10, rows
    assert rows == [(e, SOUND_WAVS[e], SOUND_LABELS[e]) for e in SOUND_WAVS]


def test_parse_sounds_ignores_unrelated_strings() -> None:
    texts = ["Software\\Beermat Software\\DopeWars\\Settings\\", "readme.wav"]
    strings = eb.scan_strings(pack_strings(texts + sound_strings()))
    assert len(eb.parse_sounds(strings)) == 10


def test_parse_sounds_matches_wav_case_insensitively() -> None:
    texts = sound_strings()
    texts[texts.index("siren.wav")] = "Siren.wav"
    rows = eb.parse_sounds(eb.scan_strings(pack_strings(texts)))
    assert ("DWCopChase", "Siren.wav", "Cops Start Chasing You") in rows


def test_parse_sounds_missing_row_raises() -> None:
    strings = eb.scan_strings(pack_strings(sound_strings(skip="DWMugged")))
    try:
        eb.parse_sounds(strings)
    except ValueError as err:
        assert "DWMugged" in str(err), err
        return
    raise AssertionError("a missing AppEvent row was accepted")


def test_parse_sounds_wrong_wav_raises() -> None:
    texts = sound_strings()
    texts[texts.index("bark.wav")] = "meow.wav"
    try:
        eb.parse_sounds(eb.scan_strings(pack_strings(texts)))
    except ValueError as err:
        assert "DWPoliceDog" in str(err), err
        return
    raise AssertionError("a wrong wav was accepted")


def test_write_sounds_outputs_tsv_and_strings() -> None:
    data = pack_strings(sound_strings())
    with tempfile.TemporaryDirectory() as tmp:
        out = Path(tmp)
        assert eb.write_string_outputs(data, lambda off: 0x400000 + off, out) == 0
        tsv = (out / "sounds.tsv").read_text().splitlines()
        assert len(tsv) == 10, tsv
        assert tsv[0] == "DWCopGunShot\tgun.wav\tCops Gun"
        strings = (out / "strings.txt").read_text().splitlines()
        assert strings[0] == "00400002\tAllowSound", strings[0]
        assert len(strings) == len(sound_strings())


def test_write_sounds_missing_row_exits_nonzero() -> None:
    data = pack_strings(sound_strings(skip="DWDead"))
    with tempfile.TemporaryDirectory() as tmp:
        out = Path(tmp)
        assert eb.write_string_outputs(data, lambda off: off, out) == 1
        assert (out / "strings.txt").is_file()


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
