"""Проверка require в Lua-файлах по правилам Defold.

Defold разрешает require("a.b") только в файл a/b.lua. Файл a/b/init.lua не подхватывается,
поэтому тесты в LuaJIT (которые ищут ./?/init.lua) могут пройти, а сборка упадёт.
Запуск из корня проекта: python tools/check_requires.py
Код возврата 1, если найдены require без файла.
"""

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SKIP_DIRS = {".git", "build", ".internal"}
# Встроенные модули LuaJIT/Defold, файлов проекта не требуют.
BUILTIN = {"bit", "ffi", "jit", "string", "table", "math", "io", "os"}
REQUIRE_RE = re.compile(r'require\s*\(?\s*"([^"]+)"')


def main():
    sys.stdout.reconfigure(encoding="utf-8")
    bad = []
    for path in ROOT.rglob("*"):
        if not path.is_file() or path.suffix not in {".lua", ".script", ".gui_script", ".render_script"}:
            continue
        if any(part in SKIP_DIRS for part in path.relative_to(ROOT).parts):
            continue
        text = path.read_text(encoding="utf-8")
        for lineno, line in enumerate(text.splitlines(), start=1):
            for name in REQUIRE_RE.findall(line):
                if name in BUILTIN:
                    continue
                target = ROOT / (name.replace(".", "/") + ".lua")
                if not target.exists():
                    bad.append(f"{path.relative_to(ROOT)}:{lineno}: require(\"{name}\") -> нет файла {target.relative_to(ROOT)}")
    for msg in bad:
        print(msg)
    if bad:
        print(f"нарушений: {len(bad)}")
        return 1
    print("require в порядке")
    return 0


if __name__ == "__main__":
    sys.exit(main())
