local journal = require("core.journal")

local M = {}

M["record stores changes and reports them"] = function(t)
	local j = journal.new(0)
	t.true_(journal.record(j, 3, 2, "pickup"), "запись")
	t.true_(journal.has(j, 3, 2, "pickup"), "есть")
	t.true_(not journal.has(j, 3, 2, "kill"), "другой тип не учтён")
	t.equal(journal.size(j), 1, "одна запись")
end

M["duplicate record does not grow the journal"] = function(t)
	local j = journal.new(0)
	journal.record(j, 3, 2, "kill")
	journal.record(j, 3, 2, "kill")
	t.equal(journal.size(j), 1, "дубликат не добавляется")
end

M["unknown kind is refused"] = function(t)
	local j = journal.new(0)
	local ok = journal.record(j, 1, 1, "teleport")
	t.true_(not ok, "неизвестный тип отклонён")
	t.equal(journal.size(j), 0, "журнал пуст")
end

M["rows below the return point are not recorded"] = function(t)
	local j = journal.new(10)
	t.true_(not journal.record(j, 9, 0, "pickup"), "ниже точки возврата")
	t.true_(journal.record(j, 10, 0, "pickup"), "на точке возврата")
end

M["moving the return point truncates older entries"] = function(t)
	local j = journal.new(0)
	journal.record(j, 1, 0, "pickup")
	journal.record(j, 5, 0, "kill")
	journal.record(j, 9, 0, "camp")
	t.true_(journal.set_return_row(j, 5), "новая точка")
	t.equal(journal.size(j), 2, "запись ряда 1 удалена")
	t.true_(not journal.has(j, 1, 0, "pickup"), "старая запись забыта")
	t.true_(journal.has(j, 5, 0, "kill"), "запись на точке сохранена")
end

M["return point cannot move down"] = function(t)
	local j = journal.new(8)
	t.true_(not journal.set_return_row(j, 3), "вниз нельзя")
end

return M
