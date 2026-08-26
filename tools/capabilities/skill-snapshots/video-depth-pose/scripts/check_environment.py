#!/usr/bin/env python3
from __future__ import annotations

import importlib.util
import json
import shutil
import sys


REQUIRED = {
    "cv2": "opencv-python",
    "numpy": "numpy",
    "PIL": "Pillow",
    "torch": "torch",
    "transformers": "transformers",
    "ultralytics": "ultralytics",
}


def main() -> int:
    missing = [package for module, package in REQUIRED.items() if importlib.util.find_spec(module) is None]
    report = {
        "python": sys.version.split()[0],
        "ffmpeg": shutil.which("ffmpeg"),
        "ffprobe": shutil.which("ffprobe"),
        "missing_python_packages": missing,
        "ready": not missing,
    }
    print(json.dumps(report, ensure_ascii=False, indent=2))
    if missing:
        print(
            "\nInstall missing packages with:\n"
            f'  "{sys.executable}" -m pip install -r "{__file__.replace("check_environment.py", "requirements.txt")}"'
        )
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
