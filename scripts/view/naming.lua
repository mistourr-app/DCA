-- Показ названий сущностей на картах (docs/DEFOLD_INTEGRATION.md §5.3).
-- Данные в balance.csv/реестре хранятся капсом (ARCANIST, DARK WARDEN) — это константы
-- правил, их не трогаем. На карте название должно читаться как имя: «Arcanist».
-- Функция чистая, без состояния: её же можно использовать для HUD и подсказок.

local M = {}

-- «ARCANIST» -> «Arcanist», «DARK WARDEN» -> «Dark Warden», «WARDEN» -> «Warden».
function M.display_name(label)
	if label == nil or label == "" then
		return ""
	end
	local lower = label:lower()
	return (lower:gsub("^%l", string.upper):gsub("%s%l", string.upper))
end

return M
