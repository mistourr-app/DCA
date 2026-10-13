-- Seed ряда: f(global_seed, row_index) (GDD §11.1).
-- Чистая функция: один и тот же ряд всегда получает один и тот же seed,
-- независимо от того, какие ряды генерировались раньше.

local rng = require("core.rng")

local M = {}

local TWO32 = 4294967296

-- Возвращает seed (беззнаковое 32-битное целое) для ряда row_index мира global_seed.
function M.row_seed(global_seed, row_index)
	assert(type(global_seed) == "number", "global_seed должен быть числом")
	assert(type(row_index) == "number" and row_index >= 0, "row_index должен быть неотрицательным")
	local world = rng.mix32(math.floor(global_seed))
	local row = rng.mix32((math.floor(row_index) + 0x9E3779B9) % TWO32)
	return rng.mix32((world + row) % TWO32)
end

return M
