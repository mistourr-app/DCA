# Defold 1.14.0: версия, настройки и изменения

## 1. Версия

- Целевая версия: **Defold 1.14.0**. Editor, Bob и SDK — одной версии; смешивать нельзя.
- Версия API и ссылки на manual фиксируются здесь: https://defold.com/manuals/.
- При обновлении движка правки ограничиваются `game.project`/Bob, если не затрагиваются учитываемые изменения (§2).

## 2. Что изменилось в 1.14.0 и как это учитывать

Оставлены только изменения, влияющие на код и сборку проекта.

| Изменение | Тип | Что делать в проекте |
|---|---|---|
| Общий Lua state всегда включён для `.script`, `.gui_script`, `.render_script` | Breaking | Не полагаться на изоляцию скриптов, не использовать глобалы. Модули `core/` подключать через `require` |
| Акселерометр выключен по умолчанию | Breaking | В проекте не используется. Оставить выключенным |
| Удалена поддержка win32 (32-бит) | Breaking | Build-скрипты используют только `x86_64-win32` |

Прочие breaking-изменения 1.14.0 (generational handles GO, рендер-таргеты, Metal, `.defignore` wildcards, safe-area, emoji) проект не затрагивают. Источник: https://forum.defold.com/t/defold-1-14-0-beta/83288

## 3. Настройки game.project для mobile-first

Файл `game.project` правится в редакторе. Значения ниже — рекомендуемые стартовые. Точные ключи проверять в manual «Project settings».

| Раздел | Ключ | Значение | Причина |
|---|---|---|---|
| project | title | `Dungeon Card Crawler` (рабочее, уточнить) | Название |
| display | width | `720` | Логическое разрешение (портрет) |
| display | height | `1560` | Логическое разрешение (портрет, 19.5:9) |
| display | high_dpi | `1` | Чёткая картинка на современных экранах |
| display | dynamic_orientation | `0` | Только портрет |
| display | update_frequency | `60` | Частота кадров |
| display | swap_interval | `1` | Vsync |
| input | use_accelerometer | `0` | Не используется (breaking 1.14.0) |
| input | repeat_delay / repeat_interval | по умолчанию | Не используется |
| engine | fixed_update_frequency | не менять (по умолчанию) | Логика ходов не в fixed_update |
| graphics | default_texture_min_filter | `nearest` | Пиксельные заглушки (клетки), без размытия |
| graphics | default_texture_mag_filter | `nearest` | Как min |

Точка входа описана в §3a. Физика: **не используется**. Physics-секция остаётся по умолчанию, но коллизионные объекты не создаются (`docs/ARCHITECTURE.md`).

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
- Шрифты прототипа: `assets/label.font` (значение на карте, vera_mo_bd.ttf, size 30) и `assets/label_name.font` (название, size 20). `/builtins/fonts/default.font` маленький: надписи в клетках становятся нечитаемыми. Размер текста «в покое» задаётся в `.font` (инспектор). Runtime-свойство label `scale` (число или vector3) работает: подписи масштабируются вместе с подложкой при подъёме карты (`anim.lift`), глифы растягиваются как картинка — на пике роста текст слегка размывается, это принятая плата за общий рост карты.
- Обводка спрайта: у sprite-компонента своей обводки нет (поля Outline в инспекторе не существует — только Image, Default Animation, Material, Blend Mode, Size Mode, Slice 9). Рамка карты сделана вторым спрайтом `border` того же изображения: он того же размера, что и карта, красится `tint` в цвет рамки и лежит на z ниже подложки, поэтому виден только полосой по краю. Подложка при этом ужимается на толщину рамки — рамка оказывается внутри габарита карты и не увеличивает её. Толщина — `card_border` в `geom_cfg` (её мир передаёт карте в `set` и ею же ужимает оверлей угрозы с z выше карты, иначе подсветка закрашивает рамку), цвет — роли палитры `border_step`/`border_jump` (рамка — индикация хода, не цвет карты).
- Обводка текста (букв) — отдельная возможность label: цвет `outline` (runtime `go.set("#label", "outline", vector4)`), толщина — `Outline Width` в `.font` (общая для шрифта). Сейчас не используется: обводка карты ≠ обводка букв.
- Alpha узла GUI: в `.gui` это **отдельное поле** `alpha:` (в инспекторе — Alpha), а не 4-й компонент `color`. `color { w }` движок при загрузке игнорирует: узел с `color.w = 0.5` и без `alpha` приходит в игру с alpha 1. `gui.get_color` возвращает RGB узла и alpha в `w`, `gui.get_alpha` — то же число. Поэтому прозрачность палитры задаётся полем Alpha (проверено: `alpha: 0.25` → `gui.get_color(...) = (r, g, b, 0.25)`).
- Устаревшее: label.set_text (предупреждение GAMESYS). Использовать go.set("#label", "text", value).
- Z-слои 2D: орфографическая content-проекция рендерит только z в диапазоне [-1..1]. Объект с z вне диапазона НЕ рисуется молча, без ошибок в логе (проверено: z=10..30 — объекты исчезли). Больше z = ближе к камере (рисуется позже); равный z = порядок не определён, возможны мигания. Итоговый z = z game object + z компонента + z родительских GO. Все z-константы — в `scripts/view/layers.lua` (единый источник), держим в (0..1); порядок снизу вверх: клетки < оверлей угрозы < «вас видят» < подписи клеток < карты акторов < пунктир < цифры. Порядок фиксирует `tests/view/layers_test.lua`. Надписи карт подняты на +0.2 компонентом в `card.go` (`layers.LABEL_OFFSET`), чтобы подсветки не перекрывали текст; рамка карты — на -0.01, под подложкой.
- Уже проверено в 1.14.0: у label нет полей text_leading, text_tracking, align, blend_mode; у gui нет значений ADJUST_FIT, ADJUST_STRETCH.
- Easing для go.animate: константы в пространстве go.EASING_* (go.EASING_INOUTQUAD, go.EASING_OUTBACK и т.п.). Имени vmath.EASE_* не существует; nil в аргументе easing даёт runtime error "easing must be either a easing constant or a vmath.vector" в момент вызова animate.
- Сигнатура go.animate: (url, property, playback, to, easing, duration, delay, complete_function) — complete_function передаётся только 8-м аргументом, 7-й это delay; вызов с колбэком на месте delay = "bad argument #7 (number expected, got function)".
- Сигнатура gui.animate ДРУГАЯ: (node, property, to, easing, duration, delay, complete_function, playback) — playback не на 3-м месте, отмена gui.cancel_animations(node, "color"), easing gui.EASING_*. Не путать с go.animate.
- Масштаб «подъёма» карты: анимировать надо scale компонентов (`#sprite`, `#border`, `#name`, `#value`), а не GO целиком — scale game object растягивает и текст, и рамку без возможности это отменить. `anim.lift` получает список частей с их «спокойным» масштабом.
- go.property: дефолт — только литерал (число, строка, hash, vmath-конструктор с литералами); арифметика вида `26/255` не проходит линтером редактора ("invalid numeric argument"), значения пересчитывать заранее. В gui_script go.property запрещён в принципе ("cannot be used in this file type") — параметры передавать сообщением из .script.
- Цвет как script property — только `vmath.vector4`: x = red, y = green, z = blue, w = alpha. Отдельного типа «color» нет, в инспекторе поля подписаны X/Y/Z/W, цветового пикера нет (в manual: «all color values are encoded in a vector4»). В `.go`/`.collection`: `value: "1.0, 0.122, 0.122, 1.0"`, `type: PROPERTY_TYPE_VECTOR4` (через запятую с пробелом). Пикер цвета есть только у GUI-нод (`gui/palette.gui`) — общая палитра игры живёт там, включая фон и текст каждой карты (`fill_`/`ink_<skin>`) и цвета рамок хода (`border_step`/`border_jump`).

## 4. Mobile-специфика

- Ориентация портрет: `dynamic_orientation = 0`. Лейаут строится по логическим координатам 720×1560.
- Вырез и системные панели: `render/game.render_script` вписывает контент в `window.get_safe_area()` с сохранением пропорций. На платформах без выреза inset-ы равны 0.
- Единая проекция: мир и GUI рендерятся одной content-проекцией. В `gui/hud.gui` `adjust_reference = ADJUST_REFERENCE_DISABLED`, поэтому узлы остаются в координатах 720×1560 и масштабируются вместе с полем.
- Адаптация под разные соотношения сторон: контент центрируется, по краям остаются поля. Поле 5 колонок и HUD всегда видны целиком.
- Ввод: тап через `action_id = hash("touch")`, `action.pressed`. Для content-fit использовать `action.screen_x`/`action.screen_y` (реальные пиксели окна) и `layout.screen_to_design` с тем же fit и safe area. `action.x`/`action.y` уже растянуты в виртуальные 720×1560 и для letterbox дают смещение.
- Производительность: цель 60 FPS на современных телефонах (2024+). Профилировать через `Profiling` manual на Android-устройстве.
- Батарея: при паузе приложения (`msg` `window_pause`/`lost_focus` через `on_message`) останавливать таймеры и анимации. Проверить актуальные имена сообщений системы в manual «Application lifecycle».
- Сохранение при уходе в фон: состояние мира на последней точке возврата (клетки её ряда) и золото (GDD §18).

## 5. Платформы сборки

- Первый приоритет: **Android** (APK/AAB) и **iOS** (нужен Mac для финальной сборки).
- Вторичный: HTML5 для быстрой проверки в браузере (необязательно для прототипа).
- Desktop (`Windows`, `macOS`, `Linux`) — для разработки и отладки в редакторе.
- Для Android: минимальный SDK и таргет — значения из актуальной документации Defold 1.14.0 (раздел «Android» manual). Не выдумывать версии, сверять с manual на момент сборки.
- Собранный проект можно запускать без редактора (`bob` + `dmengine`, порядок команд — `docs/TESTING.md` §8). Факт движка 1.14.0: `dmengine.exe --config=<путь>` не поддерживается (пишет `WARNING:DLIB: Invalid config option`), движок грузит данные из `build/default` относительно текущей рабочей папки.

## 6. Что не используем

- Физику (2D и 3D) и её компоненты.
- Нативные расширения (dmSDK, extender).
- Аккселерометр, гироскоп.
- Кастомные проходы рендера. Свой `render/game.render` нужен только для content-fit/safe-area и повторяет проходы `builtins/render/default.render`.
- Spine, Rive, Particle FX — только если понадобятся на этапе арта, и только после согласования.
- Live Update (не нужен на прототипе).
- Монетизацию и рекламу (не нужна на прототипе).

## 7. Что проверять при обновлении версии

1. Breaking changes релизных заметок.
2. Совместимость установленных расширений (если появятся).
3. Прогон `lua tests/run.lua` (логика не зависит от движка, должна пройти без изменений).
4. Сборка Android на тестовом устройстве.
5. Обновить таблицу в разделе 2 этого документа.
