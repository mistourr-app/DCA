-- Подсказки на поле (GDD §5.4, §12). Чистая логика: возвращает данные, рисует collections/world.script.
--
-- Обводки ходов: step (зелёная) — бесплатный шаг, jump (фиолетовая) — прыжок за HP.
--   Снаружи обводится только перемещение: клетки, куда можно пойти. Клетки врагов
--   в подсказки не попадают — у карты врага уже есть своя рамка, вторая обводка вокруг
--   неё читалась как лишняя. Ход на врага при этом остаётся обычным ходом
--   (movement.options). Клетки-ловушки арены обводятся как обычные ходы: их тип виден
--   по собственной карте, а не по цвету внешней рамки.
-- Пунктир выстрела: рисуется до каждой цели, в которую выстрел возможен (есть заряд,
--   цель в дальности, линия не перекрыта стеной). Если выстрел невозможен — ничего.
-- Зрение врагов: оранжевым помечаются все клетки, которые видит хотя бы один враг своего ряда.
--   Стена не подсвечивается и блокирует обзор за собой. Если игрока видит враг, его клетка
--   красная. Непрозрачность 25% на каждого врага (design.screen.threatAlpha), сумма не выше 100%.

local design = require("core.data.design")
local grid = require("core.grid")
local movement = require("core.movement")
local visibility = require("core.visibility")
local equipment = require("core.equipment")
local registry = require("core.registry.init")

local M = {}

local COLUMNS = grid.COLUMNS
local PER_ENEMY = design.screen.threatAlpha

local function wall_fn(row)
	return function(x)
		local c = row and row[x]
		return c ~= nil and c.type == "WALL"
	end
end

-- Ходы на следующий ряд: { x, y, kind = "step" | "jump" }. Клетки врагов пропускаются:
-- их карта обводится собственной рамкой (line_enemy), внешняя подсказка не нужна.
function M.moves(pos, hp, row_above)
	local out = {}
	for _, o in ipairs(movement.options(pos, hp, row_above)) do
		if o.cell_type ~= "ENEMY" then
			local kind = "jump"
			if o.cost == 0 then
				kind = "step"
			end
			table.insert(out, { x = o.x, y = o.y, kind = kind })
		end
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

-- Карта зрения ряда y: для каждой колонки число врагов, которые её видят.
-- Враги ходят только по своему ряду, поэтому угрозы действуют на клетки того же ряда.
-- Стена не помечается; клетки за стеной не помечаются (обзор блокируется).
function M.vision(row, y)
	local out = {}
	for x = 0, COLUMNS - 1 do
		out[x] = 0
	end
	local wall = wall_fn(row)
	for ex = 0, COLUMNS - 1 do
		local c = row and row[ex]
		if c and c.type == "ENEMY" then
			local vision = registry.enemies.types[c.enemy].vision
			for x = 0, COLUMNS - 1 do
				local cell = row[x]
				if cell ~= nil and cell.type ~= "WALL" and visibility.can_see({ x = ex, y = y }, { x = x, y = y }, vision, wall) then
					out[x] = out[x] + 1
				end
			end
		end
	end
	return out
end

-- Непрозрачность оранжевого оверлея для клетки, видимую count врагам; nil — оверлея нет.
function M.vision_alpha(count)
	if count <= 0 then
		return nil
	end
	return math.min(1, PER_ENEMY * count)
end

-- Попадает ли игрок в поле зрения врагов своего ряда.
function M.spotted(vision_row, player_x)
	return vision_row[player_x] > 0
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

-- Арена: ходы по X на своем ряду. Соседняя колонка — step, дальше — jump (стоит HP).
-- Вид клетки на обводку не влияет: рамка снаружи означает только «сюда можно пойти»,
-- поэтому клетка-ловушка обводится как шаг или прыжок. Недоступные прыжки
-- (HP − стоимость < 1) не подсвечиваются.
function M.arena_moves(a)
	local out = {}
	if a.turn ~= "player" then
		return out
	end
	for x = 0, COLUMNS - 1 do
		if x ~= a.player_x then
			local cost = math.max(0, math.abs(x - a.player_x) - 1)
			if a.player_hp - cost >= 1 then
				local kind = "jump"
				if cost == 0 then
					kind = "step"
				end
				table.insert(out, { x = x, kind = kind, cost = cost })
			end
		end
	end
	return out
end

-- Арена: колонка босса, если выстрел по нему возможен сейчас, иначе nil.
-- Лимит арены — один выстрел за ход (a.fired); флаг «уже стрелял на ряду» — механика мира.
function M.arena_shot(a, weapon, range)
	if a.turn ~= "player" or a.fired then
		return nil
	end
	if math.abs(a.boss_x - a.player_x) > range then
		return nil
	end
	if not equipment.can_use(weapon) then
		return nil
	end
	return a.boss_x
end

return M
