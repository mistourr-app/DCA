-- Примитивы анимации GO-карты (docs/DEFOLD_INTEGRATION.md §5.5, §5.7): lift/lunge/fall/flash.
-- «Анимация один раз»: любой прототип карты (card.go, будущие ловушка/сундук) вызывает эти
-- функции, передавая абсолютные url своих компонентов (относительные "#..." резолвятся только
-- внутри скрипта-GO, у модуля своего GO нет). Протокол "anim_done" остаётся в card.script.

local M = {}

-- Подъём карты: все её части растут и возвращаются вместе — подложка, обводка, подписи.
-- Иначе текст и рамка «отклеиваются» от карты. opts: ms (секунды), scale,
-- parts — список { url, base }: base — «спокойный» масштаб части (у подписи 1, у
-- подложки/обводки — свой размер карты).
-- Шрифт масштабируется как картинка (лёгкое размытие на пике) — это плата за общий рост.
function M.lift(opts)
	for _, part in ipairs(opts.parts) do
		go.cancel_animations(part.url, "scale")
		go.animate(part.url, "scale", go.PLAYBACK_ONCE_FORWARD,
			vmath.vector3(part.base.x * opts.scale, part.base.y * opts.scale, 1),
			go.EASING_OUTBACK, opts.ms, 0, function()
				go.animate(part.url, "scale", go.PLAYBACK_ONCE_FORWARD, part.base,
					go.EASING_INOUTQUAD, opts.ms)
			end)
	end
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

-- Падение поверженной карты: сдвиг вниз и уход подложки/обводки/подписей в прозрачность.
-- opts: root, sprite, border (url обводки или nil), border_color, labels (список url
-- подписей), offset, ms, color, done.
function M.fall(opts)
	go.cancel_animations(opts.root, "position")
	go.cancel_animations(opts.sprite, "tint")
	local fall_s = opts.ms / 1000
	local home = go.get_position(opts.root)
	go.animate(opts.root, "position", go.PLAYBACK_ONCE_FORWARD, home + opts.offset,
		go.EASING_INCUBIC, fall_s)
	go.animate(opts.sprite, "tint", go.PLAYBACK_ONCE_FORWARD,
		vmath.vector4(opts.color.x, opts.color.y, opts.color.z, 0),
		go.EASING_LINEAR, fall_s, 0, opts.done)
	if opts.border ~= nil then
		local c = opts.border_color or vmath.vector4(0, 0, 0, 0)
		go.cancel_animations(opts.border, "tint")
		-- Рамка лежит под подложкой во всю площадь карты: если гасить её вместе с подложкой,
		-- на полпути она просвечивает через полупрозрачный фон. Поэтому рамка гаснет первой.
		go.animate(opts.border, "tint", go.PLAYBACK_ONCE_FORWARD,
			vmath.vector4(c.x, c.y, c.z, 0), go.EASING_LINEAR, fall_s * 0.4)
	end
	for _, url in ipairs(opts.labels) do
		go.cancel_animations(url, "color")
		go.animate(url, "color", go.PLAYBACK_ONCE_FORWARD,
			vmath.vector4(0, 0, 0, 0), go.EASING_LINEAR, fall_s)
	end
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
