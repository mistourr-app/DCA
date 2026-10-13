local upgrades = require("core.upgrades")
local balance = require("core.data.balance")

local M = {}

M["price is base plus step times current level"] = function(t)
	local s = upgrades.new_state()
	local b = balance.upgrades.hp
	t.equal(upgrades.next_price(s, "hp"), b.base, "уровень 0: base")
	upgrades.buy(s, 10000, "hp")
	t.equal(upgrades.next_price(s, "hp"), b.base + b.step, "уровень 1: base + step")
end

M["total cost of L levels matches the closed formula"] = function(t)
	local s = upgrades.new_state()
	local sum = 0
	for _ = 1, 5 do
		sum = sum + upgrades.next_price(s, "weaponDamage")
		upgrades.buy(s, 1e9, "weaponDamage")
	end
	t.equal(upgrades.total_cost("weaponDamage", 5), sum, "сумма по формуле")
end

M["buy deducts gold and raises the level"] = function(t)
	local s = upgrades.new_state()
	local price = upgrades.next_price(s, "maxAmmo")
	local left = upgrades.buy(s, price + 5, "maxAmmo")
	t.equal(left, 5, "остаток золота")
	t.equal(s.levels.maxAmmo, 1, "уровень 1")
end

M["buy is refused without enough gold and changes nothing"] = function(t)
	local s = upgrades.new_state()
	local left, err = upgrades.buy(s, 1, "hp")
	t.equal(left, nil, "покупки нет")
	t.true_(err ~= nil, "есть причина")
	t.equal(s.levels.hp, 0, "уровень не изменился")
end

M["unknown track is an error"] = function(t)
	t.error_(function() upgrades.buy(upgrades.new_state(), 1000, "energy") end, "энергии нет")
end

M["stats apply the effect of each level"] = function(t)
	local s = upgrades.new_state()
	local base = upgrades.stats(s)
	t.equal(base.max_hp, balance.player.hp, "базовый HP")
	s.levels.hp = 2
	s.levels.weaponDamage = 3
	s.levels.maxAmmo = 1
	local st = upgrades.stats(s)
	t.equal(st.max_hp, balance.player.hp + 2 * balance.upgrades.hp.effect, "HP с прокачкой")
	t.equal(st.weapon_damage, balance.player.weapon.damage + 3 * balance.upgrades.weaponDamage.effect, "урон")
	t.equal(st.max_charges, balance.player.weapon.maxCharges + balance.upgrades.maxAmmo.effect, "заряды")
end

M["only three tracks exist"] = function(t)
	t.equal(#upgrades.TRACKS, 3, "hp, weaponDamage, maxAmmo")
end

return M
