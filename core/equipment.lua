-- Экипировка с зарядами (GDD §6, §7). Чистая логика, без Defold API.
--
-- Общий принцип для любого предмета с зарядами:
--   - каждое применение расходует 1 заряд;
--   - когда заряды исчерпаны полностью, предмет недоступен rechargeTurns ходов игрока;
--   - после перезарядки заряды восстанавливаются полностью;
--   - в лагере и при возврате после смерти заряды восстанавливаются полностью (GDD §8.4, §10).
--
-- Оружие дополнительно: не более shotsPerRow выстрелов за ряд; флаг сбрасывается при движении
-- на следующий ряд (GDD §5.1, §5.2).
--
-- Состояние: { charges, max_charges, recharge_turns, recharge_left, fired_this_row }.
-- Урон и дальность — не здесь: их задаёт вызывающий код (баланс + прокачка weaponDamage).

local M = {}

-- Новое состояние предмета. Заряды полные, перезарядки нет.
function M.new(max_charges, recharge_turns)
	assert(type(max_charges) == "number" and max_charges >= 1, "max_charges >= 1")
	assert(type(recharge_turns) == "number" and recharge_turns >= 1, "recharge_turns >= 1")
	return {
		charges = max_charges,
		max_charges = max_charges,
		recharge_turns = recharge_turns,
		recharge_left = 0,
		fired_this_row = false,
	}
end

function M.is_recharging(e)
	return e.recharge_left > 0
end

-- Можно ли применить предмет сейчас.
function M.can_use(e)
	if M.is_recharging(e) then
		return false, "Weapon is recharging"
	end
	if e.charges <= 0 then
		return false, "No charges left"
	end
	return true
end

-- Применение: расходует заряд. Если заряды кончились, запускается перезарядка.
function M.use(e)
	local ok, reason = M.can_use(e)
	if not ok then
		return false, reason
	end
	e.charges = e.charges - 1
	if e.charges == 0 then
		e.recharge_left = e.recharge_turns
	end
	return true
end

-- Выстрел из оружия: применение плюс ограничение один выстрел за ряд.
function M.can_fire(e)
	if e.fired_this_row then
		return false, "Already fired on this row"
	end
	return M.can_use(e)
end

function M.fire(e)
	local ok, reason = M.can_fire(e)
	if not ok then
		return false, reason
	end
	local used, why = M.use(e)
	if not used then
		return false, why
	end
	e.fired_this_row = true
	return true
end

-- Ход игрока прошёл: таймер перезарядки уменьшается на один.
-- Когда таймер доходит до нуля, заряды восстанавливаются полностью.
function M.tick(e)
	if e.recharge_left <= 0 then
		return
	end
	e.recharge_left = e.recharge_left - 1
	if e.recharge_left == 0 then
		e.charges = e.max_charges
	end
end

-- Переход на следующий ряд: флаг выстрела сбрасывается (GDD §5.2).
function M.new_row(e)
	e.fired_this_row = false
end

-- Полное восстановление: лагерь и возврат после смерти (GDD §8.4, §10).
function M.restore(e)
	e.charges = e.max_charges
	e.recharge_left = 0
	e.fired_this_row = false
end

return M
