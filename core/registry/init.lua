-- Сборка реестров и проверка (docs/ENTITY_REGISTRY.md §2, §5).
-- Ядро обращается к сущностям только через этот модуль, без if type == "...".

local M = {}

M.cells = require("core.registry.cells")
M.enemies = require("core.registry.enemies")
M.equipment = require("core.registry.equipment")
M.bosses = require("core.registry.bosses")
M.row_kinds = require("core.registry.row_kinds")

local CELL_FIELDS = { "label", "blocks_movement", "blocks_vision", "visibility" }
local ENEMY_FIELDS = { "label", "base_hp", "vision", "weight" }
local EQUIPMENT_FIELDS = { "slot", "label", "max_charges", "recharge_turns", "damage", "range", "shots_per_row" }
local ROW_FIELDS = { "label", "generated" }

-- Возвращает список ошибок (пустой список — всё в порядке).
function M.validate()
	local errors = {}
	local function check(cond, msg)
		if not cond then
			table.insert(errors, msg)
		end
	end
	local function required(entry, fields, where)
		for _, f in ipairs(fields) do
			check(entry[f] ~= nil, where .. ": нет поля " .. f)
		end
	end

	for key, e in pairs(M.cells) do
		required(e, CELL_FIELDS, "cells." .. key)
	end
	for key, e in pairs(M.enemies.types) do
		check(key:match("^TYPE_%d+$") ~= nil, "enemies: ключ не TYPE_N: " .. key)
		required(e, ENEMY_FIELDS, "enemies." .. key)
		check(e.weight >= 0, "enemies." .. key .. ": вес отрицательный")
	end
	for key, e in pairs(M.equipment) do
		required(e, EQUIPMENT_FIELDS, "equipment." .. key)
	end
	for key, e in pairs(M.row_kinds) do
		required(e, ROW_FIELDS, "row_kinds." .. key)
	end
	return errors
end

return M
