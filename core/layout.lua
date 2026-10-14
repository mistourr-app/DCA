-- Геометрия экрана: клетки поля <-> логические координаты (GDD §2, docs/ARCHITECTURE.md §7).
-- Чистая логика. Логическое разрешение 720x1280 (design/design.csv, раздел screen.*),
-- начало координат снизу слева.
--
-- Обычный режим: видны VISIBLE_ROWS рядов (ряд игрока внизу и ряды над ним), высота ряда CELL_H.
-- Режим боя на арене: видны только два ряда арены (ряд игрока и ряд босса). Высота каждого
-- ряда арены ARENA_H = CELL_H * arenaRowScale, поэтому два ряда занимают всё поле.

local design = require("core.data.design")
local balance = require("core.data.balance")

local M = {}

M.COLUMNS = balance.board.columns
M.WIDTH = design.screen.width
M.HEIGHT = design.screen.height
M.VISIBLE_ROWS = design.screen.visibleRows
M.MARGIN_TOP = design.screen.marginTop
M.MARGIN_BOTTOM = design.screen.marginBottom
M.ARENA_SCALE = design.screen.arenaRowScale

M.CELL_W = math.floor(M.WIDTH / M.COLUMNS)
M.CELL_H = math.floor((M.HEIGHT - M.MARGIN_TOP - M.MARGIN_BOTTOM) / M.VISIBLE_ROWS)
M.ARENA_H = M.CELL_H * M.ARENA_SCALE

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

-- Режим арены: два ряда по высоте ARENA_H. k = 0 — ряд игрока (внизу), k = 1 — ряд босса.
function M.arena_row_y(k)
	return M.MARGIN_BOTTOM + k * M.ARENA_H + M.ARENA_H / 2
end

-- Клетка арены под точкой (px, py). Возвращает x, k (0 — ряд игрока, 1 — ряд босса) или nil.
function M.arena_cell_at(px, py)
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
	local k = math.floor((py - M.MARGIN_BOTTOM) / M.ARENA_H)
	if k < 0 or k > 1 then
		return nil
	end
	return x, k
end

-- Смещения рядов, которые видны в обычном режиме: от ряда игрока вверх. Остальное — туман войны.
function M.visible_offsets()
	local out = {}
	for k = 0, M.VISIBLE_ROWS - 1 do
		table.insert(out, k)
	end
	return out
end

return M
