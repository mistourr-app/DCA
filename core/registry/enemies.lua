-- Реестр типов врагов (docs/ENTITY_REGISTRY.md §3.2). Данные — из баланса.
-- Ключи TYPE_N стабильны (сохранения, тесты, ассеты). Урон врага = его текущий HP (GDD §3.5).

local balance = require("core.data.balance")

local M = {}

M.keys = {}
for key in pairs(balance.enemies) do
	table.insert(M.keys, key)
end
table.sort(M.keys)

M.types = {}
for _, key in ipairs(M.keys) do
	local e = balance.enemies[key]
	M.types[key] = {
		key = key,
		label = e.label,
		base_hp = e.hp,
		vision = { range = e.visionRange, shape = e.visionShape },
		weight = e.weight,
	}
end

return M
