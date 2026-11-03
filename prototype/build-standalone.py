#!/usr/bin/env python3
"""Собирает standalone.html — версию прототипа с абсолютными ссылками на картинки.

Нужна для открытия по внешней ссылке без GitHub Pages (например, через
htmlpreview.github.io): внутри HTML нет ни одного относительного пути.
"""
from pathlib import Path

BASE = "https://raw.githubusercontent.com/AlfaGideon/IdlePixelMMORPG/arena/58423ecd-idlepixelmmorpg/prototype/screens"

here = Path(__file__).resolve().parent
html = (here / "index.html").read_text(encoding="utf-8")

old = "const src = (v,i) => `screens/${v}/${SCREENS[i].id}.png`;"
new = f"const src = (v,i) => `{BASE}/${{v}}/${{SCREENS[i].id}}.png`;"
assert old in html, "шаблон src() не найден — обнови скрипт"

html = html.replace(old, new)
html = html.replace(
    "<title>IdlePixelMMORPG — прототип интерфейса</title>",
    "<title>IdlePixelMMORPG — прототип (standalone, внешние ссылки)</title>",
)
html = html.replace(
    "<html lang=\"ru\">",
    "<!-- Сгенерировано build-standalone.py из index.html: абсолютные raw.githubusercontent.com URL. -->\n<html lang=\"ru\">",
)
(here / "standalone.html").write_text(html, encoding="utf-8")
print("standalone.html готов, абсолютных URL:", html.count(BASE))
