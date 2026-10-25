-- Роли палитры: имена узлов gui/palette.gui -> цвета в self.pal collections/world.script.
-- Правило: цвета живут только здесь (GUI-редактор даёт пикер RGBA; у script properties
-- пикера нет — docs/ENGINE_DEFOLD.md §3b). Список ролей читает palette.gui_script при старте.
--
-- У каждой карты три роли: фон (fill_), цвет текста (ink_) и цвет обводки (line_).
-- Наличие обводки — поле Alpha узла line_<skin> (0 — рамки нет), это поле GUI-узла,
-- а не 4-й компонент цвета (docs/ENGINE_DEFOLD.md §3b).
-- Названия skin совпадают с полем skin в scripts/view/style.lua: новый тип карты —
-- строка в style.lua + три узла в palette.gui. Полноту проверяет tests/view/palette_test.lua.
local M = {}

M.SKINS = { "empty", "wall", "heal", "gold", "enemy", "attack", "camp", "player", "boss" }

-- Роли эффектов поля (обводки хода, пунктир, угрозы) — не привязаны к картам.
M.EFFECTS = { "outline_step", "outline_jump", "dot", "vision", "spotted" }

M.KEYS = {}
for _, key in ipairs(M.EFFECTS) do
	M.KEYS[#M.KEYS + 1] = key
end
for _, skin in ipairs(M.SKINS) do
	M.KEYS[#M.KEYS + 1] = "fill_" .. skin
	M.KEYS[#M.KEYS + 1] = "ink_" .. skin
	M.KEYS[#M.KEYS + 1] = "line_" .. skin
end

-- Три роли карты по её skin: board берёт цвета отсюда и передаёт карте.
function M.roles(skin)
	return "fill_" .. skin, "ink_" .. skin, "line_" .. skin
end

return M
