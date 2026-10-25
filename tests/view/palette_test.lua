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

-- Каждая роль style.lua обязана иметь цвет в палитре: иначе на экране будет nil-цвет.
-- Цвета живут в gui/palette.gui; список ключей — scripts/view/palette.lua.
M["палитра: роли style покрыты"] = function(t)
	for type_, view in pairs(style) do
		t.true_(has(view.fill), "нет цвета для fill " .. type_ .. " -> " .. view.fill)
		t.true_(has(view.ink), "нет цвета для ink " .. type_ .. " -> " .. view.ink)
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
	local keys = { "outline_step", "outline_jump", "outline_attack", "dot", "vision", "spotted" }
	for _, key in ipairs(keys) do
		t.true_(has(key), "нет ключа " .. key)
	end
end

return M
