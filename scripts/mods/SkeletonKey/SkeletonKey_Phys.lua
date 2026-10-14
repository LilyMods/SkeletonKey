local mod = get_mod("SkeletonKey")
local G = rawget(_G, "__skeletonkey")
local SK = G and G.SK

if not SK then
	return
end

-- ───────────────────── ❀ ─────────────────────
--  Include Collision
-- ───────────────────── ❀ ─────────────────────

local phys = {}

phys.hint = "Include collision: H and moving take it too."
phys.placed_at = setmetatable({}, { __mode = "k" })

phys.wanted = function(how)
	if how ~= nil then
		return how == "ghost"
	end

	local ok, on = pcall(mod.get, mod, "include_collision")

	return ok and on == true
end

phys.hosting = function()
	local state = rawget(_G, "Managers") and Managers.state
	local session = state and state.game_session

	if not session then
		return false
	end

	local ok, server = pcall(session.is_server, session)

	return ok and server == true
end

phys.on = function()
	return phys.wanted() and phys.hosting()
end

phys.says = function(ghost, parts, hidden)
	if ghost then
		return string.format("Hid %s, collision off. %s hidden now.", SK.count(parts, "part"), SK.count(hidden, "thing"))
	end

	return string.format("Hid %s. Collision stays unless you host.", SK.count(parts, "part"))
end

phys.take = function(parts)
	local taken = {}

	for i = 1, #(parts or {}) do
		local unit = parts[i]
		local okn, n = false, 0

		if SK.alive(unit) then
			okn, n = pcall(Unit.num_actors, unit)
		end

		for a = 1, (okn and type(n) == "number") and n or 0 do
			local oka, actor = pcall(Unit.actor, unit, a)
			local okq, on = false, false

			if oka and actor then
				okq, on = pcall(Actor.is_scene_query_enabled, actor)
			end

			if okq and on and pcall(Actor.set_scene_query_enabled, actor, false) then
				taken[#taken + 1] = { unit = unit, index = a }
			end
		end
	end

	return taken
end

phys.give = function(taken)
	for i = 1, #(taken or {}) do
		local one = taken[i]

		if SK.alive(one.unit) then
			local oka, actor = pcall(Unit.actor, one.unit, one.index)

			if oka and actor then
				pcall(Actor.set_scene_query_enabled, actor, true)
			end
		end
	end
end

phys.give_back = function(entry)
	if entry then
		phys.give(entry.ghost)
	end
end

phys.take_again = function(entry)
	if entry.ghost then
		entry.ghost = phys.hosting() and phys.take(entry.parts) or nil
	end
end

phys.rebuilt = function(unit)
	for i = 1, #(SK.hidden or {}) do
		local one = SK.hidden[i]
		local had = false

		for j = 1, #(one.ghost or {}) do
			had = had or one.ghost[j].unit == unit
		end

		if had then
			for _, t in ipairs(phys.take({ unit })) do
				one.ghost[#one.ghost + 1] = t
			end
		end
	end
end

phys.taken = function(unit)
	phys.placed_at[unit] = nil
end

phys.placed = function(unit)
	local object = G.object or {}
	local move, spin = object.move or {}, object.spin or {}
	local placed = string.format("%.4f %.4f %.4f %.3f %.3f %.3f", move[1] or 0, move[2] or 0, move[3] or 0,
		spin[1] or 0, spin[2] or 0, spin[3] or 0)

	if placed ~= (phys.placed_at[unit] or "0.0000 0.0000 0.0000 0.000 0.000 0.000") then
		phys.placed_at[unit] = placed

		if phys.on() then
			SK.collide_pending[unit] = SK.now()
		end
	end
end

mod.sk_phys = function(what)
	if what == "toggle" then
		local on = not phys.wanted()

		pcall(mod.set, mod, "include_collision", on)

		if not on then
			return "Collision off: only the look changes."
		end

		return phys.hosting() and "Collision on: H and moving take it too." or "Collision on, but only in games you host."
	end

	return phys.wanted() and "on" or "off"
end

-- ───────────────────── ❀ ─────────────────────
--  PHYS Tag
-- ───────────────────── ❀ ─────────────────────

phys.widget = function(UIWidget, rect, text, x, w, h)
	return UIWidget.create_definition({
		{
			pass_type = "hotspot",
			content_id = "hotspot",
			style = { size = { w, h }, offset = { x, 0, 4 } },
		},
		rect("face", { 255, 26, 24, 22 }, { w, h }, { x, 0, 1 }),
		rect("bar", { 255, 230, 220, 195 }, { w, 2 }, { x, 0, 2 }),
		text("PHYS", "label", { w, h }, { x, 0, 3 }, { 255, 141, 148, 160 }, 14, "center", "machine_medium"),
	}, "note")
end

phys.step = function(view, show, sliding)
	local widget = view._widgets_by_name and view._widgets_by_name.button_phys

	if not widget then
		return
	end

	show(widget, not sliding)

	if view:_pressed(widget) then
		view:_say(mod.sk_phys("toggle"), "obj")
	end

	local on = phys.wanted()
	local face, ink = widget.style.face.color, widget.style.label.text_color

	face[2], face[3], face[4] = on and 230 or 26, on and 220 or 24, on and 195 or 22
	ink[2], ink[3], ink[4] = on and 27 or 141, on and 29 or 148, on and 33 or 160
end

SK.phys = phys
