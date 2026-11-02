#!/usr/bin/env bash
# Публикует лог упавшей сборки в репозиторий, чтобы его можно было прочитать
# без доступа к API логов GitHub Actions.
#
# Использование: publish-log.sh <android|web>
set -uo pipefail

JOB="${1:-build}"
LOG="/tmp/build-${JOB}.log"

mkdir -p ci-logs
{
  echo "# Лог сборки ${JOB}"
  echo
  echo "- ветка: ${GITHUB_REF_NAME:-local}"
  echo "- коммит: ${GITHUB_SHA:-local}"
  echo "- запуск: ${GITHUB_SERVER_URL:-}/${GITHUB_REPOSITORY:-}/actions/runs/${GITHUB_RUN_ID:-0}"
  echo
  echo '```'
  if [ -f "$LOG" ]; then
    tail -n 400 "$LOG"
  else
    echo "(лог пуст — шаг упал до записи)"
  fi
  echo '```'
} > "ci-logs/${JOB}.md"

git config user.name "github-actions[bot]"
git config user.email "41898282+github-actions[bot]@users.noreply.github.com"
git add "ci-logs/${JOB}.md"
git commit -m "ci: лог сборки ${JOB} [skip ci]" || exit 0

# оба джоба пишут в одну ветку — ретраим с ребейзом, иначе push отклоняется
for attempt in 1 2 3 4 5; do
  if git push origin "HEAD:${GITHUB_REF_NAME}"; then
    exit 0
  fi
  echo "push отклонён, попытка $attempt: ребейз"
  git pull --rebase --autostash origin "${GITHUB_REF_NAME}" || git rebase --abort || true
  sleep $((attempt * 3))
done
echo "не удалось запушить лог"
exit 0
