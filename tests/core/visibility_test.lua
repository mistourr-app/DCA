local visibility = require("core.visibility")

local M = {}

local ROW = { range = 4, shape = "row" }
local SIDES = { range = 1, shape = "sides" }

M["enemy sees player on same row within range"] = function(t)
	t.true_(visibility.can_see({ x = 0, y = 5 }, { x = 3, y = 5 }, ROW), "в пределах")
end

M["enemy does not see beyond range"] = function(t)
	t.true_(not visibility.can_see({ x = 0, y = 5 }, { x = 4, y = 5 }, { range = 3, shape = "row" }),
		"дальше обзора")
end

M["enemy does not see other rows"] = function(t)
	t.true_(not visibility.can_see({ x = 0, y = 5 }, { x = 1, y = 6 }, ROW), "другой ряд")
	t.true_(not visibility.can_see({ x = 0, y = 5 }, { x = 1, y = 4 }, ROW), "ряд ниже")
end

M["wall between enemy and player blocks sight"] = function(t)
	local wall = function(x, y) return x == 1 and y == 5 end
	t.true_(not visibility.can_see({ x = 0, y = 5 }, { x = 3, y = 5 }, ROW, wall), "стена блокирует")
end

M["wall outside the line does not block"] = function(t)
	local wall = function(x, y) return x == 4 and y == 5 end
	t.true_(visibility.can_see({ x = 0, y = 5 }, { x = 3, y = 5 }, ROW, wall), "стена сбоку")
end

M["warden sees only adjacent cells on its row"] = function(t)
	t.true_(visibility.can_see({ x = 2, y = 0 }, { x = 1, y = 0 }, SIDES), "слева")
	t.true_(visibility.can_see({ x = 2, y = 0 }, { x = 3, y = 0 }, SIDES), "справа")
	t.true_(not visibility.can_see({ x = 2, y = 0 }, { x = 4, y = 0 }, SIDES), "через клетку")
end

M["zero distance is never visible"] = function(t)
	t.true_(not visibility.can_see({ x = 2, y = 0 }, { x = 2, y = 0 }, ROW), "та же клетка")
end

return M
