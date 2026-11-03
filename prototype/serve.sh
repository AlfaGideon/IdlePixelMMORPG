#!/usr/bin/env bash
# Превью прототипа. Биндимся на 0.0.0.0 — обязательно для Arena live preview.
# Раздаём КОРЕНЬ репозитория: там лежит основной интерактивный index.html,
# а картинки доступны по относительному пути prototype/screens/.
set -euo pipefail
cd "$(dirname "$0")/.."
exec python3 -u -m http.server "${PORT:-8000}" --bind 0.0.0.0
