#!/usr/bin/env python3
from __future__ import annotations

import os
import plistlib
import shutil
import stat
import subprocess
import sys
from pathlib import Path


ROOT = Path(__file__).resolve().parent.parent
WORK = ROOT / "work"
OUTPUTS = ROOT / "outputs"
APP_NAME = "Paper Forge"
APP_BUNDLE = OUTPUTS / f"{APP_NAME}.app"
CONTENTS = APP_BUNDLE / "Contents"
MACOS = CONTENTS / "MacOS"
RESOURCES = CONTENTS / "Resources"


def make_executable(path: Path) -> None:
    mode = path.stat().st_mode
    path.chmod(mode | stat.S_IXUSR | stat.S_IXGRP | stat.S_IXOTH)


def main() -> int:
    OUTPUTS.mkdir(parents=True, exist_ok=True)
    if APP_BUNDLE.exists():
        shutil.rmtree(APP_BUNDLE)

    MACOS.mkdir(parents=True, exist_ok=True)
    RESOURCES.mkdir(parents=True, exist_ok=True)

    shutil.copy2(WORK / "pdf_to_image_app.py", RESOURCES / "pdf_to_image_app.py")

    launcher = MACOS / APP_NAME
    launcher.write_text(
        "#!/bin/sh\n"
        "DIR=\"$(CDPATH= cd -- \"$(dirname -- \"$0\")\" && pwd)\"\n"
        "exec /Users/chiachung.lim/.cache/codex-runtimes/codex-primary-runtime/dependencies/python/bin/python3 "
        "\"$DIR/../Resources/pdf_to_image_app.py\"\n",
        encoding="utf-8",
    )
    make_executable(launcher)

    plist = {
        "CFBundleName": APP_NAME,
        "CFBundleDisplayName": APP_NAME,
        "CFBundleExecutable": APP_NAME,
        "CFBundleIdentifier": "com.codex.pdf-to-image-converter",
        "CFBundlePackageType": "APPL",
        "CFBundleVersion": "1.0.0",
        "CFBundleShortVersionString": "1.0.0",
        "NSHighResolutionCapable": True,
        "LSMinimumSystemVersion": "10.15",
    }
    with open(CONTENTS / "Info.plist", "wb") as f:
        plistlib.dump(plist, f)

    # Add a helpful README inside the app bundle for future maintenance.
    (RESOURCES / "README.txt").write_text(
        "Launch the app by double-clicking the .app bundle.\n"
        "The converter uses the bundled Python runtime and Poppler pdftoppm.\n",
        encoding="utf-8",
    )

    print(f"Created {APP_BUNDLE}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
