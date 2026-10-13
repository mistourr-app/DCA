local death = require("core.death")
local balance = require("core.data.balance")

local M = {}

local equipment = require("core.equipment")

local function player_at_death()
	local w = equipment.new(3, 5)
	equipment.use(w)
	equipment.use(w)
	equipment.use(w)
	return {
		hp = 0,
		max_hp = 20,
		weapon = w,
		gold = 450,
		equipment = { weapon = "CROSSBOW" },
	}
end

M["camp respawn restores hp and weapon charges fully"] = function(t)
	local p = death.respawn(player_at_death(), "camp")
	t.equal(p.hp, 20, "HP полностью")
	t.equal(p.weapon.charges, 3, "заряды полностью")
	t.true_(not equipment.is_recharging(p.weapon), "перезарядка сброшена")
end

M["checkpoint respawn restores hp and weapon charges (GDD 9)"] = function(t)
	local p = death.respawn(player_at_death(), "checkpoint")
	t.equal(p.hp, 20, "HP восстановлен")
	t.equal(p.weapon.charges, 3, "заряды восстановлены")
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

M["death takes the configured percent of current gold"] = function(t)
	local pct = balance.death.goldPenaltyPercent
	local p, lost = death.respawn(player_at_death(), "camp")
	t.equal(lost, math.floor(450 * pct / 100), "штраф от текущего золота")
	t.equal(p.gold, 450 - lost, "остаток золота")
end

M["penalty rounds down and never makes gold negative"] = function(t)
	t.equal(death.gold_penalty(0), 0, "ноль золота")
	t.equal(death.gold_penalty(1), 0, "округление вниз")
	local s = player_at_death()
	s.gold = 0
	local p = death.respawn(s, "checkpoint")
	t.equal(p.gold, 0, "нулевое золото остаётся нулём")
end

M["equipment is kept on respawn"] = function(t)
	local p = death.respawn(player_at_death(), "camp")
	t.equal(p.equipment.weapon, "CROSSBOW", "экипировка сохранена")
end

M["respawn does not modify the input state"] = function(t)
	local before = player_at_death()
	death.respawn(before, "camp")
	t.equal(before.hp, 0, "исходный HP не изменён")
	t.equal(before.gold, 450, "исходное золото не изменено")
	t.equal(before.weapon.charges, 0, "исходные заряды не изменены")
end

M["unknown return point kind is refused"] = function(t)
	local p, err = death.respawn(player_at_death(), "teleport")
	t.equal(p, nil, "результата нет")
	t.true_(err ~= nil, "есть причина")
end

return M
