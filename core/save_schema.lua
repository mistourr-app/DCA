-- Схема сохранения и валидация (GDD §18, docs/AI_CODING_RULES.md §9).
-- Загруженные данные никогда не используются без валидации.
--
-- Правила:
--   version должна совпадать с SCHEMA_VERSION, иначе данные отвергаются целиком;
--   неизвестные ключи отбрасываются;
--   отрицательные и нечисловые значения заменяются значением по умолчанию;
--   точка возврата проверяется по виду и границам поля;
--   ключи, которых нет в схеме (включая прототипные), не копируются.

local upgrades = require("core.upgrades")
local grid = require("core.grid")

local M = {}

M.SCHEMA_VERSION = 1

local RETURN_KINDS = { start = true, camp = true, checkpoint = true }

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
		return_point = { kind = "start", row = 0, x = math.floor(grid.COLUMNS / 2) },
	}
end

local function valid_return_point(rp)
	return type(rp) == "table"
		and RETURN_KINDS[rp.kind] == true
		and non_negative_int(rp.row)
		and non_negative_int(rp.x)
		and rp.x < grid.COLUMNS
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
	if valid_return_point(raw.return_point) then
		out.return_point = { kind = raw.return_point.kind, row = raw.return_point.row, x = raw.return_point.x }
	end
	return out
end

return M
