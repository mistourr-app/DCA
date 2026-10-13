-- Смерть и возврат в точку возврата (GDD §8.4, §9, §10).
-- Чистая логика. Состояние игрока: { hp, max_hp, weapon = <состояние equipment>, gold, equipment }.
--
-- Правила:
--   возврат в лагерь (kind = "camp"), в чекпоинт или на старт: HP и заряды оружия восстанавливаются
--     полностью (GDD §9); перезарядка сбрасывается;
--   штраф: теряется death.goldPenaltyPercent процентов от текущего золота (временно 50%, GDD §10);
--   экипировка сохраняется;
--   смерть на ряду лагеря невозможна (на ряду лагеря нет врагов).
-- Пересоздание рядов выше точки возврата делает core/world (respawn_count), не этот модуль.

local balance = require("core.data.balance")
local equipment = require("core.equipment")

local M = {}

local function copy_weapon(w)
	local out = {}
	for k, v in pairs(w) do
		out[k] = v
	end
	return out
end

-- Сумма штрафа от текущего золота (округление вниз).
function M.gold_penalty(gold)
	return math.floor(gold * balance.death.goldPenaltyPercent / 100)
end

-- Возвращает новое состояние игрока после смерти в точке возврата kind.
-- Второе значение — потерянное золото (для лога и HUD).
function M.respawn(player, kind)
	if kind ~= "camp" and kind ~= "checkpoint" and kind ~= "start" then
		return nil, "неизвестный вид точки возврата: " .. tostring(kind)
	end
	local out = {}
	for k, v in pairs(player) do
		out[k] = v
	end
	local lost = M.gold_penalty(out.gold)
	out.gold = out.gold - lost
	out.hp = out.max_hp
	out.weapon = copy_weapon(player.weapon)
	equipment.restore(out.weapon)
	return out, lost
end

return M
