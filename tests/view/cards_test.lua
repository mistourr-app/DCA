-- Название и значение на картах (GDD: карта показывает имя и число под ним),
-- а также рамка карты — она кодирует не тип клетки, а вид хода.
-- cell_view / card_msg — чистая сборка, поэтому проверяются без движка: подставляем палитру.
local board = require("scripts.view.board")
local palette = require("scripts.view.palette")

local M = {}

-- Палитра приходит из gui/palette.gui только в движке: здесь подставляем «цвет есть».
local function fake_self()
	local pal = {}
	for _, key in ipairs(palette.KEYS) do
		pal[key] = true
	end
	return { pal = pal }
end

local function view(cell)
	return board.cell_view(fake_self(), cell)
end

M["карта: пустая клетка без текста"] = function(t)
	local name, value = view({ type = "EMPTY" })
	t.equal(name, "", "у пустой клетки нет названия")
	t.equal(value, "", "у пустой клетки нет значения")
end

M["карта: стена подписана, значения нет"] = function(t)
	local name, value = view({ type = "WALL" })
	t.equal(name, "Wall", "название стены")
	t.equal(value, "", "у стены нет значения")
end

M["карта: золото и лечение показывают сумму"] = function(t)
	local gold_name, gold_value = view({ type = "GOLD" })
	t.equal(gold_name, "Gold", "название золота")
	t.equal(gold_value, "10", "сумма золота из balance.csv")

	local heal_name, heal_value = view({ type = "HEAL" })
	t.equal(heal_name, "Heal", "название лечения")
	t.equal(heal_value, "6", "лечение из balance.csv")
end

M["карта: враг — имя из реестра и HP"] = function(t)
	local name, value = view({ type = "ENEMY", enemy = "TYPE_1", hp = 4 })
	t.equal(name, "Arcanist", "имя врага в обычном регистре")
	t.equal(value, "4", "текущий HP")

	local _, base = view({ type = "ENEMY", enemy = "TYPE_3" })
	t.equal(base, "10", "без hp берётся базовый HP типа")
end

M["карта: ловушка арены показывает урон"] = function(t)
	local name, value = view({ type = "ATTACK_CELL", damage = 7 })
	t.equal(name, "Attack", "название клетки-ловушки")
	t.equal(value, "7", "урон клетки")
end

M["карта: фон и текст есть у всех типов"] = function(t)
	for _, cell in ipairs({
		{ type = "EMPTY" }, { type = "WALL" }, { type = "GOLD" },
		{ type = "HEAL" }, { type = "CAMP" }, { type = "ATTACK_CELL" },
		{ type = "ENEMY", enemy = "TYPE_1" },
	}) do
		local _, _, fill, ink = view(cell)
		t.true_(fill ~= nil, "нет цвета фона для " .. cell.type)
		t.true_(ink ~= nil, "нет цвета текста для " .. cell.type)
	end
end

-- Рамка карты — индикация хода: цвет берётся из роли вида хода, а не из skin карты.
M["рамка: цвет и толщина зависят от вида хода, а не от клетки"] = function(t)
	local self_ = fake_self()
	self_.pal.border_step = "зелёная роль"
	self_.pal.border_jump = "фиолетовая роль"
	self_.card_border = 3
	self_.cell_gap = 8
	local step = board.card_msg(self_, 1, 0, "Wall", "", "fill", "ink", "step")
	t.equal(step.border_color, "зелёная роль", "шаг — цвет шага")
	t.equal(step.border_width, 3, "толщина из geom_cfg.card_border")
	local jump = board.card_msg(self_, 1, 0, "Wall", "", "fill", "ink", "jump")
	t.equal(jump.border_color, "фиолетовая роль", "прыжок — цвет прыжка")
	local none = board.card_msg(self_, 1, 0, "Wall", "", "fill", "ink", nil)
	t.equal(none.border_color, nil, "нет хода — рамки нет")
end

-- Оверлей угрозы ужимается на толщину рамки, а рамка есть только у целей хода.
M["подсветка: толщина рамки для оверлея угрозы"] = function(t)
	local self_ = fake_self()
	self_.card_border = 3
	self_.moves = { [1] = { [3] = "step" } }
	t.equal(board.cell_inset(self_, 3, 1), 3, "клетка — цель хода: подсветка ужимается")
	t.equal(board.cell_inset(self_, 4, 1), 0, "соседняя клетка не цель хода — рамки нет")
	t.equal(board.cell_inset(self_, 0, 5), 0, "ряд без ходов — рамки нет")
	t.equal(board.cell_inset(self_, nil, nil), 0, "нет клетки — как без рамки")
end

return M
