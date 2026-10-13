local row_gen = require("core.row_gen")
local balance = require("core.data.balance")

local M = {}

local COLUMNS = balance.layout.columns
local PERIOD = balance.boss.period

M["schedule: checkpoint every K rows, boss arena before it"] = function(t)
	t.equal(row_gen.kind(0), "checkpoint", "стартовый ряд — checkpoint")
	t.equal(row_gen.kind(PERIOD), "checkpoint", "ряд K — checkpoint")
	t.equal(row_gen.kind(PERIOD - 2), "boss", "арена начинается за A рядов до checkpoint")
	t.equal(row_gen.kind(PERIOD - 1), "boss", "вторая строка арены")
	t.equal(row_gen.kind(1), "normal", "обычный ряд")
end

M["every checkpoint follows a boss arena"] = function(t)
	for r = PERIOD, PERIOD * 20, PERIOD do
		t.equal(row_gen.kind(r), "checkpoint", "checkpoint на " .. r)
		t.equal(row_gen.kind(r - 1), "boss", "арена перед checkpoint на " .. r)
	end
end

M["checkpoint row has only walls or empty cells"] = function(t)
	for r = 0, PERIOD * 30, PERIOD do
		local row = row_gen.generate(1234, r)
		for x = 0, COLUMNS - 1 do
			local c = row.cells[x]
			t.true_(c.type == "EMPTY" or c.type == "WALL",
				string.format("ряд %d колонка %d: %s", r, x, c.type))
			t.true_(c.enemy == nil, "на checkpoint нет врагов")
		end
	end
end

M["boss rows are not filled with cells"] = function(t)
	local row = row_gen.generate(1, PERIOD - 1)
	t.equal(row.kind, "boss", "тип")
	t.equal(next(row.cells), nil, "клеток нет, арена генерируется отдельно")
end

M["normal row has exactly COLUMNS cells with valid types"] = function(t)
	local allowed = { EMPTY = true, WALL = true, HEAL = true, ENERGY = true, GOLD = true, ENEMY = true }
	local row = row_gen.generate(5, 1)
	local count = 0
	for x = 0, COLUMNS - 1 do
		count = count + 1
		t.true_(allowed[row.cells[x].type] == true, "тип " .. row.cells[x].type)
	end
	t.equal(count, COLUMNS, "число клеток")
end

M["enemies carry a valid enemy key"] = function(t)
	local found = 0
	for r = 1, 200 do
		if row_gen.kind(r) == "normal" then
			local row = row_gen.generate(77, r)
			for x = 0, COLUMNS - 1 do
				local c = row.cells[x]
				if c.type == "ENEMY" then
					found = found + 1
					t.true_(balance.enemies[c.enemy] ~= nil, "неизвестный враг " .. tostring(c.enemy))
				end
			end
		end
	end
	t.true_(found > 0, "враги встречаются")
end

M["generation is deterministic and independent of order"] = function(t)
	local direct = row_gen.generate(42, 137)
	for r = 0, 136 do
		row_gen.generate(42, r)
	end
	local again = row_gen.generate(42, 137)
	for x = 0, COLUMNS - 1 do
		t.equal(again.cells[x].type, direct.cells[x].type, "тип на колонке " .. x)
		t.equal(again.cells[x].enemy, direct.cells[x].enemy, "враг на колонке " .. x)
	end
end

M["chances are interpolated and saturate at rampRows"] = function(t)
	local ramp = balance.rows.rampRows
	local spec = balance.rows.chances.WALL
	t.equal(row_gen.chance("WALL", 0), spec.from, "ряд 0 — from")
	t.true_(math.abs(row_gen.chance("WALL", ramp) - spec.to) < 1e-9, "на rampRows — to")
	t.true_(math.abs(row_gen.chance("WALL", ramp * 10) - spec.to) < 1e-9, "дальше — to")
end

M["chance sums stay within 1 for many rows"] = function(t)
	for r = 0, 2000 do
		row_gen.chances(r)
	end
	t.true_(true, "сумма <= 1 на 2000 рядах")
end

M["empirical wall share on normal rows matches the chance"] = function(t)
	local r = 1
	local expected = row_gen.chance("WALL", r)
	local walls, total = 0, 0
	for seed = 1, 400 do
		local row = row_gen.generate(seed, r)
		for x = 0, COLUMNS - 1 do
			total = total + 1
			if row.cells[x].type == "WALL" then
				walls = walls + 1
			end
		end
	end
	local share = walls / total
	t.true_(math.abs(share - expected) < 0.03,
		string.format("доля стен %.3f при шансе %.3f", share, expected))
end

return M
