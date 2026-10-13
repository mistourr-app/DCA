-- Проверки реестров данных (docs/ENTITY_REGISTRY.md §5).
-- Пока реестры core/registry/* не созданы (PLAN.md, пункт 13), проверяются
-- данные баланса, из которых реестры будут строиться.

local balance = require("core.data.balance")
local design = require("core.data.design")
local registry = require("core.registry.init")

local M = {}

M["registry validates: all entries have required fields"] = function(t)
	local errors = registry.validate()
	t.equal(#errors, 0, "ошибки реестра: " .. table.concat(errors, "; "))
end

M["registry enemy keys are TYPE_N and match balance"] = function(t)
	for _, key in ipairs(registry.enemies.keys) do
		t.true_(balance.enemies[key] ~= nil, "враг " .. key .. " есть в балансе")
	end
	t.equal(#registry.enemies.keys, 3, "три типа врагов")
end

M["registry cells cover every cell type the core uses"] = function(t)
	for _, name in ipairs({ "EMPTY", "WALL", "HEAL", "GOLD", "ENEMY", "ATTACK_CELL", "CAMP" }) do
		t.true_(registry.cells[name] ~= nil, "клетка " .. name)
	end
	t.true_(registry.cells.ENERGY == nil, "клетки ENERGY нет (GDD §22)")
	t.true_(registry.cells.AMMO == nil, "клетки AMMO нет (GDD §22)")
end

M["registry equipment has only the crossbow in one slot"] = function(t)
	local count, slots = 0, {}
	for _, e in pairs(registry.equipment) do
		count = count + 1
		slots[e.slot] = (slots[e.slot] or 0) + 1
	end
	t.equal(count, 1, "один предмет")
	t.equal(slots.weapon, 1, "слот weapon один")
end

M["row kinds are the four GDD kinds"] = function(t)
	for _, name in ipairs({ "normal", "boss", "checkpoint", "camp" }) do
		t.true_(registry.row_kinds[name] ~= nil, "тип ряда " .. name)
	end
end

M["boss hp multiplier grows with boss number"] = function(t)
	t.equal(registry.bosses.hp_multiplier(1), balance.boss.hpMultiplier.from, "первый босс")
	t.true_(registry.bosses.hp_multiplier(2) > registry.bosses.hp_multiplier(1), "второй сильнее")
end


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
	t.true_(balance.cells.GOLD.amount ~= nil, "GOLD.amount")
end

M["no energy remains in balance"] = function(t)
	t.true_(balance.player.energy == nil, "player.energy удалён (энергии нет)")
	t.true_(balance.cells.ENERGY == nil, "клетка ENERGY удалена")
	t.true_(balance.rows.chances.ENERGY == nil, "шанс ENERGY удалён")
	t.true_(balance.arena.supply == nil, "пол арены (был только по энергии) удалён")
	t.true_(balance.upgrades.energy == nil, "трек VIGOUR удалён")
	t.true_(balance.upgrades.energyPerCell == nil, "трек SIPHON удалён")
end

M["no AMMO or bonus cells remain in balance"] = function(t)
	t.true_(balance.cells.AMMO == nil, "AMMO удалён (GDD §22)")
	t.true_(balance.cells.ATTACK_BONUS == nil, "бонусы атаки удалены")
	t.true_(balance.cells.DEFENSE_BONUS == nil, "бонусы защиты удалены")
	t.true_(balance.upgrades.boltsPerCell == nil, "SALVAGE удалён")
	t.true_(balance.upgrades.attackBonus == nil, "бонус атаки удалён из прокачки")
end

M["upgrades: three tracks (energy tracks removed)"] = function(t)
	local count = 0
	for _ in pairs(balance.upgrades) do
		count = count + 1
	end
	t.equal(count, 3, "число треков прокачки: hp, weaponDamage, maxAmmo")
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
	t.equal(design.screen.width, 720, "ширина")
	t.equal(design.screen.height, 1280, "высота")
	t.equal(balance.board.columns, 5, "колонки")
end

M["balance and design are separated"] = function(t)
	t.true_(balance.layout == nil, "layout.* moved to design.csv")
	t.true_(balance.timing == nil, "timing.* moved to design.csv as anim.*")
	t.true_(design.board == nil, "board.* is a game rule, stays in balance.csv")
	t.true_(design.enemies == nil and design.player == nil, "no game numbers in design.csv")
	t.equal(balance.board.columns, 5, "column count lives in balance")
end

return M
