local combat = require("core.combat")

local M = {}

M["damage reduces hp and never goes below zero"] = function(t)
	t.equal(combat.apply_damage(10, 4), 6, "10 - 4")
	t.equal(combat.apply_damage(3, 9), 0, "не ниже нуля")
end

M["dead when hp is zero or less"] = function(t)
	t.true_(combat.is_dead(0), "HP 0 — мёртв")
	t.true_(not combat.is_dead(1), "HP 1 — жив")
end

M["melee: player strikes for its hp, enemy answers with remaining hp"] = function(t)
	-- игрок 10 бьёт врага 7: враг остаётся с 0 и не отвечает
	local p, e = combat.melee(10, 7)
	t.equal(e, 0, "враг мёртв")
	t.equal(p, 10, "игрок цел")
	-- игрок 5 бьёт врага 10: враг остаётся с 5 и бьёт игрока на 5
	p, e = combat.melee(5, 10)
	t.equal(e, 5, "враг с 5 HP")
	t.equal(p, 0, "игрок получает 5 и погибает")
end

M["shot does not get a reply and deals weapon damage"] = function(t)
	t.equal(combat.shot(10, 3), 7, "урон оружия 3")
	t.equal(combat.shot(2, 3), 0, "не ниже нуля")
end

M["behind attack deals enemy current hp to player"] = function(t)
	t.equal(combat.behind_attack(20, 4), 16, "урон равен HP врага")
end

return M
