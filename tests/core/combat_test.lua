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

M["melee: enemy weaker than player dies, player loses enemy hp and survives"] = function(t)
	-- игрок 10, враг 7: враг погибает, игрок теряет 7 HP
	local p, e = combat.melee(10, 7)
	t.equal(e, 0, "враг мёртв")
	t.equal(p, 3, "игрок получил 7 урона")
end

M["melee: enemy stronger than player kills the player, enemy keeps the rest"] = function(t)
	-- игрок 5, враг 10: игрок погибает, враг теряет 5 HP
	local p, e = combat.melee(5, 10)
	t.equal(p, 0, "игрок мёртв")
	t.equal(e, 5, "у врага остаётся 5")
end

M["melee: tie is a player death"] = function(t)
	local p, e = combat.melee(6, 6)
	t.equal(p, 0, "при равенстве погибает игрок")
	t.equal(e, 0, "враг тоже без HP")
end

M["melee: exactly one of the two dies, never both alive"] = function(t)
	for pp = 1, 15 do
		for ee = 1, 15 do
			local p, e = combat.melee(pp, ee)
			t.true_(p <= 0 or e <= 0, string.format("player %d vs enemy %d: оба живы", pp, ee))
			t.true_(not (p <= 0 and e <= 0) or pp == ee, "оба погибают только при равенстве")
		end
	end
end

M["shot does not get a reply and deals weapon damage"] = function(t)
	t.equal(combat.shot(10, 3), 7, "урон оружия 3")
	t.equal(combat.shot(2, 3), 0, "не ниже нуля")
end

M["behind attack deals enemy current hp to player"] = function(t)
	t.equal(combat.behind_attack(20, 4), 16, "урон равен HP врага")
end

return M
