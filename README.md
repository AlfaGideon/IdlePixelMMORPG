# IdlePixelMMORPG

Пиксель-арт MMORPG с idle-механикой.

## Прототип интерфейса

`prototype/` — визуальный прототип будущего приложения: **2 варианта × 6 страниц**
в одном каноне современного HD-пикселя (не 8-бит, не чиби).

- `prototype/index.html` — кликабельный многостраничный прототип: переключатель
  вариантов A/B, режим сравнения, все страницы сразу, стрелки клавиатуры.
- `prototype/contact-sheet.png` — все 12 экранов на одном листе для быстрого выбора.
- `prototype/screens/a/` — вариант A «Янтарь / индиго».
- `prototype/screens/b/` — вариант B «Аркан-неон».
- `prototype/standalone.html` — та же галерея, но с абсолютными ссылками на
  `raw.githubusercontent.com` (собирается `prototype/build-standalone.py`): нужна,
  чтобы открыть прототип по внешней ссылке до включения GitHub Pages.
- `prototype/STYLE_CANON.md` — зафиксированный канон стиля, анти-канон, палитры,
  постоянный HUD и переиспользуемый префикс промпта для достроек.

Страницы: Лагерь → Подземелье/Автобой → Герой → Инвентарь → Карта мира → Магазин.

### Запуск превью

```bash
bash prototype/serve.sh          # порт 8000, bind 0.0.0.0
PORT=8080 bash prototype/serve.sh  # при необходимости другой порт
```

Сервер статический, без зависимостей; `index.html` использует только относительные
пути к картинкам, поэтому работает и через прокси Arena live preview.

## Внешние ссылки (уже работают)

Всё запушено в ветку `arena/58423ecd-idlepixelmmorpg` публичного репозитория
<https://github.com/AlfaGideon/IdlePixelMMORPG> — файлы доступны извне сразу:

- Ветка целиком: <https://github.com/AlfaGideon/IdlePixelMMORPG/tree/arena/58423ecd-idlepixelmmorpg>
- Все 12 экранов одним листом: <https://raw.githubusercontent.com/AlfaGideon/IdlePixelMMORPG/arena/58423ecd-idlepixelmmorpg/prototype/contact-sheet.png>
- Отдельный экран: `https://raw.githubusercontent.com/AlfaGideon/IdlePixelMMORPG/arena/58423ecd-idlepixelmmorpg/prototype/screens/{a|b}/{01-hub…06-shop}.png`
- Канон стиля: <https://github.com/AlfaGideon/IdlePixelMMORPG/blob/arena/58423ecd-idlepixelmmorpg/prototype/STYLE_CANON.md>
- Интерактивный прототип без Pages (сторонний рендерер htmlpreview,
  тянет картинки с raw.githubusercontent.com):
  <https://htmlpreview.github.io/?https://raw.githubusercontent.com/AlfaGideon/IdlePixelMMORPG/arena/58423ecd-idlepixelmmorpg/prototype/standalone.html>

## GitHub Pages — один ручной шаг

GitHub **не разрешает** integration-токену и `GITHUB_TOKEN` впервые создать
Pages-сайт (`POST /repos/.../pages` → `Resource not accessible by integration`),
даже с `permissions: write-all`. Первое включение Pages — одноразовое действие
владельца репозитория; автоматизировать его изнутри репозитория нельзя.

1. Открыть <https://github.com/AlfaGideon/IdlePixelMMORPG/settings/pages>
2. **Build and deployment → Source: GitHub Actions**
3. Перезапустить воркфлоу
   <https://github.com/AlfaGideon/IdlePixelMMORPG/actions/workflows/deploy-pages.yml>
   (кнопка Run workflow) или сделать любой пуш в ветку.

Готово: сайт на <https://alfagideon.github.io/IdlePixelMMORPG/>, прототип напрямую
на <https://alfagideon.github.io/IdlePixelMMORPG/prototype/index.html>, и каждый
пуш в ветку обновляет его автоматически.

Воркфлоу устроен безопасно: пока Pages не включён, он проверяет
`GET /pages`, пишет понятное сообщение и завершается успешно (без красных
крестов), а после включения сам собирает `_site` (корневой `index.html`
редиректит на прототип, `.nojekyll` отключает Jekyll) и деплоит через
`actions/deploy-pages`.
