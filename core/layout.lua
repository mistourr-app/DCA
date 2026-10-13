-- Геометрия экрана: клетки поля <-> логические координаты (GDD §2, docs/ARCHITECTURE.md §7).
-- Чистая логика. Логическое разрешение 720x1280 (design/design.csv, раздел screen.*), начало координат снизу слева.
--
-- Видимы VISIBLE_ROWS рядов: ряд игрока (k = 0, внизу поля) и ряды над ним (k = 1..VISIBLE_ROWS-1).
-- Остальные ряды не рисуются (туман войны). Клетки растянуты по высоте, чтобы поле занимало
-- экран между MARGIN_BOTTOM и HEIGHT - MARGIN_TOP.

local balance = require("core.data.balance")
local design = require("core.data.design")

local M = {}

M.COLUMNS = balance.board.columns
M.WIDTH = design.screen.width
M.HEIGHT = design.screen.height
M.VISIBLE_ROWS = design.screen.visibleRows
M.MARGIN_TOP = design.screen.marginTop
M.MARGIN_BOTTOM = design.screen.marginBottom

M.CELL_W = math.floor(M.WIDTH / M.COLUMNS)
M.CELL_H = math.floor((M.HEIGHT - M.MARGIN_TOP - M.MARGIN_BOTTOM) / M.VISIBLE_ROWS)

-- Центр клетки колонки x по горизонтали.
function M.cell_x(x)
	return x * M.CELL_W + M.CELL_W / 2
end

-- Центр ряда k (0 — ряд игрока, 1..VISIBLE_ROWS-1 — ряды над ним) по вертикали.
function M.row_y(k)
	return M.MARGIN_BOTTOM + k * M.CELL_H + M.CELL_H / 2
end

-- Центр ряда row по вертикали при игроке на ряду player_row.
function M.cell_y(row, player_row)
	return M.row_y(row - player_row)
end

-- Клетка под точкой (px, py) при игроке на ряду player_row.
-- Возвращает x, row или nil, если точка вне поля (по горизонтали, ниже или выше видимой области).
function M.cell_at(px, py, player_row)
	if px < 0 or px >= M.WIDTH then
		return nil
	end
	if py < M.MARGIN_BOTTOM or py >= M.HEIGHT - M.MARGIN_TOP then
		return nil
	end
	local x = math.floor(px / M.CELL_W)
	if x < 0 or x >= M.COLUMNS then
		return nil
	end
	local k = math.floor((py - M.MARGIN_BOTTOM) / M.CELL_H)
	if k < 0 or k >= M.VISIBLE_ROWS then
		return nil
	end
	return x, player_row + k
end

-- Смещения рядов, которые видны: от ряда игрока вверх. Ряды вне этого диапазона — туман.
function M.visible_offsets()
	local out = {}
	for k = 0, M.VISIBLE_ROWS - 1 do
		table.insert(out, k)
	end
	return out
end

return M
