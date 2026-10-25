-- Роли палитры: имена узлов gui/palette.gui и ключи self.pal в collections/world.script.
-- Цвета в коде не хранятся: источник — узлы palette.gui, которые правятся цветовым пикером
-- GUI-редактора (у script properties пикера нет, docs/ENGINE_DEFOLD.md §3b).
-- Список используется дважды: palette.gui_script читает по нему узлы, world.script проверяет
-- при старте, что все роли дошли. Покрытие ролей style.lua фиксирует tests/view/palette_test.lua.

local M = {}

M.KEYS = {
	"fill_neutral", "fill_wall", "fill_good", "fill_gold",
	"fill_danger", "fill_attack", "fill_camp", "fill_player",
	"ink_dark", "ink_light",
	"outline_step", "outline_jump", "outline_attack",
	"dot", "vision", "spotted",
}

return M
