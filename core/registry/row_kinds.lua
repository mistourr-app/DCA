-- Реестр типов рядов (docs/ENTITY_REGISTRY.md §3.5, GDD §3.2).
-- generated = true: ряд строится генератором core/row_gen.
-- camp: ряд, который игрок превратил в лагерь (GDD §8). Генератором не создаётся.

local M = {}

M.normal = { label = "normal", generated = true, enemies_allowed = true, objects_allowed = true }
M.boss = { label = "boss", generated = false, enemies_allowed = false, objects_allowed = false }
M.checkpoint = { label = "checkpoint", generated = true, enemies_allowed = false, objects_allowed = false }
M.camp = { label = "camp", generated = false, enemies_allowed = false, objects_allowed = true }

return M
