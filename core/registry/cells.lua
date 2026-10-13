-- Реестр типов клеток (docs/ENTITY_REGISTRY.md §3.1).
-- Параметры — из баланса. Обработчики поведения появятся вместе с core/run (пункт 14).

local balance = require("core.data.balance")

local M = {}

M.EMPTY = { label = "EMPTY", blocks_movement = false, blocks_vision = false, visibility = "visible" }

M.WALL = { label = "WALL", blocks_movement = true, blocks_vision = true, visibility = "visible" }

M.HEAL = {
	label = "HEALTH",
	blocks_movement = false,
	blocks_vision = false,
	visibility = "visible",
	amount = balance.cells.HEAL.amount,
}

M.GOLD = {
	label = "GOLD",
	blocks_movement = false,
	blocks_vision = false,
	visibility = "visible",
	amount = balance.cells.GOLD.amount,
}

M.ENEMY = { label = "ENEMY", blocks_movement = true, blocks_vision = false, visibility = "visible" }

M.ATTACK_CELL = {
	label = "ATTACK",
	blocks_movement = false,
	blocks_vision = false,
	visibility = "visible",
	damage_min = balance.cells.ATTACK_CELL.damageMin,
	damage_max = balance.cells.ATTACK_CELL.damageMax,
}

M.CAMP = { label = "CAMP", blocks_movement = false, blocks_vision = false, visibility = "visible" }

return M
