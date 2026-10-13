local world = require("core.world")
local row_gen = require("core.row_gen")
local balance = require("core.data.balance")

local M = {}

local MODES = world.MODES

M["new world starts in WORLD on the start checkpoint"] = function(t)
	local w = world.new(1)
	t.equal(w.mode, MODES.WORLD, "режим")
	t.equal(w.pos.y, 0, "ряд 0")
	t.equal(w.return_point.kind, "start", "стартовая точка")
	t.equal(row_gen.kind(0), "checkpoint", "ряд 0 — checkpoint по расписанию")
end

M["transition table: allowed moves"] = function(t)
	local w = world.new(1)
	t.true_(world.transition(w, MODES.CAMP), "WORLD -> CAMP")
	t.true_(world.transition(w, MODES.WORLD), "CAMP -> WORLD")
	t.true_(world.transition(w, MODES.BOSS), "WORLD -> BOSS")
	t.true_(world.transition(w, MODES.DEATH), "BOSS -> DEATH")
	t.true_(world.transition(w, MODES.WORLD), "DEATH -> WORLD")
end

M["transition table: forbidden moves are refused"] = function(t)
	local w = world.new(1)
	local ok = world.transition(w, MODES.CAMP)
	t.true_(ok, "WORLD -> CAMP")
	local ok2, err = world.transition(w, MODES.BOSS)
	t.true_(not ok2, "CAMP -> BOSS запрещён")
	t.true_(err ~= nil, "есть причина")
	t.equal(w.mode, MODES.CAMP, "режим не изменился")
end

M["move only in WORLD mode and only to a free step"] = function(t)
	local w = world.new(1)
	local ok = world.move(w, { x = w.pos.x, y = 1 })
	t.true_(ok, "прямо на ряд вверх")
	t.equal(w.pos.y, 1, "ряд 1")
	t.true_(not world.move(w, { x = w.pos.x, y = 3 }), "через ряд нельзя")
	world.transition(w, MODES.CAMP)
	t.true_(not world.move(w, { x = w.pos.x, y = 2 }), "в CAMP ходить нельзя")
end

M["return point cannot be above current row"] = function(t)
	local w = world.new(1)
	world.move(w, { x = w.pos.x, y = 1 })
	t.true_(not world.set_return_point(w, "camp", 5), "выше текущего ряда")
	t.true_(world.set_return_point(w, "camp", 1), "текущий ряд")
	t.equal(w.return_point.kind, "camp", "лагерь")
end

M["start point cannot be set manually"] = function(t)
	local w = world.new(1)
	t.true_(not world.set_return_point(w, "start", 0), "start нельзя задать")
end

M["death respawns at return point in WORLD"] = function(t)
	local w = world.new(1)
	world.move(w, { x = w.pos.x, y = 1 })
	world.set_return_point(w, "checkpoint", 1)
	world.move(w, { x = w.pos.x, y = 2 })
	world.move(w, { x = w.pos.x, y = 3 })
	world.transition(w, MODES.DEATH)
	t.true_(world.respawn(w), "respawn")
	t.equal(w.mode, MODES.WORLD, "режим WORLD")
	t.equal(w.pos.y, 1, "ряд точки возврата")
end

M["respawn only from DEATH"] = function(t)
	local w = world.new(1)
	t.true_(not world.respawn(w), "из WORLD нельзя")
end

M["boss victory moves to next checkpoint and makes it the return point"] = function(t)
	local period = balance.boss.period
	local w = world.new(1)
	-- идём до арены первого босса
	local arena_row = period - 2
	for y = 1, arena_row do
		world.move(w, { x = w.pos.x, y = y })
	end
	t.equal(row_gen.kind(w.pos.y), "boss", "игрок на арене")
	world.transition(w, MODES.BOSS)
	t.true_(world.boss_victory(w), "победа")
	t.equal(w.mode, MODES.WORLD, "обратно в WORLD")
	t.equal(row_gen.kind(w.pos.y), "checkpoint", "игрок на checkpoint")
	t.equal(w.return_point.kind, "checkpoint", "точка возврата — checkpoint")
	t.equal(w.return_point.row, w.pos.y, "точка возврата на этом ряду")
end

M["window has 2W+1 rows and is clipped at the bottom"] = function(t)
	local W = balance.memory.W
	local w = world.new(1)
	local lo, hi = world.window(w)
	t.equal(lo, 0, "внизу обрезано нулём")
	t.equal(hi, W, "вверх на W рядов")
	t.equal(world.window_size(w), W + 1, "размер окна у нижнего края")
	world.move(w, { x = w.pos.x, y = 1 })
	t.equal(world.window_size(w), W + 2, "вырос при подъёме на ряд 1")
end

M["window size does not grow with row index"] = function(t)
	local w = world.new(1)
	for y = 1, 2000 do
		t.true_(world.move(w, { x = w.pos.x, y = y }), "подъём на ряд " .. y)
	end
	t.true_(world.window_size(w) <= 2 * balance.memory.W + 1, "размер окна ограничен W")
	t.true_(world.in_window(w, w.pos.y), "текущий ряд в окне")
	t.true_(not world.in_window(w, 0), "нижние ряды вне окна")
end

return M
