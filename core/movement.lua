-- Движение вперёд и правило «заперт» (GDD §5.1, §5.2).
-- Единственный ресурс движения — HP. Стоимость хода: grid.jump_cost (max(0, |dx| − 1)).
-- Ход допустим, только если после оплаты игрок остаётся жив: hp − cost ≥ 1.
--
-- Клетка следующего ряда, на которую можно шагнуть:
--   не WALL, и HP больше стоимости хода.
-- Клетка ENEMY — цель ближнего боя; ход на неё тоже требует HP больше стоимости (GDD §5.1).
-- Если ни одна клетка следующего ряда не допустима — игрок заперт и погибает (GDD §5.2).
--
-- row_above: таблица клеток следующего ряда { [x] = клетка }; nil означает пустой ряд.

local grid = require("core.grid")

local M = {}

local function cell_at(row, x)
	if row == nil then
		return nil
	end
	return row[x]
end

local function is_blocked(cell)
	return cell ~= nil and cell.type == "WALL"
end

-- Допустимые цели на следующем ряду: список { x, y, cost, cell_type }.
function M.options(pos, hp, row_above)
	local out = {}
	for x = 0, grid.COLUMNS - 1 do
		local target = { x = x, y = pos.y + 1 }
		local cost = grid.jump_cost(pos, target)
		local cell = cell_at(row_above, x)
		if not is_blocked(cell) and hp - cost >= 1 then
			table.insert(out, {
				x = x,
				y = target.y,
				cost = cost,
				cell_type = cell and cell.type or "EMPTY",
			})
		end
	end
	return out
end

-- Игрок заперт: ни одного допустимого хода на следующий ряд.
function M.is_stuck(pos, hp, row_above)
	return #M.options(pos, hp, row_above) == 0
end

-- Выполнить ход на цель (x, y) следующего ряда. Возвращает новое hp и новую позицию,
-- либо nil и причину. Вызывающий код проверяет смерть отдельно: stuck и hp <= 0.
function M.step(pos, hp, row_above, x, y)
	for _, opt in ipairs(M.options(pos, hp, row_above)) do
		if opt.x == x and opt.y == y then
			return hp - opt.cost, { x = x, y = y }
		end
	end
	return nil, "ход недопустим: стена, нехватка HP или не следующий ряд"
end

return M
