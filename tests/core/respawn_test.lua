-- Возрождение (GDD §10, §11): позиции рядов и боссов фиксированы, содержимое меняется.
local row_gen = require("core.row_gen")
local balance = require("core.data.balance")

local M = {}

local COLUMNS = balance.board.columns
local PERIOD = balance.boss.period

M["row kinds do not change after respawn"] = function(t)
	for y = 0, PERIOD * 10 do
		t.equal(row_gen.kind(y), row_gen.kind(y), "тип ряда детерминирован " .. y)
	end
	-- kind зависит только от номера ряда, не от seed и счётчика возрождений
	t.equal(row_gen.generate(5, 0, PERIOD).kind, "checkpoint", "checkpoint на месте")
	t.equal(row_gen.generate(5, 7, PERIOD).kind, "checkpoint", "checkpoint на месте после возрождений")
	t.equal(row_gen.generate(5, 7, PERIOD - 1).kind, "boss", "арена на месте после возрождений")
end

M["normal rows change content after respawn"] = function(t)
	local changed = 0
	for y = 1, 60 do
		if row_gen.kind(y) == "normal" then
			local a = row_gen.generate(11, 0, y).cells
			local b = row_gen.generate(11, 1, y).cells
			for x = 0, COLUMNS - 1 do
				if a[x].type ~= b[x].type or a[x].enemy ~= b[x].enemy then
					changed = changed + 1
				end
			end
		end
	end
	t.true_(changed > 0, "обычные ряды изменились после возрождения")
end

M["same respawn count gives the same rows"] = function(t)
	for y = 1, 30 do
		if row_gen.kind(y) ~= "boss" then
			local a = row_gen.generate(11, 2, y).cells
			local b = row_gen.generate(11, 2, y).cells
			for x = 0, COLUMNS - 1 do
				t.equal(a[x].type, b[x].type, "детерминизм в пределах одной эпохи")
			end
		end
	end
end

M["boss rows stay empty and checkpoint rows hold no objects after respawn"] = function(t)
	for count = 0, 3 do
		local boss = row_gen.generate(9, count, PERIOD - 1)
		t.equal(next(boss.cells), nil, "арена без клеток при count " .. count)
		local cp = row_gen.generate(9, count, PERIOD)
		for x = 0, COLUMNS - 1 do
			t.true_(cp.cells[x].type == "EMPTY" or cp.cells[x].type == "WALL", "checkpoint без объектов")
		end
	end
end

return M
