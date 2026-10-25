local highlight = require("core.highlight")
local equipment = require("core.equipment")
local balance = require("core.data.balance")
local design = require("core.data.design")

local M = {}

local COLUMNS = balance.board.columns

local function empty_row()
	local r = {}
	for x = 0, COLUMNS - 1 do
		r[x] = { type = "EMPTY" }
	end
	return r
end

M["free step is a step, a jump is a jump, an enemy is not outlined"] = function(t)
	local above = empty_row()
	above[2] = { type = "EMPTY" }
	above[4] = { type = "GOLD" }
	above[1] = { type = "ENEMY", enemy = "TYPE_1" }
	local kinds = {}
	for _, m in ipairs(highlight.moves({ x = 2, y = 0 }, 20, above)) do
		kinds[m.x] = m.kind
	end
	t.equal(kinds[2], "step", "прямо вверх — шаг")
	t.equal(kinds[1], nil, "клетку врага не обводим — у карты врага своя рамка")
	t.equal(kinds[3], "step", "пустая колонка рядом — шаг")
end

M["a two-column jump is highlighted as a jump"] = function(t)
	local above = empty_row()
	local kinds = {}
	for _, m in ipairs(highlight.moves({ x = 0, y = 0 }, 20, above)) do
		kinds[m.x] = m.kind
	end
	t.equal(kinds[1], "step", "соседняя — шаг")
	t.equal(kinds[2], "jump", "через колонку — прыжок")
end

M["walls and unaffordable moves are not highlighted"] = function(t)
	local above = empty_row()
	above[2] = { type = "WALL" }
	for _, m in ipairs(highlight.moves({ x = 2, y = 0 }, 20, above)) do
		t.true_(m.x ~= 2, "стена не подсвечивается")
	end
	-- при HP 1 прыжок на 2 колонки недоступен
	for _, m in ipairs(highlight.moves({ x = 0, y = 0 }, 1, empty_row())) do
		t.true_(m.x ~= 2, "недоступный прыжок не подсвечивается")
	end
end

M["shot target is listed when charged, in range and in clear line"] = function(t)
	local row = empty_row()
	row[3] = { type = "ENEMY", enemy = "TYPE_2" }
	local targets = highlight.shot_targets({ x = 0, y = 5 }, row, equipment.new(3, 5), 3)
	t.equal(#targets, 1, "одна цель")
	t.equal(targets[1], 3, "колонка цели")
end

M["no shot line when a wall blocks the target"] = function(t)
	local row = empty_row()
	row[1] = { type = "WALL" }
	row[2] = { type = "ENEMY", enemy = "TYPE_2" }
	t.equal(#highlight.shot_targets({ x = 0, y = 5 }, row, equipment.new(3, 5), 3), 0, "стена перекрывает")
end

M["no shot line beyond range"] = function(t)
	local row = empty_row()
	row[4] = { type = "ENEMY", enemy = "TYPE_2" }
	t.equal(#highlight.shot_targets({ x = 0, y = 5 }, row, equipment.new(3, 5), 3), 0, "дальше 3 клеток")
end

M["no shot line without charges or after firing this row"] = function(t)
	local row = empty_row()
	row[2] = { type = "ENEMY", enemy = "TYPE_2" }
	local empty = equipment.new(1, 5)
	equipment.use(empty)
	t.equal(#highlight.shot_targets({ x = 0, y = 5 }, row, empty, 3), 0, "нет зарядов")
	local fired = equipment.new(3, 5)
	equipment.fire(fired)
	t.equal(#highlight.shot_targets({ x = 0, y = 5 }, row, fired, 3), 0, "уже стрелял на ряду")
end

M["every reachable enemy gets its own shot line"] = function(t)
	local row = empty_row()
	row[1] = { type = "ENEMY", enemy = "TYPE_1" }
	row[3] = { type = "ENEMY", enemy = "TYPE_1" }
	t.equal(#highlight.shot_targets({ x = 2, y = 5 }, row, equipment.new(3, 5), 3), 2, "две цели")
end

M["vision: enemy sees cells in range; wall is not marked and blocks beyond it"] = function(t)
	local row = empty_row()
	row[0] = { type = "ENEMY", enemy = "TYPE_1" }
	row[2] = { type = "WALL" }
	local v = highlight.vision(row, 3)
	t.equal(v[1], 1, "соседняя клетка видна")
	t.equal(v[2], 0, "стена не подсвечивается")
	t.equal(v[3], 0, "за стеной не видно")
	t.equal(v[4], 0, "и дальний край за стеной не видно")
	t.equal(v[0], 0, "клетка самого врага не помечается")
end

M["vision: cells beyond vision range are not marked"] = function(t)
	local row = empty_row()
	row[0] = { type = "ENEMY", enemy = "TYPE_3" }
	local v = highlight.vision(row, 3)
	t.equal(v[1], 1, "WARDEN видит соседнюю колонку")
	t.equal(v[2], 0, "WARDEN не видит дальше соседней")
end

M["vision: range from csv marks cells up to the limit"] = function(t)
	local row = empty_row()
	row[0] = { type = "ENEMY", enemy = "TYPE_2" }
	local v = highlight.vision(row, 3)
	t.equal(v[1] + v[2], 2, "SPEARMAN видит две колонки")
	t.equal(v[3] + v[4], 0, "дальше дальности нет")
end

M["vision alpha stacks per enemy from design and caps at 100"] = function(t)
	local a = design.screen.threatAlpha
	t.equal(highlight.vision_alpha(0), nil, "угрозы нет")
	t.equal(highlight.vision_alpha(1), a, "один враг")
	t.equal(highlight.vision_alpha(2), a * 2, "два врага — 50%")
	t.equal(highlight.vision_alpha(9), 1, "не выше 100%")
end

M["spotted: true when an enemy sees the player cell"] = function(t)
	local row = empty_row()
	row[0] = { type = "ENEMY", enemy = "TYPE_2" }
	local v = highlight.vision(row, 3)
	t.true_(highlight.spotted(v, 2), "игрок в поле зрения")
	t.equal(highlight.spotted(v, 4), false, "вне поля зрения")
	row[1] = { type = "WALL" }
	local blocked = highlight.vision(row, 3)
	t.equal(highlight.spotted(blocked, 2), false, "стена перекрывает игрока")
end

M["dash points are evenly spaced between the endpoints"] = function(t)
	local pts = highlight.dash_points(0, 0, 100, 0, 20)
	t.equal(#pts, 4, "точки между концами")
	t.equal(pts[1].x, 20, "первая точка")
	t.equal(pts[4].x, 80, "последняя точка")
end

M["arena moves: adjacent is step, far is jump, an attack cell is outlined as a move"] = function(t)
	local a = { turn = "player", player_x = 2, player_hp = 20, player_row = {}, boss_x = 2, fired = false }
	for x = 0, COLUMNS - 1 do
		a.player_row[x] = { type = "EMPTY" }
	end
	a.player_row[3] = { type = "ATTACK_CELL", damage = 5 }
	a.player_row[0] = { type = "ATTACK_CELL", damage = 5 }
	local byx = {}
	for _, m in ipairs(highlight.arena_moves(a)) do
		byx[m.x] = m.kind
	end
	t.equal(byx[1], "step", "сосед слева — шаг")
	t.equal(byx[3], "step", "клетка атаки рядом — шаг: снаружи только перемещение")
	t.equal(byx[0], "jump", "клетка атаки через колонку — прыжок")
	t.equal(byx[4], "jump", "правый край — прыжок")
	t.equal(byx[2], nil, "своя клетка не подсвечивается")
end

M["arena: unaffordable jumps are not highlighted"] = function(t)
	local a = { turn = "player", player_x = 0, player_hp = 1, player_row = {}, boss_x = 0, fired = false }
	for x = 0, COLUMNS - 1 do
		a.player_row[x] = { type = "EMPTY" }
	end
	local byx = {}
	for _, m in ipairs(highlight.arena_moves(a)) do
		byx[m.x] = m.kind
	end
	t.equal(byx[1], "step", "соседняя доступна")
	t.equal(byx[2], nil, "прыжок за 1 HP из HP 1 не подсвечивается")
end

M["arena shot highlight only when the boss is in range and the turn is the player's"] = function(t)
	local a = { turn = "player", player_x = 2, boss_x = 4, fired = false }
	t.equal(highlight.arena_shot(a, equipment.new(3, 5), 3), 4, "в дальности")
	a.boss_x = 0
	t.equal(highlight.arena_shot(a, equipment.new(3, 5), 1), nil, "вне дальности")
	a.boss_x = 2
	a.turn = "boss"
	t.equal(highlight.arena_shot(a, equipment.new(3, 5), 3), nil, "ход босса")
	a.turn = "player"
	local row_fired = equipment.new(3, 5)
	equipment.fire(row_fired)
	t.equal(highlight.arena_shot(a, row_fired, 3), 2, "флаг ряда не глушит выстрел в арене")
end

return M
