-- Мир: режимы, переходы, окно рядов, точка возврата (GDD §3.1, §4, §9, §10, §16; docs/ARCHITECTURE.md §4, §6).
-- Чистая логика без Defold API. Состояние мира — таблица, функции принимают её первым аргументом.
--
-- Режимы:
--   WORLD  — подъём по рядам, ход игрока
--   CAMP   — лагерь (установка, восстановление, прокачка; правила — в core/camp.lua)
--   BOSS   — арена босса на двух рядах
--   DEATH  — экран смерти; возврат в точку возврата
--
-- Точка возврата: { kind = "start" | "camp" | "checkpoint", row = y, x = колонка }.
-- Стартовая точка — ряд 0 (он checkpoint по расписанию row_gen).

local balance = require("core.data.balance")
local grid = require("core.grid")
local row_gen = require("core.row_gen")

local M = {}

M.MODES = { WORLD = "WORLD", CAMP = "CAMP", BOSS = "BOSS", DEATH = "DEATH" }

local TRANSITIONS = {
	WORLD = { CAMP = true, BOSS = true, DEATH = true },
	CAMP = { WORLD = true },
	BOSS = { WORLD = true, DEATH = true },
	DEATH = { WORLD = true },
}

local RETURN_KINDS = { start = true, camp = true, checkpoint = true }

local WINDOW = balance.memory.W
local START_COLUMN = math.floor(grid.COLUMNS / 2)

-- Новый мир. global_seed — глобальный seed (GDD §11.1).
function M.new(global_seed)
	assert(type(global_seed) == "number", "global_seed должен быть числом")
	local start = { kind = "start", row = 0, x = START_COLUMN }
	return {
		global_seed = global_seed,
		mode = M.MODES.WORLD,
		pos = { x = START_COLUMN, y = 0 },
		return_point = start,
	}
end

-- Переход между режимами по таблице TRANSITIONS.
function M.transition(w, to)
	local allowed = TRANSITIONS[w.mode]
	if not (allowed and allowed[to]) then
		return false, string.format("переход %s -> %s запрещён", w.mode, tostring(to))
	end
	w.mode = to
	return true
end

-- Перемещение на клетку следующего ряда (GDD §5.1). Только в режиме WORLD.
-- Любая колонка следующего ряда; стоимость в HP проверяет core/movement, не здесь.
function M.move(w, to)
	if w.mode ~= M.MODES.WORLD then
		return false, "ходить можно только в режиме WORLD"
	end
	if not grid.in_columns(to.x) then
		return false, "колонка вне поля"
	end
	if to.y ~= w.pos.y + 1 then
		return false, "ход только на следующий ряд"
	end
	w.pos = { x = to.x, y = to.y }
	return true
end

-- Установка точки возврата: лагерь (kind = "camp") или чекпоинт (kind = "checkpoint").
-- Точка возврата не может быть выше текущего ряда.
function M.set_return_point(w, kind, row, x)
	if not RETURN_KINDS[kind] or kind == "start" then
		return false, "точка возврата: только camp или checkpoint"
	end
	if row > w.pos.y then
		return false, "точка возврата выше текущего ряда"
	end
	w.return_point = { kind = kind, row = row, x = x or w.pos.x }
	return true
end

-- Смерть: возврат в точку возврата (GDD §10). Восстановление HP и зарядов здесь не делается:
-- его выполняет core/death.lua по виду точки возврата.
function M.respawn(w)
	if w.mode ~= M.MODES.DEATH then
		return false, "respawn только из режима DEATH"
	end
	local rp = w.return_point
	w.pos = { x = rp.x, y = rp.row }
	w.mode = M.MODES.WORLD
	return true
end

-- Победа над боссом (GDD §12.1): игрок выходит на ближайший ряд checkpoint выше арены,
-- точка возврата становится этим чекпоинтом.
function M.boss_victory(w)
	if w.mode ~= M.MODES.BOSS then
		return false, "победа возможна только в режиме BOSS"
	end
	local r = w.pos.y
	local limit = r + balance.boss.period + 1
	while row_gen.kind(r) ~= "checkpoint" do
		r = r + 1
		if r > limit then
			return false, "не найден checkpoint после арены"
		end
	end
	w.mode = M.MODES.WORLD
	w.pos = { x = w.pos.x, y = r }
	w.return_point = { kind = "checkpoint", row = r, x = w.pos.x }
	return true
end

-- Окно рядов в памяти: [lo, hi] вокруг текущего ряда (GDD §3.1, docs/ARCHITECTURE.md §6).
function M.window(w)
	local lo = math.max(0, w.pos.y - WINDOW)
	local hi = w.pos.y + WINDOW
	return lo, hi
end

function M.in_window(w, y)
	local lo, hi = M.window(w)
	return y >= lo and y <= hi
end

-- Число рядов в окне (не растёт с номером ряда).
function M.window_size(w)
	local lo, hi = M.window(w)
	return hi - lo + 1
end

return M
