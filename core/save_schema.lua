-- Схема сохранения и валидация (GDD §18, docs/AI_CODING_RULES.md §9).
-- Загруженные данные никогда не используются без валидации.
--
-- Версия 2 (GDD §11, §18):
--   seed           — seed мира (задаётся при старте, случайный);
--   respawn_count  — сколько раз игрок возрождался; входит в seed рядов выше точки возврата;
--   gold, upgrades — золото и прокачка;
--   return_point   — { kind, row, x, cells }, где cells — клетки ряда точки возврата
--                    (1-based, 5 строк: EMPTY | WALL | CAMP). Ряд точки возврата не пересоздаётся
--                    между сессиями, поэтому его содержимое хранится целиком.
--
-- Правила:
--   version должна совпадать с SCHEMA_VERSION, иначе сохранение отвергается целиком;
--   неизвестные ключи отбрасываются; отрицательные и нечисловые значения заменяются по умолчанию;
--   точка возврата камеры (camp) без корректных cells считается испорченной и заменяется на старт.

local upgrades = require("core.upgrades")
local grid = require("core.grid")

local M = {}

M.SCHEMA_VERSION = 2

local RETURN_KINDS = { start = true, camp = true, checkpoint = true }
local CELL_TYPES = { EMPTY = true, WALL = true, CAMP = true }

local function non_negative_int(v)
	return type(v) == "number" and v >= 0 and v == math.floor(v)
end

-- Значение по умолчанию для нового или испорченного сохранения.
function M.default()
	return {
		version = M.SCHEMA_VERSION,
		seed = 1,
		respawn_count = 0,
		gold = 0,
		upgrades = upgrades.new_state().levels,
		return_point = { kind = "start", row = 0, x = math.floor(grid.COLUMNS / 2) },
	}
end

local function valid_cells(cells)
	if type(cells) ~= "table" then
		return false
	end
	for i = 1, grid.COLUMNS do
		if not CELL_TYPES[cells[i]] then
			return false
		end
	end
	return true
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
	if non_negative_int(raw.respawn_count) then
		out.respawn_count = raw.respawn_count
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
		local rp = raw.return_point
		if rp.kind == "camp" and not valid_cells(rp.cells) then
			return out
		end
		out.return_point = { kind = rp.kind, row = rp.row, x = rp.x }
		if valid_cells(rp.cells) then
			out.return_point.cells = {}
			for i = 1, grid.COLUMNS do
				out.return_point.cells[i] = rp.cells[i]
			end
		end
	end
	return out
end

return M
