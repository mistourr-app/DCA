-- Геометрия экрана: клетка поля <-> логические координаты (GDD §2, docs/ARCHITECTURE.md §7).
-- Чистая логика. Логическое разрешение 720x1280 (balance layout.*), начало координат снизу слева
-- (как в Defold). Ряд игрока стоит на фиксированной высоте PLAYER_Y, мир прокручивается по ряду игрока.

local balance = require("core.data.balance")

local M = {}

M.COLUMNS = balance.layout.columns
M.WIDTH = balance.layout.logicalWidth
M.HEIGHT = balance.layout.logicalHeight
M.CELL = math.floor(M.WIDTH / M.COLUMNS)
M.PLAYER_Y = math.floor(M.HEIGHT * 0.3)

-- Центр клетки колонки x по горизонтали.
function M.cell_x(x)
	return x * M.CELL + M.CELL / 2
end

-- Центр ряда row по вертикали, когда игрок стоит на ряду player_row.
function M.cell_y(row, player_row)
	return M.PLAYER_Y + (row - player_row) * M.CELL
end

-- Клетка под точкой (px, py) логических координат при игроке на ряду player_row.
-- Возвращает x, row или nil, если точка вне поля по горизонтали.
function M.cell_at(px, py, player_row)
	if px < 0 or px >= M.WIDTH then
		return nil
	end
	local x = math.floor(px / M.CELL)
	if x < 0 or x >= M.COLUMNS then
		return nil
	end
	local offset = math.floor((py - M.PLAYER_Y) / M.CELL + 0.5)
	return x, player_row + offset
end

-- Сколько рядов помещается по высоте ниже и выше игрока (для выбора окна отрисовки).
function M.rows_below()
	return math.ceil(M.PLAYER_Y / M.CELL) + 1
end

function M.rows_above()
	return math.ceil((M.HEIGHT - M.PLAYER_Y) / M.CELL) + 1
end

return M
