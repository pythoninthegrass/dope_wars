#!/usr/bin/env python3
"""Download and checksum-verify the Godot export templates (TASK-012.02 AC#3).

Godot never distributes export templates via mise, on any platform, so they
are always a checksum-verified download pinned in tools/game_toolchain.lock
(version-matched to the mise-pinned Godot release in .tool-versions).
Extracted to .tools/game/xdg-data/godot/export_templates/<version>/ -- a
repo-local, gitignored path under the fake $XDG_DATA_HOME that
taskfiles/export.yml points godot's own export step at via XDG_DATA_HOME, so
this never touches the user's real ~/.local/share/godot.
"""

from __future__ import annotations

import hashlib
import shutil
import urllib.request
import zipfile
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
LOCK_FILE = REPO_ROOT / "tools" / "game_toolchain.lock"
GAME_TOOLS = REPO_ROOT / ".tools" / "game"


def die(message: str) -> None:
    raise SystemExit(message)


def load_pins() -> dict[str, str]:
    import os

    pins: dict[str, str] = {}
    for line in LOCK_FILE.read_text().splitlines():
        line = line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        pins[key.strip()] = value.strip().strip('"')
    for key in pins:
        if key in os.environ:
            pins[key] = os.environ[key]
    return pins


def require_pin(pins: dict[str, str], key: str) -> str:
    if key not in pins:
        die(f"{key} is not set in tools/game_toolchain.lock (or the environment).")
    return pins[key]


def templates_dir(pins: dict[str, str]) -> Path:
    version = require_pin(pins, "GODOT_TEMPLATE_VERSION")
    return GAME_TOOLS / "xdg-data" / "godot" / "export_templates" / version


def download_verified(url: str, sha256: str, destination: Path) -> None:
    if destination.exists():
        digest = hashlib.sha256(destination.read_bytes()).hexdigest()
        if digest == sha256:
            print(f"Reusing verified {destination.name}")
            return
        destination.unlink()
    print(f"Downloading {url}")
    try:
        with urllib.request.urlopen(url) as response:
            data = response.read()
    except OSError as e:
        die(f"Could not download {url}: {e}")
    digest = hashlib.sha256(data).hexdigest()
    if digest != sha256:
        die(f"Checksum mismatch for {url}\n  expected {sha256}\n  got      {digest}")
    destination.parent.mkdir(parents=True, exist_ok=True)
    destination.write_bytes(data)


def main() -> None:
    pins = load_pins()
    version = require_pin(pins, "GODOT_TEMPLATE_VERSION")
    dest_dir = templates_dir(pins)

    if (dest_dir / "version.txt").exists():
        if (dest_dir / "version.txt").read_text().strip() == version:
            print(f"Export templates {version} already installed at {dest_dir}")
            return

    downloads = GAME_TOOLS / "downloads"
    archive = downloads / Path(require_pin(pins, "GODOT_TEMPLATES_URL")).name
    download_verified(
        require_pin(pins, "GODOT_TEMPLATES_URL"),
        require_pin(pins, "GODOT_TEMPLATES_SHA256"),
        archive,
    )

    staging = dest_dir.parent / f".staging-{dest_dir.name}"
    shutil.rmtree(staging, ignore_errors=True)
    with zipfile.ZipFile(archive) as bundle:
        bundle.extractall(staging)
    dest_dir.parent.mkdir(parents=True, exist_ok=True)
    shutil.rmtree(dest_dir, ignore_errors=True)
    (staging / "templates").rename(dest_dir)
    shutil.rmtree(staging, ignore_errors=True)

    installed_version = (dest_dir / "version.txt").read_text().strip()
    if installed_version != version:
        die(f"Export templates report {installed_version}, expected {version}")
    print(f"Export templates {version} ready at {dest_dir}")


if __name__ == "__main__":
    try:
        main()
    except (OSError, zipfile.BadZipFile) as e:
        die(str(e))
