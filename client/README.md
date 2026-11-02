# Клиент IdlePixelMMORPG (Defold)

Скелет создан от официального мобильного шаблона Defold (`defold/template-mobile`) и
адаптирован под динамическую ориентацию.

## Как открыть

1. Установить **Defold 1.14.x** (https://defold.com/download/).
2. `File → Open Project…` → выбрать `client/game.project`.
3. `Project → Build` (F8) — запуск в окне редактора (десктоп).
4. `Project → Build And Run` — выбор устройства/эмулятора Android.

Сборка APK на машине без Android SDK невозможна: она вынесена в GitHub Actions (см. `docs/PLAN.md §7`).

## Что внутри

| Файл | Назначение |
|---|---|
| `game.project` | 720×1280, `display.dynamic_orientation = 1`, Android-пакет `com.idlepixel.mmorpg` |
| `input/game.input_binding` | тап/клик → action `touch` (как в официальном шаблоне) |
| `main/main.collection` | входная коллекция, один game object |
| `main/main.go` | компоненты: `main.script` + `hud.gui` |
| `main/main.script` | лог жизненного цикла, приём ввода |
| `main/hud.gui` | заглушка HUD: панель, заголовок, подпись, строка состояния, подсказка |
| `main/hud.gui_script` | пересчёт раскладки по `window.get_size()`, `window.get_safe_area()`, `WINDOW_EVENT_RESIZED` |
| `main/fonts/*.font` | шрифт интерфейса, `all_chars = true` (нужна кириллица) |
| `assets/fonts/` | Source Sans Pro (SIL OFL 1.1), лицензия рядом |

## Как проверить динамическую ориентацию

Запустить на телефоне и повернуть его: строка состояния внизу показывает
`портрет/ландшафт · ширина×высота · safe x,y w×h`, а панель и подписи пересчитываются.
В лог пишется `[hud] portrait 720x1280 scale=… safe=…`.

В редакторе размер окна можно менять в `Project → Properties → display.width/height` —
но настоящая проверка только на устройстве, где есть вырез и системные панели.

## Дальше по плану

Экраны `camp`, `hero`, `battle`, `map`, `market`, `chat` и layout-библиотека (`ui/`) —
см. `docs/PLAN.md §4.2–4.4`. Этот HUD-скрипт — заготовка той самой библиотеки:
пересчёт по safe area и dp-единицам.
