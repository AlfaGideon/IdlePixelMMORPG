#!/usr/bin/env python3
"""Проверка проекта Godot без запуска редактора.

Что проверяется:
  * project.godot читается, config_version = 5;
  * run/main_scene и config/icon указывают на существующие файлы;
  * все res://-пути в .tscn / .tres / .gd существуют;
  * ExtResource("id") и SubResource("id") объявлены в том же файле;
  * parent="..." у узлов .tscn указывает на существующий узел;
  * id подресурсов не дублируются.

Запуск: python3 tools/check_godot_project.py [client_dir]
"""

from __future__ import annotations

import re
import sys
from pathlib import Path

EXT_RE = re.compile(r"^\[ext_resource\b([^\]]*)\]", re.MULTILINE)
SUB_RE = re.compile(r"^\[sub_resource\b([^\]]*)\]", re.MULTILINE)
NODE_RE = re.compile(r"^\[node\b([^\]]*)\]", re.MULTILINE)
ATTR_RE = re.compile(r'(\w+)="([^"]*)"')
RES_PATH_RE = re.compile(r'"(res://[^"]+)"')
EXT_REF_RE = re.compile(r'ExtResource\(\s*"([^"]+)"\s*\)')
SUB_REF_RE = re.compile(r'SubResource\(\s*"([^"]+)"\s*\)')


def read_attrs(chunk: str) -> dict[str, str]:
    return dict(ATTR_RE.findall(chunk))


def check_scene(path: Path, project: Path, problems: list[str]) -> int:
    text = path.read_text(encoding="utf-8")
    rel = path.relative_to(project)

    ext_ids: set[str] = set()
    sub_ids: list[str] = []
    for match in EXT_RE.finditer(text):
        attrs = read_attrs(match.group(1))
        res_id = attrs.get("id")
        if res_id:
            ext_ids.add(res_id)
        res_path = attrs.get("path")
        if res_path and res_path.startswith("res://") and not (project / res_path[6:]).exists():
            problems.append(f"{rel}: ext_resource указывает на отсутствующий {res_path}")

    for match in SUB_RE.finditer(text):
        attrs = read_attrs(match.group(1))
        if "id" in attrs:
            sub_ids.append(attrs["id"])
    sub_id_set = set(sub_ids)
    for dup in {i for i in sub_ids if sub_ids.count(i) > 1}:
        problems.append(f"{rel}: дублирующийся sub_resource id={dup}")

    for res_id in EXT_REF_RE.findall(text):
        if res_id not in ext_ids:
            problems.append(f"{rel}: ExtResource(\"{res_id}\") не объявлен")
    for res_id in SUB_REF_RE.findall(text):
        if res_id not in sub_id_set:
            problems.append(f"{rel}: SubResource(\"{res_id}\") не объявлен")

    nodes: dict[str, str] = {}
    roots: list[str] = []
    for match in NODE_RE.finditer(text):
        attrs = read_attrs(match.group(1))
        name = attrs.get("name")
        if not name:
            continue
        parent = attrs.get("parent")
        if parent is None:
            roots.append(name)
            nodes[name] = name
            continue
        parent_path = "" if parent in (".", "") else parent
        if parent_path and parent_path not in nodes:
            problems.append(f"{rel}: узел {name} ссылается на несуществующего родителя {parent_path}")
        path_here = f"{parent_path}/{name}" if parent_path else name
        nodes[path_here] = path_here

    if roots and len(roots) > 1:
        problems.append(f"{rel}: несколько корневых узлов: {roots}")
    if "ExtResource" in text or "SubResource" in text:
        pass
    for res_path in RES_PATH_RE.findall(text):
        if not (project / res_path[6:]).exists():
            problems.append(f"{rel}: путь {res_path} не существует")

    return len(nodes)


def main() -> int:
    project = Path(sys.argv[1] if len(sys.argv) > 1 else "client").resolve()
    project_file = project / "project.godot"
    if not project_file.exists():
        print(f"не найден project.godot в {project}")
        return 2

    text = project_file.read_text(encoding="utf-8")
    problems: list[str] = []

    if not re.search(r"^config_version\s*=\s*5\s*$", text, re.MULTILINE):
        problems.append("project.godot: ожидается config_version=5 (формат Godot 4)")

    for key in ("run/main_scene", "config/icon"):
        match = re.search(rf"^{re.escape(key)}\s*=\s*\"(res://[^\"]+)\"", text, re.MULTILINE)
        if not match:
            problems.append(f"project.godot: не задан {key}")
            continue
        target = project / match.group(1)[6:]
        if not target.exists():
            problems.append(f"project.godot: {key} указывает на отсутствующий {match.group(1)}")

    scenes = sorted(list(project.glob("**/*.tscn")) + list(project.glob("**/*.tres")))
    scripts = sorted(project.glob("**/*.gd"))
    node_count = 0
    for scene in scenes:
        node_count += check_scene(scene, project, problems)

    for script in scripts:
        for res_path in RES_PATH_RE.findall(script.read_text(encoding="utf-8")):
        text = script.read_text(encoding="utf-8")
        for res_path in RES_PATH_RE.findall(text):
            # шаблоны вида runner_%s.png собираются в рантайме — проверяем каталог
            if "%" in res_path:
                folder = project / Path(res_path[6:]).parent
                if not folder.is_dir():
                    problems.append(f"{script.relative_to(project)}: нет каталога {res_path}")
                continue
            if not (project / res_path[6:]).exists():
                problems.append(f"{script.relative_to(project)}: путь {res_path} не существует")

    print(f"сцен: {len(scenes)}, скриптов: {len(scripts)}, узлов: {node_count}")
    if problems:
        print("ПРОБЛЕМЫ:")
        for item in problems:
            print("  ", item)
        return 1
    print("проект консистентен")
    return 0


if __name__ == "__main__":
    sys.exit(main())
