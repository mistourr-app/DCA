-- Координаты поля: соседство и границы (GDD §5.1).
-- x — колонка (0..columns-1), y — номер ряда в мире (0 — стартовый, растёт вверх).
-- Ряды бесконечны вверх, поэтому верхней границы по y нет.

local balance = require("core.data.balance")

local M = {}

M.COLUMNS = balance.layout.columns

-- Колонка лежит на поле.
function M.in_columns(x)
	return x >= 0 and x < M.COLUMNS and x == math.floor(x)
end

-- Свободный шаг: соседняя колонка на следующем ряду (|dx| <= 1, dy = 1).
function M.is_free_step(from, to)
	return to.y == from.y + 1 and math.abs(to.x - from.x) <= 1
end

-- Стоимость прыжка в энергии: max(0, |dx| - 1) (GDD §5.1).
function M.jump_cost(from, to)
	return math.max(0, math.abs(to.x - from.x) - 1)
end

-- Клетки следующего ряда, достижимые из pos свободным шагом (до трёх, в границах поля).
function M.forward_neighbors(pos)
	local out = {}
	for dx = -1, 1 do
		local nx = pos.x + dx
		if M.in_columns(nx) then
			table.insert(out, { x = nx, y = pos.y + 1 })
		end
	end
	return out
end

-- Расстояние по колонкам между двумя клетками.
function M.column_distance(a, b)
	return math.abs(a.x - b.x)
end

return M
