-- Доска: окно рядов, diff-синхронизация карт, карты акторов (docs/DEFOLD_INTEGRATION.md §5.7).
-- Состояние — в self: rows (кэш рядов), cards (карты по координатам), rows_id (контейнер),
-- player_go/boss_go (карты акторов). Принимает контекст-скрипт self.
local layout = require("core.layout")
local row_gen = require("core.row_gen")
local world = require("core.world")
local registry = require("core.registry.init")
local style = require("scripts.view.style")
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
	return cell.type
end

-- Текст и цвета карты по типу клетки: символ и роли — из scripts/view/style.lua.
function M.cell_view(self, cell)
	local view = style[cell.type] or style.EMPTY
	local text = view.symbol
	if cell.type == "ENEMY" then
		local t = registry.enemies.types[cell.enemy]
		text = t.label:sub(1, 1) .. tostring(cell.hp or t.base_hp)
	end
	return text, self.pal[view.fill], self.pal[view.ink]
end

function M.card_msg(self, x, y, text, fill, ink)
	local h = layout.row_height(y)
	return { text = text, color = fill, text_color = ink,
		width = layout.CELL_W - self.cell_gap, height = h - self.cell_gap }
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

function M.update(self, id, x, y, z, text, fill, ink)
	go.set(id, "position", vmath.vector3(layout.cell_x(x), layout.world_center(y), z))
	msg.post(id, "set", M.card_msg(self, x, y, text, fill, ink))
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
		local id = M.create(self, x, y, Z_CELL)
		if id ~= nil then
			local text, fill, ink = M.cell_view(self, cell)
			msg.post(id, "set", M.card_msg(self, x, y, text, fill, ink))
			out[x] = { id = id, sig = M.cell_sig(cell) }
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
			local sig = M.cell_sig(cell)
			local card = old and old[x]
			if card == nil then
				local id = M.create(self, x, y, Z_CELL)
				if id ~= nil then
					local text, fill, ink = M.cell_view(self, cell)
					msg.post(id, "set", M.card_msg(self, x, y, text, fill, ink))
					card = { id = id, sig = sig }
				end
			elseif card.sig ~= sig then
				go.set(card.id, "position", vmath.vector3(layout.cell_x(x), layout.world_center(y), Z_CELL))
				local text, fill, ink = M.cell_view(self, cell)
				msg.post(card.id, "set", M.card_msg(self, x, y, text, fill, ink))
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
	msg.post(self.player_go, "set",
		M.card_msg(self, pos.x, pr, view.symbol, self.pal[view.fill], self.pal[view.ink]))
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
	M.update(self, self.boss_go, a.boss_x, boss_y, Z_ACTOR,
		view.symbol .. tostring(a.boss_hp), self.pal[view.fill], self.pal[view.ink])
end

-- Прокрутка контейнера рядов, diff клеток, карты акторов, очистка эфемерных ГО.
-- Подсветки (угрозы, обводки, пунктир) рисует координатор поверх — см. world.script.
function M.refresh(self)
	local pr = self.world.pos.y
	go.set(self.rows_id, "position", vmath.vector3(0, layout.container_y(pr), 0))
	M.sync_cells(self, pr)
	M.sync_player(self, pr)
	M.sync_boss(self, pr)
	fx.clear(self)
end

return M
