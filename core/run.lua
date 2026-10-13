-- Ход игрока по шагам GDD §5.2. Чистая логика: возвращает список событий, скрипт их проигрывает.
--
-- Состояние хода (run):
--   world      состояние core/world (pos, mode)
--   player     { hp, max_hp, gold, weapon = <core/equipment> }
--   get_row    function(y) -> { [x] = клетка } | nil — клетки ряда y; nil означает «ряда нет»
--
-- Клетка: { type = "EMPTY" | "WALL" | "HEAL" | "GOLD" | "ENEMY" | "CAMP" | "ATTACK_CELL", enemy = ключ, hp = число }.
-- Клетка врага без hp берёт base_hp своего типа из реестра.
--
-- Порядок шагов (GDD §5.2):
--   [1] проверка: клетка существует, не стена, HP − стоимость ≥ 1 (core/movement)
--   [2] атака врагов «в спину» до движения (урон = их текущий HP)
--   [3] игрок погиб? — смерть, движение отменяется
--   [4] перемещение, HP списывается стоимостью хода
--   [5] взаимодействие с новой клеткой: золото, лечение
--   [6] ход завершён: смена ряда, тик перезарядки
--
-- Решения, которых не было в GDD (уточнить при необходимости):
--   - лечение не превышает max_hp;
--   - если после атак HP − стоимость хода ≤ 0, игрок погибает на ходу (смерть, не отказ);
--   - подобранная клетка GOLD/HEAL становится EMPTY (собранное не возвращается, GDD §10).

local grid = require("core.grid")
local movement = require("core.movement")
local visibility = require("core.visibility")
local combat = require("core.combat")
local equipment = require("core.equipment")
local registry = require("core.registry")
local world = require("core.world")

local M = {}

local function enemy_hp(cell)
	if cell.hp ~= nil then
		return cell.hp
	end
	return registry.enemies.types[cell.enemy].base_hp
end

local function enemy_vision(cell)
	return registry.enemies.types[cell.enemy].vision
end

-- Стена на ряду y в колонке x (для линии видимости).
local function wall_fn(row)
	return function(x)
		local c = row and row[x]
		return c ~= nil and c.type == "WALL"
	end
end

-- Шаг [2]: враги своего ряда, которые видят игрока, бьют в спину. Возвращает события и флаг смерти.
local function behind_attacks(run, from)
	local events = {}
	local row = run.get_row(from.y)
	if row == nil then
		return events
	end
	for x = 0, grid.COLUMNS - 1 do
		local cell = row[x]
		if cell ~= nil and cell.type == "ENEMY" then
			local hp = enemy_hp(cell)
			if hp > 0 and visibility.can_see({ x = x, y = from.y }, from, enemy_vision(cell), wall_fn(row)) then
				run.player.hp = combat.behind_attack(run.player.hp, hp)
				table.insert(events, { type = "behind_attack", enemy_x = x, damage = hp, hp = run.player.hp })
			end
		end
	end
	return events
end

-- Шаг [5]: эффект клетки на новой позиции. Клетка сбрасывается в EMPTY.
local function interact(run, cell, x, y)
	local events = {}
	if cell.type == "GOLD" then
		local amount = registry.cells.GOLD.amount
		run.player.gold = run.player.gold + amount
		table.insert(events, { type = "gold", amount = amount, x = x, y = y })
	elseif cell.type == "HEAL" then
		local amount = registry.cells.HEAL.amount
		local before = run.player.hp
		run.player.hp = math.min(run.player.max_hp, before + amount)
		table.insert(events, { type = "heal", amount = run.player.hp - before, x = x, y = y })
	end
	if cell.type == "GOLD" or cell.type == "HEAL" then
		local row = run.get_row(y)
		row[x] = { type = "EMPTY" }
	end
	return events
end

-- Один ход игрока на клетку (x, y) следующего ряда.
-- Возвращает ok, events. При отказе ok = false, а состояние не меняется.
function M.step(run, x, y)
	local w = run.world
	local pos = w.pos
	local row_above = run.get_row(pos.y + 1)

	-- [1] проверка
	local hp_now = run.player.hp
	local new_hp = movement.step(pos, hp_now, row_above, x, y)
	if new_hp == nil then
		return false, { { type = "refused", reason = "ход недоступен" } }
	end
	local cost = hp_now - new_hp

	-- [2] атаки в спину
	local events = behind_attacks(run, pos)

	-- [3] смерть до движения (или на ходу, если HP не хватает на стоимость)
	if run.player.hp <= 0 or run.player.hp - cost <= 0 then
		run.player.hp = 0
		table.insert(events, { type = "death", at = { x = pos.x, y = pos.y } })
		return true, events
	end

	-- [4] перемещение
	run.player.hp = run.player.hp - cost
	local ok, reason = world.move(w, { x = x, y = y })
	if not ok then
		return false, { { type = "refused", reason = reason } }
	end
	table.insert(events, { type = "move", from = pos, to = { x = x, y = y }, cost = cost })

	-- [5] взаимодействие с клеткой
	local cell = run.get_row(y)[x]
	for _, e in ipairs(interact(run, cell, x, y)) do
		table.insert(events, e)
	end

	-- [6] ход завершён
	equipment.new_row(run.player.weapon)
	equipment.tick(run.player.weapon)
	return true, events
end

return M
