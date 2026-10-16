-- HUD: сборка строк и сообщений в gui/hud.gui (docs/DEFOLD_INTEGRATION.md §5.7).
-- Принимает контекст-скрипт self; состояния не хранит.
local world = require("core.world")
local camp = require("core.camp")

local MODES = world.MODES

local M = {}

-- Текст HUD и кнопки внизу экрана.
function M.sync(self)
	local p = self.player
	local pos = self.world.pos
	local top = string.format("ROW %d   HP %d/%d   CHARGES %d/%d   GOLD %d",
		pos.y, p.hp, p.max_hp, p.weapon.charges, p.weapon.max_charges, p.gold)
	if self.camp_state.pay_turns_left > 0 then
		top = top .. string.format("   CAMP FEE: %d TURNS", self.camp_state.pay_turns_left)
	end
	local bottom
	if self.world.mode == MODES.CAMP then
		bottom = "LEAVE CAMP"
	elseif self.world.mode == MODES.WORLD then
		bottom = string.format("MAKE CAMP (%d gold)", camp.install_price(p.gold))
	elseif self.world.mode == MODES.BOSS and self.arena then
		bottom = string.format("BOSS HP %d/%d", self.arena.boss_hp, self.arena.boss_max)
	else
		bottom = ""
	end
	msg.post("#hud", "update", {
		top = top,
		bottom = bottom,
		overlay = self.world.mode == MODES.DEATH,
	})
end

-- Мигание экрана при уроне по игроку: параметры — свойства flash_cfg (gui-скрипты без property).
function M.flash(self)
	msg.post("#hud", "flash", {
		color = self.color_flash,
		alpha = self.flash_alpha,
		duration = self.flash_ms / 1000,
	})
end

return M
