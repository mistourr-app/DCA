-- Доска: окно рядов, diff-синхронизация карт, карты акторов (docs/DEFOLD_INTEGRATION.md §5.7).
-- Состояние — в self: rows (кэш рядов), cards (карты по координатам), rows_id (контейнер),
-- player_go/boss_go (карты акторов). Принимает контекст-скрипт self.
local layout = require("core.layout")
local balance = require("core.data.balance")
local row_gen = require("core.row_gen")
local world = require("core.world")
local registry = require("core.registry.init")
local highlight = require("core.highlight")
local style = require("scripts.view.style")
local naming = require("scripts.view.naming")
local palette = require("scripts.view.palette")
local fx = require("scripts.view.fx")
local layers = require("scripts.view.layers")

local MODES = world.MODES

-- Слои карт (position.z): поле и акторы; полная карта слоёв — scripts/view/layers.lua.
-- Экспортируются для координатора (анимация хода карты игрока).
local Z_CELL = layers.CELL_FILL
local Z_ACTOR = layers.ACTOR

local M = {}
M.Z_CELL = Z_CELL
M.Z_ACTOR = Z_ACTOR

-- Вид хода -> роль палитры для рамки карты. Рамка означает только «сюда можно пойти»;
-- самостоятельного цвета у рамки карты нет (GDD §5.4).
local BORDER_KEY = { step = "border_step", jump = "border_jump" }
M.BORDER_KEY = BORDER_KEY

-- Клетки ряда y; ряд генерируется по seed при первом обращении и кэшируется.
function M.get_row(self, y)
	if y < 0 then
		return nil
	end
	local cells = self.rows[y]
	if cells == nil then
		cells = row_gen.generate(self.seed, self.world.respawn_count, y).cells
		self.rows[y] = cells
	end
	return cells
end

-- Источник содержимого ряда на экране: ряды арены берутся из preview/боя, остальные —
-- из генератора (ряды типа boss без preview пусты).
function M.content_row(self, y)
	local a = self.arena
	if a ~= nil and self.arena_bottom ~= nil then
		if y == self.arena_bottom then
			return a.player_row
		end
		if y == self.arena_bottom + 1 then
			return a.boss_row
		end
	end
	if self.world.mode == MODES.BOSS and a ~= nil then
		local pr = self.world.pos.y
		if y == pr then
			return a.player_row
		end
		if y == pr + 1 then
			return a.boss_row
		end
	end
	return M.get_row(self, y)
end

-- Подпись содержимого клетки: меняется, когда нужно переслать "set".
function M.cell_sig(cell)
	if cell.type == "ENEMY" then
		return "ENEMY:" .. tostring(cell.enemy) .. ":" .. tostring(cell.hp or "")
	end
	if cell.type == "ATTACK_CELL" then
		return "ATTACK_CELL:" .. tostring(cell.damage or "")
	end
	return cell.type
end

-- Куда можно пойти: { [y] = { [x] = "step" | "jump" } }. В мире — следующий ряд, в бою
-- с боссом — ряд игрока (ходы по X). Считается перед отрисовкой карт: рамка карты — та же
-- индикация хода, отдельных обводок вокруг клеток нет.
function M.update_moves(self)
	local out = {}
	local pr = self.world.pos.y
	if self.world.mode == MODES.BOSS and self.arena ~= nil then
		for _, m in ipairs(highlight.arena_moves(self.arena)) do
			out[pr] = out[pr] or {}
			out[pr][m.x] = m.kind
		end
	else
		local up = pr + 1
		for _, m in ipairs(highlight.moves(self.world.pos, self.player.hp, M.get_row(self, up))) do
			out[up] = out[up] or {}
			out[up][m.x] = m.kind
		end
	end
	self.moves = out
end

-- Вид хода на клетке (x, y); nil — клетка не цель хода, значит рамки у её карты нет.
function M.move_kind(self, x, y)
	local row = self.moves and self.moves[y]
	return row and row[x] or nil
end

-- Цвета карты по её skin: фон и текст (fill_/ink_). Рамка — не цвет карты: её цвет задаёт
-- вид хода (border_step/border_jump), поэтому у разных карт с одним ходом рамка одного цвета.
local function colors(self, skin)
	local fill, ink = palette.roles(skin)
	return self.pal[fill], self.pal[ink]
end

-- Название и значение карты + цвета. Название — из scripts/view/style.lua (у врага — из
-- реестра, по типу), значение — данные клетки: HP, золото, лечение, урон ловушки.
function M.cell_view(self, cell)
	local view = style[cell.type] or style.EMPTY
	local name = view.name
	local value = ""
	if cell.type == "ENEMY" then
		local t = registry.enemies.types[cell.enemy]
		name = naming.display_name(t.label)
		value = tostring(cell.hp or t.base_hp)
	elseif cell.type == "HEAL" then
		value = tostring(balance.cells.HEAL.amount)
	elseif cell.type == "GOLD" then
		value = tostring(balance.cells.GOLD.amount)
	elseif cell.type == "ATTACK_CELL" then
		value = tostring(cell.damage or "")
	end
	local fill, ink = colors(self, view.skin)
	return name, value, fill, ink
end

-- Цвет рамки по виду хода: nil — рамки нет (card.script подставит прозрачный цвет).
local function border_color(self, kind)
	if kind == nil then
		return nil
	end
	return self.pal[BORDER_KEY[kind]]
end

-- Сообщение "set" карте: содержимое, цвета и рамка. Толщина рамки одна на все карты —
-- card_border из geom_cfg; приходит и оверлею угрозы через board.cell_inset.
function M.card_msg(self, x, y, name, value, fill, ink, kind)
	local h = layout.row_height(y)
	return { name = name, value = value, color = fill, text_color = ink,
		border_color = border_color(self, kind),
		border_width = self.card_border,
		width = layout.CELL_W - self.cell_gap, height = h - self.cell_gap }
end

-- Толщина рамки карты (0 — рамки нет): по ней оверлей угрозы ужимается до площади подложки,
-- иначе подсветка закрашивает рамку вместе с фоном. Рамка есть только у карт, куда можно пойти.
function M.cell_inset(self, x, y)
	if M.move_kind(self, x, y) == nil then
		return 0
	end
	return self.card_border
end

-- Подпись карты для diff-синхронизации: содержимое и вид хода. Рамка может измениться
-- без смены клетки (игрок шагнул), поэтому вид хода входит в подпись.
local function card_sig(cell, kind)
	return M.cell_sig(cell) .. "|" .. (kind or "-")
end

-- Клетка-карта в контейнере рядов: локальные координаты = пространство рядов.
function M.create(self, x, y, z)
	local pos = vmath.vector3(layout.cell_x(x), layout.world_center(y), z)
	local id = factory.create("#card_factory", pos)
	if id == nil then
		print("card create failed: label buffer full (raise [label] max_count in game.project)")
		return nil
	end
	go.set_parent(id, self.rows_id, false)
	return id
end

function M.update(self, id, x, y, z, name, value, fill, ink, kind)
	go.set(id, "position", vmath.vector3(layout.cell_x(x), layout.world_center(y), z))
	msg.post(id, "set", M.card_msg(self, x, y, name, value, fill, ink, kind))
end

-- id карты клетки (x, y) из последней синхронизации; nil — карты нет на экране.
function M.card_id_at(self, x, y)
	local rowmap = self.cards[y]
	local card = rowmap and rowmap[x]
	if card == nil then
		return nil
	end
	return card.id
end

-- Смещение выпада: от центра клетки (x0, y0) в сторону (x1, y1), доля fraction.
function M.lunge_offset(x0, y0, x1, y1, fraction)
	local dx = layout.cell_x(x1) - layout.cell_x(x0)
	local dy = layout.world_center(y1) - layout.world_center(y0)
	return vmath.vector3(dx * fraction, dy * fraction, 0)
end

-- Создать карты ряда y заранее, до анимации прокрутки: тогда ряд въезжает из-под
-- фейда, а не появляется в конце хода. В бою ряды арены уже созданы sync_cells.
function M.ensure_row(self, y)
	if y < 0 or self.cards[y] ~= nil or self.world.mode == MODES.BOSS then
		return
	end
	local row = M.content_row(self, y)
	local out = {}
	for x = 0, layout.COLUMNS - 1 do
		local cell = (row and row[x]) or { type = "EMPTY" }
		local kind = M.move_kind(self, x, y)
		local id = M.create(self, x, y, Z_CELL)
		if id ~= nil then
			local name, value, fill, ink = M.cell_view(self, cell)
			msg.post(id, "set", M.card_msg(self, x, y, name, value, fill, ink, kind))
			out[x] = { id = id, sig = card_sig(cell, kind) }
		end
	end
	self.cards[y] = out
end

-- Diff-синхронизация видимых клеток: создаём новые, обновляем изменившиеся,
-- удаляем вышедшие из окна. Ряды ниже игрока не видны и не хранятся как объекты.
-- Смена содержимого сбрасывает позицию карты: анимации (fall/lunge) могли её сместить.
function M.sync_cells(self, pr)
	local new_cards = {}
	for _, y in ipairs(layout.visible_rows(pr)) do
		local old = self.cards[y]
		local out = {}
		local row = M.content_row(self, y)
		for x = 0, layout.COLUMNS - 1 do
			local cell = (row and row[x]) or { type = "EMPTY" }
			local kind = M.move_kind(self, x, y)
			local sig = card_sig(cell, kind)
			local card = old and old[x]
			if card == nil then
				local id = M.create(self, x, y, Z_CELL)
				if id ~= nil then
					local name, value, fill, ink = M.cell_view(self, cell)
					msg.post(id, "set", M.card_msg(self, x, y, name, value, fill, ink, kind))
					card = { id = id, sig = sig }
				end
			elseif card.sig ~= sig then
				go.set(card.id, "position", vmath.vector3(layout.cell_x(x), layout.world_center(y), Z_CELL))
				local name, value, fill, ink = M.cell_view(self, cell)
				msg.post(card.id, "set", M.card_msg(self, x, y, name, value, fill, ink, kind))
				card.sig = sig
			end
			out[x] = card
		end
		if old ~= nil then
			for x, card in pairs(old) do
				if out[x] == nil then
					go.delete(card.id)
				end
			end
		end
		new_cards[y] = out
	end
	-- строки, вышедшие из окна: удаляем карты целиком
	local stale = {}
	for y in pairs(self.cards) do
		if new_cards[y] == nil then
			table.insert(stale, y)
		end
	end
	for _, y in ipairs(stale) do
		for _, card in pairs(self.cards[y]) do
			go.delete(card.id)
		end
		self.cards[y] = nil
	end
	self.cards = new_cards
end

-- Карта игрока: один персистентный объект, занимает клетку под собой и стоит над слоем угроз.
function M.sync_player(self, pr)
	local pos = self.world.pos
	if self.player_go == nil then
		self.player_go = M.create(self, pos.x, pr, Z_ACTOR)
	end
	if self.player_go == nil then
		return
	end
	go.set(self.player_go, "position",
		vmath.vector3(layout.cell_x(pos.x), layout.world_center(pr), Z_ACTOR))
	local view = style.PLAYER
	local p = self.player
	local fill, ink = colors(self, view.skin)
	msg.post(self.player_go, "set",
		M.card_msg(self, pos.x, pr, view.name, string.format("%d/%d", p.hp, p.max_hp),
			fill, ink, nil))
end

-- Карта босса: отдельный объект на верхнем ряду арены. Показывается уже в preview,
-- как только ряд босса попал в видимое окно; удаляется по концу боя.
function M.sync_boss(self, pr)
	local a = self.arena
	local boss_y = self.arena_bottom and self.arena_bottom + 1 or nil
	local visible = false
	if boss_y ~= nil then
		for _, y in ipairs(layout.visible_rows(pr)) do
			if y == boss_y then
				visible = true
				break
			end
		end
	end
	if a == nil or boss_y == nil or not visible then
		if self.boss_go ~= nil then
			go.delete(self.boss_go)
			self.boss_go = nil
		end
		return
	end
	if self.boss_go == nil then
		self.boss_go = M.create(self, a.boss_x, boss_y, Z_ACTOR)
	end
	if self.boss_go == nil then
		return
	end
	local view = style.BOSS
	local fill, ink = colors(self, view.skin)
	M.update(self, self.boss_go, a.boss_x, boss_y, Z_ACTOR,
		view.name, tostring(a.boss_hp), fill, ink, nil)
end

-- Прокрутка контейнера рядов, diff клеток, карты акторов, очистка эфемерных ГО.
-- Индикация хода (рамки карт) считается здесь же; угрозы и пунктир рисует координатор
-- поверх — см. world.script.
function M.refresh(self)
	local pr = self.world.pos.y
	go.set(self.rows_id, "position", vmath.vector3(0, layout.container_y(pr), 0))
	M.update_moves(self)
	M.sync_cells(self, pr)
	M.sync_player(self, pr)
	M.sync_boss(self, pr)
	fx.clear(self)
end

return M
