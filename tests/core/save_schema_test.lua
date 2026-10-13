local save_schema = require("core.save_schema")

local M = {}

local function valid_raw()
	return {
		version = save_schema.SCHEMA_VERSION,
		seed = 42,
		gold = 120,
		upgrades = { hp = 2, weaponDamage = 1, maxAmmo = 0 },
	}
end

M["valid save passes and keeps values"] = function(t)
	local out = save_schema.validate(valid_raw())
	t.equal(out.gold, 120, "золото")
	t.equal(out.upgrades.hp, 2, "уровень hp")
	t.equal(out.seed, 42, "seed")
end

M["wrong version is rejected entirely"] = function(t)
	local raw = valid_raw()
	raw.version = 99
	local out, err = save_schema.validate(raw)
	t.equal(out, nil, "версия не совпадает")
	t.true_(err ~= nil, "есть причина")
end

M["non-table input is rejected"] = function(t)
	local out = save_schema.validate("junk")
	t.equal(out, nil, "строка отвергнута")
end

M["unknown keys are dropped"] = function(t)
	local raw = valid_raw()
	raw.cheat = 999
	raw.upgrades.energy = 5
	local out = save_schema.validate(raw)
	t.equal(out.cheat, nil, "неизвестный верхний ключ отброшен")
	t.equal(out.upgrades.energy, nil, "неизвестный трек отброшен")
end

M["negative and non-numeric values fall back to defaults"] = function(t)
	local raw = valid_raw()
	raw.gold = -50
	raw.upgrades.hp = -1
	raw.upgrades.weaponDamage = "lots"
	local out = save_schema.validate(raw)
	t.equal(out.gold, 0, "золото не отрицательное")
	t.equal(out.upgrades.hp, 0, "уровень не отрицательный")
	t.equal(out.upgrades.weaponDamage, 0, "не число — ноль")
end

M["fractional gold is rejected"] = function(t)
	local raw = valid_raw()
	raw.gold = 10.5
	t.equal(save_schema.validate(raw).gold, 0, "дробное золото отброшено")
end

M["prototype-like keys are not copied"] = function(t)
	local raw = valid_raw()
	raw["__index"] = {}
	local out = save_schema.validate(raw)
	t.equal(out.__index, nil, "служебный ключ не скопирован")
end

M["validate does not modify the input"] = function(t)
	local raw = valid_raw()
	save_schema.validate(raw)
	t.equal(raw.gold, 120, "исходное золото не тронуто")
end

return M
