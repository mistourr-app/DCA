-- Генерация рядов (GDD §3.2, §9, §13).
-- Ряд = { y = номер, kind = "normal" | "boss" | "checkpoint", cells = { [x] = клетка } }.
-- x — 0-based колонка. Клетка: { type = "EMPTY" | "WALL" | "HEAL" | "GOLD" | "ENEMY", enemy = ключ }.
-- Ряд полностью определяется глобальным seed и номером ряда (row_seed).
--
-- Расписание рядов (boss.period = K, boss.arenaRows = A):
--   r % K == 0                 checkpoint (ряд 0 — стартовая точка возврата)
--   r % K >= K - A             boss (арена занимает последние A рядов цикла)
--   иначе                      normal
-- Для ряда checkpoint допустимы только стены (GDD §9).
-- Ряд boss не заполняется клетками: арена генерируется динамически (пункт 15).

local balance = require("core.data.balance")
local rng = require("core.rng")
local row_seed = require("core.row_seed")

local M = {}

local COLUMNS = balance.layout.columns
local PERIOD = balance.boss.period
local ARENA_ROWS = balance.boss.arenaRows
local RAMP = balance.rows.rampRows

assert(PERIOD >= ARENA_ROWS + 2, "boss.period должен оставлять хотя бы один обычный ряд")
assert(RAMP > 0, "rows.rampRows должен быть положительным")

-- Порядок накопления шансов при выборе содержимого клетки обычного ряда.
local CELL_ORDER = { "ENEMY", "WALL", "HEAL", "GOLD" }

-- Типы врагов в фиксированном порядке (для детерминизма выбора).
local ENEMY_KEYS = {}
for key in pairs(balance.enemies) do
	table.insert(ENEMY_KEYS, key)
end
table.sort(ENEMY_KEYS)

function M.kind(r)
	assert(type(r) == "number" and r >= 0 and r == math.floor(r), "номер ряда — неотрицательное целое")
	local phase = r % PERIOD
	if phase == 0 then
		return "checkpoint"
	end
	if phase >= PERIOD - ARENA_ROWS then
		return "boss"
	end
	return "normal"
end

-- Шанс на клетку для ряда r: линейная интерполяция от from к to на rampRows, дальше постоянна.
function M.chance(kind, r)
	local spec = balance.rows.chances[kind]
	assert(spec ~= nil, "нет шанса для " .. tostring(kind))
	local t = math.min(1, r / RAMP)
	return spec.from + (spec.to - spec.from) * t
end

-- Все шансы ряда r; сумма обычных клеток не превышает 1.
function M.chances(r)
	local out = {}
	local total = 0
	for _, kind in ipairs(CELL_ORDER) do
		local p = M.chance(kind, r)
		out[kind] = p
		total = total + p
	end
	assert(total <= 1, string.format("сумма шансов ряда %d = %.4f > 1", r, total))
	return out
end

local function pick_enemy(g)
	local total = 0
	for _, key in ipairs(ENEMY_KEYS) do
		total = total + balance.enemies[key].weight
	end
	local roll = g:float() * total
	local acc = 0
	for _, key in ipairs(ENEMY_KEYS) do
		acc = acc + balance.enemies[key].weight
		if roll < acc then
			return key
		end
	end
	return ENEMY_KEYS[#ENEMY_KEYS]
end

local function normal_cell(g, ch)
	local roll = g:float()
	local acc = 0
	for _, kind in ipairs(CELL_ORDER) do
		acc = acc + ch[kind]
		if roll < acc then
			if kind == "ENEMY" then
				return { type = "ENEMY", enemy = pick_enemy(g) }
			end
			return { type = kind }
		end
	end
	return { type = "EMPTY" }
end

local function checkpoint_cell(g, wall_chance)
	if g:float() < wall_chance then
		return { type = "WALL" }
	end
	return { type = "EMPTY" }
end

-- Генерирует ряд r мира global_seed.
function M.generate(global_seed, r)
	local kind = M.kind(r)
	local out = { y = r, kind = kind, cells = {} }
	if kind == "boss" then
		return out
	end
	local g = rng.new(row_seed.row_seed(global_seed, r))
	if kind == "checkpoint" then
		local wall = M.chance("WALL", r)
		for x = 0, COLUMNS - 1 do
			out.cells[x] = checkpoint_cell(g, wall)
		end
		return out
	end
	local ch = M.chances(r)
	for x = 0, COLUMNS - 1 do
		out.cells[x] = normal_cell(g, ch)
	end
	return out
end

return M
