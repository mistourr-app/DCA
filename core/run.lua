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

-- Ближний бой (GDD §5.3). Клик по врагу на следующем ряду.
--   1. атаки «в спину» врагов текущего ряда;
--   2. игрок переходит на клетку врага: стоимость max(0, |dx|-1) HP (проверка как у хода);
--   3. тычок: игрок бьёт на свой HP, враг отвечает остатком своего HP (combat.melee);
--   4. игрок возвращается на свою клетку (GDD §5.3 п.4); враг мёртв — клетка становится EMPTY.
-- Положение игрока не меняется; стоимость HP списывается.
function M.melee(run, x, y)
	local w = run.world
	local pos = w.pos
	local row_above = run.get_row(pos.y + 1)
	local target = row_above and row_above[x]
	if target == nil or target.type ~= "ENEMY" then
		return false, { { type = "refused", reason = "в клетке нет врага" } }
	end
	if y ~= pos.y + 1 then
		return false, { { type = "refused", reason = "ближний бой только с врагом на следующем ряду" } }
	end
	local cost = grid.jump_cost(pos, { x = x, y = y })
	if run.player.hp - cost < 1 then
		return false, { { type = "refused", reason = "не хватает HP на переход к врагу" } }
	end

	local events = behind_attacks(run, pos)
	if run.player.hp <= 0 then
		run.player.hp = 0
		table.insert(events, { type = "death", at = { x = pos.x, y = pos.y } })
		return true, events
	end

	run.player.hp = run.player.hp - cost
	table.insert(events, { type = "approach", to = { x = x, y = y }, cost = cost })

	local player_before = run.player.hp
	local hp = enemy_hp(target)
	local player_after, enemy_after = combat.melee(player_before, hp)
	run.player.hp = player_after
	table.insert(events, {
		type = "poke",
		dealt_to_enemy = player_before,
		dealt_to_player = enemy_after,
		enemy_hp = enemy_after,
		hp = player_after,
	})

	if combat.is_dead(enemy_after) then
		run.get_row(y)[x] = { type = "EMPTY" }
		table.insert(events, { type = "enemy_dead", x = x, y = y })
	else
		run.get_row(y)[x].hp = enemy_after
	end

	if combat.is_dead(player_after) then
		table.insert(events, { type = "death", at = { x = pos.x, y = pos.y } })
	end
	return true, events
end

-- Выстрел из арбалета по врагу на том же ряду (GDD §5.1, §5.3).
-- Дальность — equipment.range; линия видимости — core/visibility; враг не отвечает.
-- Не продвигает игрока и не завершает ход; ограничение один выстрел за ряд (core/equipment).
function M.shoot(run, x)
	local w = run.world
	local pos = w.pos
	local row = run.get_row(pos.y)
	local target = row and row[x]
	if target == nil or target.type ~= "ENEMY" then
		return false, { { type = "refused", reason = "в клетке нет врага" } }
	end
	local weapon = run.player.weapon
	local range = registry.equipment.CROSSBOW.range
	local ok, reason = equipment.can_fire(weapon)
	if not ok then
		return false, { { type = "refused", reason = reason } }
	end
	if not visibility.can_see(pos, { x = x, y = pos.y }, { range = range, shape = "row" }, wall_fn(row)) then
		return false, { { type = "refused", reason = "враг вне дальности или за стеной" } }
	end

	equipment.fire(weapon)
	local damage = run.player.weapon_damage or registry.equipment.CROSSBOW.damage
	local hp = combat.shot(enemy_hp(target), damage)
	local events = { { type = "shot", x = x, damage = damage, enemy_hp = hp } }
	if combat.is_dead(hp) then
		row[x] = { type = "EMPTY" }
		table.insert(events, { type = "enemy_dead", x = x, y = pos.y })
	else
		row[x].hp = hp
	end
	return true, events
end

return M
