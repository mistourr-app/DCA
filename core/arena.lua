-- Арена босса (GDD §12). Чистая логика, без Defold API.
--
-- Арена занимает два последних ряда цикла (boss.arenaRows). Игрок стоит на нижнем ряду арены,
-- босс — на верхнем. Движение только горизонтальное (по X).
--
-- Состояние арены:
--   player_x, boss_x          колонки игрока и босса
--   player_hp, player_max     HP игрока
--   boss_hp, boss_max         HP босса
--   turn                      "player" | "boss"
--   prev_boss_x               колонка босса до его последнего хода (для запрета возврата)
--   fired                     выстрел в этом ходу уже был
--   player_row, boss_row      клетки рядов арены { [x] = { type = ... } }
--   gen                       генератор core/rng для пересоздания клетки при уходе
--
-- Ход игрока: выстрел (не завершает ход, один за ход) или перемещение/атака клеткой
-- (завершают ход и передают его боссу). Перемещение горизонтальное: соседняя колонка — шаг
-- бесплатно, дальше — прыжок ценой max(0, |dx| - 1) HP (то же правило, что в мире, GDD §5.1).
--
-- Механизм клеток един для обоих рядов (GDD §12.4): эффект срабатывает при вступании
-- (лечение, атака игрока по боссу, атака босса по игроку), клетка становится пустой.
-- При уходе актёра с любой клетки своего ряда генератор кладёт на её место новую:
-- ряд игрока — атака/лечение/пусто по текущей HP-доле, ряд босса — атака/пусто по базовому
-- шансу. Клетка под актёром не меняется; босс бьёт клеткой атаки в любой колонке.

local balance = require("core.data.balance")
local grid = require("core.grid")
local equipment = require("core.equipment")
local boss_ai = require("core.ai.boss_default")

local M = {}

local COLUMNS = balance.board.columns
local LOW = balance.arena.hpLowThreshold
local HIGH = balance.arena.hpHighThreshold
local PERIOD = balance.boss.period
local ARENA_ROWS = balance.boss.arenaRows

-- Нижний ряд арены для любого из её двух рядов; nil для обычного ряда и checkpoint.
-- Арена занимает последние ARENA_ROWS рядов периода (GDD §12.1).
function M.arena_bottom_for_row(row)
	local phase = row % PERIOD
	local bottom_phase = PERIOD - ARENA_ROWS
	if phase < bottom_phase then
		return nil
	end
	return row - phase + bottom_phase
end

-- Множитель HP босса по номеру босса (1, 2, ...), из CSV.
function M.boss_max_hp(player_max_hp, boss_number)
	local mult = balance.boss.hpMultiplier.from + balance.boss.hpMultiplier.slope * (boss_number - 1)
	return math.floor(player_max_hp * mult)
end

-- Шансы клеток ряда игрока по HP-доле (GDD §12.4). Энергии на арене нет.
function M.player_row_chances(hp_fraction)
	local c = balance.arena.chances
	local attack = c.ATTACK_CELL.base
	local heal = c.HEAL.base
	if hp_fraction < LOW then
		attack = c.ATTACK_CELL.hpLow
		heal = c.HEAL.hpLow
	elseif hp_fraction > HIGH then
		attack = c.ATTACK_CELL.hpHigh
		heal = c.HEAL.hpHigh
	end
	return { ATTACK_CELL = attack, HEAL = heal }
end

-- Урон клетки атаки: случайный в диапазоне cells.ATTACK_CELL (CSV).
local function attack_damage(g)
	return g:int(balance.cells.ATTACK_CELL.damageMin, balance.cells.ATTACK_CELL.damageMax)
end

-- Клетки ряда игрока (лечение, атака) и ряда босса (только атака) по роллу rng.
-- g — генератор core/rng; ch — шансы из player_row_chances.
function M.generate_rows(g, ch)
	local player_row, boss_row = {}, {}
	for x = 0, COLUMNS - 1 do
		local roll = g:float()
		if roll < ch.ATTACK_CELL then
			player_row[x] = { type = "ATTACK_CELL", damage = attack_damage(g) }
		elseif roll < ch.ATTACK_CELL + ch.HEAL then
			player_row[x] = { type = "HEAL" }
		else
			player_row[x] = { type = "EMPTY" }
		end
		local r2 = g:float()
		if r2 < balance.arena.chances.ATTACK_CELL.base then
			boss_row[x] = { type = "ATTACK_CELL", damage = attack_damage(g) }
		else
			boss_row[x] = { type = "EMPTY" }
		end
	end
	return player_row, boss_row
end

-- Новая клетка на месте той, с которой ушёл игрок: шансы по текущей HP-доле (GDD §12.4).
function M.reroll_player_cell(a)
	local ch = M.player_row_chances(a.player_hp / a.player_max)
	local roll = a.gen:float()
	if roll < ch.ATTACK_CELL then
		return { type = "ATTACK_CELL", damage = attack_damage(a.gen) }
	elseif roll < ch.ATTACK_CELL + ch.HEAL then
		return { type = "HEAL" }
	end
	return { type = "EMPTY" }
end

-- Новая клетка на месте той, с которой ушёл босс: базовый шанс атаки, лечения нет.
function M.reroll_boss_cell(a)
	if a.gen:float() < balance.arena.chances.ATTACK_CELL.base then
		return { type = "ATTACK_CELL", damage = attack_damage(a.gen) }
	end
	return { type = "EMPTY" }
end

-- Новое состояние арены. gen — генератор core/rng для пересоздания клеток по ходу боя.
function M.new(player_x, player_hp, player_max, boss_number, player_row, boss_row, gen)
	local boss_max = M.boss_max_hp(player_max, boss_number)
	return {
		player_x = player_x,
		boss_x = player_x,
		player_hp = player_hp,
		player_max = player_max,
		boss_hp = boss_max,
		boss_max = boss_max,
		turn = "player",
		prev_boss_x = nil,
		fired = false,
		player_row = player_row,
		boss_row = boss_row,
		gen = gen,
	}
end

-- Ход босса: перемещение и (если стал на клетку атаки) удар по игроку. Возврат ход игроку.
-- Босс бьёт клеткой атаки в любой колонке, механизм тот же, что у игрока (GDD §12.2, §12.4).
-- Уходя с клетки, босс оставляет на её месте новую.
function M.boss_turn(a)
	local events = {}
	local new_x = boss_ai.choose(a)
	local from = a.boss_x
	a.prev_boss_x = a.boss_x
	a.boss_x = new_x
	local cell = a.boss_row[new_x] or { type = "EMPTY" }
	if cell.type == "ATTACK_CELL" then
		a.player_hp = math.max(0, a.player_hp - cell.damage)
		a.boss_row[new_x] = { type = "EMPTY" }
		table.insert(events, { type = "boss_attack", damage = cell.damage, hp = a.player_hp })
	end
	table.insert(events, { type = "boss_move", x = new_x })
	a.turn = "player"
	a.fired = false
	if from ~= new_x then
		a.boss_row[from] = M.reroll_boss_cell(a)
	end
	return events
end

-- Выстрел из арбалета по боссу: не завершает ход, один за ход. Урон — оружия.
-- Лимит хода — a.fired (сбрасывается ходом босса); флаг «уже стрелял на ряду» (fired_this_row)
-- механика мира, в арене не участвует. Расход заряда и запуск перезарядки — core/equipment.
-- range — дальность оружия в клетках (по колонкам, GDD §5.1).
function M.shoot(a, weapon, damage, range)
	if a.turn ~= "player" then
		return false, "Not your turn"
	end
	if a.fired then
		return false, "Already fired this turn"
	end
	if math.abs(a.boss_x - a.player_x) > range then
		return false, "Boss out of range"
	end
	local ok, reason = equipment.can_use(weapon)
	if not ok then
		return false, reason
	end
	equipment.use(weapon)
	a.fired = true
	a.boss_hp = math.max(0, a.boss_hp - damage)
	return true, { { type = "shot", damage = damage, boss_hp = a.boss_hp } }
end

-- Перемещение игрока по X на ряде арены: соседняя колонка — шаг, дальше — прыжок за HP.
-- Передаёт ход боссу. Прыжок допустим, только если HP − стоимость ≥ 1 (GDD §5.1, §12.2).
-- Клетка на ряду игрока: лечение применяется, клетка атаки наносит урон боссу (передача хода).
function M.player_move(a, x)
	if a.turn ~= "player" then
		return false, "Not your turn"
	end
	if not grid.in_columns(x) or x == a.player_x then
		return false, "Move to another column on the arena"
	end
	local cost = math.max(0, math.abs(x - a.player_x) - 1)
	if a.player_hp - cost < 1 then
		return false, "Not enough HP to jump"
	end
	local from = a.player_x
	a.player_hp = a.player_hp - cost
	a.player_x = x
	-- Перемещение или атака клеткой передают ход боссу (GDD §12.2).
	a.turn = "boss"
	local events = { { type = "player_move", x = x, cost = cost } }
	local cell = a.player_row[x] or { type = "EMPTY" }
	if cell.type == "HEAL" then
		a.player_hp = math.min(a.player_max, a.player_hp + balance.cells.HEAL.amount)
		a.player_row[x] = { type = "EMPTY" }
		table.insert(events, { type = "heal", hp = a.player_hp })
	elseif cell.type == "ATTACK_CELL" then
		a.player_row[x] = { type = "EMPTY" }
		a.boss_hp = math.max(0, a.boss_hp - cell.damage)
		table.insert(events, { type = "player_attack", damage = cell.damage, boss_hp = a.boss_hp })
	end
	-- Уходя с клетки, игрок оставляет на её месте новую (GDD §12.4).
	a.player_row[from] = M.reroll_player_cell(a)
	return true, events
end

-- Атака клеткой на верхнем ряду (ряд босса) не используется: удар по боссу идёт через клетку игрока.
-- Проверка победы.
function M.result(a)
	if a.boss_hp <= 0 then
		return "victory"
	end
	if a.player_hp <= 0 then
		return "defeat"
	end
	return nil
end

return M
