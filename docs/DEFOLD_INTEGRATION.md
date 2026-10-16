# Интеграция в Defold: структура и границы

> Документ фиксирует, как устроен Defold-слой проекта (связка `core/` с экраном), где живут какие числа, какие есть проблемы и как их решать при росте: новые типы врагов, боссов и объектов поля.
> Правила игры и числа не описывает: механику — `GDD.md`, баланс — `balance/balance.csv`, дизайн-числа — `design/design.csv`.
> Основано на фактическом состоянии репозитория; карта файлов — `docs/ARCHITECTURE.md` §2.

---

## 1. Границы: где что редактируется

В Defold есть три места правки параметров. Их важно не путать.

| Место | Что там лежит | Что редактируется | Видно в Outliner коллекции |
|---|---|---|---|
| Outliner коллекции (`.collection`) | статические инстансы (`world`, `rows`, будущий `config`) | `go.property` компонентов-скриптов этих инстансов | да |
| Assets → прототип `.go` | то, что создаётся фабрикой в рантайме (клетки, враги, попапы) | `go.property` скриптов прототипа | нет, появляется только в рантайме |
| `.gui` | GUI-узлы HUD | свойства узлов; **`go.property` в `gui_script` невозможен** | нет, правится в файле `.gui`/редакторе GUI |

Отсюда правило: **в Outliner выносится только презентация.** Игровые числа остаются в CSV (там источник истины и на них завязаны тесты). Символы типов и привязка «тип → вид» — данные Defold-слоя, не `go.property` на каждый тип.

---

## 2. Источники чисел

| Число | Источник | В Outliner? | Причина |
|---|---|---|---|
| Правила игры: HP, урон, шансы, цены, кривые, K, N | `balance/balance.csv` → `core/data/balance.lua` | нет | единственный источник истины, проверяется инвариантами и тестами |
| Числа, которые читает `core/` (геометрия `screen.*`, `screen.threatAlpha`) | `design/design.csv` → `core/data/design.lua` | нет | `core/` не видит Defold и `go.property` |
| Презентация: палитра, длительности анимаций, зазоры, обводки, пунктир | `go.property` скриптов экрана | да | правится в редакторе без правки кода |
| Символы типов и привязка «тип → цвет/роль» | таблица в Lua Defold-слоя (view-registry) | нет | текст и данные; `go.property` на каждый тип разрастается линейно |
| Порядок отрисовки (z) | константы кода `world.script` | нет | это структурная константа, не настраиваемая |

Ссылки: `docs/AI_CODING_RULES.md` §12, `docs/BALANCE.md` §1.

---

## 3. Текущее состояние

### 3.1 Дерево

```
collections/world.collection
├── world  (game_objects/world.go)
│     ├── world          → collections/world.script    (1 go.property: debug_seed)
│     ├── geom_cfg        → game_objects/geom_cfg.script
│     ├── anim_cfg        → game_objects/anim_cfg.script
│     ├── flash_cfg       → game_objects/flash_cfg.script
│     ├── palette_cfg     → game_objects/palette_cfg.script  (16 ролевых цветов)
│     ├── card_factory    → game_objects/card.go        (5 go.property в card.script)
│     ├── bar_factory     → game_objects/bar.go
│     ├── popup_factory   → game_objects/popup.go        (5 go.property в popup.script)
│     └── hud             → gui/hud.gui                  (go.property нет)
└── rows   (game_objects/rows.go)
      └── script          → game_objects/rows.script     (пустой контейнер)
```

- Игрок и босс рисуются **тем же прототипом** `card.go` (создаются фабрикой `card_factory`). Отдельных `player.go`, `enemy.go`, `boss.go` нет.
- `rows.go` — контейнер, родитель всех карт, обводок и цифр; позицию задаёт `world.script` (прокрутка).
- Лагерь и смерть — не отдельные коллекции/GUI, а экранные состояния внутри `world.script` + `hud.gui` (оверлей).

### 3.2 Где какие `go.property`

| Скрипт | Свойств | Что содержит |
|---|---:|---|
| `collections/world.script` | 1 | `debug_seed` (параметр мира: 0 — новый мир, иначе фиксированный seed) |
| `game_objects/geom_cfg.script` | 4 | `cell_gap`, `border_width`, `dash_step`, `dash_size` |
| `game_objects/anim_cfg.script` | 4 | `move_ms`, `fall_drop`, `popup_spread`, `popup_y_factor` |
| `game_objects/flash_cfg.script` | 3 | `color_flash`, `flash_alpha`, `flash_ms` |
| `game_objects/palette_cfg.script` | 16 | роль-палитра: `fill_neutral`/`fill_wall`/`fill_good`/`fill_gold`/`fill_danger`/`fill_attack`/`fill_camp`/`fill_player`, `ink_dark`/`ink_light`, `outline_step`/`outline_jump`/`outline_attack`, `dot`/`vision`/`spotted` |
| `game_objects/card.script` | 5 | `lift_scale`, `lunge_ms`, `fall_ms`, `flash_ms`, `flash_color` |
| `game_objects/popup.script` | 5 | `float_ms`, `float_rise`, `color_damage`, `color_heal`, `color_gold` |
| `gui/hud.gui_script` | 0 | невозможно; параметры вспышки приходят сообщением `flash` |

`world.script` читает конфиги через `go.get("#geom_cfg", ...)` и держит значения в `self` (`read_config`), проверяя при старте полноту палитры (`check_palette`).

### 3.3 Метрики

- `collections/world.script` — 813 строк: ввод, маршрутизация режимов, вызовы `core/`, делегирование view-модулям, лагерь, смерть, сохранения.
- Презентация вынесена в `scripts/view/`: `style.lua` (тип → символ + роли палитры), `fx.lua` (обводки, пунктир, угрозы, цифры), `timeline.lua` (раннер анимаций и `anim_done`), `anim.lua` (примитивы lift/lunge/fall/flash), `board.lua` (ряды, diff-синхронизация карт, карты акторов), `hud.lua` (строки HUD). `world.script` — тонкий координатор.
- Движковые проверки автотестами не покрыты (`docs/TESTING.md` §1): изменения скриптов проверяются сборкой и ручным запуском.

---

## 4. Проблемы и ограничения

### 4.1 Проблемы

Снято этапами из §7:

- _(этап 1)_ Плоский список 34 свойств на компоненте `world` → свойства разнесены по `geom_cfg`/`anim_cfg`/`flash_cfg`/`palette_cfg` (§3.2).
- _(этап 2)_ Палитра «на каждый тип» (16 цветов fill/ink) → роль-палитра из 8 фонов + 2 чернил (§5.4); «тип → вид» вынесен в `scripts/view/style.lua`.

Осталось:

1. **Монолит `world.script`.** Логика координатора, отрисовки и данных в одном файле. При росте типов сущностей и механик файл превратится в спагетти.
2. **Привязки типов зашиты в мировой скрипт.** Новый тип клетки/врага/объекта требует правки `world.script` — нарушает принцип реестра (`docs/ENTITY_REGISTRY.md` §1.3): новая сущность не должна трогать ядро или игровой цикл.

Потенциальные (при росте):

3. **Дублирование анимаций.** Если появятся сущности с иной формой (босс-мультиклетка, ловушка, сундук), логика lift/lunge/fall/flash может размножиться по скриптам.
4. **Doc drift.** Дисциплина: при изменении структуры сначала правки в `docs/ARCHITECTURE.md` §2, затем код. Ранее документация описывала `main/`, `camp.collection`, `player/enemy/boss.go` — карта приведена к факту (фаза 1, §8).

### 4.2 Ограничения движка (данность, не проблемы)

Это не ошибки структуры, а рамки, в которых она обязана работать. Их не «исправляют», а учитывают.

- **`go.property` в `gui_script` запрещён.** Поэтому параметры вспышки HUD могут жить только в `.script` и прилетать в HUD сообщением. Вынос их в `flash_cfg` на `world.go` — косметика группировки Outliner, а не исправление ошибки: другого места у них нет.
- **Чтение script property из другого компонента.** Поддерживается: `go.get("#id", "prop")` читает значение свойства. Значения `go.property` — константы этапа сборки, они не зависят от того, отработал ли `init` владельца (manual «Script properties» показывает чтение свойства соседнего объекта прямо в `init()`). Неопределённость порядка инициализации касается рантайм-состояния, а не значений свойств, поэтому конфиги читаются обычным `go.get` (§5.2), ленивое чтение не требуется.
- **Значения script property и спавн.** Значения живут в прототипе `.go` (переопределяются у инстанса в редакторе — синим в Properties). При спавне их можно задать сразу: `factory.create("#fac", position, rotation, props)`, где `props = { lift_scale = 1.2 }`, — это перекрывает прототип и дефолты скрипта. В рантайме свойство меняется через `go.set(url, "prop", v)`; числовые и векторные — ещё и через `go.animate`. Отдельный прототип с собственными дефолтами — валидный путь, если типу нужны иные значения.
- **Лимиты `[label]`/`[sprite]`** (буфер, `game.project`), **z только в `[-1..1]`** (вне диапазона объект молча не рисуется), **дефолты `go.property` — только литералы**. Подробности — `docs/ENGINE_DEFOLD.md` §3b.

---

## 5. Предлагаемая архитектура

### 5.1 Слои

```
core/                      правила, реестр, balance/design            (не меняется)
   ▲
scripts/view/              общие модули отрисовки (Defold-facing; url/фабрики — параметры)
   ├── board.lua           раскладка, видимые ряды, diff-синхронизация карт
   ├── timeline.lua        раннер анимаций (сейчас inline в world.script)
   ├── fx.lua              bars: обводки, пунктир, слой угроз, всплывающие цифры
   ├── anim.lua            примитивы анимации ГО (lift/lunge/fall/flash) — «анимация один раз»
   ├── style.lua           view-registry: ключ типа → { symbol, fill_role, ink_role }
   └── hud.lua             сборка строк HUD и сообщений в hud.gui
   ▲
collections/world.script   тонкий координатор: ввод, режимы, вызовы core, таймлайн, делегирование
   ▲
game_objects/              прототипы и скрипты
   ├── card.go/.script     ЕДИНЫЙ примитив карты (спрайт+label+анимации), переиспользуется всеми сущностями
   ├── bar.go/.script
   └── popup.go/.script
```

### 5.2 Группировка `go.property` (sibling-компоненты на `world.go`)

Свойства мирового скрипта разносятся в короткие config-скрипты, прикреплённые к тому же `world.go`. В Outliner объект `world` раскрывается в компоненты — каждый со своим списком:

| Компонент | Свойства |
|---|---|
| `geom_cfg` | `cell_gap`, `border_width`, `dash_step`, `dash_size` |
| `anim_cfg` | `move_ms`, `fall_drop`, `popup_spread`, `popup_y_factor` |
| `flash_cfg` | `color_flash`, `flash_alpha`, `flash_ms` |
| `palette_cfg` | роль-палитра: `fill_neutral`, `fill_wall`, `fill_good`, `fill_gold`, `fill_danger`, `fill_attack`, `fill_camp`, `fill_player`, `ink_dark`, `ink_light`, цвета обводок/пунктира/угроз |

Имена в `palette_cfg` — роли (§5.4): на этапе 1 свойства переносились под временными именами `color_*`, на этапе 2 заменены ролями, а связь «тип → роли» вынесена в `scripts/view/style.lua`. `debug_seed` остаётся единственным `go.property` на самом `world.script` — это параметр мира, а не конфиг анимации или отрисовки.

`world.script` читает конфиги обычным `go.get("#geom_cfg", "cell_gap")`: значения `go.property` — константы сборки и от `init` владельца не зависят (§4.2), поэтому ленивое чтение не требуется. Схема с sibling-компонентами выбрана по локальности и числу сущностей; отдельный объект `config` в коллекции отклонён — меньше локальности.

**Приёмочный критерий этапа 1:** значения конфигов совпадают с заданными в Outliner; проверка ролей (§5.6) проходит.

### 5.3 Единый примитив карты + view-registry

Все сущности поля (клетки, враги, игрок, босс, будущие объекты) рисуются одним `card.go`. Различия — только данные в `scripts/view/style.lua`:

```lua
-- scripts/view/style.lua (фрагмент)
M.EMPTY       = { symbol = "",  fill = "fill_neutral", ink = "ink_dark" }
M.WALL        = { symbol = "#", fill = "fill_wall",    ink = "ink_light" }
M.HEAL        = { symbol = "+", fill = "fill_good",    ink = "ink_dark" }
M.GOLD        = { symbol = "$", fill = "fill_gold",    ink = "ink_dark" }
M.ENEMY       = { symbol = "E", fill = "fill_danger",  ink = "ink_light" }
M.ATTACK_CELL = { symbol = "A", fill = "fill_attack",  ink = "ink_light" }
M.CAMP        = { symbol = "C", fill = "fill_camp",    ink = "ink_dark" }
M.PLAYER      = { symbol = "@", fill = "fill_player",  ink = "ink_dark" }
M.BOSS        = { symbol = "B", fill = "fill_danger",  ink = "ink_light" }
```

Буква врага конкретного типа (`A`/`S`/`W`) и его HP берутся из записи `core/registry/enemies`. `world.script` и `card.script` при этом **не меняются**.

### 5.4 Роль-палитра

Вместо палитры «на каждый тип» — фиксированный набор ролей и два уровня чернил. Сейчас все враги уже одного цвета, поэтому визуально ничего не теряется. Новый цвет добавляется только если действительно нужен новый смысл.

### 5.5 «Анимация один раз»

Примитивы lift/lunge/fall/flash выносятся в `scripts/view/anim.lua`. `card.script` их вызывает. Будущая сущность с иной формой (босс-мультиклетка, ловушка) тоже `require`-ит `anim.lua` — код не дублируется. Сейчас переиспользование достигается за счёт общего прототипа; модуль добавит переиспользование на уровне кода.

### 5.6 Проверка связей style → palette

Роль в `style.lua`, которой нет в `palette_cfg`, даёт молчаливый `nil` и падение в бою. Защита — две независимые проверки, закрывающие разные ошибки:

- **Обязательно — проверка при старте.** Игра проходит по всем записям `style.lua` и убеждается, что каждая роль есть в `palette_cfg`. Ненайденная роль — остановка с понятным сообщением разработчика. Ловит «роль есть в таблице, но забыта в редакторе»; работает только при запуске игры.
- **По желанию — быстрый тест без движка.** Отдельный тест (`luajit tests/run.lua`) сверяет, что таблица типов ссылается только на допустимые имена ролей. Ловит опечатку в имени роли и работает до запуска игры, но требует держать список допустимых имён отдельным чистым модулем и поддерживать его в согласии с `palette_cfg`.

Первая проверка обязательна, вторая — опциональна.

### 5.7 Интерфейсы модулей (этап 3.0)

Все view-модули — **чистые функции без собственного состояния**: первый аргумент — контекст-скрипт `self` (паттерн, уже принятый в `world.script`). Состояние живёт в `self`; таблица фиксирует, кто им владеет.

| Поле в `self` | Владелец | Назначение |
|---|---|---|
| `rows` (y → cells) | board | окно сгенерированных рядов (кэш по seed) |
| `cards` (y → { x → id }) | board | живые ГО-карты поля по координатам |
| `rows_id` | board | id контейнера `rows`, к которому крепятся карты и fx |
| `player_go`, `boss_go` | board | карты акторов |
| `fx` (список id) | fx | временные ГО (bar/popup); очищаются при `refresh` |
| `anim_steps`, `anim_done` | timeline | очередь шагов и колбэк завершения |
| `anim_waiters`, `anim_token` | timeline | ожидание ответов `anim_done` от карт |

Модули и сигнатуры (передаётся `self`; префикс — имя модуля):

**`scripts/view/board.lua`** — раскладка, окно рядов, diff-синхронизация карт:

- `board.get_row(self, y) -> cells | nil`
- `board.content_row(self, y) -> cells` (в бою ряды берутся из арены)
- `board.cell_sig(cell) -> string`
- `board.cell_view(self, cell) -> text, fill, ink` (символ/роли через `style`, буква врага — из реестра)
- `board.card_msg(self, x, y, text, fill, ink) -> table`
- `board.create(self, x, y, z) -> id | nil`
- `board.update(self, id, x, y, z, text, fill, ink)`
- `board.card_id_at(self, x, y) -> id | nil`
- `board.sync_cells(self, pr)` (пересылает `set` только при смене подписи)
- `board.sync_player(self, pr)`, `board.sync_boss(self, pr)`
- `board.lunge_offset(x0, y0, x1, y1, fraction) -> vector3` (чистая)
- `board.refresh(self)` (позиция контейнера, diff клеток, карты акторов, `fx.clear`)

Слои карт `board.Z_CELL` (0) и `board.Z_ACTOR` (0.3) экспортируются: их использует координатор при анимации хода игрока.

**`scripts/view/fx.lua`** — одноразовые ГО (обводки, пунктир, угрозы, цифры):

- `fx.bar(self, cx, cy, w, h, color, z) -> id`
- `fx.outline(self, cx, cy, w, h, color)`
- `fx.dashed(self, ax, ay, bx, by)`
- `fx.threat(self, cx, cy, h, color, alpha, z)`
- `fx.popup(self, x, y, text, kind, dx)`
- `fx.clear(self)` (удаляет все id из `self.fx` и обнуляет список)

**`scripts/view/timeline.lua`** — раннер очереди шагов:

- `timeline.play(self, steps, done)` — `steps` — список шагов, `done` — колбэк конца
- `timeline.advance(self)`
- `timeline.card_anim(self, id, name, payload)` — посылает карте и ждёт `anim_done` по `token`
- `timeline.on_message(self, message)` — приём `anim_done` от карт (из `on_message` скрипта)

**`scripts/view/anim.lua`** — примитивы анимации ГО, вызывает `card.script` (абсолютные url компонентов):

- `anim.lift({ sprite, base, ms, scale })`
- `anim.lunge({ root, offset, ms, done })`
- `anim.fall({ root, sprite, label, offset, ms, color, done })`
- `anim.flash({ sprite, from, to, ms, done })`

**`scripts/view/hud.lua`** — строки HUD и сообщения в `hud.gui`:

- `hud.sync(self)`, `hud.flash(self)`

Границы: `world.script` остаётся владельцем режимов, ввода, вызовов `core/` и ссылок `self.player`/`self.world`/`self.arena`; он только делегирует перечисленному выше. `core/` модули не меняются.

---

## 6. Правила расширения

Новый тип клетки, врага, босса или объекта поля (симметрично `docs/ENTITY_REGISTRY.md` §4):

1. **Решение.** Поведение и видимость — в `GDD.md` и `balance/balance.csv`.
2. **Баланс.** Строки в `balance/balance.csv` → `python tools/build_balance.py`.
3. **Реестр ядра.** Запись в `core/registry/*` (данные + обработчики). Ядро не меняется.
4. **Вид.** Строка в `scripts/view/style.lua`: `{ symbol, fill_role, ink_role }`.
5. **Проверка вида.** Убедиться, что роли из новой записи существуют в `palette_cfg` (проверка при старте, §5.6); при необходимости добавить роль в `palette_cfg`.
6. **Тесты.** `tests/core/<name>_test.lua`; тест реестра (`tests/registry_test.lua`).
7. **Проверка.** `python tools/build_balance.py --check`, `luajit tests/run.lua`, сборка и запуск в редакторе.

`collections/world.script` и `game_objects/card.script` при добавлении типа **не меняются**. Если для нового типа нужна правка мирового скрипта — это сигнал, что не хватает точки расширения; точка расширения добавляется отдельным коммитом.

---

## 7. План реализации

Каждый этап — отдельный коммит с проверкой. Порядок: сначала дешёвые и снижающие риск шаги (доки), затем группировка свойств, затем дробный вынос модулей. `core/` не меняется, поэтому `luajit tests/run.lua` (228 тестов) и `build_balance.py --check` остаются зелёными; движковая часть проверяется сборкой и ручным запуском (`docs/TESTING.md` §1, §6).

**Синхронизация документации — часть каждого этапа** (Definition of Done): после шага документы описывают то, что реально в коде. Отдельного финального «этапа только для доков» нет.

| Этап | Содержание | Проверка |
|---|---|---|
| 0 | Синхронизация документации под текущий факт | **Выполнено** (фаза 1: `ARCHITECTURE`, `AI_CODING_RULES`, `BALANCE`, `TESTING`, `ENGINE_DEFOLD`, `CONVENTIONS`, `PLAN`; `PLAN_14` удалён) |
| 1 | Config-компоненты на `world.go` (`geom_cfg`/`anim_cfg`/`flash_cfg`/`palette_cfg`); перенос свойств; чтение через `go.get`; проверка полноты палитры при старте | **Выполнено**; сборка 1.14.0, лог без ERROR, ручная игра |
| 2 | Роль-палитра + `scripts/view/style.lua`; снятие `SYMBOL`/`FILL_KEY`/`INK_KEY` из `world.script`; проверка style → palette (§5.6) | **Выполнено**; сборка, ручная сверка вида клеток/врагов/игрока |
| 3.0 | Фиксация интерфейсов модулей (кто владеет `self.cards`, `self.anim_waiters`, `self.fx`, `self.anim_token`; сигнатуры) | **Выполнено** (§5.7); ревью, поведение не меняется |
| 3a | Переименование `cell.go`/`cell.script`/`cell_factory` → `card.go`/`card.script`/`card_factory` (правки в `world.go`, `world.script`, прототипе); вынос `scripts/view/fx.lua` | **Выполнено**; сборка, ручная игра |
| 3b | Вынос `scripts/view/timeline.lua` (+ `card_anim`) | **Выполнено**; сборка, прогон боя, атак «в спину», арены |
| 3c | Вынос `scripts/view/board.lua` (diff-синхронизация, идентичность карт, `content_row` арены) и `scripts/view/hud.lua`; `world.script` — тонкий координатор | **Выполнено**; сборка, ручная игра всех режимов |

Порядок внутри 3 задан от менее связанного к более связанному (`fx` → `timeline` → `board`), чтобы не переписывать весь отлаженный таймлайн одним коммитом. `anim.lua` вынесен отдельным коммитом после 3a (примитивы анимации — общий код для будущих прототипов; `card.script` собирает абсолютные url компонентов в `init`). `cell` → `card` сделано в 3a: имя уже врёт (прототип универсальный), а ссылок мало. Палитра переходит между этапами 1 и 2: на этапе 1 `palette_cfg` переносит свойства под текущими именами (`color_*`), на этапе 2 они переименовываются в роли и подключается `style.lua` — так этап 1 не меняет картинку.

---

## 8. Синхронизация документации

Документация Defold-слоя приведена к фактическому состоянию репозитория (фаза 1): `docs/ARCHITECTURE.md` (карта файлов, режимы), `docs/AI_CODING_RULES.md` (ссылки вместо дублей и устаревших путей), `docs/BALANCE.md` (слим), `docs/TESTING.md` (фактический набор тестов), `docs/ENGINE_DEFOLD.md`, `docs/CONVENTIONS.md`. `docs/PLAN_14.md` удалён как перекрытый. Карта файлов — единственная, в `ARCHITECTURE.md` §2; остальные документы ссылаются на неё.

Правило на будущее: при изменении структуры сначала правка `ARCHITECTURE.md` §2, затем код.

---

## 9. Открытые вопросы

1. Нужны ли боссам отдельные прототипы (мультиклеточный вид) или view-registry достаточно до первого такого босса.
2. Роль-палитра убирает различие цветов между типами внутри одной роли (сейчас у врагов цвет и так общий — риск низкий).
3. Вводим ли быстрый тест style → palette (отдельный чистый модуль ролей, §5.6) или ограничиваемся проверкой при старте.

---

*Документ описывает Defold-слой. Механика — `GDD.md`, числа — `balance/balance.csv` и `design/design.csv`, правила кода — `docs/AI_CODING_RULES.md`. Изменения структуры сначала вносятся сюда, затем в код.*
