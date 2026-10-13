-- Seed ряда: f(world_seed, respawn_count, row_index) (GDD §11.1).
-- world_seed задаётся при старте мира. respawn_count растёт при каждом возрождении: ряды выше
-- точки возврата после возрождения генерируются заново (GDD §11).
-- Чистая функция: одни и те же входы всегда дают один и тот же seed.

local rng = require("core.rng")

local M = {}

local TWO32 = 4294967296

-- Возвращает seed (беззнаковое 32-битное целое) для ряда row_index.
function M.row_seed(world_seed, respawn_count, row_index)
	assert(type(world_seed) == "number", "world_seed должен быть числом")
	assert(type(respawn_count) == "number" and respawn_count >= 0, "respawn_count должен быть неотрицательным")
	assert(type(row_index) == "number" and row_index >= 0, "row_index должен быть неотрицательным")
	local world = rng.mix32(math.floor(world_seed))
	local epoch = rng.mix32((math.floor(respawn_count) + 0x7F4A7C15) % TWO32)
	local row = rng.mix32((math.floor(row_index) + 0x9E3779B9) % TWO32)
	return rng.mix32((rng.mix32((world + epoch) % TWO32) + row) % TWO32)
end

return M
