local movement = require("core.movement")

local M = {}

local function full_row(fill)
	local r = {}
	for x = 0, 4 do
		r[x] = { type = fill }
	end
	return r
end

M["free step costs no hp"] = function(t)
	local hp, pos = movement.step({ x = 2, y = 0 }, 10, { [2] = { type = "EMPTY" } }, 2, 1)
	t.equal(hp, 10, "прямо вверх бесплатно")
	t.equal(pos.y, 1, "ряд 1")
end

M["jump costs hp equal to max(0, |dx|-1)"] = function(t)
	local hp = movement.step({ x = 0, y = 0 }, 10, { [2] = { type = "EMPTY" } }, 2, 1)
	t.equal(hp, 9, "dx 2 стоит 1 HP")
	local hp2 = movement.step({ x = 0, y = 0 }, 10, { [4] = { type = "EMPTY" } }, 4, 1)
	t.equal(hp2, 7, "dx 4 стоит 3 HP")
end

M["cannot move onto a wall"] = function(t)
	local res = movement.step({ x = 2, y = 0 }, 10, { [2] = { type = "WALL" } }, 2, 1)
	t.equal(res, nil, "стена недоступна")
end

M["cannot move if the cost would kill the player"] = function(t)
	-- dx 2 стоит 1 HP; при HP 1 после хода было бы 0 — ход запрещён
	local res = movement.step({ x = 0, y = 0 }, 1, { [2] = { type = "EMPTY" } }, 2, 1)
	t.equal(res, nil, "при HP 1 прыжок на 2 запрещён")
end

M["player with exactly enough hp can still move"] = function(t)
	local hp = movement.step({ x = 0, y = 0 }, 2, { [2] = { type = "EMPTY" } }, 2, 1)
	t.equal(hp, 1, "остаётся 1 HP")
end

M["stuck when every cell of the next row is a wall"] = function(t)
	t.true_(movement.is_stuck({ x = 1, y = 5 }, 20, full_row("WALL")), "заперт между стенами")
end

M["stuck when the only open cells cost more hp than the player has"] = function(t)
	-- игрок на колонке 0 с HP 1: соседняя колонка 1 стоит 0 HP — доступна;
	-- остальные колонки стоят больше, чем HP-1 — поэтому в целом ход есть.
	-- Для полной блокировки стены на колонке 0 и 1, а HP 1: колонка 2 стоит 1 HP — ход запрещён.
	local r = { [0] = { type = "WALL" }, [1] = { type = "WALL" } }
	r[2] = { type = "EMPTY" }
	r[3] = { type = "EMPTY" }
	r[4] = { type = "EMPTY" }
	t.true_(movement.is_stuck({ x = 0, y = 5 }, 1, r), "HP 1: все цели стоят не меньше 1 HP")
end

M["not stuck when a free neighbour exists"] = function(t)
	local r = full_row("WALL")
	r[1] = { type = "EMPTY" }
	t.true_(not movement.is_stuck({ x = 0, y = 5 }, 5, r), "есть свободная клетка")
end

M["empty row above (nil) is never stuck with hp"] = function(t)
	t.true_(not movement.is_stuck({ x = 2, y = 5 }, 5, nil), "пустой ряд — ход есть")
end

M["enemy cell is a legal melee target when hp allows"] = function(t)
	local r = { [2] = { type = "ENEMY", enemy = "TYPE_1" } }
	local opts = movement.options({ x = 2, y = 0 }, 5, r)
	local enemy_targets = 0
	for _, o in ipairs(opts) do
		if o.cell_type == "ENEMY" then
			enemy_targets = enemy_targets + 1
		end
	end
	t.equal(enemy_targets, 1, "враг — допустимая цель ближнего боя")
end

M["step to an unaffordable target is refused"] = function(t)
	local res = movement.step({ x = 0, y = 0 }, 2, {}, 4, 1)
	t.equal(res, nil, "dx 4 стоит 3 HP, при HP 2 запрещено")
end

return M
