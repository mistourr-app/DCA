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

M["step onto a row with no cells does not crash"] = function(t)
	local r = make({ [1] = {} }, 10)
	local ok = run.step(r, 2, 1)
	t.true_(ok, "ход на ряд без клеток не падает")
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


M["melee: player hits for its hp, enemy answers with its rest"] = function(t)
	local rows = {
		[0] = { [2] = { type = "EMPTY" } },
		[1] = { [2] = { type = "ENEMY", enemy = "TYPE_2" } },
	}
	local r = make(rows, 3)
	-- игрок 3 бьёт врага 7 -> остаток 4; враг отвечает 4 -> игрок 3 - 4 — смерть
	local ok, events = run.melee(r, 2, 1)
	t.true_(ok, "бой прошёл")
	local p = has(events, "poke")
	t.equal(p.dealt_to_enemy, 3, "игрок бьёт на свой HP")
	t.equal(p.enemy_hp, 4, "у врага остаётся 4")
	t.equal(p.dealt_to_player, 4, "враг отвечает остатком")
end

M["melee kills a weak enemy and leaves the player unhurt"] = function(t)
	local rows = {
		[0] = { [2] = { type = "EMPTY" } },
		[1] = { [2] = { type = "ENEMY", enemy = "TYPE_1", hp = 2 } },
	}
	local r = make(rows, 10)
	local _, events = run.melee(r, 2, 1)
	t.true_(has(events, "enemy_dead") ~= nil, "враг мёртв")
	t.equal(r.get_row(1)[2].type, "EMPTY", "клетка опустела")
	t.equal(r.player.hp, 10, "враг не ответил: погиб от первого удара")
	t.equal(r.world.pos.y, 0, "игрок остался на своей клетке (GDD 5.3 п.4)")
end

M["melee: enemy answers with its remaining hp"] = function(t)
	local rows = {
		[0] = { [2] = { type = "EMPTY" } },
		[1] = { [2] = { type = "ENEMY", enemy = "TYPE_2", hp = 7 } },
	}
	local r = make(rows, 3)
	-- игрок 3 бьёт врага 7 -> 4 HP; враг отвечает 4 -> игрок 3-4 = 0 — смерть
	local _, events = run.melee(r, 2, 1)
	t.true_(has(events, "death") ~= nil, "игрок погибает от ответа")
end

M["melee refused without enough hp for the approach"] = function(t)
	local rows = {
		[0] = { [2] = { type = "EMPTY" } },
		[1] = { [4] = { type = "ENEMY", enemy = "TYPE_1" } },
	}
	local r = make(rows, 3)
	-- dx 2 стоит 1 HP; при HP 1 после перехода было бы 0 — отказ
	r.player.hp = 1
	local ok = run.melee(r, 4, 1)
	t.true_(not ok, "переход на HP 1 недоступен")
end

M["melee on an empty cell is refused"] = function(t)
	local r = make({ [1] = { [2] = { type = "EMPTY" } } }, 10)
	local ok = run.melee(r, 2, 1)
	t.true_(not ok, "нет врага")
end

M["shot hits an enemy on the same row without a reply"] = function(t)
	local rows = {
		[0] = { [4] = { type = "ENEMY", enemy = "TYPE_2" } },
	}
	local r = make(rows, 10)
	local ok, events = run.shoot(r, 4)
	t.true_(ok, "выстрел прошёл")
	t.equal(r.player.hp, 10, "враг не ответил")
	t.equal(has(events, "shot").damage, 3, "урон арбалета 3")
	t.equal(r.get_row(0)[4].hp, 4, "враг с 7 HP -> 4")
	t.equal(r.world.pos.y, 0, "игрок не сдвинулся")
end

M["shot kills and clears the cell"] = function(t)
	local rows = { [0] = { [4] = { type = "ENEMY", enemy = "TYPE_1", hp = 2 } } }
	local r = make(rows, 10)
	local _, events = run.shoot(r, 4)
	t.true_(has(events, "enemy_dead") ~= nil, "враг мёртв")
	t.equal(r.get_row(0)[4].type, "EMPTY", "клетка опустела")
end

M["only one shot per row"] = function(t)
	local rows = { [0] = { [4] = { type = "ENEMY", enemy = "TYPE_2" }, [3] = { type = "ENEMY", enemy = "TYPE_1" } } }
	local r = make(rows, 10)
	run.shoot(r, 4)
	local ok = run.shoot(r, 3)
	t.true_(not ok, "второй выстрел на ряду запрещён")
end

M["shot out of range is refused"] = function(t)
	local rows = { [0] = { [0] = { type = "ENEMY", enemy = "TYPE_1" } } }
	local r = make(rows, 10)
	r.world.pos = { x = 4, y = 0 }
	local ok = run.shoot(r, 0)
	t.true_(not ok, "дальше 3 клеток")
end

M["shot blocked by a wall"] = function(t)
	local rows = { [0] = { [3] = { type = "WALL" }, [4] = { type = "ENEMY", enemy = "TYPE_2" } } }
	local r = make(rows, 10)
	local ok = run.shoot(r, 4)
	t.true_(not ok, "стена между игроком и врагом")
end
return M
