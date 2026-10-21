-- Геометрия экрана: клетки поля <-> логические координаты (GDD §2, docs/ARCHITECTURE.md §7).
-- Чистая логика. Логическое разрешение 720x1560 (design/design.csv, раздел screen.*),
-- начало координат снизу слева.
--
-- Поле — контейнер рядов: клетки живут в «пространстве рядов» (координата вверх по номеру
-- ряда), контейнер сдвигается так, чтобы ряд игрока стоял у нижнего края поля. Питч рядов
-- неоднороден: обычные ряды CELL_H, ряды арены (kind = "boss") ARENA_H = CELL_H * arenaRowScale.
-- Карта высот — кусочно-линейная формула по номеру ряда, без хранения промежуточных значений.

local design = require("core.data.design")
local balance = require("core.data.balance")
local row_gen = require("core.row_gen")

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
-- Высота игрового поля между отступами.
M.FIELD_H = M.HEIGHT - M.MARGIN_TOP - M.MARGIN_BOTTOM

local PERIOD = balance.boss.period
local ARENA_ROWS = balance.boss.arenaRows
local NORMAL_BAND = PERIOD - ARENA_ROWS
-- Высота одного цикла периода: обычные ряды + ряды арены.
local CYCLE_H = NORMAL_BAND * M.CELL_H + ARENA_ROWS * M.ARENA_H

-- Высота ряда по его номеру: ряды арены вдвое выше обычных (GDD §12.1).
function M.row_height(row)
	if row_gen.kind(row) == "boss" then
		return M.ARENA_H
	end
	return M.CELL_H
end

-- Нижний край ряда в пространстве рядов (row 0 начинается с 0). Сумма высот рядов ниже row.
function M.world_bottom(row)
	assert(type(row) == "number" and row >= 0 and row == math.floor(row), "world_bottom: ряд — неотрицательное целое")
	local p = math.floor(row / PERIOD)
	local r = row - p * PERIOD
	if r <= NORMAL_BAND then
		return p * CYCLE_H + r * M.CELL_H
	end
	return p * CYCLE_H + NORMAL_BAND * M.CELL_H + (r - NORMAL_BAND) * M.ARENA_H
end

-- Центр ряда в пространстве рядов.
function M.world_center(row)
	return M.world_bottom(row) + M.row_height(row) / 2
end

-- Позиция контейнера рядов по y, при которой ряд игрока стоит у нижнего края поля.
function M.container_y(player_row)
	return M.MARGIN_BOTTOM - M.world_bottom(player_row)
end

-- Экранный центр ряда row при игроке на player_row.
function M.screen_center(row, player_row)
	return M.MARGIN_BOTTOM + (M.world_bottom(row) - M.world_bottom(player_row)) + M.row_height(row) / 2
end

-- Центр клетки колонки x по горизонтали.
function M.cell_x(x)
	return x * M.CELL_W + M.CELL_W / 2
end

-- Видимые ряды от ряда игрока вверх: ряд входит, если его нижний край начался в поле.
-- Верхний ряд может быть виден частично (переход к высокой арене), дальше — туман войны.
function M.visible_rows(player_row)
	local out = {}
	local y = player_row
	local acc = 0
	while acc < M.FIELD_H do
		table.insert(out, y)
		acc = acc + M.row_height(y)
		y = y + 1
	end
	return out
end

-- Вписывание логического экрана в окно с сохранением пропорций и safe area.
-- safe_area — таблица window.get_safe_area() (x, y, width, height) или nil.
-- Возвращает масштаб и прямоугольник контента в координатах окна (снизу слева).
function M.screen_fit(window_w, window_h, safe_area)
	if type(window_w) ~= "number" or type(window_h) ~= "number" then
		return nil
	end
	if window_w <= 0 or window_h <= 0 then
		return nil
	end
	local x, y, w, h = 0, 0, window_w, window_h
	if type(safe_area) == "table" and safe_area.width and safe_area.height then
		local sx = safe_area.x or 0
		local sy = safe_area.y or 0
		local sw = safe_area.width
		local sh = safe_area.height
		if sw > 0 and sh > 0 then
			x = math.max(0, sx)
			y = math.max(0, sy)
			w = math.min(sw, window_w - x)
			h = math.min(sh, window_h - y)
		end
	end
	if w <= 0 or h <= 0 then
		x, y, w, h = 0, 0, window_w, window_h
	end
	local scale = math.min(w / M.WIDTH, h / M.HEIGHT)
	local width = M.WIDTH * scale
	local height = M.HEIGHT * scale
	return {
		scale = scale,
		left = x + (w - width) / 2,
		bottom = y + (h - height) / 2,
		width = width,
		height = height,
	}
end

-- Точка окна -> логические координаты. nil, если точка вне вписанного экрана.
function M.screen_to_design(px, py, fit)
	if fit == nil or fit.scale <= 0 then
		return nil
	end
	local x = (px - fit.left) / fit.scale
	local y = (py - fit.bottom) / fit.scale
	if x < 0 or x >= M.WIDTH or y < 0 or y >= M.HEIGHT then
		return nil
	end
	return x, y
end

-- Клетка под точкой (px, py) при игроке на ряду player_row.
-- Возвращает x, row или nil, если точка вне поля (горизонталь, ниже поля, выше поля/HUD).
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
	local cur = M.MARGIN_BOTTOM
	local y = player_row
	while cur < M.HEIGHT - M.MARGIN_TOP do
		local h = M.row_height(y)
		if py < cur + h then
			return x, y
		end
		cur = cur + h
		y = y + 1
	end
	return nil
end

return M
