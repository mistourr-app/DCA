local layout = require("core.layout")

local M = {}

M["cell size fits five columns in the logical width"] = function(t)
	t.equal(layout.CELL, 144, "720 / 5")
	t.true_(layout.CELL * layout.COLUMNS <= layout.WIDTH, "колонки помещаются")
end

M["tap in the centre of a cell returns that cell"] = function(t)
	for x = 0, layout.COLUMNS - 1 do
		for row = 2, 4 do
			local px, py = layout.cell_x(x), layout.cell_y(row, 3)
			local cx, cy = layout.cell_at(px, py, 3)
			t.equal(cx, x, "колонка по тапу")
			t.equal(cy, row, "ряд по тапу")
		end
	end
end

M["player row is at PLAYER_Y"] = function(t)
	t.equal(layout.cell_y(7, 7), layout.PLAYER_Y, "ряд игрока на фиксированной высоте")
end

M["taps outside the horizontal bounds return nil"] = function(t)
	t.equal(layout.cell_at(-1, layout.PLAYER_Y, 0), nil, "левее поля")
	t.equal(layout.cell_at(layout.WIDTH, layout.PLAYER_Y, 0), nil, "правее поля")
end

M["rows above and below cover the screen"] = function(t)
	t.true_(layout.rows_below() >= 1, "есть ряды ниже игрока")
	t.true_(layout.rows_above() * layout.CELL >= layout.HEIGHT - layout.PLAYER_Y, "ряды выше покрывают экран")
end

return M
