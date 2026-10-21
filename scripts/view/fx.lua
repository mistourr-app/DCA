-- Одноразовые ГО поля (docs/DEFOLD_INTEGRATION.md §5.7): обводки ходов, пунктир выстрела,
-- оверлей угроз, всплывающие цифры. Созданные id живут в self.fx и удаляются в fx.clear.
-- Функции принимают контекст-скрипт self (паттерн из §5.7), состояния не хранят.
local layout = require("core.layout")
local highlight = require("core.highlight")

local BAR_URL = "#bar_factory"
local POPUP_URL = "#popup_factory"

-- Слои (position.z): обводки под картами-акторами (0.3) и поверх подписей клеток (0.2).
-- Карта слоёв — в world.script.
local Z_OUTLINE = 0.25
local Z_DASH = 0.7
local Z_POPUP = 0.8

local M = {}

-- Прямоугольник без надписи (обводка, точка пунктира, оверлей угрозы). Эфемерный: в self.fx.
function M.bar(self, cx, cy, w, h, color, z)
	local id = factory.create(BAR_URL, vmath.vector3(cx, cy, z))
	if id == nil then
		print("bar spawn failed: sprite buffer full (raise [sprite] max_count in game.project)")
		return
	end
	go.set_parent(id, self.rows_id, false)
	msg.post(id, "set", { width = w, height = h, color = color })
	table.insert(self.fx, id)
end

-- Обводка клетки: четыре полоски в зазоре между клетками. Координаты — пространство рядов.
function M.outline(self, cx, cy, w, h, color)
	local gap = self.cell_gap
	local border = self.border_width
	local ox = (w - gap) / 2 + border / 2
	local oy = (h - gap) / 2 + border / 2
	M.bar(self, cx, cy + oy, w, border, color, Z_OUTLINE)
	M.bar(self, cx, cy - oy, w, border, color, Z_OUTLINE)
	M.bar(self, cx - ox, cy, border, h, color, Z_OUTLINE)
	M.bar(self, cx + ox, cy, border, h, color, Z_OUTLINE)
end

-- Тонкая пунктирная линия от точки (ax, ay) до (bx, by), верхний слой. Пространство рядов.
function M.dashed(self, ax, ay, bx, by)
	for _, p in ipairs(highlight.dash_points(ax, ay, bx, by, self.dash_step)) do
		M.bar(self, p.x, p.y, self.dash_size, self.dash_size, self.pal.dot, Z_DASH)
	end
end

-- Оверлей угрозы поверх клетки: цвет с заданной непрозрачностью, в своём слое z.
function M.threat(self, cx, cy, h, color, alpha, z)
	M.bar(self, cx, cy, layout.CELL_W - self.cell_gap, h - self.cell_gap,
		vmath.vector4(color.x, color.y, color.z, alpha), z)
end

-- Всплывающая цифра над клеткой (x, y); kind — цвет из свойств popup.script,
-- dx — разброс при нескольких цифрах на одной клетке.
function M.popup(self, x, y, text, kind, dx)
	local px = layout.cell_x(x) + (dx or 0)
	local py = layout.world_center(y) + layout.row_height(y) * self.popup_y_factor
	local id = factory.create(POPUP_URL, vmath.vector3(px, py, Z_POPUP))
	if id == nil then
		print("popup create failed: label buffer full (raise [label] max_count in game.project)")
		return
	end
	go.set_parent(id, self.rows_id, false)
	msg.post(id, "show", { text = text, kind = kind })
end

-- Удаляет все эфемерные ГО и обнуляет список.
function M.clear(self)
	for _, id in ipairs(self.fx) do
		go.delete(id)
	end
	self.fx = {}
end

return M
