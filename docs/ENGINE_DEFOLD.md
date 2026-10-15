# Defold 1.14.0: версия, настройки и изменения

## 1. Версия

- Целевая версия: **Defold 1.14.0**.
- Статус на дату документа (10.2026): 1.14.0 вышла в **beta** (форум, 30.09.2026). Stable на GitHub — 1.13.1. Стабильный 1.14.0 может выйти позже.
- Если 1.14.0 stable выйдет, обновлять версию в этом файле и в `game.project`/Bob без правок кода.
- Editor, Bob и SDK должны быть одной версии. Смешивать версии нельзя.
- Проверять ссылки на manual: https://defold.com/manuals/ (раздел Manuals). Дата и версия API фиксируются здесь.

## 2. Что изменилось в 1.14.0 и как это учитывать

| Изменение | Тип | Что делать в проекте |
|---|---|---|
| Общий Lua state всегда включён для `.script`, `.gui_script`, `.render_script` | Breaking | Не полагаться на изоляцию скриптов. Не использовать глобалы, даже если кажется, что они локальны. Модули `core/` подключать через `require` |
| Акселерометр выключен по умолчанию | Breaking | В проекте не используется. Оставить выключенным (`input.use_accelerometer = 0`) |
| Удалена поддержка win32 (32-бит) | Breaking | Build-скрипты используют только `x86_64-win32` |
| Generational handles game object и collection | Breaking (нативные расширения) | Не используем нативные расширения. Не зависит от Lua-кода |
| Изменения рендер-таргетов (cubemap) | Breaking (dmSDK) | Не используем. Не зависит от Lua-кода |
| Metal — бэкенд по умолчанию на macOS | Новое | Не влияет на мобильную сборку |
| Accelerometer, `b2d.get_gameobject_id()` | Новое | Физика не используется |
| `.defignore` и `.defunload` поддерживают wildcards | Новое | Можно использовать для исключения `tools/`, `docs/`, `tests/` из сборки |
| Lint Code on Build выключен по умолчанию | Изменение | Включить вручную в Preferences, если нужен lint |
| Bob выбирает build server по каналу релиза | Изменение | Для стабильной сборки использовать stable |
| GUI safe-area: корневые узлы учитывают safe-area | Исправление | Проверить вёрстку HUD на устройстве с вырезом |
| Поддержка текста со сложными скриптами и emoji | Исправление | Нужно для локализации |

Источник: https://forum.defold.com/t/defold-1-14-0-beta/83288

## 3. Настройки game.project для mobile-first

Файл `game.project` правится в редакторе. Значения ниже — рекомендуемые стартовые. Точные ключи проверять в manual «Project settings».

| Раздел | Ключ | Значение | Причина |
|---|---|---|---|
| project | title | `Dungeon Card Crawler` (рабочее, уточнить) | Название |
| display | width | `720` | Логическое разрешение (портрет) |
| display | height | `1280` | Логическое разрешение (портрет, 9:16) |
| display | high_dpi | `1` | Чёткая картинка на современных экранах |
| display | dynamic_orientation | `0` | Только портрет |
| display | update_frequency | `60` | Частота кадров |
| display | swap_interval | `1` | Vsync |
| input | use_accelerometer | `0` | Не используется (breaking 1.14.0) |
| input | repeat_delay / repeat_interval | по умолчанию | Не используется |
| engine | fixed_update_frequency | не менять (по умолчанию) | Логика ходов не в fixed_update |
| graphics | default_texture_min_filter | `linear` (для UI-арта), `nearest` (для пиксельного) | Выбрать на этапе арта, сейчас заглушки |
| graphics | default_texture_mag_filter | как min | — |
| project | write_log_file | `Debug` | Логи только в отладке |
| bootstrap | main_collection | `/main/main.collectionc` | Точка входа |

Физика: **не используется**. Physics-секция остаётся по умолчанию, но коллизионные объекты не создаются. Решение зафиксировано в `docs/ARCHITECTURE.md`.

Заглушки на этапе прототипа: все клетки и персонажи — цветные прямоугольники и `label`-текст. Атласы и тайлсорсы не создаются до этапа арта.

## 3a. Точка входа и загрузка мира

- `bootstrap.main_collection` в `game.project` указывает на стартовую коллекцию. Сейчас это `/collections/world.collectionc`: мир загружается сразу, без промежуточной коллекции.
- Компоненты `collectionproxy` в game object-ах для стартовой загрузки не используются: при сборке это дало ошибку `Assert failed: (map? game-object-build-target)`. Вернуться к промежуточной коллекции — только если появится реальная необходимость (например, экран загрузки).
- Текстовые файлы Defold без BOM (см. `AI_CODING_RULES.md`, раздел 13a).

## 3b. Поля и enum в файлах Defold

- Имена полей и значений enum из памяти не использовать. Перед записью сверять с манулом 1.14.0 или со схемой .proto (поля LabelDesc, NodeDesc и т.д.).
- Неизвестное поле или значение enum делает файл нечитаемым, и редактор падает при загрузке проекта. Ошибки смотреть в логе редактора: C:\Users\<user>\AppData\Local\Defold\editor2.<дата>.log (поиск: WARN Unable to read resource, ERROR).
- Встроенные ресурсы: builtins — это builtins.zip внутри установки Defold (C:\Users\<user>\AppData\Local\Defold\unpack\<версия>\builtins\builtins.zip). Пути проверять по нему. Шрифт по умолчанию: /builtins/fonts/default.font (system_font.font в 1.14 не существует).
- require: Defold ищет только a/b.lua для require("a.b"). Файл a/b/init.lua НЕ подхватывается (ошибка "/core/registry.lua could not be found"). Модуль-папку подключать явно: require("core.registry.init"). Проверка: python tools/check_requires.py.
- Лимит меток: каждый label-компонент занимает слот. По умолчанию [label] max_count = 64, и экран мира (≈66 клеток) его превышает. Значение задано в game.project: [label] max_count = 512. Удаление через go.delete отложенное, поэтому буфер нужен с запасом.
- Лимит спрайтов: [sprite] max_count по умолчанию 128. Экран мира создаёт ≈66 клеток с подложкой, поэтому задано 512. Ошибка в консоли: "Sprite could not be created since the buffer is full".
- Графика прототипа: клетки — белый квадрат assets/cell.png (32×32) с nearest-фильтром ([graphics] default_texture_*_filter = nearest), окрашивается через tint. Встроенный particle_blob не использовать для клеток: он размытый.
- Шрифт прототипа: assets/label.font (встроенный vera_mo_bd.ttf, size 30). /builtins/fonts/default.font маленький: надписи в клетках становятся нечитаемыми. Масштабировать объект с label нельзя: растянется текст. Размер текста задаётся только в .font.
- Устаревшее: label.set_text (предупреждение GAMESYS). Использовать go.set("#label", "text", value).
- Z-слои 2D: default-камера (stretch projection) рендерит только z в диапазоне [-1..1]. Объект с z вне диапазона НЕ рисуется молча, без ошибок в логе (проверено: z=10..30 — объекты исчезли). Больше z = ближе к камере (рисуется позже); равный z = порядок не определён, возможны мигания. Итоговый z = z game object + z компонента + z родительских GO. Все z-константы — в collections/world.script, держим в (0..1); надписи клеток подняты на +0.2 компонентом в cell.go, чтобы слой угроз (0.1) не перекрывал текст.
- Уже проверено в 1.14.0: у label нет полей text_leading, text_tracking, align, blend_mode; у gui нет значений ADJUST_FIT, ADJUST_STRETCH.
- Easing для go.animate: константы в пространстве go.EASING_* (go.EASING_INOUTQUAD, go.EASING_OUTBACK и т.п.). Имени vmath.EASE_* не существует; nil в аргументе easing даёт runtime error "easing must be either a easing constant or a vmath.vector" в момент вызова animate.
- Сигнатура go.animate: (url, property, playback, to, easing, duration, delay, complete_function) — complete_function передаётся только 8-м аргументом, 7-й это delay; вызов с колбэком на месте delay = "bad argument #7 (number expected, got function)".
- Сигнатура gui.animate ДРУГАЯ: (node, property, to, easing, duration, delay, complete_function, playback) — playback не на 3-м месте, отмена gui.cancel_animations(node, "color"), easing gui.EASING_*. Не путать с go.animate.
- Масштаб «подъёма» карты: анимировать надо scale компонента "#sprite", а не GO целиком — scale game object с label растягивает текст (см. выше).

## 4. Mobile-специфика

- Ориентация портрет: `dynamic_orientation = 0`. Лейаут строится по логическим координатам 720×1280.
- Вырез и системные панели: корневые GUI-узлы учитывают safe-area (1.14.0). Нижний HUD и верхняя панель привязывать к краям через anchor, а не к абсолютным координатам.
- Адаптация под разные соотношения сторон: поле 5 колонок центрируется по ширине, высота поля скроллится (см. GDD §5.2 и `docs/ARCHITECTURE.md`).
- Ввод: тап через `action_id = hash("touch")`, `action.pressed`. Мультитач не нужен.
- Производительность: цель 60 FPS на современных телефонах (2024+). Профилировать через `Profiling` manual на Android-устройстве.
- Батарея: при паузе приложения (`msg` `window_pause`/`lost_focus` через `on_message`) останавливать таймеры и анимации. Проверить актуальные имена сообщений системы в manual «Application lifecycle».
- Сохранение при уходе в фон: состояние мира на последней точке возврата (seed, respawn_count, клетки ряда точки возврата) и золото (GDD 18).

## 5. Платформы сборки

- Первый приоритет: **Android** (APK/AAB) и **iOS** (нужен Mac для финальной сборки).
- Вторичный: HTML5 для быстрой проверки в браузере (необязательно для прототипа).
- Desktop (`Windows`, `macOS`, `Linux`) — для разработки и отладки в редакторе.
- Для Android: минимальный SDK и таргет — значения из актуальной документации Defold 1.14.0 (раздел «Android» manual). Не выдумывать версии, сверять с manual на момент сборки.

## 6. Что не используем

- Физику (2D и 3D) и её компоненты.
- Нативные расширения (dmSDK, extender).
- Аккселерометр, гироскоп.
- Рендер-скрипты с кастомными проходами. Используется `builtins/render/default.render`.
- Spine, Rive, Particle FX — только если понадобятся на этапе арта, и только после согласования.
- Live Update (не нужен на прототипе).
- Монетизацию и рекламу (не нужна на прототипе).

## 7. Что проверять при обновлении версии

1. Breaking changes релизных заметок.
2. Совместимость установленных расширений (если появятся).
3. Прогон `lua tests/run.lua` (логика не зависит от движка, должна пройти без изменений).
4. Сборка Android на тестовом устройстве.
5. Обновить таблицу в разделе 2 этого документа.
