-- Роли палитры: имена узлов gui/palette.gui -> цвета в self.pal collections/world.script.
-- Правило: цвета живут только здесь (GUI-редактор даёт пикер RGBA; у script properties
-- пикера нет — docs/ENGINE_DEFOLD.md §3b). Список ролей читает palette.gui_script при старте.
--
-- У каждой карты две роли: фон (fill_) и цвет текста (ink_). Цвет самой карты рамку больше
-- не задаёт: рамка — индикация хода, её цвета общие для всех карт (border_step/border_jump),
-- и рисуются они только у карт, на которые можно пойти.
-- Названия skin совпадают с полем skin в scripts/view/style.lua: новый тип карты —
-- строка в style.lua + две роли в palette.gui. Полноту проверяет tests/view/palette_test.lua.
local M = {}

M.SKINS = { "empty", "wall", "heal", "gold", "enemy", "attack", "camp", "player", "boss" }

-- Роли поля: рамки ходов, пунктир, угрозы — к картам не привязаны.
M.EFFECTS = { "border_step", "border_jump", "dot", "vision", "spotted" }

M.KEYS = {}
for _, key in ipairs(M.EFFECTS) do
	M.KEYS[#M.KEYS + 1] = key
end
for _, skin in ipairs(M.SKINS) do
	M.KEYS[#M.KEYS + 1] = "fill_" .. skin
	M.KEYS[#M.KEYS + 1] = "ink_" .. skin
end

-- Две роли карты по её skin: board берёт цвета отсюда и передаёт карте.
function M.roles(skin)
	return "fill_" .. skin, "ink_" .. skin
end

return M
