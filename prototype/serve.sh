#!/usr/bin/env bash
# Превью прототипа. Биндимся на 0.0.0.0 — обязательно для Arena live preview.
# Все ассеты в index.html относительные, поэтому отдаём из каталога prototype/.
set -euo pipefail
cd "$(dirname "$0")"
exec python3 -u -m http.server "${PORT:-8000}" --bind 0.0.0.0
