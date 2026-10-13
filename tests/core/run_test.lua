local run = require("core.run")
local world = require("core.world")
local equipment = require("core.equipment")

local M = {}

-- Мир на ряду 0 в колонке 2; rows — таблица { [y] = { [x] = клетка } }.
local function make(rows, hp)
	local w = world.new(1)
	w.pos = { x = 2, y = 0 }
	local player = { hp = hp or 20, max_hp = 20, gold = 0, weapon = equipment.new(3, 5) }
	return {
		world = w,
		player = player,
		get_row = function(y) return rows[y] end,
	}
end

local function has(events, type_)
	for _, e in ipairs(events) do
		if e.type == type_ then
			return e
		end
	end
	return nil
end

M["free step moves the player and costs no hp"] = function(t)
	local r = make({ [1] = { [2] = { type = "EMPTY" } } }, 10)
	local ok, events = run.step(r, 2, 1)
	t.true_(ok, "ход прошёл")
	t.equal(r.world.pos.y, 1, "игрок на ряду 1")
	t.equal(r.player.hp, 10, "HP не изменился")
	t.true_(has(events, "move") ~= nil, "есть событие move")
end

M["jump costs hp max(0, |dx|-1)"] = function(t)
	local r = make({ [1] = { [4] = { type = "EMPTY" } } }, 10)
	local ok = run.step(r, 4, 1)
	t.true_(ok, "прыжок с колонки 2 на 4 (dx 2)")
	t.equal(r.player.hp, 9, "стоит 1 HP: max(0, 2-1)")
end

M["refused step changes nothing"] = function(t)
	local r = make({ [1] = { [2] = { type = "WALL" } } }, 10)
	local ok, events = run.step(r, 2, 1)
	t.true_(not ok, "стена недоступна")
	t.equal(r.world.pos.y, 0, "позиция не изменилась")
	t.equal(r.player.hp, 10, "HP не изменился")
	t.true_(has(events, "refused") ~= nil, "есть событие refused")
end

M["gold cell adds gold and becomes empty"] = function(t)
	local r = make({ [1] = { [2] = { type = "GOLD" } } }, 10)
	local _, events = run.step(r, 2, 1)
	t.equal(r.player.gold, 10, "золото прибавлено")
	t.equal(r.get_row(1)[2].type, "EMPTY", "клетка опустела")
	t.true_(has(events, "gold") ~= nil, "событие gold")
end

M["heal cell restores hp but not above max"] = function(t)
	local r = make({ [1] = { [2] = { type = "HEAL" } } }, 18)
	run.step(r, 2, 1)
	t.equal(r.player.hp, 20, "не выше максимума")
end

M["behind attack: enemy on the same row that sees the player hits for its hp"] = function(t)
	local rows = {
		[0] = { [4] = { type = "ENEMY", enemy = "TYPE_1" } },
		[1] = { [2] = { type = "EMPTY" } },
	}
	local r = make(rows, 20)
	local ok, events = run.step(r, 2, 1)
	t.true_(ok, "ход прошёл")
	local b = has(events, "behind_attack")
	t.true_(b ~= nil, "событие атаки в спину")
	t.equal(b.damage, 4, "урон равен HP врага (TYPE_1 base 4)")
	t.equal(r.player.hp, 16, "игрок потерял 4 HP")
end

M["enemy behind wall cannot attack"] = function(t)
	local rows = {
		[0] = { [4] = { type = "ENEMY", enemy = "TYPE_1" }, [3] = { type = "WALL" } },
		[1] = { [2] = { type = "EMPTY" } },
	}
	local r = make(rows, 20)
	local _, events = run.step(r, 2, 1)
	t.true_(has(events, "behind_attack") == nil, "стена блокирует атаку")
	t.equal(r.player.hp, 20, "HP не изменился")
end

M["behind attack that kills the player ends the run with death"] = function(t)
	local rows = {
		[0] = { [4] = { type = "ENEMY", enemy = "TYPE_1", hp = 6 } },
		[1] = { [2] = { type = "EMPTY" } },
	}
	local r = make(rows, 5)
	local ok, events = run.step(r, 2, 1)
	t.true_(ok, "ход обработан")
	t.true_(has(events, "death") ~= nil, "смерть")
	t.equal(r.player.hp, 0, "HP 0")
	t.equal(r.world.pos.y, 0, "игрок не сдвинулся")
end

M["death on the move when hp does not cover the cost"] = function(t)
	-- враг бьёт на 1 HP, прыжок на 4 колонки стоит 3 HP: 2 - 1 = 1, затем 1 - 3 <= 0 — смерть
	local rows = {
		[0] = { [4] = { type = "ENEMY", enemy = "TYPE_1", hp = 1 } },
		[1] = { [0] = { type = "EMPTY" } },
	}
	local r = make(rows, 2)
	r.world.pos = { x = 2, y = 0 }
	local ok, events = run.step(r, 0, 1)
	t.true_(ok, "обработано")
	t.true_(has(events, "death") ~= nil, "смерть на ходу")
end

M["new row resets the shot flag and ticks recharge"] = function(t)
	local r = make({ [1] = { [2] = { type = "EMPTY" } } }, 10)
	r.player.weapon.fired_this_row = true
	run.step(r, 2, 1)
	t.true_(not r.player.weapon.fired_this_row, "флаг выстрела сброшен на новом ряду")
end

M["a turn that is refused does not tick recharge"] = function(t)
	local r = make({ [1] = { [2] = { type = "WALL" } } }, 10)
	equipment.use(r.player.weapon)
	equipment.use(r.player.weapon)
	equipment.use(r.player.weapon)
	local before = r.player.weapon.recharge_left
	run.step(r, 2, 1)
	t.equal(r.player.weapon.recharge_left, before, "отказ не тратит ход перезарядки")
end

return M
