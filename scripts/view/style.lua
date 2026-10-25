-- View-registry: тип карты -> как он выглядит (docs/DEFOLD_INTEGRATION.md §5.3).
-- name — верхняя строка карты; skin — набор цветов в палитре (fill_/ink_/line_ + skin).
-- Сами цвета — узлы gui/palette.gui (пикер GUI), проверяются при старте (§5.6).
-- Значение под названием — данные клетки (HP, золото, урон): его собирает board.lua.
-- Новый тип карты = строка здесь + три узла в palette.gui; world.script/card.script не меняются.
local M = {}

M.EMPTY = { name = "", skin = "empty" }
M.WALL = { name = "Wall", skin = "wall" }
M.HEAL = { name = "Heal", skin = "heal" }
M.GOLD = { name = "Gold", skin = "gold" }
M.ENEMY = { name = "Enemy", skin = "enemy" }
M.ATTACK_CELL = { name = "Attack", skin = "attack" }
M.CAMP = { name = "Camp", skin = "camp" }
M.PLAYER = { name = "Player", skin = "player" }
M.BOSS = { name = "Boss", skin = "boss" }

return M
