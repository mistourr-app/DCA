local equipment = require("core.equipment")
local balance = require("core.data.balance")

local M = {}

local function crossbow()
	return equipment.new(balance.player.weapon.maxCharges, balance.player.weapon.rechargeTurns)
end

M["starts with full charges and no recharge"] = function(t)
	local e = crossbow()
	t.equal(e.charges, balance.player.weapon.maxCharges, "полные заряды")
	t.true_(not equipment.is_recharging(e), "не перезаряжается")
end

M["each use spends exactly one charge"] = function(t)
	local e = crossbow()
	t.true_(equipment.use(e), "первое применение")
	t.equal(e.charges, balance.player.weapon.maxCharges - 1, "минус один заряд")
end

M["exhausting charges starts recharge of configured length"] = function(t)
	local e = crossbow()
	for _ = 1, balance.player.weapon.maxCharges do
		equipment.use(e)
		equipment.new_row(e)
	end
	t.equal(e.charges, 0, "заряды исчерпаны")
	t.true_(equipment.is_recharging(e), "перезарядка запущена")
	t.equal(e.recharge_left, balance.player.weapon.rechargeTurns, "длина перезарядки из CSV")
end

M["cannot use while recharging or without charges"] = function(t)
	local e = crossbow()
	for _ = 1, balance.player.weapon.maxCharges do
		equipment.use(e)
	end
	local ok = equipment.use(e)
	t.true_(not ok, "во время перезарядки нельзя")
end

M["recharge completes after N ticks and restores all charges"] = function(t)
	local e = crossbow()
	for _ = 1, balance.player.weapon.maxCharges do
		equipment.use(e)
	end
	for _ = 1, balance.player.weapon.rechargeTurns - 1 do
		equipment.tick(e)
	end
	t.true_(equipment.is_recharging(e), "ещё перезаряжается на N-1 ходе")
	equipment.tick(e)
	t.true_(not equipment.is_recharging(e), "готов на N-м ходе")
	t.equal(e.charges, balance.player.weapon.maxCharges, "заряды полные")
end

M["tick does nothing when not recharging"] = function(t)
	local e = crossbow()
	equipment.tick(e)
	t.equal(e.charges, balance.player.weapon.maxCharges, "без перезарядки тик ничего не меняет")
end

M["one shot per row"] = function(t)
	local e = crossbow()
	t.true_(equipment.fire(e), "первый выстрел")
	t.true_(not equipment.can_fire(e), "второй на том же ряду запрещён")
	equipment.new_row(e)
	t.true_(equipment.can_fire(e), "на новом ряду снова можно")
end

M["restore refills charges and clears recharge"] = function(t)
	local e = crossbow()
	for _ = 1, balance.player.weapon.maxCharges do
		equipment.use(e)
	end
	equipment.restore(e)
	t.equal(e.charges, balance.player.weapon.maxCharges, "заряды полные")
	t.true_(not equipment.is_recharging(e), "перезарядка сброшена")
end

M["same rules for any charged item (general principle)"] = function(t)
	local other = equipment.new(2, 3)
	equipment.use(other)
	equipment.use(other)
	t.true_(equipment.is_recharging(other), "другой предмет с зарядами работает так же")
	for _ = 1, 3 do
		equipment.tick(other)
	end
	t.equal(other.charges, 2, "восстанавливается по своему N")
end

M["invalid parameters are refused"] = function(t)
	t.error_(function() equipment.new(0, 3) end, "0 зарядов")
	t.error_(function() equipment.new(3, 0) end, "0 ходов перезарядки")
end

return M
