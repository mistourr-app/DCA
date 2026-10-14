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
--
-- Ход игрока: выстрел (не завершает ход, один за ход) или перемещение/атака клеткой
-- (завершают ход и передают его боссу).

local balance = require("core.data.balance")
local grid = require("core.grid")
local equipment = require("core.equipment")

local M = {}

local COLUMNS = balance.board.columns
local LOW = balance.arena.hpLowThreshold
local HIGH = balance.arena.hpHighThreshold

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

-- Новое состояние арены.
function M.new(player_x, player_hp, player_max, boss_number, player_row, boss_row)
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
	}
end

-- AI босса: профиль по HP-доле (GDD §12.5).
function M.profile(boss_hp, boss_max)
	local frac = boss_hp / boss_max
	if frac > 0.6 then
		return "aggressive"
	elseif frac > 0.25 then
		return "balanced"
	end
	return "defensive"
end

-- Допустимые ходы босса по X: ±1 от текущей позиции, в пределах поля.
-- Возврат на предыдущую клетку запрещён, если есть альтернативы (GDD §12.5).
function M.boss_moves(a)
	local out = {}
	for dx = -1, 1 do
		local nx = a.boss_x + dx
		if dx ~= 0 and nx >= 0 and nx < COLUMNS then
			table.insert(out, nx)
		end
	end
	if #out > 1 and a.prev_boss_x ~= nil then
		local filtered = {}
		for _, nx in ipairs(out) do
			if nx ~= a.prev_boss_x then
				table.insert(filtered, nx)
			end
		end
		if #filtered > 0 then
			out = filtered
		end
	end
	return out
end

-- Оценка клетки для AI: атака/бонус предпочтительнее лечения при агрессивном профиле и наоборот.
local function cell_score(profile, cell, player_x, x)
	local score = 0
	if cell.type == "ATTACK_CELL" then
		score = profile == "aggressive" and 3 or (profile == "balanced" and 2 or 1)
	elseif cell.type == "HEAL" then
		score = profile == "defensive" and 3 or 0
	end
	if profile == "defensive" and x == player_x then
		score = score - 2
	end
	return score
end

-- Ход босса: выбирает колонку по профилю. Возвращает новый x.
function M.boss_choose(a, rng_g)
	local moves = M.boss_moves(a)
	if #moves == 0 then
		return a.boss_x
	end
	local profile = M.profile(a.boss_hp, a.boss_max)
	local best, best_score = nil, nil
	for _, x in ipairs(moves) do
		local s = cell_score(profile, a.boss_row[x] or { type = "EMPTY" }, a.player_x, x)
		if best_score == nil or s > best_score then
			best, best_score = x, s
		end
	end
	return best
end

-- Ход босса: перемещение и (если на клетке атаки) удар по игроку. Возврат ход игроку.
-- Урон босса = его текущий HP (GDD §5.3 для атаки, согласованно с врагами).
function M.boss_turn(a)
	local events = {}
	local new_x = M.boss_choose(a, nil)
	a.prev_boss_x = a.boss_x
	a.boss_x = new_x
	local cell = a.boss_row[new_x] or { type = "EMPTY" }
	if cell.type == "ATTACK_CELL" and new_x == a.player_x then
		a.player_hp = math.max(0, a.player_hp - cell.damage)
		table.insert(events, { type = "boss_attack", damage = cell.damage, hp = a.player_hp })
	end
	table.insert(events, { type = "boss_move", x = new_x })
	a.turn = "player"
	a.fired = false
	return events
end

-- Выстрел из арбалета по боссу: не завершает ход, один за ход. Урон — оружия.
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
	local ok, reason = equipment.fire(weapon)
	if not ok then
		return false, reason
	end
	a.fired = true
	a.boss_hp = math.max(0, a.boss_hp - damage)
	return true, { { type = "shot", damage = damage, boss_hp = a.boss_hp } }
end

-- Перемещение игрока по X на ряде арены. Передаёт ход боссу.
-- Клетка на ряду игрока: лечение применяется, клетка атаки наносит урон боссу (передача хода).
function M.player_move(a, x)
	if a.turn ~= "player" then
		return false, "Not your turn"
	end
	if not grid.in_columns(x) or math.abs(x - a.player_x) > 1 then
		return false, "Move only to an adjacent column"
	end
	a.player_x = x
	-- Перемещение или атака клеткой передают ход боссу (GDD §12.2).
	a.turn = "boss"
	local events = { { type = "player_move", x = x } }
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
