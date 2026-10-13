local grid = require("core.grid")

local M = {}

M["columns come from balance and are five"] = function(t)
	t.equal(grid.COLUMNS, 5, "5 колонок")
end

M["in_columns accepts 0..4 and rejects others"] = function(t)
	for x = 0, 4 do
		t.true_(grid.in_columns(x), "колонка " .. x)
	end
	t.true_(not grid.in_columns(-1), "-1 вне поля")
	t.true_(not grid.in_columns(5), "5 вне поля")
end

M["free step is one column sideways and one row up"] = function(t)
	t.true_(grid.is_free_step({ x = 2, y = 3 }, { x = 1, y = 4 }), "диагональ")
	t.true_(grid.is_free_step({ x = 2, y = 3 }, { x = 2, y = 4 }), "прямо")
	t.true_(not grid.is_free_step({ x = 2, y = 3 }, { x = 2, y = 3 }), "на месте")
	t.true_(not grid.is_free_step({ x = 2, y = 3 }, { x = 2, y = 2 }), "назад")
	t.true_(not grid.is_free_step({ x = 0, y = 3 }, { x = 2, y = 4 }), "больше чем на колонку")
end

M["jump cost is max(0, |dx|-1)"] = function(t)
	t.equal(grid.jump_cost({ x = 0, y = 0 }, { x = 0, y = 1 }), 0, "dx 0")
	t.equal(grid.jump_cost({ x = 0, y = 0 }, { x = 1, y = 1 }), 0, "dx 1")
	t.equal(grid.jump_cost({ x = 0, y = 0 }, { x = 2, y = 1 }), 1, "dx 2")
	t.equal(grid.jump_cost({ x = 0, y = 0 }, { x = 4, y = 1 }), 3, "dx 4")
end

M["forward neighbours clipped at edges"] = function(t)
	t.equal(#grid.forward_neighbors({ x = 2, y = 0 }), 3, "центр: три клетки")
	t.equal(#grid.forward_neighbors({ x = 0, y = 0 }), 2, "левый край: две клетки")
	t.equal(#grid.forward_neighbors({ x = 4, y = 0 }), 2, "правый край: две клетки")
end

M["forward neighbours are on the next row"] = function(t)
	for _, c in ipairs(grid.forward_neighbors({ x = 1, y = 9 })) do
		t.equal(c.y, 10, "следующий ряд")
	end
end

M["column distance is symmetric"] = function(t)
	t.equal(grid.column_distance({ x = 1, y = 0 }, { x = 4, y = 7 }), 3, "расстояние")
	t.equal(grid.column_distance({ x = 4, y = 0 }, { x = 1, y = 7 }), 3, "симметрия")
end

return M
