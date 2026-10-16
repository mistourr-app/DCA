-- Примитивы анимации GO-карты (docs/DEFOLD_INTEGRATION.md §5.5, §5.7): lift/lunge/fall/flash.
-- «Анимация один раз»: любой прототип карты (card.go, будущие ловушка/сундук) вызывает эти
-- функции, передавая абсолютные url своих компонентов (относительные "#..." резолвятся только
-- внутри скрипта-GO, у модуля своего GO нет). Протокол "anim_done" остаётся в card.script.

local M = {}

-- Подъём подложки: до base*scale и обратно. opts: sprite, base, ms (секунды), scale.
function M.lift(opts)
	go.cancel_animations(opts.sprite, "scale")
	go.animate(opts.sprite, "scale", go.PLAYBACK_ONCE_FORWARD,
		vmath.vector3(opts.base.x * opts.scale, opts.base.y * opts.scale, 1),
		go.EASING_OUTBACK, opts.ms, 0, function()
			go.animate(opts.sprite, "scale", go.PLAYBACK_ONCE_FORWARD, opts.base,
				go.EASING_INOUTQUAD, opts.ms)
		end)
end

-- Выпад к цели и возврат. opts: root, offset, ms (в каждую сторону), done.
function M.lunge(opts)
	go.cancel_animations(opts.root, "position")
	local half_s = opts.ms / 1000
	local home = go.get_position(opts.root)
	go.animate(opts.root, "position", go.PLAYBACK_ONCE_FORWARD, home + opts.offset,
		go.EASING_OUTQUAD, half_s, 0, function()
			go.animate(opts.root, "position", go.PLAYBACK_ONCE_FORWARD, home,
				go.EASING_INOUTQUAD, half_s, 0, opts.done)
		end)
end

-- Падение поверженной карты: сдвиг вниз и уход подложки/подписи в прозрачность.
-- opts: root, sprite, label, offset, ms, color, done.
function M.fall(opts)
	go.cancel_animations(opts.root, "position")
	go.cancel_animations(opts.sprite, "tint")
	go.cancel_animations(opts.label, "color")
	local fall_s = opts.ms / 1000
	local home = go.get_position(opts.root)
	go.animate(opts.root, "position", go.PLAYBACK_ONCE_FORWARD, home + opts.offset,
		go.EASING_INCUBIC, fall_s)
	go.animate(opts.sprite, "tint", go.PLAYBACK_ONCE_FORWARD,
		vmath.vector4(opts.color.x, opts.color.y, opts.color.z, 0),
		go.EASING_LINEAR, fall_s, 0, opts.done)
	go.animate(opts.label, "color", go.PLAYBACK_ONCE_FORWARD,
		vmath.vector4(0, 0, 0, 0), go.EASING_LINEAR, fall_s)
end

-- Вспышка подложки. opts: sprite, from, to, ms, done.
function M.flash(opts)
	go.cancel_animations(opts.sprite, "tint")
	local half_s = opts.ms / 2000
	go.animate(opts.sprite, "tint", go.PLAYBACK_ONCE_FORWARD, opts.to,
		go.EASING_LINEAR, half_s, 0, function()
			go.animate(opts.sprite, "tint", go.PLAYBACK_ONCE_FORWARD, opts.from,
				go.EASING_LINEAR, half_s, 0, opts.done)
		end)
end

return M
