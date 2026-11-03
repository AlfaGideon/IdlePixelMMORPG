#!/usr/bin/env python3
"""Собирает standalone.html — версию интерактивного прототипа с абсолютными URL.

Основной index.html лежит в корне репозитория и использует относительный путь
`prototype/screens`. Для открытия по внешней ссылке (htmlpreview.github.io)
нужны абсолютные ссылки на raw.githubusercontent.com, поэтому заменяем только
константу ART_BASE. Всё остальное (CSS, JS, состояние) остаётся идентичным.
"""
from pathlib import Path

RAW = ("https://raw.githubusercontent.com/AlfaGideon/IdlePixelMMORPG/"
       "arena/58423ecd-idlepixelmmorpg/prototype/screens")

here = Path(__file__).resolve().parent
root = here.parent
html = (root / "index.html").read_text(encoding="utf-8")

old = "const ART_BASE = 'prototype/screens'; // STANDALONE_BASE"
new = f"const ART_BASE = '{RAW}'; // STANDALONE_BASE"
assert old in html, "маркер ART_BASE не найден — обнови скрипт"

html = html.replace(old, new)
html = html.replace(
    "<title>IdlePixelMMORPG — интерактивный прототип</title>",
    "<title>IdlePixelMMORPG — интерактивный прототип (внешняя ссылка)</title>",
)
html = html.replace(
    '<html lang="ru">',
    "<!-- Сгенерировано build-standalone.py из корневого index.html. Не редактировать вручную. -->\n<html lang=\"ru\">",
)
(here / "standalone.html").write_text(html, encoding="utf-8")
print("standalone.html готов, абсолютный ART_BASE подставлен")
