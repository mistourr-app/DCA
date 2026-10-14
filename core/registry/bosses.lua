-- Реестр боссов (docs/ENTITY_REGISTRY.md 3.4, GDD 12).
-- Записи ключуются номером босса (1, 2, ...). Босс 1 появляется на ряду K (boss.period).
-- ai — модуль поведения (выбор хода). Сейчас у всех боссов базовый AI из DR (GDD 12.5).

local balance = require("core.data.balance")

local M = {}

M.arena_rows = balance.boss.arenaRows
M.period = balance.boss.period

-- Поведение по номеру босса. Новый босс добавляется записью с собственным модулем ai.
M.ai = {
	[1] = require("core.ai.boss_default"),
}

function M.ai_for(boss_number)
	return M.ai[boss_number] or M.ai[1]
end

-- Множитель HP босса по номеру: from на первом, затем + slope за каждый следующий (CSV).
function M.hp_multiplier(boss_number)
	assert(type(boss_number) == "number" and boss_number >= 1, "номер босса >= 1")
	return balance.boss.hpMultiplier.from + balance.boss.hpMultiplier.slope * (boss_number - 1)
end

return M
