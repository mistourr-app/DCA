-- Прокачка за золото (GDD §15.3). Три трека: hp, weaponDamage, maxAmmo.
-- Цена следующего уровня: base + step * текущий уровень. Уровни не ограничены.
-- Эффект: effect за каждый купленный уровень. Чистая логика.
--
-- Состояние прокачки: { levels = { [track] = целое >= 0 } }.

local balance = require("core.data.balance")

local M = {}

M.TRACKS = { "hp", "weaponDamage", "maxAmmo" }

local function track_spec(track)
	local spec = balance.upgrades[track]
	assert(spec ~= nil, "неизвестный трек прокачки: " .. tostring(track))
	return spec
end

function M.new_state()
	local levels = {}
	for _, track in ipairs(M.TRACKS) do
		levels[track] = 0
	end
	return { levels = levels }
end

-- Цена следующего уровня трека при текущем уровне.
function M.next_price(state, track)
	local spec = track_spec(track)
	return spec.base + spec.step * state.levels[track]
end

-- Сумма цен от нуля до уровня L: L*base + step*L(L-1)/2.
function M.total_cost(track, level)
	local spec = track_spec(track)
	return level * spec.base + spec.step * level * (level - 1) / 2
end

-- Покупка уровня. Возвращает новое золото или nil и причину.
function M.buy(state, gold, track)
	track_spec(track)
	local price = M.next_price(state, track)
	if gold < price then
		return nil, "не хватает золота: нужно " .. price
	end
	state.levels[track] = state.levels[track] + 1
	return gold - price
end

-- Итоговые характеристики с учётом прокачки. Базовые значения — из баланса.
function M.stats(state)
	local lv = state.levels
	local b = balance.player
	return {
		max_hp = b.hp + lv.hp * balance.upgrades.hp.effect,
		weapon_damage = b.weapon.damage + lv.weaponDamage * balance.upgrades.weaponDamage.effect,
		max_charges = b.weapon.maxCharges + lv.maxAmmo * balance.upgrades.maxAmmo.effect,
	}
end

return M
