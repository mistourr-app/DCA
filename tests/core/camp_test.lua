local camp = require("core.camp")
local balance = require("core.data.balance")

local M = {}

local GOLD_AMOUNT = balance.cells.GOLD.amount

local function plain_row()
	return {
		[0] = { type = "EMPTY" },
		[1] = { type = "WALL" },
		[2] = { type = "GOLD" },
		[3] = { type = "HEAL" },
		[4] = { type = "EMPTY" },
	}
end

M["install price is a percent of current gold"] = function(t)
	local p = balance.camp.pricePercent
	t.equal(camp.install_price(1000), math.floor(1000 * p / 100), "процент от золота")
	t.equal(camp.install_price(0), 0, "ноль золота — ноль ценника")
end

M["cannot install without gold"] = function(t)
	local ok = camp.can_install(camp.new_state(), 0, plain_row())
	t.true_(not ok, "без золота нельзя")
end

M["cannot install on a row with enemies"] = function(t)
	local row = plain_row()
	row[4] = { type = "ENEMY", enemy = "TYPE_1" }
	local ok = camp.can_install(camp.new_state(), 1000, row)
	t.true_(not ok, "с врагом нельзя")
end

M["install charges the price, keeps walls, collects gold, converts the rest"] = function(t)
	local gold = 1000
	local res = camp.install(camp.new_state(), gold, plain_row())
	t.true_(res ~= nil, "установка прошла")
	t.equal(res.price, camp.install_price(gold), "ценник")
	t.equal(res.collected, GOLD_AMOUNT, "золото с клетки собрано")
	t.equal(res.gold, gold - res.price + GOLD_AMOUNT, "баланс после установки")
	t.equal(res.cells[1].type, "WALL", "стена остаётся")
	t.equal(res.cells[2].type, "CAMP", "золото становится лагерем")
	t.equal(res.cells[3].type, "CAMP", "лечение становится лагерем")
end

M["install does not modify the input row"] = function(t)
	local row = plain_row()
	camp.install(camp.new_state(), 1000, row)
	t.equal(row[2].type, "GOLD", "исходная клетка не изменилась")
end

M["exit starts the payment window of configured length"] = function(t)
	local st = camp.new_state()
	camp.exit(st)
	t.equal(st.pay_turns_left, balance.camp.payTurns, "длина окна")
end

M["payment is a percent of current gold each turn, only inside the window"] = function(t)
	local st = camp.new_state()
	local gold = 1000
	local g0, paid0 = camp.tick_payment(st, gold)
	t.equal(paid0, 0, "до выхода не платим")
	t.equal(g0, gold, "золото не менялось")
	camp.exit(st)
	local g1, paid1 = camp.tick_payment(st, gold)
	t.equal(paid1, math.floor(gold * balance.camp.payPercent / 100), "процент от золота")
	t.equal(g1, gold - paid1, "золото уменьшено")
end

M["spending inside the window lowers the next payment"] = function(t)
	local st = camp.new_state()
	camp.exit(st)
	local gold = 1000
	local g1, paid1 = camp.tick_payment(st, gold)
	local spent_gold = g1 - 300
	local _, paid2 = camp.tick_payment(st, spent_gold)
	t.true_(paid2 < paid1, "платёж считается от текущего золота")
end

M["window ends after payTurns payments"] = function(t)
	local st = camp.new_state()
	camp.exit(st)
	local gold = 10000
	for _ = 1, balance.camp.payTurns do
		gold = camp.tick_payment(st, gold)
	end
	t.equal(st.pay_turns_left, 0, "окно закрыто")
	local after, paid = camp.tick_payment(st, gold)
	t.equal(paid, 0, "после окна не платим")
	t.equal(after, gold, "золото не меняется")
end

M["payment never takes gold below zero"] = function(t)
	local st = camp.new_state()
	camp.exit(st)
	local g, paid = camp.tick_payment(st, 0)
	t.equal(g, 0, "ноль остаётся нулём")
	t.equal(paid, 0, "нечего списывать")
end

M["cannot install again while payment is running"] = function(t)
	local st = camp.new_state()
	camp.exit(st)
	local ok = camp.can_install(st, 1000, plain_row())
	t.true_(not ok, "окно оплаты не закрыто")
end

return M
