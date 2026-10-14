-- Подсказки на поле (GDD §5.4, §12). Чистая логика: возвращает данные, рисует collections/world.script.
--
-- Обводки ходов: step (зелёная) — бесплатный шаг, jump (фиолетовая) — прыжок за HP,
--   attack (красная) — ближний бой с врагом на следующем ряду.
-- Пунктир выстрела: рисуется до каждой цели, в которую выстрел возможен (есть заряд,
--   цель в дальности, линия не перекрыта стеной). Если выстрел невозможен — ничего.
-- Карты угроз: alert — колонка видна врагу (красный), idle — колонка в зоне обзора, но линия
--   перекрыта стеной (оранжевый). По 25% на каждого врага, сумма не выше 100%.

local design = require("core.data.design")
local grid = require("core.grid")
local movement = require("core.movement")
local visibility = require("core.visibility")
local equipment = require("core.equipment")
local registry = require("core.registry.init")

local M = {}

local COLUMNS = grid.COLUMNS
local PER_ENEMY = 0.25

M.DASH_STEP = design.screen.dashStep

local function wall_fn(row)
	return function(x)
		local c = row and row[x]
		return c ~= nil and c.type == "WALL"
	end
end

-- Ходы на следующий ряд: { x, y, kind = "step" | "jump" | "attack" }.
function M.moves(pos, hp, row_above)
	local out = {}
	for _, o in ipairs(movement.options(pos, hp, row_above)) do
		local kind = "jump"
		if o.cell_type == "ENEMY" then
			kind = "attack"
		elseif o.cost == 0 then
			kind = "step"
		end
		table.insert(out, { x = o.x, y = o.y, kind = kind })
	end
	return out
end

-- Колонки врагов на ряду игрока, в которые выстрел возможен сейчас.
function M.shot_targets(pos, row, weapon, range)
	local out = {}
	if not equipment.can_fire(weapon) then
		return out
	end
	local wall = wall_fn(row)
	for x = 0, COLUMNS - 1 do
		local c = row and row[x]
		if x ~= pos.x and c and c.type == "ENEMY" then
			if visibility.can_see(pos, { x = x, y = pos.y }, { range = range, shape = "row" }, wall) then
				table.insert(out, x)
			end
		end
	end
	return out
end

-- Карта угроз ряда y: для каждой колонки { alert = n, idle = n } (n — число врагов ряда).
-- Враги ходят только по своему ряду, поэтому угрозы действуют на клетки того же ряда.
function M.threat(row, y)
	local out = {}
	for x = 0, COLUMNS - 1 do
		out[x] = { alert = 0, idle = 0 }
	end
	local wall = wall_fn(row)
	for ex = 0, COLUMNS - 1 do
		local c = row and row[ex]
		if c and c.type == "ENEMY" then
			local vision = registry.enemies.types[c.enemy].vision
			for x = 0, COLUMNS - 1 do
				local dist = math.abs(x - ex)
				if x ~= ex and dist <= vision.range then
					if visibility.can_see({ x = ex, y = y }, { x = x, y = y }, vision, wall) then
						out[x].alert = out[x].alert + 1
					else
						out[x].idle = out[x].idle + 1
					end
				end
			end
		end
	end
	return out
end

-- Стиль угрозы клетки: вид ("alert" | "idle" | nil) и непрозрачность 0..1.
function M.threat_style(t)
	if t.alert > 0 then
		return "alert", math.min(1, PER_ENEMY * t.alert)
	end
	if t.idle > 0 then
		return "idle", math.min(1, PER_ENEMY * t.idle)
	end
	return nil, 0
end

-- Точки пунктирной линии от (ax, ay) до (bx, by), без концов (они внутри клеток).
function M.dash_points(ax, ay, bx, by, step)
	local dx, dy = bx - ax, by - ay
	local dist = math.sqrt(dx * dx + dy * dy)
	local n = math.floor(dist / step)
	local out = {}
	for i = 1, n - 1 do
		local t = i / n
		table.insert(out, { x = ax + dx * t, y = ay + dy * t })
	end
	return out
end

-- Арена: ходы по X на ряду игрока. kind = "attack" для клетки атаки, иначе "step".
function M.arena_moves(a)
	local out = {}
	if a.turn ~= "player" then
		return out
	end
	for _, dx in ipairs({ -1, 1 }) do
		local x = a.player_x + dx
		if x >= 0 and x < COLUMNS then
			local c = a.player_row[x] or { type = "EMPTY" }
			table.insert(out, { x = x, kind = c.type == "ATTACK_CELL" and "attack" or "step" })
		end
	end
	return out
end

-- Арена: колонка босса, если выстрел по нему возможен сейчас, иначе nil.
function M.arena_shot(a, weapon, range)
	if a.turn ~= "player" or a.fired then
		return nil
	end
	if math.abs(a.boss_x - a.player_x) > range then
		return nil
	end
	if not equipment.can_fire(weapon) then
		return nil
	end
	return a.boss_x
end

return M
