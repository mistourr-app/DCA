-- Смерть и возврат в точку возврата (GDD §8.4, §10).
-- Чистая логика. Состояние игрока: { hp, max_hp, energy, max_energy, charges, max_charges, gold, equipment }.
--
-- Правила:
--   возврат в лагерь (kind = "camp"): полное восстановление HP, энергии и зарядов;
--   возврат в чекпоинт или на старт (kind = "checkpoint" | "start"): без восстановления (GDD §9);
--   экипировка и золото сохраняются;
--   собранное и убитое не возвращается: журнал не откатывается (GDD §10).

local M = {}

-- Копия состояния игрока (исходная таблица не меняется).
local function copy(player)
	local out = {}
	for k, v in pairs(player) do
		if type(v) == "table" then
			local inner = {}
			for k2, v2 in pairs(v) do
				inner[k2] = v2
			end
			out[k] = inner
		else
			out[k] = v
		end
	end
	return out
end

-- Возвращает новое состояние игрока после смерти в точке возврата kind.
function M.respawn(player, kind)
	local out = copy(player)
	if kind == "camp" then
		out.hp = out.max_hp
		out.energy = out.max_energy
		out.charges = out.max_charges
	elseif kind ~= "checkpoint" and kind ~= "start" then
		return nil, "неизвестный вид точки возврата: " .. tostring(kind)
	end
	return out
end

return M
