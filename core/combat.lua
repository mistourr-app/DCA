-- Бой (GDD §5.3). Урон всегда равен текущему HP атакующего
-- (ближний бой, атака «в спину», ответ врага) либо урону оружия (арбалет).
-- Бонусов и защиты в игре нет, поэтому урон проходит в HP целиком.

local M = {}

function M.apply_damage(hp, damage)
	return math.max(0, hp - damage)
end

function M.is_dead(hp)
	return hp <= 0
end

-- Ближний бой (GDD §5.3): одновременный обмен ударами.
-- Игрок наносит врагу урон, равный своему HP; враг наносит игроку урон, равный своему полному HP.
-- Ровно один погибает:
--   enemy_hp < player_hp  — враг погибает, игрок теряет enemy_hp и выживает;
--   иначе                 — игрок погибает (ничья тоже проигрыш игрока), HP врага уменьшается.
-- Возвращает новые значения: player_hp, enemy_hp.
function M.melee(player_hp, enemy_hp)
	local enemy_after = M.apply_damage(enemy_hp, player_hp)
	local player_after = M.apply_damage(player_hp, enemy_hp)
	return player_after, enemy_after
end

-- Выстрел из арбалета: враг не отвечает (GDD §5.3).
-- Возвращает новое значение enemy_hp.
function M.shot(enemy_hp, weapon_damage)
	return M.apply_damage(enemy_hp, weapon_damage)
end

-- Атака «в спину»: враг бьёт на свой текущий HP (GDD §5.3).
-- Возвращает новое значение player_hp.
function M.behind_attack(player_hp, enemy_hp)
	return M.apply_damage(player_hp, enemy_hp)
end

return M
