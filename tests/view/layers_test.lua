local layers = require("scripts.view.layers")

local M = {}

-- Порядок отрисовки снизу вверх, docs/DEFOLD_INTEGRATION.md §5.7.
M["z: поле под подсветками"] = function(t)
	t.true_(layers.CELL_FILL < layers.THREAT, "клетки под слоем угрозы")
	t.true_(layers.THREAT < layers.SPOTTED, "угроза под «вас видят»")
	t.true_(layers.SPOTTED < layers.CELL_INK, "«вас видят» под подписью клетки")
	t.true_(layers.CELL_INK < layers.OUTLINE, "подпись клетки под обводкой")
end

M["z: карты над подсветками"] = function(t)
	t.true_(layers.OUTLINE < layers.ACTOR, "обводки под картами актёров")
	t.true_(layers.ACTOR < layers.ACTOR_INK, "карта актёра под своей подписью")
end

M["z: пунктир и цифры выше карт"] = function(t)
	t.true_(layers.ACTOR_INK < layers.DASH, "карты под пунктиром")
	t.true_(layers.DASH < layers.POPUP, "пунктир под цифрами")
end

M["z: в диапазоне камеры"] = function(t)
	for name, z in pairs(layers) do
		if type(z) == "number" then
			t.true_(z >= 0 and z <= 1, "слой " .. name .. " вне 0..1: " .. tostring(z))
		end
	end
end

-- card.go поднимает компонент label на это значение; правится только вместе с layers.lua.
M["z: подписи используют один offset"] = function(t)
	t.equal(layers.LABEL_OFFSET, 0.2, "LABEL_OFFSET совпадает с z label в card.go")
	t.equal(layers.LABEL_OFFSET, layers.CELL_INK - layers.CELL_FILL, "offset подписи клетки")
	t.equal(layers.LABEL_OFFSET, layers.ACTOR_INK - layers.ACTOR, "offset подписи актёра")
end

return M
