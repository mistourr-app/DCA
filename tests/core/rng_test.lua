local rng = require("core.rng")

local M = {}

M["same seed gives same sequence"] = function(t)
	local a, b = rng.new(12345), rng.new(12345)
	for _ = 1, 100 do
		t.equal(a:next_u32(), b:next_u32(), "последовательность совпадает")
	end
end

M["different seeds diverge"] = function(t)
	local a, b = rng.new(1), rng.new(2)
	local same = 0
	for _ = 1, 50 do
		if a:next_u32() == b:next_u32() then
			same = same + 1
		end
	end
	t.true_(same < 2, "разные seed дают разные последовательности")
end

M["values are unsigned 32-bit"] = function(t)
	local g = rng.new(99)
	for _ = 1, 1000 do
		local v = g:next_u32()
		t.true_(v >= 0 and v < 4294967296 and v == math.floor(v), "диапазон u32: " .. v)
	end
end

M["float is in [0,1)"] = function(t)
	local g = rng.new(7)
	for _ = 1, 1000 do
		local f = g:float()
		t.true_(f >= 0 and f < 1, "float вне [0,1): " .. f)
	end
end

M["int respects inclusive bounds"] = function(t)
	local g = rng.new(3)
	local seen_min, seen_max = false, false
	for _ = 1, 2000 do
		local v = g:int(2, 5)
		t.true_(v >= 2 and v <= 5, "int вне [2,5]: " .. v)
		if v == 2 then seen_min = true end
		if v == 5 then seen_max = true end
	end
	t.true_(seen_min and seen_max, "края диапазона достигаются")
end

M["zero seed does not get stuck"] = function(t)
	local g = rng.new(0)
	local a, b = g:next_u32(), g:next_u32()
	t.true_(a ~= 0 and a ~= b, "состояние не застревает на нуле")
end

M["int rejects inverted range"] = function(t)
	t.error_(function()
		rng.new(1):int(5, 2)
	end, "int(5,2) должен падать")
end

M["uniform buckets over 10 bins are close to 10 percent"] = function(t)
	local g = rng.new(2026)
	local bins = {}
	for i = 0, 9 do bins[i] = 0 end
	local n = 100000
	for _ = 1, n do
		local k = g:int(0, 9)
		bins[k] = bins[k] + 1
	end
	for i = 0, 9 do
		local share = bins[i] / n
		t.true_(math.abs(share - 0.1) < 0.01, string.format("корзина %d: %.4f", i, share))
	end
end

return M
