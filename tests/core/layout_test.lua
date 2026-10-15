local layout = require("core.layout")
local balance = require("core.data.balance")
local design = require("core.data.design")
local row_gen = require("core.row_gen")

local M = {}

local PERIOD = balance.boss.period
local ARENA_ROWS = balance.boss.arenaRows

M["visible rows come from balance and are four"] = function(t)
	t.equal(layout.VISIBLE_ROWS, 4, "игрок и три ряда над ним")
	t.equal(design.screen.visibleRows, 4, "значение в CSV")
end

M["cells fit five columns in the logical width"] = function(t)
	t.equal(layout.CELL_W, 144, "720 / 5")
	t.true_(layout.CELL_W * layout.COLUMNS <= layout.WIDTH, "колонки помещаются")
end

M["four normal rows fit between the margins"] = function(t)
	local used = layout.CELL_H * layout.VISIBLE_ROWS
	t.equal(used, layout.FIELD_H, "поле ровно на четыре обычных ряда")
	t.true_(used <= layout.HEIGHT - layout.MARGIN_TOP, "ряды помещаются")
end

M["arena row is exactly twice a normal row"] = function(t)
	t.equal(layout.ARENA_H, layout.CELL_H * 2, "высота ряда арены вдвое больше обычной")
	t.equal(layout.ARENA_H, layout.CELL_H * layout.ARENA_SCALE, "коэффициент из design.csv")
end

M["row height follows the row kind"] = function(t)
	for y = 0, 2 * PERIOD + 2 do
		local expected = row_gen.kind(y) == "boss" and layout.ARENA_H or layout.CELL_H
		t.equal(layout.row_height(y), expected, "высота ряда " .. y)
	end
end

M["world_bottom is a sum of row heights"] = function(t)
	t.equal(layout.world_bottom(0), 0, "нулевой ряд начинается с нуля")
	for y = 0, 3 * PERIOD + 3 do
		t.equal(layout.world_bottom(y + 1) - layout.world_bottom(y), layout.row_height(y),
			"ряд " .. y .. ": высота учтена")
	end
end

M["world_center is between bottom and top of its row"] = function(t)
	for y = 0, PERIOD + 1 do
		local bottom = layout.world_bottom(y)
		local c = layout.world_center(y)
		t.equal(c, bottom + layout.row_height(y) / 2, "центр ряда " .. y)
	end
end

M["container anchors the player row at the field bottom"] = function(t)
	for _, pr in ipairs({ 0, 3, PERIOD - ARENA_ROWS, PERIOD + 1 }) do
		t.equal(layout.screen_center(pr, pr), layout.MARGIN_BOTTOM + layout.row_height(pr) / 2,
			"ряд игрока прижат к нижнему краю, player_row=" .. pr)
		t.equal(layout.container_y(pr), layout.MARGIN_BOTTOM - layout.world_bottom(pr), "смещение контейнера")
	end
end

M["four normal rows are visible when the pitch is uniform"] = function(t)
	local rows = layout.visible_rows(0)
	t.equal(#rows, 4, "четыре ряда")
	t.equal(rows[1], 0, "первый — ряд игрока")
	t.equal(rows[4], 3, "последний — третий над игроком")
end

M["two arena rows fill the field exactly"] = function(t)
	local arena_bottom = PERIOD - ARENA_ROWS
	local rows = layout.visible_rows(arena_bottom)
	t.equal(#rows, 2, "в бою видны ровно два ряда арены")
	t.equal(rows[1], arena_bottom, "нижний — ряд игрока на арене")
	t.equal(rows[2], arena_bottom + 1, "верхний — ряд босса")
end

M["arena seen partially from the row below"] = function(t)
	local arena_bottom = PERIOD - ARENA_ROWS
	local rows = layout.visible_rows(arena_bottom - 1)
	t.equal(#rows, 3, "обычный ряд и два ряда арены (верхний частично)")
	t.equal(rows[3], arena_bottom + 1, "ряд босса виден сверху частично")
end

M["tap in the centre of a visible cell returns that cell"] = function(t)
	for _, y in ipairs(layout.visible_rows(3)) do
		for x = 0, layout.COLUMNS - 1 do
			local px, py = layout.cell_x(x), layout.screen_center(y, 3)
			local cx, cy = layout.cell_at(px, py, 3)
			t.equal(cx, x, "колонка по тапу")
			t.equal(cy, y, "ряд по тапу")
		end
	end
end

M["tap between normal and tall rows resolves correctly"] = function(t)
	local pr = PERIOD - ARENA_ROWS - 1
	-- границы: pr занимает CELL_H, пр+1 — ARENA_H, pr+2 начинается внутри поля
	local _, r0 = layout.cell_at(10, layout.MARGIN_BOTTOM + 1, pr)
	t.equal(r0, pr, "низ поля — ряд игрока")
	local _, r1 = layout.cell_at(10, layout.MARGIN_BOTTOM + layout.CELL_H + 1, pr)
	t.equal(r1, pr + 1, "первый высокий ряд")
	local _, r2 = layout.cell_at(10, layout.MARGIN_BOTTOM + layout.CELL_H + layout.ARENA_H + 1, pr)
	t.equal(r2, pr + 2, "второй высокий ряд (частично видимый)")
end

M["taps outside the field return nil"] = function(t)
	t.equal(layout.cell_at(-1, layout.MARGIN_BOTTOM + 10, 0), nil, "левее поля")
	t.equal(layout.cell_at(layout.WIDTH, layout.MARGIN_BOTTOM + 10, 0), nil, "правее поля")
	t.equal(layout.cell_at(10, 5, 0), nil, "под полем (кнопка)")
	t.equal(layout.cell_at(10, layout.HEIGHT - 5, 0), nil, "над полем (HUD)")
end

return M
