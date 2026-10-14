local arena = require("core.arena")
local equipment = require("core.equipment")
local rng = require("core.rng")
local balance = require("core.data.balance")

local M = {}

local COLUMNS = balance.board.columns

local function empty_row()
	local r = {}
	for x = 0, COLUMNS - 1 do
		r[x] = { type = "EMPTY" }
	end
	return r
end

local function new_fight(player_hp, player_max, boss_number)
	local pr, br = empty_row(), empty_row()
	return arena.new(2, player_hp, player_max, boss_number or 1, pr, br)
end

M["boss hp is player max hp times the configured multiplier"] = function(t)
	local expected = math.floor(20 * balance.boss.hpMultiplier.from)
	t.equal(arena.boss_max_hp(20, 1), expected, "первый босс")
	t.true_(arena.boss_max_hp(20, 2) > arena.boss_max_hp(20, 1), "второй босс сильнее")
end

M["player row chances follow hp fraction thresholds"] = function(t)
	local low = arena.player_row_chances(0.2)
	local high = arena.player_row_chances(0.9)
	local mid = arena.player_row_chances(0.6)
	t.equal(low.HEAL, balance.arena.chances.HEAL.hpLow, "низкое HP — больше лечения")
	t.equal(high.ATTACK_CELL, balance.arena.chances.ATTACK_CELL.hpHigh, "высокое HP — больше атаки")
	t.equal(mid.HEAL, balance.arena.chances.HEAL.base, "середина — базовый шанс")
end

M["arena has no energy cells"] = function(t)
	local pr, br = arena.generate_rows(rng.new(5), arena.player_row_chances(0.6))
	for x = 0, COLUMNS - 1 do
		t.true_(pr[x].type ~= "ENERGY", "на ряду игрока нет энергии")
		t.true_(br[x].type ~= "HEAL", "на ряду босса нет лечения")
	end
end

M["attack cell damage stays in the configured range"] = function(t)
	local pr = arena.generate_rows(rng.new(9), { ATTACK_CELL = 1, HEAL = 0 })
	for x = 0, COLUMNS - 1 do
		local c = pr[x]
		t.equal(c.type, "ATTACK_CELL", "все клетки атаки")
		t.true_(c.damage >= balance.cells.ATTACK_CELL.damageMin and c.damage <= balance.cells.ATTACK_CELL.damageMax, "урон в диапазоне")
	end
end

M["shot does not end the turn and is allowed once"] = function(t)
	local a = new_fight(20, 20)
	local w = equipment.new(3, 5)
	local ok = arena.shoot(a, w, 3, 3)
	t.true_(ok, "первый выстрел")
	t.equal(a.turn, "player", "ход не передан")
	t.true_(not arena.shoot(a, w, 3, 3), "второй выстрел в этом ходу запрещён")
end

M["shot is refused when the boss is out of range"] = function(t)
	local a = new_fight(20, 20)
	a.player_x = 0
	a.boss_x = 4
	local ok, reason = arena.shoot(a, equipment.new(3, 5), 3, 3)
	t.true_(not ok, "дальше дальности")
	t.true_(reason ~= nil, "есть причина")
end

M["shot damages the boss"] = function(t)
	local a = new_fight(20, 20)
	local before = a.boss_hp
	arena.shoot(a, equipment.new(3, 5), 3, 3)
	t.equal(a.boss_hp, before - 3, "урон оружия")
end

M["player move passes the turn to the boss"] = function(t)
	local a = new_fight(20, 20)
	local ok = arena.player_move(a, 3)
	t.true_(ok, "ход прошёл")
	t.equal(a.player_x, 3, "игрок сдвинулся")
	local ev = arena.boss_turn(a)
	t.equal(a.turn, "player", "после хода босса снова игрок")
	t.true_(#ev >= 1, "есть события хода босса")
end

M["player cannot move more than one column"] = function(t)
	local a = new_fight(20, 20)
	t.true_(not arena.player_move(a, 4), "через колонку нельзя")
end

M["heal cell restores hp and is consumed"] = function(t)
	local a = new_fight(10, 20)
	a.player_row[3] = { type = "HEAL" }
	arena.player_move(a, 3)
	t.equal(a.player_hp, 10 + balance.cells.HEAL.amount, "лечение")
	t.equal(a.player_row[3].type, "EMPTY", "клетка опустела")
end

M["heal never exceeds max hp"] = function(t)
	local a = new_fight(19, 20)
	a.player_row[3] = { type = "HEAL" }
	arena.player_move(a, 3)
	t.equal(a.player_hp, 20, "не выше максимума")
end

M["attack cell on the player row hits the boss and passes the turn"] = function(t)
	local a = new_fight(20, 20)
	a.player_row[3] = { type = "ATTACK_CELL", damage = 7 }
	local before = a.boss_hp
	arena.player_move(a, 3)
	t.equal(a.boss_hp, before - 7, "урон боссу клеткой")
end

M["boss profile follows hp fraction"] = function(t)
	t.equal(arena.profile(100, 100), "aggressive", ">60%")
	t.equal(arena.profile(50, 100), "balanced", "25-60%")
	t.equal(arena.profile(20, 100), "defensive", "<=25%")
end

M["boss does not return to its previous column when it has alternatives"] = function(t)
	local a = new_fight(20, 20)
	a.boss_x = 2
	a.prev_boss_x = 1
	local moves = arena.boss_moves(a)
	for _, x in ipairs(moves) do
		t.true_(x ~= 1, "предыдущая колонка исключена")
	end
end

M["boss turn stays inside the board"] = function(t)
	local a = new_fight(20, 20)
	a.boss_x = 0
	for _, x in ipairs(arena.boss_moves(a)) do
		t.true_(x >= 0 and x < COLUMNS, "колонка в поле")
	end
end

M["boss hits the player when it steps onto an attack cell in the player column"] = function(t)
	local a = new_fight(20, 20)
	a.player_x = 2
	a.boss_x = 1
	a.prev_boss_x = nil
	for x = 0, COLUMNS - 1 do
		a.boss_row[x] = { type = "EMPTY" }
	end
	-- клетка атаки только в колонке игрока; босс идёт на неё из колонки 1
	a.boss_row[2] = { type = "ATTACK_CELL", damage = 5 }
	-- форсируем выбор: в колонке 2 атака, соседние пусты
	local orig = arena.boss_choose
	arena.boss_choose = function() return 2 end
	local ev = arena.boss_turn(a)
	arena.boss_choose = orig
	local hit = false
	for _, e in ipairs(ev) do
		if e.type == "boss_attack" then
			hit = true
			t.equal(e.damage, 5, "урон клетки атаки")
		end
	end
	t.true_(hit, "босс ударил игрока")
	t.equal(a.player_hp, 15, "HP игрока уменьшился")
end

M["result: victory when boss hp is zero, defeat when player hp is zero"] = function(t)
	local a = new_fight(20, 20)
	a.boss_hp = 0
	t.equal(arena.result(a), "victory", "победа")
	local b = new_fight(20, 20)
	b.player_hp = 0
	t.equal(arena.result(b), "defeat", "поражение")
	local c = new_fight(20, 20)
	t.equal(arena.result(c), nil, "бой продолжается")
end

return M
