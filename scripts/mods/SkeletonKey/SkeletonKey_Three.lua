local mod = get_mod("SkeletonKey")

local SkeletonKeyPoseView = mod:io_dofile("SkeletonKey/scripts/mods/SkeletonKey/SkeletonKey_Pose")

if mod:get("panel_layout") ~= "three" then
	return SkeletonKeyPoseView
end

local okd, definitions = pcall(mod.io_dofile, mod, "SkeletonKey/scripts/mods/SkeletonKey/SkeletonKey_Three_Definitions")

if not okd or type(definitions) ~= "table" or not definitions.THREE then
	return SkeletonKeyPoseView
end

-- ───────────────────── ❀ ─────────────────────
--  Constants & Keys
-- ───────────────────── ❀ ─────────────────────

local L = definitions.THREE
local SAY_HOLDS = 5
local ASKS_FOR = 4
local HOLD_STEP = 0.1
local KEY_ENTER = Keyboard and Keyboard.button_index and Keyboard.button_index("enter") or nil
local LEFT_BUTTON = Mouse and Mouse.button_index and Mouse.button_index("left") or nil

local function sk()
	local G = rawget(_G, "__skeletonkey")

	return G, G and G.SK
end

local function sk_now()
	local _, SK = sk()

	return SK and SK.now() or 0
end

local function show(widget, on)
	if widget then
		widget.content.visible = on and true or false
	end
end

local function hovered(widget)
	local content = widget and widget.content
	local hotspot = content and content.hotspot

	return hotspot ~= nil and hotspot.is_hover == true and content.visible ~= false
end

local function left_held()
	if not LEFT_BUTTON then
		return false
	end

	local ok, held = pcall(Mouse.button, LEFT_BUTTON)

	return ok and held and held > 0
end

local function paint(color, r, g, b)
	color[2], color[3], color[4] = r, g, b
end

local function lit(widget, on)
	if not widget then
		return
	end

	if on then
		widget.style.face.color[1] = 255
		paint(widget.style.face.color, 230, 220, 195)
	end

	paint(widget.style.label.text_color, on and 27 or 236, on and 29 or 230, on and 33 or 216)
end

local function shown_name(name)
	if type(name) ~= "string" or name == "" or string.sub(name, 1, 1) == "#" then
		return "Unnamed Prop"
	end

	return name
end

local function typed_of(widget)
	local text = widget and widget.content.input_text or ""

	return text ~= "" and text or nil
end

local function notch_of(input_service)
	local ok, axis = pcall(input_service.get, input_service, "scroll_axis")

	return ok and axis and axis[2] or 0
end

local function cursor_of(input_service)
	local ok, cursor = pcall(input_service.get, input_service, "cursor")

	if not ok or not cursor then
		return nil
	end

	local scale = RESOLUTION_LOOKUP and RESOLUTION_LOOKUP.inverse_scale or 1

	return cursor[1] * scale, cursor[2] * scale
end

-- ───────────────────── ❀ ─────────────────────
--  View Setup
-- ───────────────────── ❀ ─────────────────────

local SkeletonKeyThreeView = class("SkeletonKeyThreeView", "SkeletonKeyPoseView")

SkeletonKeyThreeView.LAYOUT = L
SkeletonKeyThreeView.PANELS = {
	pose = { node = "pose", grip = "grip", key = "three_pose_at", home = -24,
		w = "PANEL_W", h = "PANEL_H", side = "right" },
	objkey = { node = "objkey", grip = "obj_grip", key = "three_obj_at", home = 24,
		w = "OBJ_PANEL_W", h = "OBJ_PANEL_H", side = "left" },
}
SkeletonKeyThreeView.OWN = {
	left = { node = "sk3_left", key = "three_left_at", at = L.LEFT_AT },
	dock = { node = "sk3_dock", key = "three_dock_at", at = L.DOCK_AT },
}

SkeletonKeyThreeView.init = function (self, settings, context)
	local real = SkeletonKeyPoseView.super

	SkeletonKeyPoseView.super = setmetatable({
		init = function (view, _, ...)
			return real.init(view, definitions, ...)
		end,
	}, { __index = real })

	local ok, err = pcall(SkeletonKeyPoseView.init, self, settings, context)

	SkeletonKeyPoseView.super = real

	if not ok then
		error(err)
	end

	local G = rawget(_G, "__skeletonkey")
	local was = G and G.three_at or {}

	self._tab, self._otab = "joints", "move"
	self._atop = was.atop or 0
	self._ktop = was.ktop or 0
	self._stop = was.stop or 0
	self._itop3 = was.itop or 0
	self._gtop3 = was.gtop or 0
	self._job_want = was.job

	do
		local G2, SK2 = sk()

		self._t_person = mod.pose_state().unit
		self._t_obj = SK2 and SK2.object_alive() and G2.object.unit or nil
		self._t_pick_at = G2 and G2.pick and G2.pick.at or nil
		self._t_take_at = self._t_pick_at
	end

	self._t_writing = {}
	self._gsel3 = {}
	self._own_at = {}
	self._ask = {}

	local widgets = self._widgets_by_name

	if widgets.sk3_filter then
		widgets.sk3_filter.content.placeholder_text = "Filter"
		widgets.sk3_filter.content.input_text = was.filter or ""
	end

	if widgets.sk3_name then
		widgets.sk3_name.content.input_text = was.name or ""
	end

	if widgets.sk3_chat_in then
		widgets.sk3_chat_in.content.max_length = 200
		widgets.sk3_chat_in.content.placeholder_text = "Type a message, or a /command"
	end

	for _, name in ipairs({ "sk3_filter", "sk3_name", "sk3_chat_in" }) do
		for _, id in ipairs({ "display_text", "active_placeholder" }) do
			local st = widgets[name] and widgets[name].style[id]

			if st then
				st.font_size = 14
			end
		end
	end

	self:_three_job()
end

SkeletonKeyThreeView.on_exit = function (self)
	local G = rawget(_G, "__skeletonkey")
	local widgets = self._widgets_by_name

	for _, name in ipairs({ "sk3_filter", "sk3_name", "sk3_path", "sk3_chat_in" }) do
		if widgets[name] then
			widgets[name].content.is_writing = false
		end
	end

	if G then
		G.three_at = { atop = self._atop, ktop = self._ktop, stop = self._stop, itop = self._itop3, gtop = self._gtop3,
			job = self._job, filter = widgets.sk3_filter and widgets.sk3_filter.content.input_text or "",
			name = widgets.sk3_name and widgets.sk3_name.content.input_text or "" }
	end

	self:_three_chat_window(false)

	return SkeletonKeyPoseView.on_exit(self)
end

SkeletonKeyThreeView._restore_place = function (self)
	local sw = self:_screen()

	for which, p in pairs(self.PANELS) do
		local ok, saved = pcall(mod.get, mod, p.key)
		local x, y = 0, 0

		if which == "objkey" then
			x = sw - (definitions[p.w] or 330) - p.home * 2
		end

		if ok and type(saved) == "string" then
			local sx, sy = string.match(saved, "^(-?%d+),(-?%d+)$")

			x, y = tonumber(sx) or x, tonumber(sy) or y
		end

		self:_place(x, y, which)
	end

	for which, o in pairs(self.OWN) do
		local ok, saved = pcall(mod.get, mod, o.key)
		local x, y = 0, 0

		if ok and type(saved) == "string" then
			local sx, sy = string.match(saved, "^(-?%d+),(-?%d+)$")

			x, y = tonumber(sx) or 0, tonumber(sy) or 0
		end

		self._own_at[which] = { x, y }
		self:_own_clamp(which)
	end
end

SkeletonKeyThreeView._own_clamp = function (self, which)
	local sw, sh = self:_screen()
	local at = self._own_at[which] or { 0, 0 }
	local ox, oy, w, h = self:_own_origin(which)

	local lo = which == "dock" and L.CW or 0

	self._own_at[which] = { at[1] + math.max(lo - ox, math.min(sw - w - ox, 0)), at[2] + math.max(-oy, math.min(sh - h - oy, 0)) }
end

SkeletonKeyThreeView._handle_input = function (self, input_service, dt, t)
	local widgets = self._widgets_by_name
	local writing = false

	for _, name in ipairs({ "sk3_filter", "sk3_name", "sk3_path", "sk3_chat_in" }) do
		writing = writing or (widgets[name] ~= nil and widgets[name].content.is_writing == true)
	end

	if writing and not self._rename and input_service:get("close_view") then
		for _, name in ipairs({ "sk3_filter", "sk3_name", "sk3_path", "sk3_chat_in" }) do
			if widgets[name] then
				widgets[name].content.is_writing = false
			end
		end

		return
	end

	return SkeletonKeyPoseView._handle_input(self, input_service, dt, t)
end

SkeletonKeyThreeView._typing = function (self)
	local widgets = self._widgets_by_name

	for _, name in ipairs({ "sk3_filter", "sk3_name", "sk3_path", "sk3_chat_in" }) do
		if widgets[name] and widgets[name].content.is_writing then
			return true
		end
	end

	return SkeletonKeyPoseView._typing(self)
end

SkeletonKeyThreeView._chat = function (self)
	local widgets = self._widgets_by_name

	for _, name in ipairs({ "sk3_filter", "sk3_name", "sk3_path", "sk3_chat_in" }) do
		if widgets[name] then
			widgets[name].content.is_writing = false
		end
	end

	return SkeletonKeyPoseView._chat(self)
end

SkeletonKeyThreeView._list_keys = function (self)
	local widgets = self._widgets_by_name

	if not self._rename and KEY_ENTER and widgets.sk3_chat_in and widgets.sk3_chat_in.content.is_writing
		and self:_fresh_key(KEY_ENTER) then
		self:_three_send()

		return
	end

	if not self._rename and KEY_ENTER then
		local path = widgets.sk3_path and widgets.sk3_path.content
		local writing = path and path.is_writing

		for _, name in ipairs({ "sk3_filter", "sk3_name" }) do
			writing = writing or (widgets[name] and widgets[name].content.is_writing)
		end

		if writing and self:_fresh_key(KEY_ENTER) then
			if path and path.is_writing then
				self:_three_spawn()
			end

			for _, name in ipairs({ "sk3_filter", "sk3_name" }) do
				if widgets[name] then
					widgets[name].content.is_writing = false
				end
			end

			return
		end
	end

	return SkeletonKeyPoseView._list_keys(self)
end

-- A widget hidden while the mouse is on it keeps reading as hovered, so a
-- press is only asked of what is shown.
SkeletonKeyThreeView._three_pressed = function (self, widget)
	return widget ~= nil and widget.content.visible ~= false and self:_pressed(widget)
end

-- A reply goes to the side the screen is showing: the pose panel's foot for a
-- person, Object Key's line or the dock's for a prop.
SkeletonKeyThreeView._say = function (self, text, side)
	if not self._own_at then
		return SkeletonKeyPoseView._say(self, text, side)
	end

	if self:_three_job() == "prop" then
		self._obj_reply, self._obj_said_at = tostring(text or ""), sk_now()
	else
		self._reply, self._said_at = tostring(text or ""), sk_now()
	end
end

SkeletonKeyThreeView._three_spawn = function (self)
	local box = self._widgets_by_name.sk3_path.content
	local said = mod.spawn_at_screen(box.input_text, RESOLUTION_LOOKUP.width * 0.5, RESOLUTION_LOOKUP.height * 0.5)

	box.is_writing = false
	self:_say(said or "Spawning...", "obj")
end

-- ───────────────────── ❀ ─────────────────────
--  Each Frame
-- ───────────────────── ❀ ─────────────────────

SkeletonKeyThreeView._buttons = function (self, input_service)
	self._tab, self._otab = "joints", "move"
	self:_step("_three_base_buttons", input_service)
	self:_step("_three_buttons", input_service)
end

SkeletonKeyThreeView._three_base_buttons = function (self, input_service)
	return SkeletonKeyPoseView._buttons(self, input_service)
end

SkeletonKeyThreeView._fill = function (self)
	self._tab, self._otab = "joints", "move"
	self:_step("_three_base_fill")
	self:_step("_three_fill")
end

SkeletonKeyThreeView._three_base_fill = function (self)
	return SkeletonKeyPoseView._fill(self)
end

-- Whoever or whatever was picked last owns the screen; with nothing picked
-- it is laid out for props, so a spawn or a group load needs no pick first.
SkeletonKeyThreeView._three_job = function (self)
	local G, SK = sk()
	local pose = mod.pose_state()
	local obj_unit = SK and SK.object_alive() and G.object.unit or nil

	if obj_unit ~= self._t_obj then
		self._t_obj = obj_unit

		if obj_unit then
			self._job_want = "prop"
		end
	end

	if pose.unit ~= self._t_person then
		self._t_person = pose.unit

		if pose.unit then
			self._job_want = "person"
		end
	end

	local pk = G and G.pick

	if pk and pk.at ~= self._t_pick_at then
		self._t_pick_at = pk.at

		local crew = false

		for _, c in ipairs((obj_unit and G.object.crew) or {}) do
			crew = crew or c.unit == pk.unit
		end

		if pk.unit and pk.unit == pose.unit then
			self._job_want = "person"
		elseif pk.unit and (pk.unit == obj_unit or crew) then
			self._job_want = "prop"
		end
	end

	local job = self._job_want

	if (job == "person" and not pose.unit) or (job == "prop" and not obj_unit) then
		job = nil
	end

	self._job = job or (pose.unit and "person") or "prop"

	if self._job ~= self._t_job_was then
		self._t_job_was = self._job
		self:_own_clamp("left")
	end

	return self._job
end

SkeletonKeyThreeView._three_away = function (self)
	return self:_out_of_way() or (self._box ~= nil and self._box.drawn == true)
end

-- ───────────────────── ❀ ─────────────────────
--  Moving Panels
-- ───────────────────── ❀ ─────────────────────

SkeletonKeyThreeView._own_origin = function (self, which)
	local sw, sh = self:_screen()
	local at = self._own_at[which] or { 0, 0 }

	if which == "left" then
		return L.LEFT_AT[1] + at[1], L.LEFT_AT[2] + at[2], L.LW, self._job == "person" and L.LH or L.GH
	end

	return (sw - L.DW) * 0.5 + L.DOCK_AT[1] + at[1], sh - L.DH + L.DOCK_AT[2] + at[2], L.DW, L.DH
end

SkeletonKeyThreeView._own_drag = function (self, input_service, which, plate_name, band_w)
	local widget = self._widgets_by_name[plate_name]
	local hotspot = widget and widget.content.hotspot

	if not hotspot or widget.content.visible == false then
		return
	end

	local cx, cy = cursor_of(input_service)

	if hotspot.on_pressed then
		hotspot.on_pressed = false

		if cx and not self._own_drag_at then
			local ox, oy = self:_own_origin(which)

			if cx >= ox and cx - ox <= (band_w or 10000) and cy - oy <= 40 then
				self._own_drag_at = { which = which, x = cx, y = cy }
			end
		end
	end

	local drag = self._own_drag_at

	widget.style.grip_hint.color[1] = (drag and drag.which == which) and 24 or 0

	if not drag or drag.which ~= which then
		return
	end

	self._hovering = true

	if left_held() and cx then
		local at = self._own_at[which] or { 0, 0 }
		local sw, sh = self:_screen()
		local ox, oy, w, h = self:_own_origin(which)
		local dx = math.max((which == "dock" and L.CW or 0) - ox, math.min(sw - w - ox, cx - drag.x))
		local dy = math.max(-oy, math.min(sh - h - oy, cy - drag.y))

		self._own_at[which] = { at[1] + dx, at[2] + dy }
		drag.x, drag.y = drag.x + dx, drag.y + dy
	else
		local at = self._own_at[which] or { 0, 0 }

		self._own_drag_at = nil
		pcall(mod.set, mod, self.OWN[which].key, string.format("%d,%d", at[1], at[2]))
	end
end

-- ───────────────────── ❀ ─────────────────────
--  Presses
-- ───────────────────── ❀ ─────────────────────

-- A posed person stays picked until Clear Target, which the prop side does
-- not show; once they are hidden, a click on someone else takes over.
SkeletonKeyThreeView._three_take_over = function (self)
	local G, SK = sk()
	local pk = G and G.pick
	local pose = mod.pose_state()

	if not (pk and pk.unit and pk.at and pk.at ~= self._t_take_at) then
		return
	end

	self._t_take_at = pk.at

	if not (pose.unit and pose.picked and pk.unit ~= pose.unit and SK.is_hidden and SK.is_hidden(pose.unit)) then
		return
	end

	if not (SK.pose_rig and SK.pose_rig(pk.unit, pk.pos, true)) then
		return
	end

	pose.picked = nil
	mod.sk_pose("target")
	G.pick_done = pk.at
	self._joint = 1
	self:_say("Got them. Click a joint, then drag a bar.")
end

SkeletonKeyThreeView._three_buttons = function (self, input_service)
	self:_three_take_over()

	local widgets = self._widgets_by_name
	local G, SK = sk()
	local job = self:_three_job()
	local away = self:_three_away()

	if away then
		self._own_drag_at = nil

		return
	end

	do
		local newest = nil

		for _, name in ipairs({ "sk3_filter", "sk3_name", "sk3_path", "sk3_chat_in" }) do
			local on = widgets[name] and widgets[name].content.is_writing == true

			if on and not self._t_writing[name] then
				newest = name
			end

			self._t_writing[name] = on
		end

		for _, name in ipairs(newest and { "sk3_filter", "sk3_name", "sk3_path", "sk3_chat_in" } or {}) do
			if name ~= newest and widgets[name] then
				widgets[name].content.is_writing = false
				self._t_writing[name] = false
			end
		end
	end

	for _, name in ipairs({ "sk3_strip_plate", "sk3_anim_plate", "sk3_get_plate", "sk3_dock_plate", "sk3_keysheet" }) do
		if hovered(widgets[name]) then
			self._hovering = true
		end
	end

	self:_own_drag(input_service, "left", job == "person" and "sk3_anim_plate" or "sk3_get_plate")
	self:_own_drag(input_service, "dock", "sk3_dock_plate", 160)

	if self:_three_pressed(widgets.sk3_hide) then
		self._lit_hide = sk_now()
		self:_say(mod.sk_hide("this"), "obj")
	end

	if self:_three_pressed(widgets.sk3_unhide) then
		self._lit_undo = sk_now()
		self:_say(self:_unhide_or_rehide(), "obj")
	end

	if self:_three_pressed(widgets.sk3_marks) then
		self:_say(mod.sk_marks(), "obj")
	end

	if SK and SK.phys and mod.sk_phys and self:_three_pressed(widgets.sk3_phys) then
		self:_say(mod.sk_phys("toggle"), "obj")
	end

	if self:_three_pressed(widgets.sk3_chat) then
		self._t_chat = not self._t_chat

		if widgets.sk3_chat_in then
			widgets.sk3_chat_in.content.is_writing = self._t_chat == true
		end
	end

	if self:_three_pressed(widgets.sk3_key) then
		self._t_sheet = not self._t_sheet
	end

	local notch = notch_of(input_service)

	if self._t_chat then
		if self:_three_pressed(widgets.sk3_chat_ch) then
			self:_three_channel(true)
		end

		if self:_three_pressed(widgets.sk3_chat_send) then
			self:_three_send()
		end
	end

	if job == "person" then
		self:_three_anims(input_service, notch)

		if not self._t_chat then
			self:_three_frames(notch)
			self:_three_sets(notch)
		end
	else
		if self:_three_pressed(widgets.sk3_spawn) then
			self:_three_spawn()
		end

		if not self._t_chat then
			self:_three_items(notch)
			self:_three_groups(notch)
		end
	end
end

-- ───────────────────── ❀ ─────────────────────
--  Chat
-- ───────────────────── ❀ ─────────────────────

-- The game's chat element keeps every line in a ring of 500; the dock shows
-- the newest and sends through the same channels and DMF's commands.
SkeletonKeyThreeView._three_chat_element = function (self)
	local _, SK = sk()

	if not (SK and SK.chat_parts) then
		return nil, nil
	end

	return SK.chat_parts()
end

SkeletonKeyThreeView._three_chat_lines = function (self, n)
	local chat = self:_three_chat_element()
	local msgs = chat and chat._messages
	local out = {}

	if type(msgs) ~= "table" then
		return out
	end

	local total = #msgs
	local i = chat._last_message_index or total

	for _ = 1, math.min(n, total) do
		if msgs[i] then
			table.insert(out, 1, msgs[i])
		end

		i = i - 1

		if i < 1 then
			i = total
		end
	end

	return out
end

SkeletonKeyThreeView._three_channel = function (self, next_one)
	local chat = self:_three_chat_element()

	if not (chat and chat._next_connected_channel_handle) then
		return nil
	end

	if next_one or not chat._selected_channel_handle then
		local ok, handle = pcall(chat._next_connected_channel_handle, chat)

		if ok and handle then
			chat._selected_channel_handle = handle
		end
	end

	local handle = chat._selected_channel_handle
	local okc, sessions = pcall(function() return Managers.chat:sessions() end)
	local channel = okc and sessions and handle and sessions[handle]

	return handle, channel, chat
end

SkeletonKeyThreeView._three_channel_name = function (self, chat, tag, name)
	local ok, shown = pcall(chat._channel_name, chat, tag, false, name)

	return ok and shown or tostring(tag or "")
end

SkeletonKeyThreeView._three_cut = function (self, text, most)
	local u = rawget(_G, "Utf8")

	if u and u.string_length and u.sub_string then
		local ok, n = pcall(u.string_length, text)

		if ok and n and n > most then
			local okc, cut = pcall(u.sub_string, text, 1, most)

			return okc and cut or text
		end

		return text
	end

	return string.sub(text, 1, most)
end

SkeletonKeyThreeView._three_send = function (self)
	local box = self._widgets_by_name.sk3_chat_in.content
	local text = box.input_text or ""

	box.input_text = ""
	box.is_writing = true

	if text == "" then
		return
	end

	if string.sub(text, 1, 1) == "/" then
		local dmf = get_mod("DMF")
		local name = string.match(text, "^/(%S+)")
		local args = {}

		for word in string.gmatch(text, "%S+") do
			args[#args + 1] = word
		end

		table.remove(args, 1)

		local okl, list = pcall(function() return dmf and name and dmf.get_commands_list(name) or {} end)
		local found = nil

		for _, one in ipairs(okl and list or {}) do
			if one.name == string.lower(name) then
				found = one.name
			end
		end

		if found then
			dmf.run_command(found, unpack(args))
		else
			self:_say("That command isn't known: " .. text)
		end

		return
	end

	local handle, channel, chat = self:_three_channel(false)

	if not (handle and channel and chat) then
		self:_say("No chat channel is open yet. Try again soon.")

		return
	end

	local okm, scrubbed = pcall(chat._scrub, chat, text)

	pcall(function()
		Managers.chat:send_channel_message(handle, self:_three_cut(okm and scrubbed or text, 200))
	end)
end

-- While the dock is chat the game's own window stays shut; it keeps every
-- line meanwhile, and giving it back re-runs its visibility.
SkeletonKeyThreeView._three_chat_window = function (self, hide)
	local chat, elements = self:_three_chat_element()

	if hide and chat and chat.set_visible and (not self._t_chat_hid or sk_now() - self._t_chat_hid > 1) then
		self._t_chat_hid = sk_now()
		pcall(chat.set_visible, chat, false)
	elseif not hide and self._t_chat_hid then
		self._t_chat_hid = nil

		if elements then
			elements._current_group_name = nil
		end
	end
end

SkeletonKeyThreeView._three_anim_list = function (self)
	local _, SK = sk()
	local typed = typed_of(self._widgets_by_name.sk3_filter)
	local now = sk_now()
	local cache = self._t_anims

	if cache and cache.typed == typed and now >= cache.at and now - cache.at < 1 then
		return cache.list
	end

	local list = SK and SK.poses and SK.poses(typed) or {}

	self._t_anims = { typed = typed, at = now, list = list }

	return list
end

SkeletonKeyThreeView._three_anims = function (self, input_service, notch)
	local widgets = self._widgets_by_name
	local pose = mod.pose_state()
	local list = self:_three_anim_list()
	local rows = L.ANIM_ROWS
	local most = math.max(0, #list - rows)
	local over = false

	for r = 1, rows do
		over = over or hovered(widgets["sk3_anim_" .. r]) or hovered(widgets["sk3_anim" .. r .. "_play"])
	end

	if over and notch ~= 0 then
		self._atop = self._atop - (notch > 0 and 1 or -1)
	end

	self._atop = math.max(0, math.min(most, self._atop))

	for r = 1, rows do
		local e = list[self._atop + r]

		if e and self:_three_pressed(widgets["sk3_anim" .. r .. "_play"]) then
			self:_say(mod.sk_tape("record", e.event, e.machine))
		end
	end

	local name = typed_of(widgets.sk3_name)

	if self:_three_pressed(widgets.sk3_rest) then
		self:_say(mod.sk_anim("rest"))
	end

	if self:_three_pressed(widgets.sk3_clip) then
		self:_say(mod.sk_keyframe("clip", name))
	end

	if self:_three_pressed(widgets.sk3_keyrange) then
		self:_say(mod.sk_tape("keyto", 1))
	end

	if self:_three_pressed(widgets.sk3_keyframe) then
		self:_say(mod.sk_tape("key", name))
	end

	local tape = widgets.sk3_tape
	local frames = pose.tape and pose.tape.frames and #pose.tape.frames or 0

	if tape and (hovered(tape) or (tape.content.inhot and tape.content.inhot.is_hover and tape.content.visible ~= false)) then
		self._hovering = true
	end

	if tape and tape.content.hotspot.on_pressed then
		tape.content.hotspot.on_pressed = false

		local on_in = tape.content.inhot and tape.content.inhot.is_hover
		local cx = cursor_of(input_service)

		if on_in and cx and frames > 1 then
			local x = cx - self:_own_origin("left") - L.TAPE_X

			local function x_of(i)
				return (math.max(1, math.min(frames, i or 1)) - 1) / (frames - 1) * L.TAPE_W
			end

			on_in = math.abs(x - x_of(pose.tape_in)) < math.abs(x - x_of(pose.tape_i))
		end

		self._t_tdrag = frames > 0 and (on_in and "in" or "at") or nil
	end

	if self._t_tdrag then
		local cx = cursor_of(input_service)

		if left_held() and cx and frames > 0 then
			local ox = self:_own_origin("left")
			local along = math.max(0, math.min(1, (cx - ox - L.TAPE_X) / L.TAPE_W))

			mod.sk_tape(self._t_tdrag == "in" and "in" or "seek", 1 + along * (frames - 1))
			self._hovering = true
		else
			self._t_tdrag = nil
		end
	end
end

SkeletonKeyThreeView._three_window = function (self)
	local pose = mod.pose_state()
	local n = #(pose.frames or {})
	local most = math.max(0, n - L.KF_SLOTS)

	self._ktop = math.max(0, math.min(most, self._ktop or 0))

	return pose.frames or {}, self._ktop, most
end

SkeletonKeyThreeView._three_frames = function (self, notch)
	local widgets = self._widgets_by_name
	local pose = mod.pose_state()
	local frames, top, most = self:_three_window()

	if self:_three_pressed(widgets.sk3_save) then
		self:_say(mod.sk_keyframe("save", typed_of(widgets.sk3_name)))
		self._kf_sel = #pose.frames
		self._ktop = math.max(0, #pose.frames - L.KF_SLOTS)
	end

	if self:_three_pressed(widgets.sk3_play) then
		self:_say(mod.sk_keyframe(pose.play and "stop" or "play"))
	end

	if self:_three_pressed(widgets.sk3_loop) then
		self:_say(mod.sk_keyframe("loop"))
	end

	if self._ask.clear and sk_now() - self._ask.clear > ASKS_FOR then
		self._ask.clear = nil
	end

	if self:_three_pressed(widgets.sk3_kclear) then
		if self._ask.clear then
			self._ask.clear = nil
			self._kf_sel = nil
			self:_say(mod.sk_keyframe("clear"))
		elseif #frames > 0 then
			self._ask.clear = sk_now()
			self:_say("Press Confirm to delete your " .. (#frames == 1 and "1 keyframe" or (#frames .. " keyframes")) .. ".")
		else
			self:_say(mod.sk_keyframe("clear"))
		end
	end

	if self:_three_pressed(widgets.sk3_kprev) then
		self._ktop = math.max(0, top - L.KF_SLOTS)
	end

	if self:_three_pressed(widgets.sk3_knext) then
		self._ktop = math.min(most, top + L.KF_SLOTS)
	end

	for k = 1, L.KF_SLOTS do
		local i = top + k
		local frame = frames[i]
		local block = widgets["sk3_kf_" .. k]

		if frame and hovered(block) and notch ~= 0 then
			mod.sk_keyframe("hold", i, (frame.hold or 2) + notch * HOLD_STEP)
		end

		if frame and self:_three_pressed(block) then
			self._kf_sel = i
			self._chip = i
			self:_say(mod.sk_keyframe("apply", i))
		end
	end

	local sel = self._kf_sel and frames[self._kf_sel] and self._kf_sel or nil

	if sel and self:_three_pressed(widgets.sk3_kupdate) then
		self:_say(mod.sk_keyframe("over", sel))
	end

	if sel and self:_three_pressed(widgets.sk3_kdel) then
		self._kf_sel = nil
		self._chip = nil
		self:_say(mod.sk_keyframe("delete", sel))
	end
end

SkeletonKeyThreeView._three_sets = function (self, notch)
	local widgets = self._widgets_by_name
	local _, SK = sk()
	local names = SK and SK.anim_index("sets") or {}
	local over = false

	if self:_three_pressed(widgets.sk3_setsave) then
		local name = typed_of(widgets.sk3_name)

		self:_say(name and mod.sk_set("save", name) or "Type a name for the set first.")
	end

	for r = 1, L.DROWS do
		over = over or hovered(widgets["sk3_set_" .. r])

		for _, verb in ipairs({ "play", "load", "export", "del" }) do
			over = over or hovered(widgets["sk3_set" .. r .. "_" .. verb])
		end
	end

	if over and notch ~= 0 then
		self._stop = self._stop - (notch > 0 and 1 or -1)
	end

	self._stop = math.max(0, math.min(math.max(0, #names - L.DROWS), self._stop))

	for r = 1, L.DROWS do
		local name = names[self._stop + r]

		if name and self:_three_pressed(widgets["sk3_set" .. r .. "_play"]) then
			self:_say(mod.sk_set("play", name))
		end

		if name and self:_three_pressed(widgets["sk3_set" .. r .. "_export"]) then
			self:_say(mod.sk_set("export", name))
		end

		if name and self:_three_pressed(widgets["sk3_set" .. r .. "_load"]) then
			local have = #(mod.pose_state().frames or {})
			local ask = self._ask.load

			if have > 0 and not (ask and ask.name == name and sk_now() - ask.at < ASKS_FOR) then
				self._ask.load = { name = name, at = sk_now() }
				self:_say("Press Load again to replace your " .. (have == 1 and "1 keyframe" or (have .. " keyframes")) .. ".")
			else
				self._ask.load = nil

				local said, failed = mod.sk_set("load", name)

				if not failed then
					mod.sk_keyframe("apply", 1)
					self._kf_sel, self._ktop = 1, 0
				end

				self:_say(said)
			end
		end

		if name and self:_three_pressed(widgets["sk3_set" .. r .. "_del"]) then
			local ask = self._ask.del

			if ask and ask.name == name and sk_now() - ask.at < ASKS_FOR then
				self._ask.del = nil
				self:_say(mod.sk_set("delete", name))
			else
				self._ask.del = { name = name, at = sk_now() }
				self:_say("Press × again to delete " .. name .. ".")
			end
		end
	end
end

SkeletonKeyThreeView._three_items = function (self, notch)
	local widgets = self._widgets_by_name
	local G, SK = sk()
	local kept = SK and SK.keep_list() or {}
	local over = false

	if self:_three_pressed(widgets.sk3_holdall) then
		self:_say(mod.sk_object("holdall"), "obj")
	end

	if self:_three_pressed(widgets.sk3_grpsave) then
		if not (SK and SK.object_alive()) then
			self:_say("Hold something first, then Save As Group.", "obj")
		else
			self._rename = { id = "newgroup", row = "" }
			widgets.rename_input.content.input_text = ""
			widgets.rename_input.content.is_writing = true
			widgets.rename_box.content.what = "a new group, or an old one to add to"
		end
	end

	for r = 1, L.DROWS do
		over = over or hovered(widgets["sk3_item_" .. r]) or hovered(widgets["sk3_item" .. r .. "_x"])
	end

	if over and notch ~= 0 then
		self._itop3 = self._itop3 - (notch > 0 and 1 or -1)
	end

	self._itop3 = math.max(0, math.min(math.max(0, #kept - L.DROWS), self._itop3))

	for r = 1, L.DROWS do
		local i = self._itop3 + r

		local on_x = self:_three_pressed(widgets["sk3_item" .. r .. "_x"])
		local on_row = self:_three_pressed(widgets["sk3_item_" .. r])

		if kept[i] and on_x then
			self:_say(mod.sk_object("forget", i), "obj")
		elseif kept[i] and on_row then
			local anchor = self._t_ianchor

			if self:_ctrl_held() then
				self:_say(mod.sk_object("toggle", i), "obj")
				self._t_ianchor = i
			elseif anchor and kept[anchor] and self:_three_shift() then
				local run = {}

				for j = math.min(anchor, i), math.max(anchor, i) do
					run[#run + 1] = j
				end

				self:_say(mod.sk_object("holdset", table.concat(run, ",")), "obj")
			else
				self:_say(mod.sk_object("kept", i), "obj")
				self._t_ianchor = i
			end
		end
	end
end

SkeletonKeyThreeView._three_shift = function (self)
	for _, name in ipairs({ "left shift", "right shift" }) do
		local okk, index = pcall(Keyboard.button_index, name)
		local okd, down = pcall(Keyboard.button, okk and index or -1)

		if okk and index and okd and down and down > 0 then
			return true
		end
	end

	return false
end

SkeletonKeyThreeView._three_group_names = function (self)
	local now = sk_now()

	if not self._t_groups or now < (self._t_groups_at or 0) or now - self._t_groups_at > 1 then
		self._t_groups = self:_group_names()
		self._t_groups_at = now
	end

	return self._t_groups
end

SkeletonKeyThreeView._three_groups = function (self, notch)
	local widgets = self._widgets_by_name
	local _, SK = sk()
	local names = self:_three_group_names()
	local over = false

	for r = 1, L.GROWS do
		over = over or hovered(widgets["sk3_grp_" .. r])
	end

	if over and notch ~= 0 then
		self._gtop3 = self._gtop3 - (notch > 0 and 1 or -1)
	end

	self._gtop3 = math.max(0, math.min(math.max(0, #names - L.GROWS), self._gtop3))

	for r = 1, L.GROWS do
		local i = self._gtop3 + r
		local name = names[i]

		if name and self:_three_pressed(widgets["sk3_grp" .. r .. "_save"]) then
			self:_say(mod.sk_object("sync", name), "obj")
		elseif name and self:_three_pressed(widgets["sk3_grp" .. r .. "_load"]) then
			local out = SK and SK.group_loaded and SK.group_loaded(name)

			self:_say(mod.sk_object(out and "unload" or "load", name), "obj")
			self._t_groups = nil
		elseif name and self:_three_pressed(widgets["sk3_grp_" .. r]) then
			if self:_ctrl_held() then
				self._gsel3[name] = not self._gsel3[name] or nil
				self._t_ganchor = i
			elseif self._t_ganchor and names[self._t_ganchor] and self:_three_shift() then
				self._gsel3 = {}

				for j = math.min(self._t_ganchor, i), math.max(self._t_ganchor, i) do
					self._gsel3[names[j]] = true
				end
			else
				self._gsel3 = { [name] = true }
				self._t_ganchor = i
			end
		end
	end

	local chosen = {}

	for _, name in ipairs(names) do
		if self._gsel3[name] then
			chosen[#chosen + 1] = name
		end
	end

	if self:_three_pressed(widgets.sk3_export) then
		local said

		for _, name in ipairs(chosen) do
			said = mod.sk_object("export", name)
		end

		if #chosen == 0 then
			self:_say("Click a group first, then Export.", "obj")
		elseif #chosen == 1 then
			self:_say(said, "obj")
		else
			self:_say("Exported " .. #chosen .. " groups.", "obj")
		end
	end

	if self:_three_pressed(widgets.sk3_folder) then
		self:_say(mod.sk_object("folder"), "obj")
	end

	if self:_three_pressed(widgets.sk3_merge) then
		if #chosen < 2 then
			self:_say("Ctrl+click two or more groups, then Merge.", "obj")
		else
			self._merge_from = table.concat(chosen, ",")
			self._rename = { id = "mergegroup", row = "" }
			widgets.rename_input.content.input_text = ""
			widgets.rename_input.content.is_writing = true
			widgets.rename_box.content.what = "the merged group, from " .. #chosen .. " groups"
		end
	end
end

-- ───────────────────── ❀ ─────────────────────
--  Fill
-- ───────────────────── ❀ ─────────────────────

local BASE_HIDDEN = {
	"note", "button_marks", "button_chat", "button_phys", "button_hide_this", "button_show_all", "hide_note",
	"button_tab_poses", "button_tab_joints", "button_tab_frames", "button_tab_sets",
	"button_otab_move", "button_otab_items", "button_otab_groups",
}

local GLASS_PLATES = {
	plate = { "plate", "list", "dials", "frames", "foot" },
	obj_plate = { "plate", "dials" },
}

-- Every move of a node is written down, the panel's own included, so the
-- skin only moves one when it changes; a move costs a whole scenegraph pass.
SkeletonKeyThreeView._set_scenegraph_position = function (self, id, x, y, ...)
	self._t_nodes = self._t_nodes or {}
	self._t_nodes[id] = { x, y }

	return SkeletonKeyPoseView._set_scenegraph_position(self, id, x, y, ...)
end

SkeletonKeyThreeView._three_node = function (self, id, x, y)
	local was = self._t_nodes and self._t_nodes[id]

	if not (was and was[1] == x and was[2] == y) then
		pcall(self._set_scenegraph_position, self, id, x, y)
	end
end

SkeletonKeyThreeView._three_place = function (self, which, on)
	local p = self.PANELS[which]

	if not on then
		self:_three_node(p.node, which == "pose" and 4000 or -4000, 0)

		return
	end

	local at = self._at and self._at[which] or { 0, 0 }
	local grow = which == "objkey" and (self._obj_grow or 0) or 0

	self:_three_node(p.node, p.home + at[1], at[2] + grow)
end

-- The newest reply, for the dock to show while no side panel is up to say it.
SkeletonKeyThreeView._three_fresh = function (self)
	local now = sk_now()
	local pose_fresh = (self._reply or "") ~= "" and now - (self._said_at or 0) < SAY_HOLDS
	local obj_fresh = (self._obj_reply or "") ~= "" and now - (self._obj_said_at or 0) < SAY_HOLDS

	if pose_fresh and obj_fresh then
		return (self._said_at or 0) >= (self._obj_said_at or 0) and self._reply or self._obj_reply
	end

	return (pose_fresh and self._reply) or (obj_fresh and self._obj_reply) or nil
end

SkeletonKeyThreeView._three_fill = function (self)
	local widgets = self._widgets_by_name

	for _, name in ipairs(BASE_HIDDEN) do
		show(widgets[name], false)
	end

	local G, SK = sk()
	local pose = mod.pose_state()
	local job = self._job or self:_three_job()
	local away = self:_three_away()
	local person = job == "person" and not away
	local prop = job == "prop" and not away

	do
		local okk, index = pcall(Keyboard.button_index, "k")
		local okd, down = pcall(Keyboard.button, okk and index or -1)
		local held = okk and okd and down and down > 0 and not self:_typing()

		self._t_sheet_up = not away and (held or self._t_sheet or hovered(widgets.sk3_key)) and true or false
		show(widgets.keysheet, false)
		show(widgets.sk3_keysheet, self._t_sheet_up)
	end

	self:_three_place("pose", person and not self._pose_parked)
	self:_three_place("objkey", prop and not self._obj_parked)

	for name, ids in pairs(GLASS_PLATES) do
		local w = widgets[name]

		self._t_alpha = self._t_alpha or {}

		for _, id in ipairs(w and ids or {}) do
			local st = w.style[id]

			if st and st.color then
				local key = name .. "." .. id

				self._t_alpha[key] = self._t_alpha[key] or st.color[1]
				st.color[1] = math.min(self._t_alpha[key], L.GLASS_ALPHA)
			end
		end
	end

	for which, o in pairs(self.OWN) do
		local ox, oy = 0, 0

		if not away then
			local at = self._own_at[which] or { 0, 0 }

			ox, oy = o.at[1] + at[1], o.at[2] + at[2]
		else
			ox = -4000
		end

		self:_three_node(o.node, ox, oy)
	end

	local _, SKs = sk()
	local unhide_up = SKs ~= nil and ((SKs.hidden and #SKs.hidden > 0) or (SKs.unhidden and #SKs.unhidden > 0)) or false
	local short = unhide_up and 0 or (widgets.sk3_unhide.style.face.size[1] + 6)

	widgets.sk3_strip_plate.style.plate.size[1] = L.STRIP_W - short

	if widgets.sk3_strip_plate.style.hotspot then
		widgets.sk3_strip_plate.style.hotspot.size[1] = L.STRIP_W - short
	end
	self:_three_node("sk3_strip", L.STRIP_AT[1] + short * 0.5, away and -4000 or L.STRIP_AT[2])

	if widgets.sk3_filter then
		widgets.sk3_filter.content.placeholder_text = "Filter"
	end

	self:_three_fill_strip(away)

	local chatting = self._t_chat == true and (person or prop)
	local under = self._t_sheet_up == true
	local dock_person = person and not chatting and not under
	local dock_prop = prop and not chatting and not under

	for _, name in ipairs({ "sk3_anim_plate", "sk3_filter", "sk3_rest", "sk3_clip" }) do
		show(widgets[name], person)
	end

	for _, name in ipairs({ "sk3_save", "sk3_play", "sk3_loop", "sk3_kclear", "sk3_name", "sk3_setsave" }) do
		show(widgets[name], dock_person)
	end

	for _, name in ipairs({ "sk3_get_plate", "sk3_path", "sk3_spawn", "sk3_get_hint" }) do
		show(widgets[name], prop)
	end

	for _, name in ipairs({ "sk3_holdall", "sk3_grpsave", "sk3_merge", "sk3_export", "sk3_folder" }) do
		show(widgets[name], dock_prop)
	end

	show(widgets.sk3_dock_plate, person or prop)
	widgets.sk3_dock_plate.style.split.color[1] = chatting and 0 or 255
	self:_three_fill_chat(chatting and not under)

	for _, name in ipairs({ "sk3_filter", "sk3_name" }) do
		if widgets[name] and not person then
			widgets[name].content.is_writing = false
		end
	end

	if widgets.sk3_path and not prop then
		widgets.sk3_path.content.is_writing = false
	end

	if self._rename then
		for _, name in ipairs({ "sk3_filter", "sk3_name", "sk3_path", "sk3_chat_in" }) do
			if widgets[name] then
				widgets[name].content.is_writing = false
			end
		end
	end

	if self._t_naming and not self._rename then
		self._t_groups = nil
	end

	self._t_naming = self._rename ~= nil

	local dock = widgets.sk3_dock_plate.content

	if chatting then
		dock.left, dock.right, dock.sub = "", "", ""
	elseif person then
		dock.left, dock.right, dock.sub = "Keyframes", "Sets", ""
	elseif prop then
		local kept = SK and SK.keep_list() or {}

		dock.left, dock.right = "Items", "Groups"
		local card = widgets.obj_plate
		local fresh = card and card.content.visible == false and self:_three_fresh() or nil

		dock.sub = fresh or (#kept == 0 and "Nothing on the list yet. S adds what you hold."
			or (#kept .. " on the list. Click one to hold it."))
		dock.sub = self:_fit_to(widgets.sk3_dock_plate, "sub", dock.sub, 44)
	end

	self:_three_fill_anims(person, pose)
	self:_three_fill_frames(dock_person, pose)
	self:_three_fill_sets(dock_person, SK)
	self:_three_fill_items(dock_prop, G, SK)
	self:_three_fill_groups(dock_prop, SK)
end

SkeletonKeyThreeView._three_fill_chat = function (self, chatting)
	local widgets = self._widgets_by_name

	for _, name in ipairs({ "sk3_chat_in", "sk3_chat_ch", "sk3_chat_send" }) do
		show(widgets[name], chatting)
	end

	if not self._t_chat and widgets.sk3_chat_in then
		widgets.sk3_chat_in.content.is_writing = false
	end

	self:_three_chat_window(self._t_chat == true and not self._tucked)

	-- The text template only limits pasting, so a typed line is cut here, by
	-- characters, never through one.
	local box = widgets.sk3_chat_in and widgets.sk3_chat_in.content

	if box and box.input_text then
		box.input_text = self:_three_cut(box.input_text, 200)
	end

	local lines = chatting and self:_three_chat_lines(L.CHAT_LINES) or {}
	local chat = chatting and self:_three_chat_element() or nil

	for i = 1, L.CHAT_LINES do
		local w = widgets["sk3_chat_line_" .. i]
		local m = lines[#lines - L.CHAT_LINES + i]

		show(w, chatting and m ~= nil)

		if w and m then
			local text = tostring(m.message_text or "")

			if m.author_name then
				local tag = "[" .. self:_three_channel_name(chat, m.channel_tag) .. "]"
				local plain = self:_fit_to(w, "label", tag .. " " .. tostring(m.author_name) .. ": " .. text, 120)

				if string.sub(plain, 1, #tag) == tag and m.channel_color then
					plain = "{#color(" .. m.channel_color .. ")}" .. tag .. "{#reset()}" .. string.sub(plain, #tag + 1)
				end

				w.content.label = plain
				paint(w.style.label.text_color, 236, 230, 216)
			else
				w.content.label = self:_fit_to(w, "label", (string.gsub(text, "\n", " ")), 120)
				paint(w.style.label.text_color, 141, 148, 160)
			end
		end
	end

	if chatting and widgets.sk3_chat_ch then
		local _, channel, element = self:_three_channel(false)

		widgets.sk3_chat_ch.content.label = channel and element and self:_three_channel_name(element, channel.tag, channel.channel_name)
			or "No channel yet"
	end
end

SkeletonKeyThreeView._three_fill_strip = function (self, away)
	local widgets = self._widgets_by_name
	local _, SK = sk()
	local hidden = SK and SK.hidden and #SK.hidden or 0
	local again = SK ~= nil and SK.unhidden ~= nil and #SK.unhidden > 0
	local okh, holding_any = pcall(function() return SK and SK.selected_unit() ~= nil end)

	show(widgets.sk3_strip_plate, not away)

	for _, t in ipairs(L.TOOLS) do
		show(widgets[t[1]], not away)
	end

	show(widgets.sk3_phys, not away and SK ~= nil and SK.phys ~= nil)
	show(widgets.sk3_unhide, not away and (hidden > 0 or again))

	if away then
		return
	end

	widgets.sk3_unhide.content.label = hidden > 0 and ("Unhide " .. hidden) or (again and "Rehide" or "Unhide")

	local marks = mod.sk_marks("state") == "on"

	lit(widgets.sk3_marks, marks)
	widgets.sk3_marks.content.label = marks and "Hide Hidden Markers" or "Show Hidden Markers"
	lit(widgets.sk3_phys, SK ~= nil and SK.phys ~= nil and SK.phys.wanted() == true)
	lit(widgets.sk3_chat, self._t_chat == true)
	lit(widgets.sk3_key, self._t_sheet == true)
	lit(widgets.sk3_hide, false)
	lit(widgets.sk3_unhide, false)
	self:_dim(widgets.sk3_hide, "sk3_hide", not (okh and holding_any), "Click something first, then Hide.")
end

SkeletonKeyThreeView._three_fill_anims = function (self, person, pose)
	local widgets = self._widgets_by_name
	local list = person and self:_three_anim_list() or {}
	local playing = pose.anim and pose.anim.event or nil

	for r = 1, L.ANIM_ROWS do
		local row = widgets["sk3_anim_" .. r]
		local e = list[self._atop + r]

		show(row, person and e ~= nil)
		show(widgets["sk3_anim" .. r .. "_play"], person and e ~= nil)

		if row and e then
			local on = playing ~= nil and e.event == playing

			row.content.name = self:_fit_to(row, "name", (string.gsub(e.name or e.event or "", "_", " ")), 26)
			row.content.source = self:_fit_to(row, "source", e.source or "", 12)
			row.style.face.color[1] = 255
			paint(row.style.face.color, on and 64 or 44, on and 66 or 48, on and 62 or 54)
			lit(widgets["sk3_anim" .. r .. "_play"], on)
		end
	end

	local empty = widgets.sk3_anim_empty

	show(empty, person and #list == 0)

	if empty and person and #list == 0 then
		local typed = typed_of(widgets.sk3_filter)

		empty.content.line1 = typed and "Nothing matches that." or "No animations yet."
		empty.content.line2 = typed and "Try fewer letters." or "The game has not loaded its item list yet."
	end

	local frames = pose.tape and pose.tape.frames and #pose.tape.frames or 0

	local tape = widgets.sk3_tape

	show(tape, person)
	show(widgets.sk3_keyrange, person)
	show(widgets.sk3_keyframe, person)

	if tape and person then
		local function x_of(i)
			return frames > 1 and (math.max(1, math.min(frames, i or 1)) - 1) / (frames - 1) * L.TAPE_W or 0
		end

		local at, from = x_of(pose.tape_i), x_of(pose.tape_in)
		local back = at < from

		tape.style.fill.offset[1] = L.TAPE_X + math.min(at, from)
		tape.style.fill.size[1] = math.abs(at - from)
		paint(tape.style.fill.color, back and 192 or 120, back and 96 or 190, back and 78 or 120)
		tape.style.knob.offset[1] = L.TAPE_X + at - 4
		tape.style.inknob.offset[1] = L.TAPE_X + from - 4
		tape.style.inhot.offset[1] = L.TAPE_X + from - 10
		tape.content.label = frames > 0 and (math.max(1, math.min(frames, pose.tape_i or 1)) .. " / " .. frames)
			or "Play an animation to fill the tape."

		for _, name in ipairs({ "sk3_keyrange", "sk3_keyframe" }) do
			self:_dim(widgets[name], name, frames == 0 or pose.taping ~= nil, "Play an animation first.")
		end
	end

	if person then
		widgets.sk3_clip.content.label = pose.frozen and "Save Held" or "Save Clip"
	end
end

SkeletonKeyThreeView._three_fill_frames = function (self, person, pose)
	local widgets = self._widgets_by_name
	local _, SK = sk()
	local frames, top, most = self:_three_window()
	local n = math.min(L.KF_SLOTS, #frames - top)
	local gap = 3
	local room = L.KF_W - gap * math.max(0, n - 1)
	local least = 56
	local total = 0

	for k = 1, n do
		total = total + math.max(0.05, frames[top + k].hold or 2)
	end

	local x = L.KF_X
	local sel = self._kf_sel and frames[self._kf_sel] and self._kf_sel or nil

	if not frames[self._kf_sel or 0] then
		self._kf_sel = nil
	end

	for k = 1, L.KF_SLOTS do
		local i = top + k
		local frame = frames[i]
		local block = widgets["sk3_kf_" .. k]
		local there = person and frame ~= nil and k <= n

		show(block, there)

		if block and there then
			local hold = math.max(0.05, frame.hold or 2)
			local w = least + (room - least * n) * (total > 0 and hold / total or 1 / n)
			local st = block.style
			local picked = i == sel
			local now = pose.play and pose.play.i == i

			for _, id in ipairs({ "hotspot", "face", "top", "bottom" }) do
				if st[id] then
					st[id].offset[1] = x
					st[id].size[1] = w
				end
			end

			st.start.offset[1] = x
			st.name.offset[1], st.name.size[1] = x + 8, w - 12
			st.hold.offset[1], st.hold.size[1] = x + 8, w - 12
			st.top.color[1], st.bottom.color[1] = picked and 255 or 0, picked and 255 or 0
			paint(st.face.color, picked and 82 or (now and 70 or 52), picked and 80 or (now and 66 or 55), picked and 72 or (now and 52 or 60))
			block.content.name = self:_fit_to(block, "name", frame.name or ("frame " .. i), 20)
			block.content.hold = (SK and SK.num and (SK.num(hold) .. "s")) or string.format("%.1fs", hold)
			x = x + w + gap
		end
	end

	show(widgets.sk3_kprev, person and top > 0)
	show(widgets.sk3_knext, person and top < most)

	local info = widgets.sk3_kinfo

	show(info, person)

	if info and person then
		local frame = sel and frames[sel]

		info.content.label = frame and self:_fit_to(info, "label", (frame.name or "") .. "   holds " .. string.format("%.1fs", frame.hold or 2), 30) or ""
		info.content.hint = #frames > 0 and "Wheel on a bar changes its time." or ""
		info.content.empty = #frames == 0 and "No keyframes yet." or ""
		info.content.empty2 = #frames == 0 and "Pose a joint, then press Save Pose." or ""
	end

	show(widgets.sk3_kupdate, person and sel ~= nil)
	show(widgets.sk3_kdel, person and sel ~= nil)

	if person then
		widgets.sk3_play.content.label = pose.play and "Stop" or "Play"
		lit(widgets.sk3_loop, pose.loop == true)
		widgets.sk3_kclear.content.label = self._ask.clear and "Confirm" or "Clear"
		self:_dim(widgets.sk3_play, "sk3_play", #frames == 0, "No keyframes to play yet.")
		self:_dim(widgets.sk3_kclear, "sk3_kclear", #frames == 0, "No keyframes to clear.")
	end
end

SkeletonKeyThreeView._three_fill_sets = function (self, person, SK)
	local widgets = self._widgets_by_name
	local names = person and SK and SK.anim_index("sets") or {}

	for r = 1, L.DROWS do
		local name = names[self._stop + r]
		local row = widgets["sk3_set_" .. r]

		show(row, person and name ~= nil)

		for _, verb in ipairs({ "play", "load", "export", "del" }) do
			show(widgets["sk3_set" .. r .. "_" .. verb], person and name ~= nil)
		end

		if row and name then
			row.content.name = self:_fit_to(row, "name", name, 14)

			local asked = self._ask.del and self._ask.del.name == name and sk_now() - self._ask.del.at < ASKS_FOR

			widgets["sk3_set" .. r .. "_del"].content.label = asked and "?" or "×"
		end
	end

	local empty = widgets.sk3_dempty

	show(empty, person and #names == 0)

	if empty and person and #names == 0 then
		empty.content.line1 = "No sets yet."
		empty.content.line2 = "Make keyframes, then Save Keyframes As Set."
	end
end

SkeletonKeyThreeView._three_fill_items = function (self, prop, G, SK)
	local widgets = self._widgets_by_name
	local kept = prop and SK and SK.keep_list() or {}
	local obj = G and G.object
	local holding = SK ~= nil and SK.object_alive()

	for r = 1, L.DROWS do
		local i = self._itop3 + r
		local one = kept[i]
		local row = widgets["sk3_item_" .. r]
		local x = widgets["sk3_item" .. r .. "_x"]

		show(row, prop and one ~= nil)
		show(x, prop and one ~= nil and (hovered(row) or hovered(x)))

		if row and one then
			local kind, dot = "", SK.KIND_PROP

			if SK.kind_of then
				kind, dot = SK.kind_of(one.unit)
			end

			local away = SK.distance_to and SK.distance_to(one.unit)
			local held = false

			for _, c in ipairs((holding and obj and obj.crew) or {}) do
				if c.unit == one.unit then
					held = true
				end
			end

			row.content.name = self:_fit_to(row, "name", shown_name(one.name), 30)
			row.content.kind = kind or ""
			row.content.away = away and (away .. " m") or ""
			row.style.held.color[1] = held and 255 or 0

			if dot then
				paint(row.style.dot.color, dot[1], dot[2], dot[3])
			end
		end
	end

	if prop then
		self:_dim(widgets.sk3_holdall, "sk3_holdall", #kept < 2, "Needs two or more things on the list.")
		self:_dim(widgets.sk3_grpsave, "sk3_grpsave", not holding, "Hold something first.")
	end
end

SkeletonKeyThreeView._three_fill_groups = function (self, prop, SK)
	local widgets = self._widgets_by_name
	local names = prop and self:_three_group_names() or {}
	local picked = 0

	for r = 1, L.GROWS do
		local name = names[self._gtop3 + r]
		local row = widgets["sk3_grp_" .. r]
		local out = name ~= nil and SK and SK.group_loaded and SK.group_loaded(name) or false

		show(row, prop and name ~= nil)
		show(widgets["sk3_grp" .. r .. "_load"], prop and name ~= nil)
		show(widgets["sk3_grp" .. r .. "_save"], prop and name ~= nil and out == true and SK.group_sync ~= nil)

		if row and name then
			row.content.name = self:_fit_to(row, "name", name, 20)
			row.style.dot.color[1] = out and 255 or 0
			row.style.sel.color[1] = self._gsel3[name] and 255 or 0
			widgets["sk3_grp" .. r .. "_load"].content.label = out and "Unload" or "Load"
		end
	end

	for _, name in ipairs(names) do
		if self._gsel3[name] then
			picked = picked + 1
		end
	end

	local empty = widgets.sk3_dempty

	if prop and #names == 0 then
		show(empty, true)
		empty.content.line1 = "No groups in this level yet."
		empty.content.line2 = "Hold things, then Save As Group."
	elseif prop then
		show(empty, false)
	end

	if prop then
		self:_dim(widgets.sk3_merge, "sk3_merge", picked < 2, "Ctrl+click two or more groups first.")
		self:_dim(widgets.sk3_export, "sk3_export", picked < 1, "Click a group first, then Export.")
	end
end

return SkeletonKeyThreeView
