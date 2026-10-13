"""Генерация core/data/balance.lua из balance/balance.csv.

Использование (из корня проекта):
    python tools/build_balance.py           перегенерировать core/data/balance.lua
    python tools/build_balance.py --check   завершиться с кодом 1, если файл не совпадает с CSV

Формат CSV: path,value,notes. Всё после второй запятой — заметка, в код не попадает.
Числовой сегмент пути (enemyWindow.shape.0) — ключ таблицы с числовым индексом (0, 1, ...).
Значение TBD не допускается: генерация завершается с ошибкой (PLAN.md, пункт 2).
"""

import hashlib
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
CSV_PATH = ROOT / "balance" / "balance.csv"
LUA_PATH = ROOT / "core" / "data" / "balance.lua"

IDENT_RE = re.compile(r"^[A-Za-z_][A-Za-z0-9_]*$")
INT_RE = re.compile(r"^-?\d+$")
FLOAT_RE = re.compile(r"^-?\d+\.\d+$")


class BalanceError(Exception):
    pass


def parse_value(raw, where):
    if raw == "TBD":
        raise BalanceError(f"{where}: значение TBD не задано")
    if raw in ("true", "false"):
        return raw == "true"
    if INT_RE.match(raw) or FLOAT_RE.match(raw):
        return float(raw) if "." in raw else int(raw)
    return raw


def parse_csv(text):
    """Возвращает список (path_segments, value) и проверяет дубликаты."""
    entries = []
    seen = set()
    for lineno, line in enumerate(text.splitlines(), start=1):
        stripped = line.strip()
        if not stripped or stripped.startswith("#"):
            continue
        parts = stripped.split(",", 2)
        if len(parts) < 2:
            raise BalanceError(f"строка {lineno}: ожидается path,value")
        path, raw = parts[0].strip(), parts[1].strip()
        if not path:
            raise BalanceError(f"строка {lineno}: пустой путь")
        if path in seen:
            raise BalanceError(f"строка {lineno}: дубликат пути {path}")
        seen.add(path)
        segments = [int(s) if s.isdigit() else s for s in path.split(".")]
        for seg in segments:
            if isinstance(seg, str) and not IDENT_RE.match(seg):
                raise BalanceError(f"строка {lineno}: недопустимый сегмент {seg!r}")
        entries.append((segments, parse_value(raw, f"строка {lineno} ({path})")))
    return entries


def build_tree(entries):
    root = {}
    for segments, value in entries:
        node = root
        for seg in segments[:-1]:
            child = node.get(seg)
            if child is None:
                child = {}
                node[seg] = child
            elif not isinstance(child, dict):
                raise BalanceError(f"конфликт пути на сегменте {seg!r}")
            node = child
        last = segments[-1]
        if last in node:
            raise BalanceError(f"конфликт пути {'.'.join(map(str, segments))}")
        node[last] = value
    return root


def lua_scalar(value):
    if isinstance(value, bool):
        return "true" if value else "false"
    if isinstance(value, int):
        return str(value)
    if isinstance(value, float):
        return repr(value)
    escaped = value.replace("\\", "\\\\").replace('"', '\\"')
    return f'"{escaped}"'


def lua_key(key):
    if isinstance(key, int):
        return f"[{key}]"
    if IDENT_RE.match(key):
        return key
    return f"[{lua_scalar(key)}]"


def emit(node, indent):
    pad = "    " * indent
    lines = ["{"]
    for key in sorted(node, key=lambda k: (isinstance(k, str), k)):
        value = node[key]
        head = f"{pad}    {lua_key(key)} = "
        if isinstance(value, dict):
            lines.append(head + emit(value, indent + 1) + ",")
        else:
            lines.append(head + lua_scalar(value) + ",")
    lines.append(pad + "}")
    return "\n".join(lines)


def check_invariants(tree):
    """Проверки, которые должны пройти до генерации (GDD 13, BALANCE.md 10)."""
    rows = tree.get("rows", {}).get("chances", {})
    for bound in ("from", "to"):
        total = 0.0
        for kind, spec in rows.items():
            if isinstance(spec, dict) and bound in spec:
                total += float(spec[bound])
        if total > 1.0:
            raise BalanceError(f"сумма шансов rows.chances ({bound}) = {total} > 1")
    enemies = tree.get("enemies", {})
    weights = [float(e["weight"]) for e in enemies.values() if isinstance(e, dict) and "weight" in e]
    if not weights or any(w < 0 for w in weights) or sum(weights) <= 0:
        raise BalanceError("веса типов врагов должны быть неотрицательными и не нулевыми")
    for name, value in _walk(tree):
        if name.endswith(".hp") or name.endswith(".rechargeTurns"):
            if isinstance(value, (int, float)) and value < 0:
                raise BalanceError(f"{name} отрицательный")


def _walk(node, prefix=""):
    for key, value in node.items():
        name = f"{prefix}.{key}" if prefix else str(key)
        if isinstance(value, dict):
            yield from _walk(value, name)
        else:
            yield name, value


def render(text, csv_rel, check_rules=True):
    csv_norm = text.replace("\r\n", "\n")
    digest = hashlib.sha256(csv_norm.encode("utf-8")).hexdigest()
    entries = parse_csv(csv_norm)
    tree = build_tree(entries)
    if check_rules:
        check_invariants(tree)
    body = emit(tree, 0)
    header = (
        f"-- GENERATED by tools/build_balance.py from {csv_rel}. DO NOT EDIT.\n"
        f"-- source sha256: {digest}\n"
    )
    return header + "return " + body + "\n"


# Два источника. balance — правила игры (проверяются инвариантами).
# design — экран и презентация (без игровых инвариантов). Редактируются отдельно.
SOURCES = [
    {
        "name": "balance",
        "csv": ROOT / "balance" / "balance.csv",
        "lua": ROOT / "core" / "data" / "balance.lua",
        "check_rules": True,
    },
    {
        "name": "design",
        "csv": ROOT / "design" / "design.csv",
        "lua": ROOT / "core" / "data" / "design.lua",
        "check_rules": False,
    },
]


def main(argv):
    for stream in (sys.stdout, sys.stderr):
        stream.reconfigure(encoding="utf-8")
    check = "--check" in argv
    status = 0
    for src in SOURCES:
        csv_path, lua_path = src["csv"], src["lua"]
        csv_rel = csv_path.relative_to(ROOT).as_posix()
        if not csv_path.exists():
            print(f"нет файла {csv_rel}", file=sys.stderr)
            return 1
        try:
            generated = render(csv_path.read_text(encoding="utf-8"), csv_rel, src["check_rules"])
        except BalanceError as err:
            print(f"ОШИБКА ({src['name']}): {err}", file=sys.stderr)
            return 1
        if check:
            current = lua_path.read_text(encoding="utf-8") if lua_path.exists() else ""
            if current.replace("\r\n", "\n") != generated:
                print(f"{lua_path.name} не совпадает с {csv_rel}; запустите tools/build_balance.py", file=sys.stderr)
                status = 1
            else:
                print(f"{lua_path.name} актуален")
            continue
        lua_path.parent.mkdir(parents=True, exist_ok=True)
        lua_path.write_text(generated, encoding="utf-8", newline="\n")
        print(f"записано {lua_path.relative_to(ROOT).as_posix()}")
    return status


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
