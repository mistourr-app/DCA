local save_schema = require("core.save_schema")

local M = {}

local CAMP_CELLS = { "CAMP", "WALL", "EMPTY", "CAMP", "EMPTY" }

local function valid_raw()
	return {
		version = save_schema.SCHEMA_VERSION,
		seed = 42,
		respawn_count = 3,
		gold = 120,
		upgrades = { hp = 2, weaponDamage = 1, maxAmmo = 0 },
		return_point = { kind = "checkpoint", row = 10, x = 2 },
	}
end

M["schema is version 2"] = function(t)
	t.equal(save_schema.SCHEMA_VERSION, 2, "версия 2")
end

M["valid save passes and keeps values"] = function(t)
	local out = save_schema.validate(valid_raw())
	t.equal(out.gold, 120, "золото")
	t.equal(out.upgrades.hp, 2, "уровень hp")
	t.equal(out.seed, 42, "seed")
	t.equal(out.respawn_count, 3, "счётчик возрождений")
end

M["version 1 saves are rejected entirely"] = function(t)
	local raw = valid_raw()
	raw.version = 1
	local out, err = save_schema.validate(raw)
	t.equal(out, nil, "старая версия отвергнута")
	t.true_(err ~= nil, "есть причина")
end

M["non-table input is rejected"] = function(t)
	t.equal(save_schema.validate("junk"), nil, "строка отвергнута")
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
	raw.respawn_count = -1
	raw.upgrades.hp = -1
	raw.upgrades.weaponDamage = "lots"
	local out = save_schema.validate(raw)
	t.equal(out.gold, 0, "золото не отрицательное")
	t.equal(out.respawn_count, 0, "счётчик не отрицательный")
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
	t.equal(save_schema.validate(raw).__index, nil, "служебный ключ не скопирован")
end

M["validate does not modify the input"] = function(t)
	local raw = valid_raw()
	save_schema.validate(raw)
	t.equal(raw.gold, 120, "исходное золото не тронуто")
end

M["invalid return point falls back to start"] = function(t)
	local raw = valid_raw()
	raw.return_point = { kind = "teleport", row = 5, x = 1 }
	t.equal(save_schema.validate(raw).return_point.kind, "start", "неизвестный вид")
	raw.return_point = { kind = "checkpoint", row = -3, x = 1 }
	t.equal(save_schema.validate(raw).return_point.kind, "start", "отрицательный ряд")
	raw.return_point = { kind = "checkpoint", row = 3, x = 9 }
	t.equal(save_schema.validate(raw).return_point.kind, "start", "колонка вне поля")
end

M["camp return point keeps its cells"] = function(t)
	local raw = valid_raw()
	raw.return_point = { kind = "camp", row = 12, x = 3, cells = CAMP_CELLS }
	local rp = save_schema.validate(raw).return_point
	t.equal(rp.kind, "camp", "вид точки")
	t.equal(rp.row, 12, "ряд")
	t.equal(rp.cells[1], "CAMP", "клетки лагеря сохранены")
	t.equal(rp.cells[2], "WALL", "стена в лагере сохранена")
end

M["camp without valid cells falls back to start"] = function(t)
	local raw = valid_raw()
	raw.return_point = { kind = "camp", row = 12, x = 3 }
	t.equal(save_schema.validate(raw).return_point.kind, "start", "лагерь без клеток — старт")
	raw.return_point = { kind = "camp", row = 12, x = 3, cells = { "ENEMY", "WALL", "EMPTY", "CAMP", "EMPTY" } }
	t.equal(save_schema.validate(raw).return_point.kind, "start", "враг в клетке лагеря — старт")
end

M["checkpoint cells are optional"] = function(t)
	local raw = valid_raw()
	raw.return_point = { kind = "checkpoint", row = 10, x = 2 }
	t.equal(save_schema.validate(raw).return_point.cells, nil, "без клеток — нет поля")
end

return M
