local highlight = require("core.highlight")
local equipment = require("core.equipment")
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

M["free step is a step, a jump is a jump, an enemy is an attack"] = function(t)
	local above = empty_row()
	above[2] = { type = "EMPTY" }
	above[4] = { type = "GOLD" }
	above[1] = { type = "ENEMY", enemy = "TYPE_1" }
	local kinds = {}
	for _, m in ipairs(highlight.moves({ x = 2, y = 0 }, 20, above)) do
		kinds[m.x] = m.kind
	end
	t.equal(kinds[2], "step", "прямо вверх — шаг")
	t.equal(kinds[1], "attack", "враг на соседней колонке — атака")
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

M["threat: enemy sees cells in its vision range, walls make idle"] = function(t)
	local row = empty_row()
	row[0] = { type = "ENEMY", enemy = "TYPE_1" }
	row[2] = { type = "WALL" }
	local th = highlight.threat(row, 3)
	t.equal(th[1].alert, 1, "соседняя клетка видна")
	t.equal(th[1].idle, 0, "видна — не idle")
	t.equal(th[3].alert, 0, "за стеной не видна")
	t.equal(th[3].idle, 1, "за стеной — idle (в зоне обзора)")
	t.equal(th[4].idle, 1, "дальний край обзора (4 клетки) за стеной — idle")
end

M["threat: cells beyond vision range are not threatened"] = function(t)
	local row = empty_row()
	row[0] = { type = "ENEMY", enemy = "TYPE_3" }
	local th = highlight.threat(row, 3)
	t.equal(th[1].alert, 1, "WARDEN видит соседнюю колонку")
	t.equal(th[2].alert + th[2].idle, 0, "WARDEN не видит дальше соседней")
end

M["threat style alpha is 25 percent per enemy, capped at 100"] = function(t)
	local kind, a = highlight.threat_style({ alert = 2, idle = 0 })
	t.equal(kind, "alert", "красный")
	t.equal(a, 0.5, "два врага — 50%")
	local _, cap = highlight.threat_style({ alert = 9, idle = 0 })
	t.equal(cap, 1, "не выше 100%")
	local k2 = highlight.threat_style({ alert = 0, idle = 1 })
	t.equal(k2, "idle", "оранжевый")
	t.equal(select(1, highlight.threat_style({ alert = 0, idle = 0 })), nil, "угрозы нет")
end

M["dash points are evenly spaced between the endpoints"] = function(t)
	local pts = highlight.dash_points(0, 0, 100, 0, 20)
	t.equal(#pts, 4, "точки между концами")
	t.equal(pts[1].x, 20, "первая точка")
	t.equal(pts[4].x, 80, "последняя точка")
end

M["arena moves: adjacent columns only, attack cell marked"] = function(t)
	local a = { turn = "player", player_x = 2, player_row = {}, boss_x = 2, fired = false }
	for x = 0, COLUMNS - 1 do
		a.player_row[x] = { type = "EMPTY" }
	end
	a.player_row[3] = { type = "ATTACK_CELL", damage = 5 }
	local byx = {}
	for _, m in ipairs(highlight.arena_moves(a)) do
		byx[m.x] = m.kind
	end
	t.equal(byx[1], "step", "влево — шаг")
	t.equal(byx[3], "attack", "вправо — клетка атаки")
	t.equal(byx[4], nil, "дальше соседней не подсвечивается")
end

M["arena shot highlight only when the boss is in range and the turn is the player's"] = function(t)
	local a = { turn = "player", player_x = 2, boss_x = 4, fired = false }
	t.equal(highlight.arena_shot(a, equipment.new(3, 5), 3), 4, "в дальности")
	a.boss_x = 0
	t.equal(highlight.arena_shot(a, equipment.new(3, 5), 1), nil, "вне дальности")
	a.boss_x = 2
	a.turn = "boss"
	t.equal(highlight.arena_shot(a, equipment.new(3, 5), 3), nil, "ход босса")
end

return M
