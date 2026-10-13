-- Линия видимости врагов (GDD §3.5, §5.4).
-- Враг видит только по своему ряду. Стена между врагом и игроком блокирует видимость.
-- Форма обзора:
--   "row"   — все клетки своего ряда в пределах visionRange;
--   "sides" — только клетки по бокам: 1 <= |dx| <= visionRange (WARDEN).

local M = {}

-- enemy, player: { x = number, y = number }
-- enemy.vision: { range = number, shape = "row" | "sides" }
-- is_wall(x, y) -> boolean (по умолчанию стен нет)
function M.can_see(enemy, player, vision, is_wall)
	if enemy.y ~= player.y then
		return false
	end
	local dx = player.x - enemy.x
	local dist = math.abs(dx)
	if dist == 0 or dist > vision.range then
		return false
	end
	if vision.shape == "sides" and dist < 1 then
		return false
	end
	if is_wall then
		local step = dx > 0 and 1 or -1
		for x = enemy.x + step, player.x - step, step do
			if is_wall(x, enemy.y) then
				return false
			end
		end
	end
	return true
end

return M
