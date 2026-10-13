local row_seed = require("core.row_seed")

local M = {}

M["same world and row give same seed"] = function(t)
	t.equal(row_seed.row_seed(42, 17), row_seed.row_seed(42, 17), "детерминизм")
end

M["seed does not depend on generation order"] = function(t)
	local direct = row_seed.row_seed(42, 500)
	for r = 0, 499 do
		row_seed.row_seed(42, r)
	end
	t.equal(row_seed.row_seed(42, 500), direct, "ряд 500 не зависит от рядов 0..499")
end

M["neighbouring rows get different seeds"] = function(t)
	local seen = {}
	for r = 0, 999 do
		local s = row_seed.row_seed(7, r)
		t.true_(not seen[s], "коллизия на ряду " .. r)
		seen[s] = true
	end
end

M["different worlds give different seeds for same row"] = function(t)
	t.true_(row_seed.row_seed(1, 10) ~= row_seed.row_seed(2, 10), "разные миры")
end

M["seed is unsigned 32-bit"] = function(t)
	for r = 0, 99 do
		local s = row_seed.row_seed(123456789, r)
		t.true_(s >= 0 and s < 4294967296 and s == math.floor(s), "u32 на ряду " .. r)
	end
end

M["negative row index is rejected"] = function(t)
	t.error_(function()
		row_seed.row_seed(1, -1)
	end, "row_index < 0 должен падать")
end

return M
