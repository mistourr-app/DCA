-- Раннер очереди анимационных шагов (docs/DEFOLD_INTEGRATION.md §5.7).
-- Состояние живёт в self: anim_steps (очередь), anim_done (финальный колбэк),
-- anim_waiters/anim_token (ожидание ответов "anim_done" от карт).
local M = {}

-- Последовательность шагов function(next). Ввод блокирован до конца; done — финал.
function M.play(self, steps, done)
	self.anim_steps = steps
	self.anim_done = done
	self.input_locked = true
	local function advance()
		local f = table.remove(self.anim_steps, 1)
		if f == nil then
			self.input_locked = false
			self.anim_done()
			return
		end
		f(advance)
	end
	advance()
end

-- Шаги, которым нужен ответ карты, регистрируют продолжение по токену;
-- карта шлёт "anim_done" {token} в sender своего сообщения.
function M.on_message(self, message_id, message, sender)
	if message_id == hash("anim_done") and message.token ~= nil then
		local cont = self.anim_waiters[message.token]
		if cont ~= nil then
			self.anim_waiters[message.token] = nil
			cont()
		end
	end
end

-- Шаг: отправить карте анимационное сообщение и дождаться "anim_done".
-- Нет карты (вне экрана) — шаг проходит сразу.
function M.card_anim(self, id, name, payload)
	return function(next)
		if id == nil then
			next()
			return
		end
		self.anim_token = self.anim_token + 1
		self.anim_waiters[self.anim_token] = next
		payload.token = self.anim_token
		msg.post(id, name, payload)
	end
end

return M
