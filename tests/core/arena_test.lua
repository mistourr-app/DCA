local arena = require("core.arena")
local boss_ai = require("core.ai.boss_default")
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
	return arena.new(2, player_hp, player_max, boss_number or 1, pr, br, rng.new(7))
end

M["boss hp is player max hp times the configured multiplier"] = function(t)
	local expected = math.floor(20 * balance.boss.hpMultiplier.from)
	t.equal(arena.boss_max_hp(20, 1), expected, "первый босс")
	t.true_(arena.boss_max_hp(20, 2) > arena.boss_max_hp(20, 1), "второй босс сильнее")
end

M["both arena rows resolve to one arena bottom row"] = function(t)
	local bottom = balance.boss.period - balance.boss.arenaRows
	t.equal(arena.arena_bottom_for_row(bottom), bottom, "нижний ряд арены")
	t.equal(arena.arena_bottom_for_row(bottom + 1), bottom, "верхний ряд арены")
	t.equal(arena.arena_bottom_for_row(bottom - 1), nil, "обычный ряд перед ареной")
	t.equal(arena.arena_bottom_for_row(0), nil, "стартовый checkpoint")
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

M["one shot is allowed on every turn while charges remain"] = function(t)
	local a = new_fight(20, 20)
	local w = equipment.new(3, 5)
	t.true_(arena.shoot(a, w, 3, 3), "выстрел первого хода")
	t.equal(a.turn, "player", "выстрел ход не передаёт")
	t.true_(not arena.shoot(a, w, 3, 3), "второй выстрел в этом ходу запрещён")
	arena.boss_turn(a) -- ход возвращается к игроку
	t.true_(arena.shoot(a, w, 3, 3), "в новом ходу выстрел снова доступен")
	arena.boss_turn(a)
	t.true_(arena.shoot(a, w, 3, 3), "и в третьем")
	t.equal(w.charges, 0, "израсходованы все заряды")
	t.true_(equipment.is_recharging(w), "исчерпание запустило перезарядку")
	a.fired = false
	local ok = arena.shoot(a, w, 3, 3)
	t.true_(not ok, "без зарядов выстрела нет")
end

M["first arena turn allows a shot even if the crossbow fired on the previous row"] = function(t)
	local a = new_fight(20, 20)
	local w = equipment.new(3, 5)
	equipment.fire(w) -- флаг «уже стрелял на ряду» из мира не должен блокировать арену
	local ok = arena.shoot(a, w, 3, 3)
	t.true_(ok, "выстрел в первый ход боя")
	t.equal(a.boss_hp, a.boss_max - 3, "босс получил урон")
end

M["arena shots consume charges and exhaustion starts recharge"] = function(t)
	local a = new_fight(20, 20)
	local w = equipment.new(1, 5)
	t.true_(arena.shoot(a, w, 3, 3), "выстрел")
	t.equal(w.charges, 0, "заряды кончились")
	t.true_(equipment.is_recharging(w), "перезарядка запущена")
	a.fired = false
	local ok, reason = arena.shoot(a, w, 3, 3)
	t.true_(not ok, "во время перезарядки нельзя")
	t.true_(reason ~= nil, "есть причина")
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

M["adjacent move is free, a jump across columns costs HP"] = function(t)
	local a = new_fight(20, 20)
	local ok, events = arena.player_move(a, 4)
	t.true_(ok, "прыжок через колонку доступен")
	t.equal(a.player_x, 4, "игрок переместился")
	t.equal(a.turn, "boss", "ход передан боссу")
	local cost = math.abs(4 - 2) - 1
	t.equal(a.player_hp, 20 - cost, "прыжок стоит max(0, |dx| - 1) HP")
	local ev = events[1]
	t.equal(ev.type, "player_move", "событие хода")
	t.equal(ev.cost, cost, "стоимость в событии")
end

M["adjacent move costs nothing"] = function(t)
	local a = new_fight(20, 20)
	arena.player_move(a, 3)
	t.equal(a.player_hp, 20, "соседняя колонка бесплатна")
end

M["jump is refused when it would leave less than 1 HP"] = function(t)
	local a = new_fight(1, 20)
	local ok, reason = arena.player_move(a, 4)
	t.true_(not ok, "прыжок за 2 HP из HP 1 запрещён")
	t.true_(reason ~= nil, "есть причина")
	t.equal(a.player_x, 2, "позиция не изменилась")
end

M["same column move is refused"] = function(t)
	local a = new_fight(20, 20)
	t.true_(not arena.player_move(a, 2), "на свою клетку ходить нельзя")
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
	t.equal(boss_ai.profile(100, 100), "aggressive", ">60%")
	t.equal(boss_ai.profile(50, 100), "balanced", "25-60%")
	t.equal(boss_ai.profile(20, 100), "defensive", "<=25%")
end

M["boss does not return to its previous column when it has alternatives"] = function(t)
	local a = new_fight(20, 20)
	a.boss_x = 2
	a.prev_boss_x = 1
	local moves = boss_ai.moves(a)
	for _, x in ipairs(moves) do
		t.true_(x ~= 1, "предыдущая колонка исключена")
	end
end

M["boss turn stays inside the board"] = function(t)
	local a = new_fight(20, 20)
	a.boss_x = 0
	for _, x in ipairs(boss_ai.moves(a)) do
		t.true_(x >= 0 and x < COLUMNS, "колонка в поле")
	end
end

M["boss hits the player from an attack cell in any column"] = function(t)
	local a = new_fight(20, 20)
	a.player_x = 0
	a.boss_x = 1
	a.prev_boss_x = nil
	for x = 0, COLUMNS - 1 do
		a.boss_row[x] = { type = "EMPTY" }
	end
	-- клетка атаки в колонке 2, игрок в колонке 0: босс бьёт без совпадения колонок
	a.boss_row[2] = { type = "ATTACK_CELL", damage = 5 }
	local orig = boss_ai.choose
	boss_ai.choose = function() return 2 end
	local ev = arena.boss_turn(a)
	boss_ai.choose = orig
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

M["heal is consumed on entry and the cell is rerolled when the player leaves"] = function(t)
	local a = new_fight(20, 20)
	a.player_row[3] = { type = "HEAL" }
	arena.player_move(a, 3)
	t.equal(a.player_hp, 20, "лечение при полном HP ограничено максимумом")
	t.equal(a.player_row[3].type, "EMPTY", "под игроком клетка пуста")
	local old3 = a.player_row[3]
	a.turn = "player"
	arena.player_move(a, 1)
	local valid = { EMPTY = true, HEAL = true, ATTACK_CELL = true }
	t.true_(a.player_row[3] ~= old3, "клетка 3 пересоздана при уходе")
	t.true_(valid[a.player_row[3].type] ~= nil, "тип после ресолла валиден")
end

M["leaving an empty cell also rerolls it"] = function(t)
	local a = new_fight(20, 20)
	local old2 = a.player_row[2]
	arena.player_move(a, 3)
	t.true_(a.player_row[2] ~= old2, "уход с пустой клетки перекатывает её")
	t.equal(a.player_row[3].type, "EMPTY", "встали на пустую — переката под ногами нет")
end

M["player attack cell is consumed and rerolled after leaving"] = function(t)
	local a = new_fight(20, 20)
	a.player_row[4] = { type = "ATTACK_CELL", damage = 7 }
	local before = a.boss_hp
	arena.player_move(a, 4)
	t.equal(a.boss_hp, before - 7, "урон боссу клеткой")
	t.equal(a.player_row[4].type, "EMPTY", "клетка пуста под игроком")
	a.turn = "player"
	local prev = a.player_row[4]
	arena.player_move(a, 3)
	t.true_(a.player_row[4] ~= prev, "ресолл при уходе")
end

M["reroll of the player row can bring attack cells and heals again"] = function(t)
	local a = new_fight(20, 20)
	a.gen = rng.new(21)
	local kinds = {}
	for _ = 1, 50 do
		local c = arena.reroll_player_cell(a)
		local valid = { EMPTY = true, HEAL = true, ATTACK_CELL = true }
		t.true_(valid[c.type] ~= nil, "валидный тип")
		if c.type == "ATTACK_CELL" then
			t.true_(c.damage >= balance.cells.ATTACK_CELL.damageMin and c.damage <= balance.cells.ATTACK_CELL.damageMax, "урон в диапазоне")
		end
		kinds[c.type] = true
	end
	t.true_(kinds.ATTACK_CELL, "клетки атаки возвращаются")
	t.true_(kinds.HEAL, "лечение возвращается")
end

M["reroll of the boss row never brings heals"] = function(t)
	local a = new_fight(20, 20)
	a.gen = rng.new(5)
	local saw_attack = false
	for _ = 1, 50 do
		local c = arena.reroll_boss_cell(a)
		t.true_(c.type == "EMPTY" or c.type == "ATTACK_CELL", "босс: только атака или пусто")
		if c.type == "ATTACK_CELL" then
			saw_attack = true
		end
	end
	t.true_(saw_attack, "атака появляется")
end

M["boss attack cell is consumed on hit and rerolled when the boss leaves"] = function(t)
	local a = new_fight(20, 20)
	a.boss_x = 1
	a.prev_boss_x = nil
	for x = 0, COLUMNS - 1 do
		a.boss_row[x] = { type = "EMPTY" }
	end
	a.boss_row[2] = { type = "ATTACK_CELL", damage = 5 }
	local old1 = a.boss_row[1]
	local orig = boss_ai.choose
	boss_ai.choose = function() return 2 end
	arena.boss_turn(a)
	t.equal(a.player_hp, 15, "босс ударил")
	t.equal(a.boss_row[2].type, "EMPTY", "клетка атаки пуста под боссом")
	t.true_(a.boss_row[1] ~= old1, "клетка, с которой ушёл босс, пересоздана")
	boss_ai.choose = function() return 3 end
	a.boss_row[3] = { type = "EMPTY" }
	local old2 = a.boss_row[2]
	arena.boss_turn(a)
	boss_ai.choose = orig
	t.true_(a.boss_row[2] ~= old2, "ресолл при уходе босса")
	t.true_(a.boss_row[2].type == "EMPTY" or a.boss_row[2].type == "ATTACK_CELL", "босс: только атака или пусто")
end

M["player cell is not rerolled while the player stands on it"] = function(t)
	local a = new_fight(20, 20)
	a.player_row[3] = { type = "HEAL" }
	arena.player_move(a, 3)
	local collected = a.player_row[3]
	-- ход босса не трогает ряд игрока
	a.boss_row[1] = { type = "EMPTY" }
	a.boss_x = 1
	a.prev_boss_x = nil
	arena.boss_turn(a)
	t.equal(a.player_row[3], collected, "клетка ждёт ухода игрока")
end

return M
