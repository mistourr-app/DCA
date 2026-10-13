# Соглашения проекта

## 1. Язык

- Документация, комментарии, тексты UI-заглушек и `notes` в CSV: **русский**.
- Идентификаторы в коде, имена файлов, ключи CSV, сообщения: **английский**, snake_case.
- Коммиты: русский или английский, одна мысль на коммит, глагол в повелительном наклонении. Пример: `Добавить генерацию balance.lua` или `Add balance generator`. Выбрать один язык на весь репозиторий: **русский** по умолчанию.

## 2. Git

- Репозиторий: `origin` → `https://github.com/mistourr-app/DCA.git`, ветка `main`.
- Работа в ветках `feature/<короткое-имя>` или `fix/<короткое-имя>`. Прямые коммиты в `main` — только документация и инфраструктура на раннем этапе.
- Перед коммитом: `git status`, `git diff`. Коммитить только свои файлы.
- Не коммитить: `build/`, `.internal/`, `*.projectc`, `*.collectionc`, `*.goc`, `*.guic`, `*.luac`, `.DS_Store`, `Thumbs.db`, логи (`*.log`), локальные настройки редактора.
- Не коммитить: пароли, токены, ключи подписи Android/iOS (`*.keystore`, `*.jks`, `*.p12`, `*.mobileprovision`).
- Формат `.gitignore`: см. раздел 5.
- Переписывать историю (`--force`, `--amend` опубликованных коммитов) — только по явной просьбе.

Рекомендуемый `.gitattributes`:

```
*.lua text eol=lf
*.csv text eol=lf
*.collection text eol=lf
*.go text eol=lf
*.gui text eol=lf
*.script text eol=lf
*.gui_script text eol=lf
*.project text eol=lf
*.md text eol=lf
*.png binary
*.ogg binary
*.wav binary
```

## 3. Ветвление и релизы

- `main` — всегда собирается и проходит `tests/run.lua`.
- Версии прототипа: теги `v0.1.0`, `v0.2.0` и т.д. Версия в `game.project` (`project.version`) совпадает с тегом.
- Пререлизы для Android: AAB/APK из тега, не из рабочей копии.

## 4. Формат документов

- Заголовки: H1 один на файл, далее H2/H3.
- Таблицы для параметров и сравнений.
- Формулы — в блоках кода или строкой с обратными кавычками.
- Ссылки на файлы проекта — относительные пути от корня: `core/grid.lua`.
- Не дублировать числа баланса в документах. Ссылаться на `balance/balance.csv`.
- Устаревшие разделы помечать `> УСТАРЕЛО` с датой, а не удалять, если на них есть ссылки.

## 5. .gitignore (стартовый)

```
# Defold build output
build/
.internal/
*.projectc
*.collectionc
*.goc
*.guic
*.luac
*.dmanifest
*.darc
*.arcd
*.arci
*.texturec
*.atlasc
*.tilesourcec
*.fontc
*.spritec
*.tilemapc
*.animc
*.soundc
*.materialc
*.vpc
*.fpc
*.render_scriptc
*.scriptc
*.gui_scriptc
*.compute
*.ttf.dmfont

# Editor and OS
.DS_Store
Thumbs.db
*.log
.vscode/
.idea/

# Secrets and signing
*.keystore
*.jks
*.p12
*.mobileprovision
secrets/

# Python tools cache
__pycache__/
*.pyc
```

Проверить список по факту сборки: если Defold создаёт другие каталоги вне `build/`, добавить их.

## 6. Инструменты

- Python 3.10+ для `tools/build_balance.py`.
- LuaJIT или Lua 5.1 для `tests/run.lua`.
- Defold Editor 1.14.0 (та же версия у всей команды).
- Bob (CLI) той же версии для сборки на CI, когда он появится.

## 7. Что проверять при изменении соглашений

Изменения этого документа согласуются с владельцем проекта и отражаются в `docs/AI_CODING_RULES.md`, если затрагивают код.
