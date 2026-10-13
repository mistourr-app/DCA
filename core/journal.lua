-- Журнал изменений рядов (GDD §11.2, docs/ARCHITECTURE.md §6).
-- Хранит, что уже собрано, убито или превращено в лагерь. Записи нужны, чтобы после смерти
-- не возвращалось золото и не воскресали враги (GDD §10).
-- Журнал хранит только ряды на или выше последней точки возврата: ниже неё игрок не попадёт
-- (возврат всегда на точку возврата), поэтому записи ниже удаляются.
--
-- Запись: { row = y, x = колонка, kind = "pickup" | "kill" | "camp" }.
-- Ключ записи (row, x, kind) уникален: повторная запись не дублирует изменение.

local M = {}

local KINDS = { pickup = true, kill = true, camp = true }

-- Пустой журнал. return_row — ряд последней точки возврата (0 для старта).
function M.new(return_row)
	return { return_row = return_row or 0, entries = {}, keys = {} }
end

local function key(row, x, kind)
	return row .. ":" .. x .. ":" .. kind
end

-- Записывает изменение. Возвращает false, если ряд ниже точки возврата или kind неизвестен.
function M.record(j, row, x, kind)
	if not KINDS[kind] then
		return false, "неизвестный тип изменения: " .. tostring(kind)
	end
	if row < j.return_row then
		return false, "ряд ниже точки возврата не журналируется"
	end
	local k = key(row, x, kind)
	if j.keys[k] then
		return true
	end
	j.keys[k] = true
	table.insert(j.entries, { row = row, x = x, kind = kind })
	return true
end

-- Изменения клетки (row, x) уже учтены: клетка собрана, враг убит, лагерь стоит.
function M.has(j, row, x, kind)
	return j.keys[key(row, x, kind)] == true
end

-- Новая точка возврата на ряду row: журнал обрезается до этого ряда (включительно).
-- Записи ниже удаляются, так как после смерти игрок не может туда попасть.
function M.set_return_row(j, row)
	if row < j.return_row then
		return false, "точка возврата не может опуститься"
	end
	j.return_row = row
	local kept = {}
	j.keys = {}
	for _, e in ipairs(j.entries) do
		if e.row >= row then
			table.insert(kept, e)
			j.keys[key(e.row, e.x, e.kind)] = true
		end
	end
	j.entries = kept
	return true
end

function M.size(j)
	return #j.entries
end

return M
