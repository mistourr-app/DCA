-- Смерть и возврат в точку возврата (GDD §8.4, §9, §10).
-- Чистая логика. Состояние игрока: { hp, max_hp, weapon = <состояние equipment>, gold, equipment }.
--
-- Правила:
--   возврат в лагерь (kind = "camp"), в чекпоинт или на старт: HP и заряды оружия восстанавливаются
--     полностью (GDD §9, уточнено пользователем); перезарядка сбрасывается;
--   экипировка и золото сохраняются;
--   собранное и убитое не возвращается: журнал не откатывается (GDD §10).

local equipment = require("core.equipment")

local M = {}

local function copy_weapon(w)
	local out = {}
	for k, v in pairs(w) do
		out[k] = v
	end
	return out
end

-- Возвращает новое состояние игрока после смерти в точке возврата kind.
function M.respawn(player, kind)
	if kind ~= "camp" and kind ~= "checkpoint" and kind ~= "start" then
		return nil, "неизвестный вид точки возврата: " .. tostring(kind)
	end
	local out = {}
	for k, v in pairs(player) do
		out[k] = v
	end
	out.hp = out.max_hp
	out.weapon = copy_weapon(player.weapon)
	equipment.restore(out.weapon)
	return out
end

return M
