-- Единственный источник правды для слоёв отрисовки поля (position.z).
-- Default-камера Defold рендерит только z в [-1..1]; объект вне диапазона молча не рисуется.
-- Больше z = ближе к камере; равный z = порядок не определён (docs/ENGINE_DEFOLD.md §3).
--
-- Порядок снизу вверх: клетки < подсветки клеток < карты актёров < пунктир < цифры.
-- Порядок зафиксирован тестом tests/view/layers_test.lua — менять только вместе с ним.
-- Слои, которые нужны координатору, лежат здесь, а не в world.script/board.lua/fx.lua.
--
-- Подпись карты — компонент label со своим z внутри GO (game_objects/card.go): итоговый z
-- подписи = z карты + LABEL_OFFSET. Значение LABEL_OFFSET обязано совпадать с position.z
-- компонента label в card.go.

local M = {}

M.CELL_FILL = 0.0 -- заливка клетки поля
M.THREAT = 0.1 -- оранжевый слой угрозы (видимость врагов)
M.SPOTTED = 0.15 -- красная клетка игрока, когда его видят
M.CELL_INK = 0.2 -- символ клетки (CELL_FILL + LABEL_OFFSET)
M.ACTOR = 0.3 -- карта актёра (игрок, босс)
M.ACTOR_INK = 0.5 -- символ актёра (ACTOR + LABEL_OFFSET)
M.DASH = 0.7 -- пунктир выстрела
M.POPUP = 0.8 -- всплывающие цифры

M.LABEL_OFFSET = M.CELL_INK - M.CELL_FILL

assert(M.LABEL_OFFSET == M.ACTOR_INK - M.ACTOR,
	"layers: подпись актёра должна использовать тот же LABEL_OFFSET, что и клетка")
assert(M.CELL_FILL < M.THREAT and M.THREAT < M.SPOTTED and M.SPOTTED < M.CELL_INK
	and M.CELL_INK < M.ACTOR and M.ACTOR < M.ACTOR_INK
	and M.ACTOR_INK < M.DASH and M.DASH < M.POPUP and M.POPUP <= 1,
	"layers: нарушен порядок слоёв z")

return M
