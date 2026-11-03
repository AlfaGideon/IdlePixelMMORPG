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

## GitHub Pages (внешние ссылки)

Сайт публикуется из корня ветки `arena/58423ecd-idlepixelmmorpg`
(`.nojekyll` отключает Jekyll, корневой `index.html` редиректит на прототип).
Любой пуш в эту ветку автоматически обновляет сайт.

- Сайт: <https://alfagideon.github.io/IdlePixelMMORPG/>
- Прототип напрямую: <https://alfagideon.github.io/IdlePixelMMORPG/prototype/index.html>
- Все 12 экранов на одном листе: <https://alfagideon.github.io/IdlePixelMMORPG/prototype/contact-sheet.png>
- Отдельный экран: `https://alfagideon.github.io/IdlePixelMMORPG/prototype/screens/{a|b}/{01-hub…06-shop}.png`
- Канон стиля: <https://github.com/AlfaGideon/IdlePixelMMORPG/blob/arena/58423ecd-idlepixelmmorpg/prototype/STYLE_CANON.md>
