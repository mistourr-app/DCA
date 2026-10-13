-- Схема сохранения и валидация (GDD §18, docs/AI_CODING_RULES.md §9).
-- Загруженные данные никогда не используются без валидации.
--
-- Правила:
--   version должна совпадать с SCHEMA_VERSION, иначе данные отвергаются целиком;
--   неизвестные ключи отбрасываются;
--   отрицательные и нечисловые значения заменяются значением по умолчанию;
--   ключи, которых нет в схеме (включая прототипные), не копируются.

local upgrades = require("core.upgrades")

local M = {}

M.SCHEMA_VERSION = 1

local function non_negative_int(v)
	return type(v) == "number" and v >= 0 and v == math.floor(v)
end

-- Значение по умолчанию для нового или испорченного сохранения.
function M.default()
	return {
		version = M.SCHEMA_VERSION,
		seed = 1,
		gold = 0,
		upgrades = upgrades.new_state().levels,
	}
end

-- Возвращает очищенную таблицу сохранения или nil и причину (несовпадение версии).
function M.validate(raw)
	if type(raw) ~= "table" then
		return nil, "сохранение не таблица"
	end
	if raw.version ~= M.SCHEMA_VERSION then
		return nil, "версия сохранения " .. tostring(raw.version) .. " не поддерживается"
	end
	local out = M.default()
	if type(raw.seed) == "number" and raw.seed == math.floor(raw.seed) then
		out.seed = raw.seed
	end
	if non_negative_int(raw.gold) then
		out.gold = raw.gold
	end
	if type(raw.upgrades) == "table" then
		for _, track in ipairs(upgrades.TRACKS) do
			local v = raw.upgrades[track]
			if non_negative_int(v) then
				out.upgrades[track] = v
			end
		end
	end
	return out
end

return M
