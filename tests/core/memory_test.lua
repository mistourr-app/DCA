-- Тест памяти (docs/TESTING.md §5, GDD §11): хранится только окно рядов и ряды выше
-- последней точки возврата. Журнала нет: после возрождения эти ряды генерируются заново.

local balance = require("core.data.balance")
local world = require("core.world")
local row_gen = require("core.row_gen")

local M = {}

local PERIOD = balance.boss.period
local W = balance.memory.W
local ROWS = 2000

local function t_ok(ok, msg)
	assert(ok, msg)
end

-- Идёт вверх на ROWS рядов, на каждом checkpoint обновляет точку возврата.
-- Возвращает максимальный пролёт без точки возврата и максимальный размер окна.
local function climb(rows)
	local w = world.new(7, 0)
	local max_window = 0
	local max_span = 0
	for y = 1, rows do
		t_ok(world.move(w, { x = w.pos.x, y = y }), "подъём на ряд " .. y)
		if row_gen.kind(y) == "checkpoint" then
			world.set_return_point(w, "checkpoint", y)
		end
		max_window = math.max(max_window, world.window_size(w))
		max_span = math.max(max_span, y - w.return_point.row)
	end
	return { window = max_window, span = max_span }
end

M["rows since the last return point are bounded by the boss period"] = function(t)
	local r = climb(ROWS)
	t.true_(r.span <= PERIOD + 1, "пролёт без точки возврата не больше периода: " .. r.span)
end

M["window size stays bounded at any depth"] = function(t)
	local r = climb(ROWS)
	t.true_(r.window <= 2 * W + 1, "окно не больше 2W+1: " .. r.window)
end

M["respawn changes the rows above the return point, not the return point"] = function(t)
	-- Ряд выше точки возврата после возрождения даёт другой набор клеток.
	local before = row_gen.generate(99, 0, 1).cells
	local after = row_gen.generate(99, 1, 1).cells
	local differs = false
	for x = 0, balance.board.columns - 1 do
		if before[x].type ~= after[x].type then
			differs = true
		end
	end
	-- на одном ряду может совпасть; проверяем на нескольких рядах
	if not differs then
		for y = 2, 40 do
			local a = row_gen.generate(99, 0, y).cells
			local b = row_gen.generate(99, 1, y).cells
			for x = 0, balance.board.columns - 1 do
				if a[x].type ~= b[x].type then
					differs = true
				end
			end
		end
	end
	t.true_(differs, "после возрождения ряды выше точки возврата другие")
end

return M
