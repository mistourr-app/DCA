local layout = require("core.layout")
local balance = require("core.data.balance")

local M = {}

M["visible rows come from balance and are four"] = function(t)
	t.equal(layout.VISIBLE_ROWS, 4, "игрок и три ряда над ним")
	t.equal(balance.layout.visibleRows, 4, "значение в CSV")
end

M["cells fit five columns in the logical width"] = function(t)
	t.equal(layout.CELL_W, 144, "720 / 5")
	t.true_(layout.CELL_W * layout.COLUMNS <= layout.WIDTH, "колонки помещаются")
end

M["four rows fit between the margins"] = function(t)
	local used = layout.CELL_H * layout.VISIBLE_ROWS
	t.true_(used <= layout.HEIGHT - layout.MARGIN_TOP - layout.MARGIN_BOTTOM, "ряды помещаются")
	t.true_(layout.CELL_H > layout.CELL_W, "клетка растянута по вертикали")
end

M["tap in the centre of a visible cell returns that cell"] = function(t)
	for x = 0, layout.COLUMNS - 1 do
		for k = 0, layout.VISIBLE_ROWS - 1 do
			local px, py = layout.cell_x(x), layout.row_y(k)
			local cx, cy = layout.cell_at(px, py, 3)
			t.equal(cx, x, "колонка по тапу")
			t.equal(cy, 3 + k, "ряд по тапу")
		end
	end
end

M["player row is the bottom visible row"] = function(t)
	t.equal(layout.cell_y(7, 7), layout.row_y(0), "ряд игрока внизу")
	t.true_(layout.cell_y(8, 7) > layout.cell_y(7, 7), "следующий ряд выше")
end

M["taps outside the field return nil"] = function(t)
	t.equal(layout.cell_at(-1, layout.row_y(0), 0), nil, "левее поля")
	t.equal(layout.cell_at(layout.WIDTH, layout.row_y(0), 0), nil, "правее поля")
	t.equal(layout.cell_at(10, 5, 0), nil, "под полем (кнопка)")
	t.equal(layout.cell_at(10, layout.HEIGHT - 5, 0), nil, "над полем (HUD)")
end

M["visible offsets are 0..three"] = function(t)
	local offs = layout.visible_offsets()
	t.equal(#offs, 4, "четыре ряда")
	t.equal(offs[1], 0, "первый — ряд игрока")
	t.equal(offs[4], 3, "последний — третий над игроком")
end

return M
