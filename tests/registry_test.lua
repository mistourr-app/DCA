-- Проверки реестров данных (docs/ENTITY_REGISTRY.md §5).
-- Пока реестры core/registry/* не созданы (PLAN.md, пункт 13), проверяются
-- данные баланса, из которых реестры будут строиться.

local balance = require("core.data.balance")

local M = {}

local REQUIRED_ENEMY_FIELDS = { "label", "hp", "visionRange", "visionShape", "weight" }

M["enemy keys are TYPE_N and unique"] = function(t)
	local seen = {}
	for key in pairs(balance.enemies) do
		t.true_(type(key) == "string" and key:match("^TYPE_%d+$") ~= nil,
			"ключ врага должен быть TYPE_N: " .. tostring(key))
		t.true_(not seen[key], "дубликат ключа " .. key)
		seen[key] = true
	end
end

M["every enemy has all required fields"] = function(t)
	for key, enemy in pairs(balance.enemies) do
		for _, field in ipairs(REQUIRED_ENEMY_FIELDS) do
			t.true_(enemy[field] ~= nil, string.format("%s: нет поля %s", key, field))
		end
	end
end

M["enemy weights are non-negative and not all zero"] = function(t)
	local total = 0
	for key, enemy in pairs(balance.enemies) do
		t.true_(enemy.weight >= 0, key .. ": вес отрицательный")
		total = total + enemy.weight
	end
	t.true_(total > 0, "сумма весов врагов равна нулю")
end

M["enemy labels are unique"] = function(t)
	local seen = {}
	for key, enemy in pairs(balance.enemies) do
		t.true_(not seen[enemy.label], key .. ": label повторяется " .. enemy.label)
		seen[enemy.label] = true
	end
end

M["cell amounts are present for item cells"] = function(t)
	t.true_(balance.cells.HEAL.amount ~= nil, "HEAL.amount")
	t.true_(balance.cells.ENERGY.amount ~= nil, "ENERGY.amount")
	t.true_(balance.cells.GOLD.amount ~= nil, "GOLD.amount")
end

M["no AMMO or bonus cells remain in balance"] = function(t)
	t.true_(balance.cells.AMMO == nil, "AMMO удалён (GDD §22)")
	t.true_(balance.cells.ATTACK_BONUS == nil, "бонусы атаки удалены")
	t.true_(balance.cells.DEFENSE_BONUS == nil, "бонусы защиты удалены")
	t.true_(balance.upgrades.boltsPerCell == nil, "SALVAGE удалён")
	t.true_(balance.upgrades.attackBonus == nil, "бонус атаки удалён из прокачки")
end

M["upgrades: five tracks"] = function(t)
	local count = 0
	for _ in pairs(balance.upgrades) do
		count = count + 1
	end
	t.equal(count, 5, "число треков прокачки")
end

M["rows chance sums do not exceed 1"] = function(t)
	for _, bound in ipairs({ "from", "to" }) do
		local total = 0
		for _, spec in pairs(balance.rows.chances) do
			total = total + spec[bound]
		end
		t.true_(total <= 1, "сумма шансов " .. bound .. " = " .. total)
	end
end

M["layout is portrait 720x1280 with 5 columns"] = function(t)
	t.equal(balance.layout.logicalWidth, 720, "ширина")
	t.equal(balance.layout.logicalHeight, 1280, "высота")
	t.equal(balance.layout.columns, 5, "колонки")
end

return M
