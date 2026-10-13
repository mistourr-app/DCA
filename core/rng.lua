-- Генератор случайных чисел с явным seed (GDD §11.1, docs/TESTING.md §4).
-- xorshift32 с финализатором murmur3 для seed. Глобальный math.random не используется.
-- Требует модуль bit (LuaJIT).

local bit = require("bit")

local M = {}

local TWO32 = 4294967296

-- Приводит любое целое к беззнаковому 32-битному значению.
local function u32(x)
	return x % TWO32
end

-- Умножение двух беззнаковых 32-битных чисел по модулю 2^32 без потери точности double.
local function mul32(a, b)
	local a_lo, a_hi = a % 65536, math.floor(a / 65536)
	local b_lo, b_hi = b % 65536, math.floor(b / 65536)
	local cross = (a_hi * b_lo + a_lo * b_hi) % 65536
	return (a_lo * b_lo + cross * 65536) % TWO32
end

-- Финализатор murmur3: равномерно перемешивает биты.
function M.mix32(x)
	x = u32(x)
	x = u32(bit.bxor(x, math.floor(x / 65536)))
	x = mul32(x, 0x85EBCA6B)
	x = u32(bit.bxor(x, math.floor(x / 8192)))
	x = mul32(x, 0xC2B2AE35)
	x = u32(bit.bxor(x, math.floor(x / 65536)))
	return x
end

local Rng = {}
Rng.__index = Rng

-- seed: целое число (любое, приводится к 32 битам). Нулевое состояние xorshift запрещено.
function M.new(seed)
	assert(type(seed) == "number", "seed должен быть числом")
	local state = M.mix32(math.floor(seed))
	if state == 0 then
		state = 0x6D2B79F5
	end
	return setmetatable({ state = state }, Rng)
end

-- Следующее беззнаковое 32-битное значение.
function Rng:next_u32()
	local x = self.state
	x = bit.bxor(x, bit.lshift(x, 13))
	x = bit.bxor(x, bit.rshift(x, 17))
	x = bit.bxor(x, bit.lshift(x, 5))
	self.state = u32(x)
	return self.state
end

-- Число в диапазоне [0, 1).
function Rng:float()
	return self:next_u32() / TWO32
end

-- Целое в диапазоне [min, max] включительно, без смещения (отбраковка остатка).
function Rng:int(min, max)
	assert(type(min) == "number" and type(max) == "number" and min <= max,
		"int: нужен диапазон min <= max")
	local range = max - min + 1
	local limit = TWO32 - (TWO32 % range)
	local r = self:next_u32()
	while r >= limit do
		r = self:next_u32()
	end
	return min + (r % range)
end

return M
