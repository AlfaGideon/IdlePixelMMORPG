#!/usr/bin/env bash
# Запускает проект Godot headless и ищет ошибки скриптов.
#
# Зачем: gdparse/gdlint проверяют только синтаксис и стиль. Ошибки уровня
# «неизвестный член», «не удалось вывести тип», битые ссылки на ресурсы
# проявляются только при реальной загрузке проекта — их и ловим.
#
# Использование: smoke_test.sh <путь_к_godot>
set -uo pipefail

GODOT="${1:-$HOME/godot/godot}"
LOG="/tmp/build-${GITHUB_JOB:-smoke}.log"
PROJECT="client"
FAIL=0

mkdir -p /tmp/smoke
: > "$LOG"

run_check() {
  local name="$1"
  shift
  local out
  out=$("$@" 2>&1)
  echo "===== $name =====" | tee -a "$LOG"
  echo "$out" | tee -a "$LOG"

  # SCRIPT ERROR / Parse Error / неразрешённые ресурсы — повод упасть
  local bad
  bad=$(echo "$out" | grep -E "SCRIPT ERROR|Parse Error|Cannot open file|Failed to load script|Invalid call\. Nonexistent function|Cannot infer the type|isn't a constant expression" || true)
  if [ -n "$bad" ]; then
    echo "FAIL: $name" | tee -a "$LOG"
    FAIL=1
  fi
}

# 1. Импорт ресурсов (создаёт .godot/ и .import)
run_check "import" timeout 180 "$GODOT" --headless --path "$PROJECT" --import

# 2. Реальная загрузка проекта: 120 кадров, затем выход
run_check "run" timeout 120 "$GODOT" --headless --path "$PROJECT" --quit-after 120

# 3. Отдельно проверим, что скрипты компилируются (--check-only)
for script in client/scripts/boot.gd client/ui/pixel_scene.gd client/ui/kit.gd; do
  run_check "check $script" timeout 60 "$GODOT" --headless --path "$PROJECT" --check-only --script "res://${script#client/}"
done

if [ "$FAIL" -ne 0 ]; then
  echo "SMOKE FAILED" | tee -a "$LOG"
  exit 1
fi
echo "SMOKE OK" | tee -a "$LOG"
