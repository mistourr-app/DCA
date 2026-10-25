-- Название и значение на картах (GDD: карта показывает имя и число под ним).
-- cell_view — чистая сборка строк, поэтому проверяется без движка: подставляем только палитру.
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

M["карта: цвета всегда есть"] = function(t)
	for _, cell in ipairs({
		{ type = "EMPTY" }, { type = "WALL" }, { type = "GOLD" },
		{ type = "HEAL" }, { type = "CAMP" }, { type = "ATTACK_CELL" },
		{ type = "ENEMY", enemy = "TYPE_1" },
	}) do
		local _, _, fill, ink, line = view(cell)
		t.true_(fill ~= nil, "нет цвета фона для " .. cell.type)
		t.true_(ink ~= nil, "нет цвета текста для " .. cell.type)
		t.true_(line ~= nil, "нет цвета обводки для " .. cell.type)
	end
end

-- Оверлей угрозы ужимается на толщину рамки: у пустой клетки рамки нет, ужать нечего.
M["подсветка: толщина рамки для оверлея угрозы"] = function(t)
	local self_ = fake_self()
	for _, key in ipairs(palette.KEYS) do
		self_.pal[key] = { w = 1 }
	end
	self_.outline_width = 3
	t.equal(board.cell_inset(self_, { type = "ENEMY", enemy = "TYPE_1" }), 3,
		"у врага рамка есть — подсветка ужимается")
	self_.pal.line_empty = { w = 0 }
	t.equal(board.cell_inset(self_, { type = "EMPTY" }), 0, "у пустой клетки рамки нет")
	t.equal(board.cell_inset(self_, nil), 0, "нет клетки — как пустая")
end

return M
