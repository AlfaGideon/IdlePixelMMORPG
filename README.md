# IdlePixelMMORPG

Idle-**RPG** на **Godot 4**: боевые классы, монстры и уровни, общий мир, аукцион и мировые события.
Платформы: Android (APK) и Web. Монетизация — внешняя, через веб-магазин и промокоды.

📄 **[План разработки](docs/PLAN.md)** — концепт, боевая система, архитектура, адаптивный UI, дорожная карта.
🎮 **[Клиент](client/README.md)** — проект Godot 4 (портрет/ландшафт, safe area, пиксель-арт).

## Состояние

| Часть | Статус |
|---|---|
| Концепт и план | v0.3, обсуждается |
| Клиент `client/` | скелет: HUD из контейнеров, переключение портрет ⇄ ландшафт |
| Сервер `server/` | ещё нет |
| Конфиги `shared/` | ещё нет |
| `legacy/defold-client/` | замороженный первый вариант на Defold (референс) |

## Структура

```
client/   -- Godot 4 (открывать client/project.godot)
docs/     -- план и спеки
tools/    -- проверки проекта и вспомогательные скрипты
server/   -- Node.js + TypeScript (появится на итерации 0)
shared/   -- протокол и игровые конфиги (появится на итерации 0)
legacy/   -- замороженный Defold-скелет
```

## Проверка без движка

```bash
python3 tools/check_godot_project.py client      # ссылки res://, узлы сцен, ресурсы
gdlint client/scripts client/ui                  # линт GDScript (pip install gdtoolkit)
python3 tools/check_defold_refs.py               # проверка legacy-проекта
```

Сборка APK/Web — в GitHub Actions: локально нужны экспорт-шаблоны Godot и Android SDK/NDK.
