-- Тест памяти (docs/TESTING.md §5, GDD §11.3): объём хранимого не растёт с номером ряда
-- при регулярных точках возврата.

local balance = require("core.data.balance")
local world = require("core.world")
local journal = require("core.journal")
local row_gen = require("core.row_gen")

local M = {}

local PERIOD = balance.boss.period
local W = balance.memory.W
local ROWS = 2000

-- Идёт вверх на ROWS рядов. На каждом обычном ряду игрок подбирает клетку и убивает врага
-- (два изменения), на каждом checkpoint точка возврата обновляется и журнал обрезается.
local function t_ok(ok, msg)
	assert(ok, msg)
end

local function climb(rows)
	local w = world.new(7)
	local j = journal.new(0)
	local max_entries = 0
	local max_window = 0
	local max_rows_since_return = 0

	for y = 1, rows do
		t_ok(world.move(w, { x = w.pos.x, y = y }), "подъём на ряд " .. y)
		local kind = row_gen.kind(y)
		if kind == "normal" then
			journal.record(j, y, w.pos.x, "pickup")
			journal.record(j, y, (w.pos.x + 1) % 5, "kill")
		end
		if kind == "checkpoint" then
			world.set_return_point(w, "checkpoint", y)
			journal.set_return_row(j, y)
		end
		max_entries = math.max(max_entries, journal.size(j))
		max_window = math.max(max_window, world.window_size(w))
		max_rows_since_return = math.max(max_rows_since_return, y - j.return_row)
	end
	return { entries = max_entries, window = max_window, span = max_rows_since_return }
end

M["journal size is bounded by rows since the last return point"] = function(t)
	local r = climb(ROWS)
	-- между двумя checkpoint не больше PERIOD рядов, по 2 записи на ряд
	t.true_(r.entries <= 2 * (PERIOD + 1), "журнал ограничен периодом: " .. r.entries)
	t.true_(r.span <= PERIOD + 1, "пролёт без точки возврата не больше периода: " .. r.span)
end

M["journal does not grow with depth"] = function(t)
	local short = climb(200)
	local long = climb(ROWS)
	t.true_(long.entries <= short.entries + 2 * PERIOD,
		string.format("журнал на 200 рядах %d, на %d рядах %d", short.entries, ROWS, long.entries))
end

M["window size stays bounded at any depth"] = function(t)
	local r = climb(ROWS)
	t.true_(r.window <= 2 * W + 1, "окно не больше 2W+1: " .. r.window)
end

return M
