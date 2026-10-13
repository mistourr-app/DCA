-- Лагерь (GDD §8). Чистая логика: функции принимают и возвращают значения, без Defold API.
--
-- Установка (§8.1): на ряду без врагов, при золоте > 0. Ценник = floor(gold * camp.pricePercent / 100)
--   списывается при установке. Клетки ряда, кроме стен, становятся CAMP; золото с клеток
--   переходит игроку; остальное содержимое пропадает.
-- Выход (§8.3): бесплатен. Со следующего хода игрок платит floor(gold * camp.payPercent / 100)
--   в течение camp.payTurns ходов. Оплата не уводит золото ниже нуля.
--
-- Состояние лагеря: { pay_turns_left = number }. Золото хранится снаружи (в состоянии игрока).

local balance = require("core.data.balance")

local M = {}

local GOLD_AMOUNT = balance.cells.GOLD.amount

local function percent_of(gold, percent)
	return math.floor(gold * percent / 100)
end

function M.new_state()
	return { pay_turns_left = 0 }
end

-- Ценник установки при текущем золоте.
function M.install_price(gold)
	return percent_of(gold, balance.camp.pricePercent)
end

-- Можно ли поставить лагерь здесь. Возвращает true или false, причина.
-- row_cells: клетки текущего ряда; row_has_enemies берётся из них.
function M.can_install(state, gold, row_cells)
	if state.pay_turns_left > 0 then
		return false, "Camp payment is still running"
	end
	if gold <= 0 then
		return false, "No gold"
	end
	if M.install_price(gold) <= 0 then
		return false, "Camp costs nothing here"
	end
	for _, cell in pairs(row_cells) do
		if cell.type == "ENEMY" then
			return false, "Enemies on this row"
		end
	end
	return true
end

-- Установка лагеря. Возвращает новое золото, собранное золото, новые клетки ряда.
-- Исходная таблица клеток не меняется.
function M.install(state, gold, row_cells)
	local ok, reason = M.can_install(state, gold, row_cells)
	if not ok then
		return nil, reason
	end
	local price = M.install_price(gold)
	local collected = 0
	local cells = {}
	for x, cell in pairs(row_cells) do
		if cell.type == "GOLD" then
			collected = collected + GOLD_AMOUNT
			cells[x] = { type = "CAMP" }
		elseif cell.type == "WALL" then
			cells[x] = { type = "WALL" }
		else
			cells[x] = { type = "CAMP" }
		end
	end
	return {
		gold = gold - price + collected,
		collected = collected,
		price = price,
		cells = cells,
	}
end

-- Выход из лагеря: запускает окно оплаты.
function M.exit(state)
	state.pay_turns_left = balance.camp.payTurns
	return true
end

-- Один ход игрока в окне оплаты. Возвращает новое золото и списанную сумму.
-- Вне окна ничего не списывается.
function M.tick_payment(state, gold)
	if state.pay_turns_left <= 0 then
		return gold, 0
	end
	local paid = math.min(gold, percent_of(gold, balance.camp.payPercent))
	state.pay_turns_left = state.pay_turns_left - 1
	return gold - paid, paid
end

return M
