"""Проверка текстовых файлов Defold: без BOM.

Defold не принимает BOM в начале файла и падает с ошибкой вида
"Expected identifier. Found '﻿'". Запуск из корня проекта:
    python tools/check_defold_files.py
Код возврата 1, если найдены нарушения.
"""

import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SUFFIXES = {
    ".go", ".script", ".gui", ".gui_script", ".collection", ".collectionproxy",
    ".factory", ".label", ".project", ".input_binding", ".lua", ".csv", ".md",
}
SKIP_DIRS = {".git", "build", ".internal"}
BOM = b"\xef\xbb\xbf"


def iter_files():
    for path in ROOT.rglob("*"):
        if not path.is_file():
            continue
        if any(part in SKIP_DIRS for part in path.relative_to(ROOT).parts):
            continue
        if path.suffix in SUFFIXES or path.name == "game.project":
            yield path


def main():
    sys.stdout.reconfigure(encoding="utf-8")
    bad = []
    for path in iter_files():
        data = path.read_bytes()
        if data.startswith(BOM):
            bad.append((path, "BOM в начале файла"))
    for path, problem in bad:
        print(f"{path.relative_to(ROOT)}: {problem}")
    if bad:
        print(f"нарушений: {len(bad)}")
        return 1
    print("файлы в порядке")
    return 0


if __name__ == "__main__":
    sys.exit(main())
