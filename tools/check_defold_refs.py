#!/usr/bin/env python3
"""Проверка ссылок внутри Defold-проекта без сборки.

Читает game.project, *.collection, *.go, *.gui, *.font, *.input_binding
и убеждается, что все ресурсы, на которые они ссылаются, существуют.

Compiled-суффикс `c` (например /main/main.collectionc) отбрасывается.
Пути /builtins/... принадлежат движку и не проверяются.

Запуск: python3 tools/check_defold_refs.py [client_dir]
(по умолчанию проверяется замороженный legacy/defold-client)
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

# расширение в исходниках -> как оно выглядит после компиляции в проекте
COMPILED = {
    ".collection": ".collectionc",
    ".go": ".goc",
    ".gui": ".guic",
    ".script": ".scriptc",
    ".gui_script": ".gui_scriptc",
    ".font": ".fontc",
    ".material": ".materialc",
    ".atlas": ".atlasc",
    ".input_binding": ".input_bindingc",
    ".label": ".labelc",
    ".tilemap": ".tilemapc",
    ".sprite": ".spritec",
    ".particlefx": ".particlefxc",
}
COMPILED_TO_SRC = {v: k for k, v in COMPILED.items()}

PATH_RE = re.compile(r'"(/[^"\s]+?)((?:%s)?)"' % "|".join(
    re.escape(ext) for ext in sorted(COMPILED, key=len, reverse=True)
))
# в game.project значения не в кавычках: key = /path/to/file
PROJECT_RE = re.compile(r"^[a-z0-9_]+(?:#\d+)?\s*=\s*(/\S+)\s*$", re.MULTILINE)


def iter_paths(path: Path):
    text = path.read_text(encoding="utf-8")
    if path.name == "game.project":
        for match in PROJECT_RE.finditer(text):
            yield match.group(1)
        return
    for match in PATH_RE.finditer(text):
        yield match.group(1) + match.group(2)


def resolve(client: Path, raw: str) -> Path | None:
    """Вернуть ожидаемый файл-исходник или None, если проверять нечего."""
    if raw.startswith("/builtins/"):
        return None
    for compiled, src_ext in COMPILED_TO_SRC.items():
        if raw.endswith(compiled):
            raw = raw[: -len(compiled)] + src_ext
            break
    return client / raw.lstrip("/")


def main() -> int:
    client = Path(sys.argv[1] if len(sys.argv) > 1 else "legacy/defold-client").resolve()
    if not (client / "game.project").exists():
        print(f"не найден game.project в {client}")
        return 2

    targets = [client / "game.project"]
    for pattern in ("**/*.collection", "**/*.go", "**/*.gui", "**/*.font", "**/*.input_binding"):
        targets.extend(client.glob(pattern))

    checked = 0
    problems: list[str] = []
    for path in sorted(set(targets)):
        for raw in iter_paths(path):
            expected = resolve(client, raw)
            if expected is None:
                continue
            checked += 1
            if not expected.exists():
                problems.append(f"{path.relative_to(client)} -> {raw} (нет файла {expected.relative_to(client)})")

    print(f"проверено ссылок: {checked}")
    if problems:
        print("ПРОБЛЕМЫ:")
        for p in problems:
            print("  ", p)
        return 1
    print("все ссылки разрешаются")
    return 0


if __name__ == "__main__":
    sys.exit(main())
