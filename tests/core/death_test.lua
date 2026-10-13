local death = require("core.death")

local M = {}

local function player_at_death()
	return {
		hp = 0,
		max_hp = 20,
		charges = 0,
		max_charges = 3,
		gold = 450,
		equipment = { weapon = "CROSSBOW" },
	}
end

M["camp respawn restores hp and charges fully"] = function(t)
	local p = death.respawn(player_at_death(), "camp")
	t.equal(p.hp, 20, "HP полностью")
	t.equal(p.charges, 3, "заряды полностью")
end

M["checkpoint respawn restores hp and charges (GDD 9, уточнено)"] = function(t)
	local p = death.respawn(player_at_death(), "checkpoint")
	t.equal(p.hp, 20, "HP восстановлен")
	t.equal(p.charges, 3, "заряды восстановлены")
end

M["start respawn restores hp and charges"] = function(t)
	local p = death.respawn(player_at_death(), "start")
	t.equal(p.hp, 20, "HP восстановлен")
end

M["no energy field exists in the player state"] = function(t)
	local p = death.respawn(player_at_death(), "camp")
	t.equal(p.energy, nil, "энергии нет")
	t.equal(p.max_energy, nil, "максимума энергии нет")
end

M["gold and equipment are kept on respawn"] = function(t)
	local p = death.respawn(player_at_death(), "camp")
	t.equal(p.gold, 450, "золото сохранено")
	t.equal(p.equipment.weapon, "CROSSBOW", "экипировка сохранена")
end

M["respawn does not modify the input state"] = function(t)
	local before = player_at_death()
	death.respawn(before, "camp")
	t.equal(before.hp, 0, "исходный HP не изменён")
end

M["unknown return point kind is refused"] = function(t)
	local p, err = death.respawn(player_at_death(), "teleport")
	t.equal(p, nil, "результата нет")
	t.true_(err ~= nil, "есть причина")
end

return M
