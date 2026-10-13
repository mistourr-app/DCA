-- Сохранения через sys.save / sys.load (GDD §18, docs/ARCHITECTURE.md §10).
-- Данные проходят core/save_schema.validate при загрузке. Здесь только ввод-вывод.

local save_schema = require("core.save_schema")

local M = {}

local PATH = sys.get_save_file("dungeon_card_crawler", "save")

-- Возвращает валидное сохранение и флаг, найдено ли сохранение.
function M.load()
	local raw = sys.load(PATH)
	if next(raw) == nil then
		return save_schema.default(), false
	end
	local data, err = save_schema.validate(raw)
	if data == nil then
		print("save rejected: " .. tostring(err))
		return save_schema.default(), false
	end
	return data, true
end

function M.write(data)
	return sys.save(PATH, data)
end

return M
