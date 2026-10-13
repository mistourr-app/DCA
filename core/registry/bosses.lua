-- Реестр боссов (docs/ENTITY_REGISTRY.md §3.4, GDD §12).
-- Поведение (ai) и правила арены добавляются на пункте 15. Здесь пока только параметры по номеру босса.
-- Записи ключуются номером босса (1, 2, ...). Босс 1 появляется на ряду K (boss.period).

local balance = require("core.data.balance")

local M = {}

-- Множитель HP босса по номеру: from на первом, затем + slope за каждый следующий (CSV).
function M.hp_multiplier(boss_number)
	assert(type(boss_number) == "number" and boss_number >= 1, "номер босса >= 1")
	return balance.boss.hpMultiplier.from + balance.boss.hpMultiplier.slope * (boss_number - 1)
end

M.arena_rows = balance.boss.arenaRows
M.period = balance.boss.period

return M
