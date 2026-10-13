-- Реестр экипировки (docs/ENTITY_REGISTRY.md §3.3, GDD §6–§7). Один слот (GDD §20 решено).
-- Сейчас единственный предмет — арбалет. Новые предметы с зарядами добавляются сюда.

local balance = require("core.data.balance")

local M = {}

M.CROSSBOW = {
	slot = "weapon",
	label = "CROSSBOW",
	max_charges = balance.player.weapon.maxCharges,
	recharge_turns = balance.player.weapon.rechargeTurns,
	damage = balance.player.weapon.damage,
	range = balance.player.weapon.range,
	shots_per_row = balance.player.weapon.shotsPerRow,
}

return M
