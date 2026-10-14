-- Базовый AI босса (GDD §12.5, профили из DR). Чистая логика.
-- Функции принимают состояние арены a (см. core/arena.lua) и возвращают решение.
--
-- Профили по HP-доле босса:
--   aggressive  > 60%   приоритет клеткам атаки
--   balanced    25–60%  смешанная оценка
--   defensive   <= 25%  приоритет лечению, штраф за клетку в колонке игрока
-- Босс не возвращается на предыдущую колонку, если есть альтернативы.

local balance = require("core.data.balance")

local M = {}

local COLUMNS = balance.board.columns

-- Профиль по HP-доле.
function M.profile(boss_hp, boss_max)
	local frac = boss_hp / boss_max
	if frac > 0.6 then
		return "aggressive"
	elseif frac > 0.25 then
		return "balanced"
	end
	return "defensive"
end

-- Допустимые колонки хода босса: ±1 от текущей, в пределах поля.
-- Предыдущую колонку исключаем, если есть альтернативы.
function M.moves(a)
	local out = {}
	for dx = -1, 1 do
		local nx = a.boss_x + dx
		if dx ~= 0 and nx >= 0 and nx < COLUMNS then
			table.insert(out, nx)
		end
	end
	if #out > 1 and a.prev_boss_x ~= nil then
		local filtered = {}
		for _, nx in ipairs(out) do
			if nx ~= a.prev_boss_x then
				table.insert(filtered, nx)
			end
		end
		if #filtered > 0 then
			out = filtered
		end
	end
	return out
end

-- Оценка клетки колонки x на ряду босса для данного профиля.
local function score(profile, cell, player_x, x)
	local s = 0
	if cell.type == "ATTACK_CELL" then
		s = profile == "aggressive" and 3 or (profile == "balanced" and 2 or 1)
	elseif cell.type == "HEAL" then
		s = profile == "defensive" and 3 or 0
	end
	if profile == "defensive" and x == player_x then
		s = s - 2
	end
	return s
end

-- Выбор колонки хода. Возвращает x (или текущую колонку, если ходить некуда).
function M.choose(a)
	local moves = M.moves(a)
	if #moves == 0 then
		return a.boss_x
	end
	local profile = M.profile(a.boss_hp, a.boss_max)
	local best, best_score = nil, nil
	for _, x in ipairs(moves) do
		local s = score(profile, a.boss_row[x] or { type = "EMPTY" }, a.player_x, x)
		if best_score == nil or s > best_score then
			best, best_score = x, s
		end
	end
	return best
end

return M
