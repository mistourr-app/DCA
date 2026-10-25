-- View-registry: тип карты -> как он выглядит (docs/DEFOLD_INTEGRATION.md §5.3).
-- Символ и роли палитры; конкретные цвета живут в gui/palette.gui (пикер GUI), проверяются при старте (§5.6).
-- Новый тип карты добавляется строкой здесь, world.script/card.script не меняются.
local M = {}

M.EMPTY = { symbol = "", fill = "fill_neutral", ink = "ink_dark" }
M.WALL = { symbol = "#", fill = "fill_wall", ink = "ink_light" }
M.HEAL = { symbol = "+", fill = "fill_good", ink = "ink_dark" }
M.GOLD = { symbol = "$", fill = "fill_gold", ink = "ink_dark" }
M.ENEMY = { symbol = "E", fill = "fill_danger", ink = "ink_light" }
M.ATTACK_CELL = { symbol = "A", fill = "fill_attack", ink = "ink_light" }
M.CAMP = { symbol = "C", fill = "fill_camp", ink = "ink_dark" }
M.PLAYER = { symbol = "@", fill = "fill_player", ink = "ink_dark" }
M.BOSS = { symbol = "B", fill = "fill_danger", ink = "ink_light" }

return M
