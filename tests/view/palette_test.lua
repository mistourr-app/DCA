local palette = require("scripts.view.palette")
local style = require("scripts.view.style")

local M = {}

local function has(key)
	for _, k in ipairs(palette.KEYS) do
		if k == key then
			return true
		end
	end
	return false
end

-- Каждая карта берёт две роли: фон и текст. Цвета живут в gui/palette.gui;
-- список ролей ведёт scripts/view/palette.lua. Пропущенный узел = карта без цвета.
-- Рамка карты — индикация хода (border_step/border_jump), а не роль skin.
M["палитра: у каждой карты две роли"] = function(t)
	for type_, view in pairs(style) do
		t.equal(type(view.skin), "string", "нет skin у типа " .. type_)
		local fill, ink = palette.roles(view.skin)
		t.true_(has(fill), "нет роли " .. fill .. " для " .. type_)
		t.true_(has(ink), "нет роли " .. ink .. " для " .. type_)
	end
end

-- Список skin — тоже источник истины: роли обязаны быть даже для типа, которого ещё нет
-- в style.lua, иначе палитра молча разъедется с картами.
M["палитра: у каждого skin две роли"] = function(t)
	for _, skin in ipairs(palette.SKINS) do
		local fill, ink = palette.roles(skin)
		t.true_(has(fill), "нет роли " .. fill)
		t.true_(has(ink), "нет роли " .. ink)
	end
end

M["палитра: ключи уникальны"] = function(t)
	local seen = {}
	for _, key in ipairs(palette.KEYS) do
		t.true_(not seen[key], "дубль ключа " .. key)
		seen[key] = true
	end
end

-- Подсветки не привязаны к style, поэтому проверяются отдельно (world.script рисует их напрямую).
M["палитра: подсветки на месте"] = function(t)
	local keys = { "border_step", "border_jump", "dot", "vision", "spotted" }
	for _, key in ipairs(keys) do
		t.true_(has(key), "нет ключа " .. key)
	end
end

return M
