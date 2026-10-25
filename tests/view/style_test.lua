-- View-registry карт: у каждого типа есть название, значение собирается из данных.
-- Проверяем то, что иначе всплывёт только глазами: пустая верхняя строка на карте.
local style = require("scripts.view.style")
local naming = require("scripts.view.naming")

local M = {}

M["карта: у каждого типа есть название"] = function(t)
	for type_, view in pairs(style) do
		t.equal(type(view.name), "string", "нет названия у типа " .. type_)
	end
end

-- Пустая клетка обязана выглядеть пустой: иначе на поле появится слово «Empty».
M["карта: пустая клетка без названия"] = function(t)
	t.equal(style.EMPTY.name, "", "у EMPTY пустое название")
end

-- Свой skin у каждого типа = свои фон/текст/обводка. Общий skin на два типа означал бы,
-- что карты нельзя раскрасить независимо — ровно то, зачем палитра разделена по картам.
M["карта: у каждого типа свой skin"] = function(t)
	local seen = {}
	for type_, view in pairs(style) do
		t.equal(type(view.skin), "string", "нет skin у типа " .. type_)
		t.true_(not seen[view.skin], "skin повторяется: " .. view.skin .. " (" .. type_ .. ")")
		seen[view.skin] = true
	end
end

-- balance.csv хранит названия врагов капсом; на карте они идут в обычном регистре.
M["карта: имя врага из CSV в обычном регистре"] = function(t)
	t.equal(naming.display_name("ARCANIST"), "Arcanist", "одно слово")
	t.equal(naming.display_name("DARK WARDEN"), "Dark Warden", "два слова")
	t.equal(naming.display_name("WARDEN"), "Warden", "короткое имя")
	t.equal(naming.display_name(""), "", "пустое имя остаётся пустым")
end

return M
