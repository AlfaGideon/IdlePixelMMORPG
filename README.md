# IdlePixelMMORPG

Пиксель-арт MMORPG с idle-механикой.

## Интерактивный прототип

**`index.html` в корне репозитория** — это кликабельный прототип, а не подборка
скриншотов: живой DOM, единое состояние игры, idle-цикл раз в секунду и сохранение
прогресса в `localStorage`. Сгенерированные кадры используются только как фон сцен,
поверх них работает настоящий интерфейс в том же каноне современного HD-пикселя.

### Что реально кликается

| Экран | Действия |
|-------|----------|
| **Лагерь** | клик по голему = удар, переключатель авто-атаки, вызов босса, забор оффлайн-лута, симуляция «+12ч» |
| **Бой** | 3 способности с расходом энергии и burst-уроном, живой лог боя, HP босса/игрока, авто-бой, лут после победы |
| **Герой** | 8 слотов экипировки → список совместимых предметов → надеть / снять; статы и мощь пересчитываются; 6 узлов навыков за очки |
| **Инвентарь** | 30 слотов, выбор предмета, фильтры (всё/оружие/броня/ресурсы), сортировка, надеть / продать / распылить / распылить обычное |
| **Карта** | 6 нод, выбор зоны, открытие за золото с проверкой уровня, вход в зону меняет босса |
| **Магазин** | вкладки ежедневное/еженедельное, 6 предложений с реальным списанием валюты и добавлением предмета в инвентарь, вклад в гильдию |

Ресурсы (золото, кристаллы, энергия), уровень, EXP, DPS, мощь, экипировка,
навыки, зоны и инвентарь — одно общее состояние: покупка в магазине видна в
инвентаре, надетый предмет меняет мощь и DPS, а DPS ускоряет бой и добычу.
Переключатель **A / B** меняет только палитру и набор фоновых кадров.

Клавиши: `1`…`6` — экраны, `Space` — удар, `A`/`B` — цветокор.

### Запуск локально

```bash
bash prototype/serve.sh            # порт 8000, bind 0.0.0.0
PORT=8080 bash prototype/serve.sh  # другой порт
```

Сервер статический, без зависимостей; раздаётся корень репозитория.

### Файлы

- `index.html` — интерактивный прототип (самодостаточный: CSS и JS встроены).
- `prototype/standalone.html` — та же игра с абсолютными URL картинок для внешней ссылки; собирается `prototype/build-standalone.py`.
- `prototype/index.html` — **галерея исходных скриншотов** (сравнение A/B), не прототип.
- `prototype/screens/a|b/` — 12 фоновых кадров (6 страниц × 2 цветокора).
- `prototype/contact-sheet.png` — все 12 кадров на одном листе.
- `prototype/STYLE_CANON.md` — канон стиля, анти-канон, палитры и промпты.

## Внешние ссылки (работают сейчас)

- Репозиторий/ветка: <https://github.com/AlfaGideon/IdlePixelMMORPG/tree/arena/58423ecd-idlepixelmmorpg>
- **Открыть прототип по внешней ссылке:** <https://htmlpreview.github.io/?https://raw.githubusercontent.com/AlfaGideon/IdlePixelMMORPG/arena/58423ecd-idlepixelmmorpg/prototype/standalone.html>
- Все 12 кадров одним листом: <https://raw.githubusercontent.com/AlfaGideon/IdlePixelMMORPG/arena/58423ecd-idlepixelmmorpg/prototype/contact-sheet.png>
- Отдельный кадр: `https://raw.githubusercontent.com/AlfaGideon/IdlePixelMMORPG/arena/58423ecd-idlepixelmmorpg/prototype/screens/{a|b}/{01-hub…06-shop}.png`

## GitHub Pages — один ручной шаг

Воркфлоу `.github/workflows/deploy-pages.yml` готов: он собирает `_site` и деплоит
через `actions/deploy-pages`. Но GitHub запрещает integration-токену и `GITHUB_TOKEN`
**впервые создать** Pages-сайт (`POST /repos/.../pages` → `Resource not accessible by
integration`), даже с `permissions: write-all`. Первое включение — одноразовое
действие владельца:

1. <https://github.com/AlfaGideon/IdlePixelMMORPG/settings/pages> → **Source: GitHub Actions**
2. Run workflow в <https://github.com/AlfaGideon/IdlePixelMMORPG/actions/workflows/deploy-pages.yml> (или любой пуш в ветку)

После этого: <https://alfagideon.github.io/IdlePixelMMORPG/>, автообновление при
каждом пуше. Пока Pages выключен, воркфлоу завершается успешно с понятным
уведомлением, а не падает.
