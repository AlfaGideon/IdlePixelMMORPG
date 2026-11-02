#!/usr/bin/env python3
"""Прописывает пути Android SDK и JDK в Editor Settings Godot.

Без этого headless-экспорт падает с «A valid Android SDK path is required
in Editor Settings», даже когда ANDROID_HOME и JAVA_HOME заданы в окружении.

Запуск: после первого `godot --headless --import` (он создаёт файл настроек).
"""

from __future__ import annotations

import glob
import os
import re
import sys
from pathlib import Path


def settings_path() -> Path:
    config_home = Path(os.environ.get("XDG_CONFIG_HOME", Path.home() / ".config"))
    candidates = sorted(glob.glob(str(config_home / "godot" / "editor_settings-*.tres")))
    if not candidates:
        sys.exit("не найден editor_settings-*.tres — сначала запустите godot --import")
    return Path(candidates[-1])


def set_key(text: str, key: str, value: str) -> str:
    pattern = re.compile(rf"^{re.escape(key)}\s*=.*$", re.MULTILINE)
    line = f'{key}="{value}"'
    if pattern.search(text):
        return pattern.sub(line, text, count=1)
    if "[resource]" not in text:
        text += "\n[resource]\n"
    return text.replace("[resource]", f"[resource]\n{line}", 1)


def main() -> int:
    android_sdk = os.environ.get("ANDROID_HOME") or os.environ.get("ANDROID_SDK_ROOT")
    java_sdk = os.environ.get("JAVA_HOME")
    if not android_sdk:
        sys.exit("ANDROID_HOME не задан")
    if not java_sdk:
        sys.exit("JAVA_HOME не задан")

    path = settings_path()
    text = path.read_text(encoding="utf-8")
    text = set_key(text, "export/android/android_sdk_path", android_sdk)
    text = set_key(text, "export/android/java_sdk_path", java_sdk)
    text = set_key(text, "export/android/force_system_user", "false")
    path.write_text(text, encoding="utf-8")

    print(f"настройки: {path}")
    for key in ("export/android/android_sdk_path", "export/android/java_sdk_path"):
        for line in path.read_text(encoding="utf-8").splitlines():
            if line.startswith(key):
                print("  ", line)

    # быстрая проверка, что SDK действительно похож на SDK
    for sub in ("platform-tools", "build-tools"):
        print("  sdk:", sub, "=", (Path(android_sdk) / sub).exists())
    return 0


if __name__ == "__main__":
    sys.exit(main())
