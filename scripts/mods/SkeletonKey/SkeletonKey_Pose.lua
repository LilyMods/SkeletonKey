local mod = get_mod("SkeletonKey")

require("scripts/ui/views/base_view")

local UIRenderer = require("scripts/managers/ui/ui_renderer")

local definitions = mod:io_dofile("SkeletonKey/scripts/mods/SkeletonKey/SkeletonKey_Pose_Definitions")

-- ───────────────────── ❀ ─────────────────────
--  Constants & Keys
-- ───────────────────── ❀ ─────────────────────

local VIEW_NAME = "skeletonkey_pose_view"
local AXES = definitions.AXES
local JOINT_SLOTS = definitions.JOINT_SLOTS
local CHART_NODES = definitions.CHART_NODES or {}
local KEY_ROWS = definitions.KEY_ROWS
local ROW_VERBS = definitions.ROW_VERBS
local SET_ROWS = definitions.SET_ROWS
local POSE_ROWS = definitions.POSE_ROWS
local HOLD_BAR_W = definitions.HOLD_BAR_W
local HOLD_MAX = definitions.HOLD_MAX
local REPEAT_AFTER = 0.35
local REPEAT_EVERY = 0.06
local TYPING_KEYS = {}

for _, pair in ipairs({
	{ "0", "0" }, { "1", "1" }, { "2", "2" }, { "3", "3" }, { "4", "4" }, { "5", "5" }, { "6", "6" }, { "7", "7" }, { "8", "8" }, { "9", "9" },
	{ "numpad 0", "0" }, { "numpad 1", "1" }, { "numpad 2", "2" }, { "numpad 3", "3" }, { "numpad 4", "4" }, { "numpad 5", "5" }, { "numpad 6", "6" }, { "numpad 7", "7" }, { "numpad 8", "8" }, { "numpad 9", "9" },
	{ "backspace", "back" }, { "enter", "enter" }, { "numpad enter", "enter" },
	{ 190, "." }, { 110, "." }, { 189, "-" }, { 109, "-" },
}) do
	local index = pair[1]

	if type(index) == "string" then
		local ok, found = pcall(Keyboard.button_index, index)

		index = ok and found or nil
	end

	if index then
		TYPING_KEYS[#TYPING_KEYS + 1] = { index = index, char = pair[2] }
	end
end

local BAR_W = definitions.BAR_W
local BAR_X = definitions.BAR_X
local RANGE = 180
local FOOT_CHARS = 62
local OBJ_SAY_CHARS = 40
local SAY_HOLDS = 5
local NAME_CHARS = 16
local CLEAR_ASKS_FOR = 4
local HOLD_STEP = 0.1
local function key_index(name)
	local ok, found = pcall(Keyboard.button_index, name)

	return ok and found or nil
end

local KEY_F2 = key_index("f2")
local KEY_DELETE = key_index("delete")
local KEY_ENTER = key_index("enter")
local KEY_ESCAPE = key_index("esc")
local KEY_H = key_index("h")
local KEY_Z = key_index("z")
local KEY_CTRL = key_index("left ctrl")
local KEY_CTRL_R = key_index("right ctrl")
local KEY_U = key_index("u")
local KEY_L = key_index("l")
local KEY_A = key_index("a")
local KEY_S = key_index("s")
local KEY_C = key_index("c")
local KEY_R = key_index("r")
local KEY_K = key_index("k")
local KEY_V = key_index("v")
local KEY_SHIFT = key_index("left shift")
local KEY_SHIFT_R = key_index("right shift")
local HOT_KEYS = { KEY_F2, KEY_DELETE, KEY_ENTER, KEY_ESCAPE, KEY_H, KEY_Z, KEY_U, KEY_L, KEY_A, KEY_S, KEY_C, KEY_R, KEY_K, KEY_V }

local function shift_held()
	for _, index in ipairs({ KEY_SHIFT, KEY_SHIFT_R }) do
		local ok, down = pcall(Keyboard.button, index)

		if ok and down and down > 0 then
			return true
		end
	end

	return false
end
local LEFT_BUTTON = Mouse and Mouse.button_index and Mouse.button_index("left") or nil
local RIGHT_BUTTON = Mouse and Mouse.button_index and Mouse.button_index("right") or nil

local function left_held()
	if not LEFT_BUTTON then
		return false
	end

	local ok, held = pcall(Mouse.button, LEFT_BUTTON)

	return ok and held and held > 0
end

local function hovered(widget)
	local content = widget and widget.content
	local hotspot = content and content.hotspot

	return hotspot ~= nil and hotspot.is_hover == true and content.visible ~= false
end

-- ───────────────────── ❀ ─────────────────────
--  View Setup
-- ───────────────────── ❀ ─────────────────────

local SkeletonKeyPoseView = class("SkeletonKeyPoseView", "BaseView")

SkeletonKeyPoseView.init = function (self, settings, context)
	SkeletonKeyPoseView.super.init(self, definitions, settings, context)

	local G = rawget(_G, "__skeletonkey")
	local was = G and G.panel_at or nil

	self._joint = was and was.joint or 1
	self._chip = was and was.chip or nil
	self._tab = self:_remembered_tab()
	self._reply = ""
	self._said_at = 0
	self._drag = {}
	self._armed_at = nil
	self._hovering = false
	self._grip = nil
	self._at = nil
	self._repeat = nil
	self._edit = nil
	self._keys_was = {}
	self._hdrag = nil
	self._sdrag = nil
	self._sel = {}
	self._sel_list = nil
	self._rename = nil
	self._hot_was = {}

	for _, index in pairs(HOT_KEYS) do
		local ok, down = pcall(Keyboard.button, index)

		self._hot_was[index] = ok and down and down > 0 or false
	end
	self._fdrag = nil
	self._field = (was and was.field) or {}
	self._field_restore = true
	self._clear_armed = nil
	self._pose_top = was and was.top or 0
	self._frame_top = was and was.frame_top or 0
	self._shut = (was and was.shut) or {}
	self._menu = nil
end

SkeletonKeyPoseView._scroll_at = function (self, total, visible, height, top, y)
	visible = visible or definitions.POSE_ROWS
	height = height or definitions.SCROLL_H
	top = top or self._pose_top
	y = y or definitions.SCROLL_Y

	local most = math.max(0, total - visible)
	local thumb = math.max(24, height * math.min(1, visible / math.max(1, total)))
	local span = height - thumb
	local at = most > 0 and (top / most) * span or 0

	return most, thumb, span, y + at
end

SkeletonKeyPoseView._frame_scroll_at = function (self, total)
	return self:_scroll_at(total, KEY_ROWS, definitions.KSCROLL_H, self._frame_top, definitions.KSCROLL_Y)
end

-- ───────────────────── ❀ ─────────────────────
--  Panel Placement
-- ───────────────────── ❀ ─────────────────────

SkeletonKeyPoseView.PANELS = {
	pose = { node = "pose", grip = "grip", key = "pose_panel_at", home = -24,
		w = "PANEL_W", h = "PANEL_H", side = "right" },
	objkey = { node = "objkey", grip = "obj_grip", key = "obj_panel_at", home = 24,
		w = "OBJ_PANEL_W", h = "OBJ_PANEL_H", side = "left" },
}

SkeletonKeyPoseView._screen = function (self)
	local scale = RESOLUTION_LOOKUP and RESOLUTION_LOOKUP.inverse_scale or 1

	return (RESOLUTION_LOOKUP and RESOLUTION_LOOKUP.width or 1920) * scale,
		(RESOLUTION_LOOKUP and RESOLUTION_LOOKUP.height or 1080) * scale
end

SkeletonKeyPoseView._in_bounds = function (self, which, x, y)
	local p = self.PANELS[which]
	local sw, sh = self:_screen()
	local w = definitions[p.w] or 440
	local h = definitions[p.h] or 600
	local room_x = math.max(0, sw - w)
	local lo_x = p.side == "right" and (-room_x - p.home) or -p.home
	local hi_x = p.side == "right" and -p.home or (room_x - p.home)
	local room_y = math.max(0, (sh - h) / 2)

	return math.max(lo_x, math.min(hi_x, x)), math.max(-room_y, math.min(room_y, y))
end

SkeletonKeyPoseView._place = function (self, x, y, which)
	which = which or "pose"

	local p = self.PANELS[which]

	x, y = self:_in_bounds(which, x, y)
	self._at = self._at or {}
	self._at[which] = { x, y }
	local grow = which == "objkey" and (self._obj_grow or 0) or 0

	pcall(self._set_scenegraph_position, self, p.node, p.home + x, y + grow)
	pcall(mod.set, mod, p.key, string.format("%d,%d", x, y))
end

SkeletonKeyPoseView._restore_place = function (self)
	for which, p in pairs(self.PANELS) do
		local ok, saved = pcall(mod.get, mod, p.key)
		local x, y = 0, 0

		if ok and type(saved) == "string" then
			local sx, sy = string.match(saved, "^(-?%d+),(-?%d+)$")

			x, y = tonumber(sx) or 0, tonumber(sy) or 0
		end

		self:_place(x, y, which)
	end
end

SkeletonKeyPoseView._drag_panel = function (self, input_service, which)
	which = which or "pose"

	local p = self.PANELS[which]
	local widget = self._widgets_by_name[p.grip]

	if not widget then
		return
	end

	local hotspot = widget.content.hotspot

	if hotspot.is_hover then
		self._hovering = true
	end

	widget.style.hint.color[1] = hotspot.is_hover and 24 or 0

	if widget.style.label then
		widget.style.label.text_color[1] = hotspot.is_hover and 255 or 0
	end

	local named = which == "pose" and self._widgets_by_name.plate
	local held = which == "objkey" and self._widgets_by_name.obj_note

	if named and named.style.target then
		named.style.target.text_color[1] = hotspot.is_hover and 0 or 255
	end

	if held and held.style.label then
		held.style.label.text_color[1] = hotspot.is_hover and 0 or 255
	end

	local held = left_held()
	self._grip = self._grip or {}

	if (hotspot.on_pressed and not self._grip[which]) or (self._grip[which] and held) then
		hotspot.on_pressed = false

		local ok, cursor = pcall(input_service.get, input_service, "cursor")

		if ok and cursor then
			local scale = RESOLUTION_LOOKUP and RESOLUTION_LOOKUP.inverse_scale or 1
			local x, y = cursor[1] * scale, cursor[2] * scale

			if not self._grip[which] then
				self._grip[which] = { x = x, y = y }
			else
				local at = (self._at and self._at[which]) or { 0, 0 }
				local g = self._grip[which]

				self:_place(at[1] + (x - g.x), at[2] + (y - g.y), which)
				g.x, g.y = x, y
			end

			self._hovering = true
		end
	else
		self._grip[which] = nil
	end
end

-- ───────────────────── ❀ ─────────────────────
--  Opening
-- ───────────────────── ❀ ─────────────────────

SkeletonKeyPoseView.on_enter = function (self)
	SkeletonKeyPoseView.super.on_enter(self)

	self._opener = mod.opener_on()

	self._tucked = false

	do
		local G = rawget(_G, "__skeletonkey")
		local pk = G and G.pick

		self._missed_at = (pk and pk.missed_at) or 0
		self._took_at = (pk and pk.at) or -1
		self._box_said = (pk and pk.box_at) or 0

		if G and G.gyro then
			G.gyro.frame = nil
		end
	end

	mod.sk_keyframe()
	self:_adopt_pick()
	self:_restore_place()

	mod.panel_open(VIEW_NAME)
end

local function sk_now()
	local G = rawget(_G, "__skeletonkey")

	return G and G.SK and G.SK.now() or 0
end

SkeletonKeyPoseView._adopt_pick = function (self)
	local G = rawget(_G, "__skeletonkey")
	local pick = G and G.pick
	local pose = mod.pose_state()

	if pose.unit and pose.picked and #pose.joints > 0 then
		return
	end

	if pick and pick.unit and pick.at > (pose.at or 0) and pick.at > (G.pick_done or -1) then
		G.pick_done = pick.at
		mod.sk_pose("target")
		self._joint = 1
	end
end

-- ───────────────────── ❀ ─────────────────────
--  Lists
-- ───────────────────── ❀ ─────────────────────

SkeletonKeyPoseView._lists = function (self)
	local pose = mod.pose_state()
	local G = rawget(_G, "__skeletonkey")

	if self._tab == "frames" then
		return { {
			id = "frames",
			rows = KEY_ROWS,
			widget = "frame_",
			count = #pose.frames,
			label = function (i) return pose.frames[i] and pose.frames[i].name end,
			move = function (i, to) return mod.sk_keyframe("move", i, to) end,
			drop = function (i) return mod.sk_keyframe("delete", i) end,
			rename = function (i, text) return mod.sk_keyframe("name", i, text) end,
		} }
	end

	if self._tab == "sets" then
		local names = G and G.SK.anim_index("sets") or {}

		return { {
			id = "sets",
			rows = definitions.SET_ROWS,
			widget = "set_",
			count = #names,
			label = function (i) return names[i] end,
			drop = function (i) return names[i] and mod.sk_set("delete", names[i]) end,
			rename = function (i, text) return names[i] and mod.sk_set("rename", names[i], text) end,
		} }
	end

	return {}
end

SkeletonKeyPoseView._frame_rows = function (self)
	local pose = mod.pose_state()
	local rows = {}
	local open_group = nil

	for i = 1, #pose.frames do
		local g = pose.frames[i].group

		if g and g ~= open_group then
			local last = i

			while pose.frames[last + 1] and pose.frames[last + 1].group == g do
				last = last + 1
			end

			rows[#rows + 1] = { head = g, from = i, to = last, shut = self._shut[g] and true or false }
			open_group = g
		elseif not g then
			open_group = nil
		end

		if not g or not self._shut[g] then
			rows[#rows + 1] = { frame = i, inside = g ~= nil }
		end
	end

	return rows
end

SkeletonKeyPoseView._list_by_id = function (self, id)
	local lists = self:_lists()

	for i = 1, #lists do
		if lists[i].id == id then
			return lists[i]
		end
	end

	return nil
end

SkeletonKeyPoseView._sel_of = function (self, id)
	self._sel[id] = self._sel[id] or {}

	return self._sel[id]
end

SkeletonKeyPoseView._row_press = function (self, desc, r, input_service)
	self._sel_list = desc.id

	if desc.id == "frames" and shift_held() and self._sel_from then
		local from, to = math.min(self._sel_from, r), math.max(self._sel_from, r)
		local sel = {}

		for k = from, to do
			sel[k] = true
		end

		self._sel[desc.id] = sel

		return false
	end

	self._sel[desc.id] = { [r] = true }

	if desc.id == "frames" then
		self._sel_from = r
	end

	return true
end

SkeletonKeyPoseView._drop_selected = function (self)
	local desc = self._sel_list and self:_list_by_id(self._sel_list)

	if not desc then
		return ""
	end

	local rows = {}

	for k in pairs(self:_sel_of(desc.id)) do
		rows[#rows + 1] = k
	end

	table.sort(rows, function (a, b) return a > b end)

	if desc.id == "sets" then
		local names = {}

		for i = #rows, 1, -1 do
			names[#names + 1] = tostring(desc.label(rows[i]) or "")
		end

		local key = table.concat(names, ",")

		if self._set_del ~= key or sk_now() - (self._set_del_at or 0) >= CLEAR_ASKS_FOR then
			self._set_del, self._set_del_at = key, sk_now()

			return "Press Delete again to delete " .. (#rows > 1 and (#rows .. " sets") or names[1]) .. "."
		end

		self._set_del = nil
	end

	local said = ""

	for i = 1, #rows do
		said = desc.drop(rows[i]) or said
	end

	self._sel[desc.id] = {}

	if desc.id == "frames" then
		self._chip = nil
	end

	return #rows > 1 and ("Deleted " .. #rows .. (desc.id == "sets" and " sets." or " keyframes.")) or said
end

SkeletonKeyPoseView._fresh_key = function (self, index)
	if not index then
		return false
	end

	local ok, down = pcall(Keyboard.button, index)
	local pressed = ok and down and down > 0 or false
	local fresh = pressed and not self._hot_was[index]

	self._hot_was[index] = pressed

	return fresh
end

-- ───────────────────── ❀ ─────────────────────
--  Hotkeys
-- ───────────────────── ❀ ─────────────────────

SkeletonKeyPoseView._list_keys = function (self)
	local widgets = self._widgets_by_name
	local box = widgets.rename_input.content

	if self._rename then
		if self:_fresh_key(KEY_ENTER) then
			local typed = box.input_text or ""
			local desc = self:_list_by_id(self._rename.id)

			if typed == "" then
				self:_say("A name cannot be empty. Nothing changed.")
			elseif self._rename.id == "newgroup" then
				self:_say(mod.sk_object("save", typed), "obj")
			elseif self._rename.id == "mergegroup" then
				self:_say(mod.sk_object("merge", typed, self._merge_from), "obj")
				self._gsel = {}
			elseif self._rename.id == "group" then
				local was = self._rename.row

				self:_say(mod.sk_group("rename", was, typed))
				self._shut[typed], self._shut[was] = self._shut[was], nil
			elseif desc and desc.rename then
				self:_say(desc.rename(self._rename.row, typed))
			end

			self:_rename_close()
		elseif self:_fresh_key(KEY_ESCAPE) then
			self:_rename_close()
			self:_say("Left as it was.")
		end

		return
	end

	if self:_chatting() then
		for _, index in pairs(HOT_KEYS) do
			self:_fresh_key(index)
		end

		return
	end

	if self:_fresh_key(KEY_ENTER) and widgets.path_input.content.is_writing then
		self:_spawn_path()
	end

	local dragging = self._gyro == true or (self._objdrag ~= nil and next(self._objdrag) ~= nil)

	if not self:_typing() and self:_fresh_key(KEY_H) then
		self._lit_hide = sk_now()
		self:_say(mod.sk_hide("this"), "obj")
	end

	if not self:_typing() and self:_fresh_key(KEY_Z) and self:_ctrl_held() and not dragging then
		self._lit_undo = sk_now()
		self:_say(mod.sk_object("undo"), "obj")
	end

	if not self:_typing() and self:_fresh_key(KEY_U) then
		self._lit_undo = sk_now()
		self:_say(self:_unhide_or_rehide(), "obj")
	end

	if not self:_typing() and self:_fresh_key(KEY_C) then
		if self:_ctrl_held() then
			self:_say(mod.sk_object("copy"), "obj")
		elseif not dragging then
			self:_clear_one()
		end
	end

	if not self:_typing() and self:_fresh_key(KEY_R) and not dragging then
		self:_say(mod.sk_object("reset"), "obj")
	end

	if not self:_typing() and self:_fresh_key(KEY_V) and self:_ctrl_held() then
		local at = self._cursor

		if at then
			mod.paste_at_screen(at[1], at[2])
			self:_say("Pasting...", "obj")
		end
	end

	if not self:_typing() and self:_fresh_key(KEY_A) and self:_ctrl_held() then
		self:_say(mod.sk_object("holdall"), "obj")
	end

	if not self:_typing() and self:_fresh_key(KEY_S) and not self:_ctrl_held() then
		self:_say(mod.sk_object("keep"), "obj")
	end

	if not self:_typing() and self:_fresh_key(KEY_L) then
		local GL = rawget(_G, "__skeletonkey")

		self._lit_lock = sk_now()
		self:_say(mod.sk_object(GL and GL.SK.object_locked() and "unlock" or "lock"), "obj")
	end

	local desc = self._sel_list and self:_list_by_id(self._sel_list)

	if not self:_typing() and self:_fresh_key(KEY_DELETE) then
		if not desc then
			self:_say("Click a row first, then Delete.")
		elseif next(self:_sel_of(desc.id)) then
			self:_say(self:_drop_selected())
		else
			self:_say("No row is picked. Click one, then Delete.")
		end
	end

	if not desc then
		return
	end

	if self:_fresh_key(KEY_F2) then
		local only, count = nil, 0

		for k in pairs(self:_sel_of(desc.id)) do
			only = k
			count = count + 1
		end

		if not desc.rename then
			self:_say("Rows here cannot be renamed.")
		elseif count == 1 and desc.label(only) then
			self._rename = { id = desc.id, row = only }
			box.input_text = desc.label(only)
			box.is_writing = true
			widgets.rename_box.content.what = desc.label(only)
		else
			self:_say(count > 1 and "Pick just one row to rename." or "Pick a row first, then F2.")
		end
	end
end

SkeletonKeyPoseView._typing = function (self)
	local widgets = self._widgets_by_name

	return widgets.input.content.is_writing or widgets.path_input.content.is_writing or self:_chatting()
end

SkeletonKeyPoseView._chatting = function (self)
	return mod.chat_typing ~= nil and mod.chat_typing() == true
end

SkeletonKeyPoseView._chat = function (self)
	local widgets = self._widgets_by_name

	self._edit = nil
	widgets.input.content.is_writing = false
	widgets.path_input.content.is_writing = false

	local said = mod.chat_open and mod.chat_open()

	if said then
		self:_say(said, "obj")
	end
end

SkeletonKeyPoseView._spawn_path = function (self)
	local box = self._widgets_by_name.path_input.content
	local said = mod.spawn_at_screen(box.input_text, RESOLUTION_LOOKUP.width * 0.5, RESOLUTION_LOOKUP.height * 0.5)

	box.is_writing = false
	self:_say(said or "Spawning...", "obj")
end

SkeletonKeyPoseView._rename_close = function (self)
	local box = self._widgets_by_name.rename_input.content

	self._rename = nil
	box.input_text = ""
	box.is_writing = false
end

-- ───────────────────── ❀ ─────────────────────
--  Hints & Replies
-- ───────────────────── ❀ ─────────────────────

local HINTS = {
	equip = "Hide what they hold. Again brings it back.",
	hide_this = "Hide the selection. Again brings it back.",
	show_all = "Show everything hidden, or hide it all again.",
	clear = "Stop posing them. They move as normal again.",
	anim_freeze = "Hold every joint where it stands.",
	anim_thaw = "Let them move again.",
	loop = "Play them round and round until stopped.",
	zero = "Every dial on every joint back to zero.",
	release = "Hold to see them without your changes.",
	tab_poses = "The game's own animations, to play or save.",
	tab_joints = "One bone at a time, three dials each.",
	tab_frames = "Your poses, in the order they play.",
	tab_sets = "Keyframes saved as sets, to load or play.",
	save = "Save this pose as a new keyframe.",
	play = "Play the keyframes from the top.",
	frames_clear = "Delete every keyframe. It asks first.",
	pose_rest = "Stand them plain, nothing playing.",
	pose_clip = "Save what is playing as a keyframe.",
	tape_back = "One frame back through the animation.",
	tape_on = "One frame on through the animation.",
	menu_flip = "This folder, played the other way round.",
	menu_rename = "Rename this folder.",
	menu_delete = "Delete this folder and everything in it.",
	tape_key = "Add this frame as a keyframe, timed to match.",
	tape_keyto = "Keys frames up to here. Scroll for how often.",
	obj_reset = "Back exactly where you found it.",
	obj_drop = "Let it go, leaving it where it is.",
	obj_add = "Save what you hold to the Items list.",
	obj_copy = "Copy it. Paste puts one where you look.",
	obj_back = "Undo the last change to a thing.",
	path_go = "Spawn that unit path where you look.",
	grp_save = "Save what you hold as a group.",
	grp_folder = "Opens the groups folder, to delete one.",
	grp_merge = "Join the picked groups into one group.",
	grp_export = "A file another mod can place this from.",
	marks = "Show or hide spawn points and other markers.",
	chat = "Open chat to type a /command. Enter sends.",
	hold_all = "Hold everything on the list together.",
	set_save = "Save these keyframes as a set.",
	jzero = "This joint's three dials back to zero.",
}

local SKG = rawget(_G, "__skeletonkey")
local PHYS = SKG and SKG.SK and SKG.SK.phys

if PHYS then
	HINTS.phys = PHYS.hint
end

for r = 1, SET_ROWS do
	HINTS["set" .. r .. "_export"] = "A file another mod can play this from."
end

local function shown_name(name)
	if type(name) ~= "string" or name == "" or string.sub(name, 1, 1) == "#" then
		return "Unnamed Prop"
	end

	return name
end

local function paint(into, from)
	into[1], into[2], into[3], into[4] = from[1], from[2], from[3], from[4]
end

local function fit(text, most)
	text = tostring(text or "")

	if string.len(text) > most then
		return string.sub(text, 1, math.max(1, most - 3)) .. "..."
	end

	return text
end

local function text_w(renderer, text, size, font)
	local ok, wide = pcall(function() return UIRenderer.text_size(renderer, text, font, size) end)

	return ok and type(wide) == "number" and wide or nil
end

local function measured(renderer, text, px, size, font)
	local whole = text_w(renderer, text, size, font)

	if not whole then
		return nil
	end

	if whole <= px then
		return text
	end

	local ends, i, n = {}, 1, string.len(text)

	while i <= n do
		local c = string.byte(text, i)
		local len = c >= 240 and 4 or (c >= 224 and 3 or (c >= 192 and 2 or 1))

		i = math.min(n, i + len - 1) + 1
		ends[#ends + 1] = i - 1
	end

	local lo, hi = 0, #ends

	while lo < hi do
		local mid = math.ceil((lo + hi) / 2)
		local wide = text_w(renderer, string.sub(text, 1, ends[mid]) .. "...", size, font)

		if wide and wide <= px then
			lo = mid
		else
			hi = mid - 1
		end
	end

	local cut = lo > 0 and string.sub(text, 1, ends[lo]) or ""

	return (string.gsub(cut, "%s+$", "")) .. "..."
end

SkeletonKeyPoseView._fit = function (self, text, px, size, font, most)
	text = tostring(text or "")
	font = font or "proxima_nova_medium"

	if not self._fits or (self._fits_n or 0) > 2000 then
		self._fits, self._fits_n = {}, 0
	end

	local key = px .. "|" .. size .. "|" .. font .. "|" .. text
	local hit = self._fits[key]

	if hit then
		return hit
	end

	local out = self._ui_renderer and measured(self._ui_renderer, text, px, size, font)
		or fit(text, most or math.max(4, math.floor(px / (size * 0.55))))

	self._fits[key] = out
	self._fits_n = self._fits_n + 1

	return out
end

SkeletonKeyPoseView._fit_to = function (self, widget, id, text, most)
	local st = widget and widget.style and widget.style[id]

	if not st or not st.size then
		return fit(text, most or 40)
	end

	return self:_fit(text, st.size[1], st.font_size or 15, st.font_type, most)
end

SkeletonKeyPoseView._hint = function (self, side)
	local widgets = self._widgets_by_name

	for name, text in pairs(HINTS) do
		local widget = widgets["button_" .. name]
		local hotspot = widget and widget.content.hotspot
		local mine = (widget and widget.scenegraph_id == "objkey") == (side == "obj")

		if mine and hotspot and hotspot.is_hover and widget.content.visible ~= false then
			return (self._needs and self._needs[name]) or text
		end
	end

	return nil
end

SkeletonKeyPoseView._dim = function (self, widget, name, off, needs)
	self._needs = self._needs or {}
	self._needs[name] = off and needs or nil

	if not widget then
		return
	end

	local label = widget.style.label.text_color

	if off then
		widget.style.face.color[1] = 0
	end

	label[2], label[3], label[4] = off and 141 or 236, off and 148 or 230, off and 160 or 216
end

SkeletonKeyPoseView._say = function (self, text, side)
	local card = self._widgets_by_name and self._widgets_by_name.obj_plate

	if side == "obj" and not (card and card.content.visible == false) then
		self._obj_reply = tostring(text or "")
		self._obj_said_at = sk_now()

		return
	end

	self._reply = tostring(text or "")
	self._said_at = sk_now()
end

-- ───────────────────── ❀ ─────────────────────
--  Joint Helpers
-- ───────────────────── ❀ ─────────────────────

SkeletonKeyPoseView._picked_joint = function (self)
	local pose = mod.pose_state()

	return pose.joints[self._joint]
end

SkeletonKeyPoseView._set_axis = function (self, axis_index, value)
	local pose = mod.pose_state()
	local name = self:_picked_joint()

	if not name then
		return
	end

	local d = pose.dial[name]
	local x, y, z = d[1], d[2], d[3]

	if axis_index == 1 then x = value elseif axis_index == 2 then y = value else z = value end

	mod.sk_pose(name, x, y, z)
end

-- ───────────────────── ❀ ─────────────────────
--  Input & Update
-- ───────────────────── ❀ ─────────────────────

SkeletonKeyPoseView._handle_input = function (self, input_service, dt, t)
	if input_service:get("close_view") then
		if self._rename then
			self:_rename_close()
			self:_say("Left as it was.")

			return
		end

		if self._tucked then
			Managers.ui:close_view(VIEW_NAME)

			return
		end

		mod.opener_spend()
		self._opener = false
		self._tucked = true
	end
end

SkeletonKeyPoseView.update = function (self, dt, t, input_service)
	if self._armed_at then
		local G = rawget(_G, "__skeletonkey")
		local pick = G and G.pick

		if pick and pick.at > self._armed_at then
			local pose = mod.pose_state()
			local was, was_at = pose.unit, pose.at

			self._armed_at = nil
			self:_say("")

			local SKv = G.SK
			local ahead = nil
			local adding = self:_ctrl_held() and SKv.object_alive()
				and not (pick.unit and SKv.alive(pick.unit) and SKv.pose_rig(pick.unit, pick.pos, true))

			if adding and SKv.person_ahead then
				ahead = SKv.person_ahead()
				adding = ahead == nil
			end

			if not adding then
				self:_adopt_pick()
			end

			local got = pose.unit and #pose.joints > 0 and (pose.unit ~= was or pose.at ~= was_at)

			if got and pick.unit then
				self._person_at = pick.at
			end

			if got then
				self:_say("Got them. Click a joint, then drag a bar.")
			elseif not pick.unit and (pick.missed_at or 0) >= pick.at then
				self:_say("Nothing there to pose or to move.", "obj")
			end
		end
	end

	self._hovering = false

	if self._rename then
		self:_step("_list_keys")
		self:_step("_fill")

		return SkeletonKeyPoseView.super.update(self, dt, t, input_service)
	end

	self:_step("_list_keys")
	self:_step("_drag_panel", input_service, "pose")
	self:_step("_drag_panel", input_service, "objkey")
	self:_step("_joints")
	self:_step("_sliders", input_service)
	self:_step("_hold_sliders", input_service)
	self:_step("_buttons", input_service)
	self:_step("_edit_tick")
	self:_step("_world_click", input_service)
	self:_step("_fill")

	return SkeletonKeyPoseView.super.update(self, dt, t, input_service)
end

SkeletonKeyPoseView._step = function (self, name, ...)
	local fn = self[name]

	if type(fn) ~= "function" then
		return
	end

	local ok, err = pcall(fn, self, ...)

	if not ok then
		self._failed = self._failed or {}

		if not self._failed[name] then
			self._failed[name] = true

			pcall(mod.echo, mod, "Skeleton Key: " .. name .. " failed: " .. tostring(err))
			pcall(self._say, self, "Something went wrong. Reopen the panel.")
		end
	end
end

SkeletonKeyPoseView._pressed = function (self, widget)
	if not widget then
		return false
	end

	local hotspot = widget.content.hotspot

	if hotspot.is_hover then
		self._hovering = true
	end

	self._flash = self._flash or {}

	local now = sk_now()
	local down = hotspot.is_held == true or (now - (self._flash[widget] or -1)) < 0.12

	if widget.style.face then
		local c = widget.style.face.color
		local hover = hotspot.is_hover

		c[1] = 255
		c[2] = down and 104 or (hover and 58 or 44)
		c[3] = down and 96 or (hover and 63 or 48)
		c[4] = down and 70 or (hover and 71 or 54)
	end

	local edge = widget.style.edge and widget.style.edge.color

	if edge then
		self._edges = self._edges or setmetatable({}, { __mode = "k" })

		local own = self._edges[widget]

		if not own then
			own = { edge[1], edge[2], edge[3], edge[4] }
			self._edges[widget] = own
		end

		if hotspot.is_hover then
			edge[1], edge[2], edge[3], edge[4] = 255, 141, 148, 160
		else
			edge[1], edge[2], edge[3], edge[4] = own[1], own[2], own[3], own[4]
		end
	end

	if hotspot.on_pressed then
		hotspot.on_pressed = false
		self._flash[widget] = now

		return true
	end

	return false
end

SkeletonKeyPoseView._stepped = function (self, widget)
	if not widget then
		return false
	end

	if self:_pressed(widget) then
		self._repeat = { widget = widget, next_t = sk_now() + REPEAT_AFTER }

		return true
	end

	local rep = self._repeat

	if rep and rep.widget == widget then
		if widget.content.hotspot.is_hover and left_held() then
			if sk_now() >= rep.next_t then
				rep.next_t = sk_now() + REPEAT_EVERY

				return true
			end
		else
			self._repeat = nil
		end
	end

	return false
end

-- ───────────────────── ❀ ─────────────────────
--  Number Typing
-- ───────────────────── ❀ ─────────────────────

SkeletonKeyPoseView._edit_begin = function (self, kind, index, label, name)
	local G2 = rawget(_G, "__skeletonkey")

	self._edit = { kind = kind, index = index, label = label, name = name, tab = self._tab, text = "",
		unit = kind == "obj" and G2 and G2.object and G2.object.unit or nil }
	self:_say("Type " .. label .. ", then Enter.", kind == "obj" and "obj" or nil)
end

SkeletonKeyPoseView._edit_text = function (self, kind, index, shown)
	local edit = self._edit

	if edit and edit.kind == kind and edit.index == index then
		return edit.text .. "_"
	end

	return shown
end

SkeletonKeyPoseView._edit_tick = function (self)
	local edit = self._edit

	if not edit then
		return
	end

	if edit.tab ~= self._tab then
		self._edit = nil

		return
	end

	if edit.kind == "obj" then
		local G2 = rawget(_G, "__skeletonkey")

		if not (G2 and G2.SK.object_alive() and G2.object.unit == edit.unit) then
			self._edit = nil

			return
		end
	end

	for i = 1, #TYPING_KEYS do
		local key = TYPING_KEYS[i]
		local ok, down = pcall(Keyboard.button, key.index)
		local pressed = ok and down and down > 0 or false
		local fresh = pressed and not self._keys_was[key.index]

		self._keys_was[key.index] = pressed

		if fresh then
			if key.char == "back" then
				edit.text = string.sub(edit.text, 1, -2)
			elseif key.char == "enter" then
				local value = tonumber(edit.text)

				if value then
					if edit.kind == "obj" then
						local G2 = rawget(_G, "__skeletonkey")
						local obj = G2 and G2.object
						local r = edit.index

						if obj then
							if r == 7 then
								self:_say(mod.sk_object("scale", value), "obj")
							elseif r < 4 then
								local m = { obj.move[1], obj.move[2], obj.move[3] }

								m[r] = value

								local said, failed = mod.sk_object("move", m[1], m[2], m[3])

								self:_say(failed and said or self:_obj_said(r, obj.move[r]), "obj")
							else
								local t = { obj.spin[1], obj.spin[2], obj.spin[3] }

								t[r - 3] = value

								local said, failed = mod.sk_object("turn", t[1], t[2], t[3])

								self:_say(failed and said or self:_obj_said(r, obj.spin[r - 3]), "obj")
							end
						end
					elseif edit.kind == "gtime" then
						mod.sk_group("time", edit.index, value)
						self:_say("Folder " .. tostring(edit.index) .. " now takes " .. tostring(value) .. "s in all.")
					elseif edit.kind == "hold" then
						mod.sk_keyframe("hold", edit.index, value)
						self:_say("Time for " .. tostring(edit.name) .. " set to " .. tostring(value) .. "s.")
					elseif edit.kind == "axis" then
						self:_set_axis(edit.index, value)
						self:_say(string.upper(AXES[edit.index]) .. " set to " .. tostring(value) .. " degrees.")
					end
				else
					self:_say("That was not a number. Nothing changed.", edit.kind == "obj" and "obj" or nil)
				end

				self._edit = nil

				return
			elseif #edit.text < 8 then
				edit.text = edit.text .. key.char
			end
		end
	end
end

-- ───────────────────── ❀ ─────────────────────
--  Hold Bars
-- ───────────────────── ❀ ─────────────────────

SkeletonKeyPoseView._hold_sliders = function (self, input_service)
	local widgets = self._widgets_by_name
	local pose = mod.pose_state()
	local per_unit = HOLD_MAX / HOLD_BAR_W

	if self._tab ~= "frames" then
		self._hdrag = nil

		return
	end

	local tree = self:_frame_rows()

	for r = 1, KEY_ROWS do
		local row = widgets["frame_" .. r]
		local entry = tree[(self._frame_top or 0) + r]
		local i = entry and entry.frame
		local frame = i and pose.frames[i]
		local bar = row and row.content.bar
		local drag = self._hdrag and self._hdrag.r == r and self._hdrag or nil

		if bar and bar.is_hover then
			self._hovering = true
		end

		local start = bar and frame and not self._hdrag and bar.on_pressed
		local keep = drag and left_held()

		if start or keep then
			local ok, cursor = pcall(input_service.get, input_service, "cursor")

			if ok and cursor then
				local scale = RESOLUTION_LOOKUP and RESOLUTION_LOOKUP.inverse_scale or 1
				local x = cursor[1] * scale

				if start then
					bar.on_pressed = false
					self._hdrag = { r = r, i = i, last_x = x, at = math.min(frame.hold or 2, HOLD_MAX) }
				else
					drag.at = math.clamp(drag.at + (x - drag.last_x) * per_unit, 0, HOLD_MAX)
					drag.last_x = x
					mod.sk_keyframe("hold", drag.i, math.floor(drag.at * 20 + 0.5) / 20)
				end
			end

			self._hovering = true
		elseif drag then
			self._hdrag = nil
		end
	end
end

-- ───────────────────── ❀ ─────────────────────
--  Tabs
-- ───────────────────── ❀ ─────────────────────

SkeletonKeyPoseView._remembered_tab = function (self)
	local was = mod:get("pose_tab")

	for _, name in ipairs({ "poses", "joints", "frames", "sets" }) do
		if was == name then
			return was
		end
	end

	return "poses"
end

SkeletonKeyPoseView._go = function (self, tab)
	if tab ~= self._tab then
		local field = self._widgets_by_name.input

		if field then
			self._field[self._tab] = field.content.input_text or ""
			field.content.input_text = self._field[tab] or ""
			field.content.is_writing = false
		end
	end

	self._tab = tab

	pcall(mod.set, mod, "pose_tab", tab)
end

-- ───────────────────── ❀ ─────────────────────
--  Animations Page
-- ───────────────────── ❀ ─────────────────────

SkeletonKeyPoseView._poses = function (self)
	local G = rawget(_G, "__skeletonkey")

	if not G then
		return {}
	end

	local typed = self:_typed()
	local now = G.SK.now()
	local cache = self._poses_cache

	if cache and cache.typed == typed and now >= cache.at and now - cache.at < 1 then
		return cache.list
	end

	local list = G.SK.poses(typed) or {}

	self._poses_cache = { typed = typed, at = now, list = list }

	return list
end

SkeletonKeyPoseView._poses_page = function (self, input_service)
	local widgets = self._widgets_by_name
	local G = rawget(_G, "__skeletonkey")
	local pose = mod.pose_state()
	local list = self:_poses()
	local okw, axis = pcall(input_service.get, input_service, "scroll_axis")
	local notch = okw and axis and axis[2] or 0
	local most = math.max(0, #list - POSE_ROWS)

	local step = hovered(widgets.plate) and notch or 0

	self._pose_top = math.max(0, math.min(most, self._pose_top - step))

	for r = 1, POSE_ROWS do
		local i = self._pose_top + r

		if list[i] and self:_pressed(widgets["button_pose" .. r .. "_play"]) then
			self:_say(mod.sk_tape("record", list[i].event, list[i].machine))
		end
	end

	if self:_pressed(widgets.button_pose_rest) then
		self:_say(mod.sk_anim("rest"))
	end

	if self:_pressed(widgets.button_pose_clip) then
		self:_say(mod.sk_keyframe("clip", self:_typed()))
	end

	if self:_pressed(widgets.button_tape_back) then
		self:_say(mod.sk_tape("step", -1))
	end

	if self:_pressed(widgets.button_tape_on) then
		self:_say(mod.sk_tape("step", 1))
	end

	if self:_pressed(widgets.button_tape_key) then
		self:_say(mod.sk_tape("key", self:_typed()))
	end

	if self:_pressed(widgets.button_tape_keyto) then
		self:_say(mod.sk_tape("keyto"))
	end

	do
		local kt = widgets.button_tape_keyto

		if kt and kt.content.hotspot.is_hover and notch ~= 0 then
			self:_say(mod.sk_tape("stride", (pose.tape_stride or 2) + notch))
		end
	end

	do
		local tape = widgets.tape
		local frames = pose.tape and #pose.tape.frames or 0

		if tape and tape.content.hotspot.is_hover then
			self._hovering = true

			if notch ~= 0 and frames > 0 then
				self:_say(mod.sk_tape("step", notch))
			end
		end

		if tape and tape.content.hotspot.on_pressed then
			tape.content.hotspot.on_pressed = false

			local ok, cursor = pcall(input_service.get, input_service, "cursor")

			if ok and cursor and frames > 0 then
				local scale = RESOLUTION_LOOKUP and RESOLUTION_LOOKUP.inverse_scale or 1

				local on_in = tape.content.inhot and tape.content.inhot.is_hover
				local at = math.max(1, math.min(frames, (on_in and pose.tape_in or pose.tape_i) or 1))

				self._tdrag = { x = cursor[1] * scale, at = at, mark = on_in and "in" or "at" }
			end
		end

		if self._tdrag then
			if left_held() and frames > 0 then
				local ok, cursor = pcall(input_service.get, input_service, "cursor")

				if ok and cursor then
					local scale = RESOLUTION_LOOKUP and RESOLUTION_LOOKUP.inverse_scale or 1
					local moved = cursor[1] * scale - self._tdrag.x

					local to = self._tdrag.at + moved / definitions.TAPE_BAR_W * frames

					if self._tdrag.mark == "in" then
						mod.sk_tape("in", to)
					else
						mod.sk_tape("seek", to)
					end
				end
			else
				self._tdrag = nil
			end
		end
	end

	local bar = widgets.scroll
	local most, thumb, span = self:_scroll_at(#list)

	if bar and bar.content.hotspot.is_hover then
		self._hovering = true
	end

	if bar and bar.content.hotspot.on_pressed then
		bar.content.hotspot.on_pressed = false

		if most > 0 then
			local ok, cursor = pcall(input_service.get, input_service, "cursor")

			if ok and cursor then
				local scale = RESOLUTION_LOOKUP and RESOLUTION_LOOKUP.inverse_scale or 1

				self._sdrag = { y = cursor[2] * scale, top = self._pose_top }
			end
		end
	end

	if self._sdrag then
		if left_held() and most > 0 and span > 0 then
			local ok, cursor = pcall(input_service.get, input_service, "cursor")

			if ok and cursor then
				local scale = RESOLUTION_LOOKUP and RESOLUTION_LOOKUP.inverse_scale or 1
				local moved = cursor[2] * scale - self._sdrag.y

				self._pose_top = math.clamp(math.floor(self._sdrag.top + moved / span * most + 0.5), 0, most)
			end

			self._hovering = true
		else
			self._sdrag = nil
		end
	end
end

-- ───────────────────── ❀ ─────────────────────
--  World Clicks
-- ───────────────────── ❀ ─────────────────────

SkeletonKeyPoseView._world_click = function (self, input_service)
	local G = rawget(_G, "__skeletonkey")

	do
		local okc, at = pcall(input_service.get, input_service, "cursor")

		if okc and at then
			self._cursor = { at[1], at[2] }
		end
	end

	if G then
		G.click_ticks = (G.click_ticks or 0) + 1
		G.click_hover = self._hovering
	end

	local plate = self._widgets_by_name.plate
	local over_panel = plate and plate.content.hotspot and plate.content.hotspot.is_hover
	local card = self._widgets_by_name.obj_plate

	if card and card.content.visible ~= false and card.content.hotspot and card.content.hotspot.is_hover then
		over_panel = true
	end

	local drop = self._widgets_by_name.gpick_face

	if drop and drop.content.visible ~= false and drop.content.hotspot and drop.content.hotspot.is_hover then
		over_panel = true
	end

	local key = self._widgets_by_name.note

	if key and key.content.visible ~= false and key.content.hotspot and key.content.hotspot.is_hover then
		over_panel = true
	end

	if self._hovering or over_panel then
		self._gyro_hover = nil

		return
	end

	local okr, right = pcall(Mouse.button, RIGHT_BUTTON)

	if okr and right and right > 0 then
		if G then
			G.rmb_hits = (G.rmb_hits or 0) + 1
		end

		mod.opener_reset()
		self._opener = true
		self._tucked = false
		mod.peek_begin(VIEW_NAME)

		return
	end

	if self._tucked then
		return
	end

	if G then
		local locked = G.SK.object_locked()
		local okl, gcur = pcall(input_service.get, input_service, "cursor")
		local lx = okl and gcur and gcur[1] or 0
		local ly = okl and gcur and gcur[2] or 0

		if not self._gyro then
			self._gyro_hover = G.SK.gyro_hit(lx, ly)
		end

		if self._gyro then
			if left_held() then
				G.SK.gyro_drag(lx, ly)
			else
				self._gyro = false
				G.SK.gyro_release()
			end

			return
		end

		local okd, down = pcall(input_service.get, input_service, "left_pressed")

		if okd and down then
			local what = G.SK.gyro_hit(lx, ly)

			if what ~= nil and G.SK.gyro_grab(what, lx, ly) then
				self._gyro = true
				self._box = nil

				return
			end
		end

		if locked then
			self._box = nil

			return
		end
	end

	local okc, cursor = pcall(input_service.get, input_service, "cursor")
	local cx = okc and cursor and cursor[1] or 0
	local cy = okc and cursor and cursor[2] or 0
	local held = left_held()

	if self._box and held then
		self._box.x1, self._box.y1 = cx, cy

		if math.abs(cx - self._box.x0) > 8 or math.abs(cy - self._box.y0) > 8 then
			self._box.drawn = true
		end

		return
	end

	if self._box and not held then
		local b = self._box

		self._box = nil

		self._armed_at = sk_now()

		if b.drawn then
			mod.box_at_screen(b.x0, b.y0, b.x1, b.y1)
			self:_say("Boxing...")
		else
			mod.pick_at_screen(b.x0, b.y0)
			self:_say("Looking...")
		end

		return
	end

	local ok, down = pcall(input_service.get, input_service, "left_pressed")

	if not ok or not down then
		return
	end

	if not okc or not cursor then
		return
	end

	self._box = { x0 = cx, y0 = cy, x1 = cx, y1 = cy, drawn = false }
end

-- ───────────────────── ❀ ─────────────────────
--  Joint Bars
-- ───────────────────── ❀ ─────────────────────

SkeletonKeyPoseView._joints = function (self)
	local widgets = self._widgets_by_name

	for i = 1, JOINT_SLOTS do
		local widget = widgets["button_joint_" .. i]
		local hotspot = widget.content.hotspot

		if hotspot.is_hover then
			self._hovering = true
		end

		if hotspot.on_pressed then
			hotspot.on_pressed = false
			self._joint = i
		end
	end

	local joints = mod.pose_state().joints or {}

	for i = 1, #CHART_NODES do
		local widget = widgets["button_node_" .. i]
		local hotspot = widget and widget.content.hotspot

		if hotspot and hotspot.is_hover then
			self._hovering = true
		end

		if hotspot and hotspot.on_pressed then
			hotspot.on_pressed = false

			for j = 1, #joints do
				if joints[j] == CHART_NODES[i] then
					self._joint = j
				end
			end
		end
	end
end

SkeletonKeyPoseView._sliders = function (self, input_service)
	local widgets = self._widgets_by_name
	local pose = mod.pose_state()
	local name = self:_picked_joint()
	local deg_per_unit = (RANGE * 2) / BAR_W

	for a = 1, #AXES do
		local widget = widgets["slider_" .. AXES[a]]
		local hotspot = widget.content.hotspot
		local drag = self._drag[a]

		if hotspot.is_hover then
			self._hovering = true
		end

		local start = name and not drag and hotspot.on_pressed
		local keep = drag and left_held()

		if start or keep then
			local ok, cursor = pcall(input_service.get, input_service, "cursor")

			if ok and cursor then
				local scale = RESOLUTION_LOOKUP and RESOLUTION_LOOKUP.inverse_scale or 1
				local x = cursor[1] * scale

				if start then
					hotspot.on_pressed = false
					self._drag[a] = { last_x = x, at = pose.dial[name][a] }
				else
					drag.at = math.clamp(drag.at + (x - drag.last_x) * deg_per_unit, -RANGE, RANGE)
					drag.last_x = x
					self:_set_axis(a, math.floor(drag.at + 0.5))
				end
			end

			self._hovering = true
		elseif drag then
			self._drag[a] = nil
		end
	end
end

-- ───────────────────── ❀ ─────────────────────
--  Hide & Clear
-- ───────────────────── ❀ ─────────────────────

SkeletonKeyPoseView._out_of_way = function (self)
	local G = rawget(_G, "__skeletonkey")

	return self._tucked == true or (G ~= nil and G.SK.gyro_busy() == true)
end

SkeletonKeyPoseView._unhide_or_rehide = function (self)
	local G = rawget(_G, "__skeletonkey")
	local hidden = G and G.SK.hidden and #G.SK.hidden or 0

	if hidden == 0 and G and G.SK.unhidden and #G.SK.unhidden > 0 then
		return mod.sk_hide("rehide")
	end

	return mod.sk_hide("all")
end

SkeletonKeyPoseView._clear_one = function (self)
	local G = rawget(_G, "__skeletonkey")

	mod.opener_spend()
	self._opener = false

	if G and G.SK.object_alive() then
		self:_say(mod.sk_object("clear"), "obj")
	elseif mod.pose_state().unit then
		self:_say(mod.sk_pose("clear"))
	else
		self:_say("Nothing to clear. Nothing is held or posed.")
	end
end

-- ───────────────────── ❀ ─────────────────────
--  Object Bars
-- ───────────────────── ❀ ─────────────────────

SkeletonKeyPoseView.OBJ_RANGE = { 5, 5, 5, 180, 180, 180, 5 }
SkeletonKeyPoseView.OBJ_SCALE_MOST = 20

SkeletonKeyPoseView._ctrl_held = function (self)
	for _, index in ipairs({ KEY_CTRL, KEY_CTRL_R }) do
		local ok, down = pcall(Keyboard.button, index)

		if ok and down and down > 0 then
			return true
		end
	end

	return false
end

SkeletonKeyPoseView._group_names = function (self)
	local G = rawget(_G, "__skeletonkey")
	local ok, names, elsewhere = pcall(function()
		if G and G.SK.group_names_here then
			return G.SK.group_names_here()
		end

		return G and G.SK.anim_index("groups"), 0
	end)

	self._groups_elsewhere = ok and tonumber(elsewhere) or 0

	return (ok and type(names) == "table") and names or {}
end

SkeletonKeyPoseView.OBJ_STEP = { 0.01, 0.01, 0.01, 0.5, 0.5, 0.5 }

SkeletonKeyPoseView._obj_said = function (self, r, v)
	local G = rawget(_G, "__skeletonkey")
	local n = G and G.SK.num(v) or tostring(v)

	if r < 4 then
		return "Moved " .. n .. " m along " .. string.upper(AXES[r]) .. "."
	end

	return "Turned " .. n .. " degrees about " .. string.upper(AXES[r - 3]) .. "."
end

SkeletonKeyPoseView._object_bars = function (self, input_service)
	local widgets = self._widgets_by_name
	local G = rawget(_G, "__skeletonkey")

	if not G or not G.SK.object_alive() then
		self._objdrag = nil

		return
	end

	local obj = G.object
	local held = left_held()

	for r = 1, 6 do
		local widget = widgets["obj_" .. r]
		local hotspot = widget and widget.content.hotspot
		local drag = self._objdrag and self._objdrag[r]

		if hotspot then
			if hotspot.is_hover then
				self._hovering = true
			end

			if hotspot.on_pressed and not drag then
				hotspot.on_pressed = false

				local ok, cursor = pcall(input_service.get, input_service, "cursor")

				if ok and cursor then
					local scale = RESOLUTION_LOOKUP and RESOLUTION_LOOKUP.inverse_scale or 1

					self._objdrag = self._objdrag or {}
					self._objdrag[r] = {
						last_x = cursor[1] * scale,
						from_x = cursor[1] * scale,
						at = r < 4 and obj.move[r] or obj.spin[r - 3],
						moved = false,
					}
				end
			elseif drag and held then
				local ok, cursor = pcall(input_service.get, input_service, "cursor")

				if ok and cursor then
					local scale = RESOLUTION_LOOKUP and RESOLUTION_LOOKUP.inverse_scale or 1
					local x = cursor[1] * scale
					local G3 = rawget(_G, "__skeletonkey")
					local span = r < 4 and ((G3 and G3.SK.OBJ_MOVE_MOST) or 1000) or 360

					if math.abs(x - drag.from_x) > 3 then
						drag.moved = true
					end

					drag.at = math.clamp(drag.at + (x - drag.last_x) * self.OBJ_STEP[r], -span, span)
					drag.last_x = x

					if drag.moved then
						local v = r < 4 and math.floor(drag.at * 100 + 0.5) / 100 or math.floor(drag.at + 0.5)

						if r < 4 then
							local m = { obj.move[1], obj.move[2], obj.move[3] }

							m[r] = v
							mod.sk_object("move", m[1], m[2], m[3])
							self:_say(self:_obj_said(r, obj.move[r]), "obj")
						else
							local t = { obj.spin[1], obj.spin[2], obj.spin[3] }

							t[r - 3] = v
							mod.sk_object("turn", t[1], t[2], t[3])
							self:_say(self:_obj_said(r, obj.spin[r - 3]), "obj")
						end
					end
				end

				self._hovering = true
			elseif drag then
				if not drag.moved then
					self:_edit_begin("obj", r, (r < 4 and "metres along " or "degrees about ") .. string.upper(AXES[r < 4 and r or r - 3]))
				end

				self._objdrag[r] = nil
			end
		end
	end

	do
		local box = widgets.hot_obj_7 and widgets.hot_obj_7.content.hotspot
		local drag = self._objdrag and self._objdrag[7]

		if box then
			if box.is_hover then
				self._hovering = true
			end

			local start = not drag and box.on_pressed

			if start or (drag and held) then
				box.on_pressed = false

				local ok, cursor = pcall(input_service.get, input_service, "cursor")

				if ok and cursor then
					local scale = RESOLUTION_LOOKUP and RESOLUTION_LOOKUP.inverse_scale or 1
					local x = cursor[1] * scale

					if start then
						self._objdrag = self._objdrag or {}
						self._objdrag[7] = { last_x = x, from_x = x, at = obj.grow or 1, moved = false }
					else
						local per = self.OBJ_RANGE[7] / definitions.OBJ_SCALE_W

						if math.abs(x - drag.from_x) > 3 then
							drag.moved = true
						end

						drag.at = math.clamp(drag.at + (x - drag.last_x) * per, 0.05, self.OBJ_SCALE_MOST)
						drag.last_x = x

						if drag.moved then
							self:_say(mod.sk_object("scale", math.floor(drag.at * 100 + 0.5) / 100), "obj")
						end
					end

					self._hovering = true
				end
			elseif drag then
				if not drag.moved then
					self:_edit_begin("obj", 7, "a size (1 is as found)")
				end

				self._objdrag[7] = nil
			end
		end
	end
end

SkeletonKeyPoseView._typed = function (self)
	local content = self._widgets_by_name.input.content
	local typed = content.input_text or ""

	if content.hotspot and content.hotspot.is_hover then
		self._hovering = true
	end

	return typed ~= "" and typed or nil
end

-- ───────────────────── ❀ ─────────────────────
--  Sets Page
-- ───────────────────── ❀ ─────────────────────

SkeletonKeyPoseView._sets_page = function (self, input_service)
	local widgets = self._widgets_by_name
	local G = rawget(_G, "__skeletonkey")
	local names = G and G.SK.anim_index("sets") or {}

	if self:_pressed(widgets.button_set_save) then
		local name = self:_typed()

		self:_say(name and mod.sk_set("save", name) or "Type a name for the set first.")
	end

	local desc = self:_list_by_id("sets")
	local top = self._set_top or 0
	local over_sets = false

	for r = 1, SET_ROWS do
		over_sets = over_sets or hovered(widgets["set_" .. r])
	end

	if over_sets then
		local okw, axis = pcall(input_service.get, input_service, "scroll_axis")
		local notch = okw and axis and axis[2] or 0

		if notch ~= 0 then
			top = top - (notch > 0 and 1 or -1)
		end
	end

	top = math.max(0, math.min(math.max(0, #names - SET_ROWS), top))
	self._set_top = top

	for r = 1, SET_ROWS do
		local name = names[top + r]

		if name and self:_pressed(widgets["set_" .. r]) then
			self:_row_press(desc, top + r, input_service)
		end

		if self:_pressed(widgets["button_set" .. r .. "_play"]) and name then
			self:_say(mod.sk_set("play", name))
		end

		if self:_pressed(widgets["button_set" .. r .. "_export"]) and name then
			self:_say(mod.sk_set("export", name))
		end

		if self:_pressed(widgets["button_set" .. r .. "_load"]) and name then
			local have = #(mod.pose_state().frames or {})

			if have > 0 and not (self._set_load == name and sk_now() - (self._set_load_at or 0) < CLEAR_ASKS_FOR) then
				self._set_load, self._set_load_at = name, sk_now()
				self:_say("Press Load again to replace your " .. (have == 1 and "1 keyframe" or (have .. " keyframes")) .. ".")
			else
				self._set_load = nil

				local said, failed = mod.sk_set("load", name)

				if not failed then
					mod.sk_keyframe("apply", 1)
					self:_go("frames")
				end

				self:_say(said)
			end
		end

		if self:_pressed(widgets["button_set" .. r .. "_del"]) and name then
			if self._set_del == name and sk_now() - (self._set_del_at or 0) < CLEAR_ASKS_FOR then
				self._set_del = nil
				self:_say(mod.sk_set("delete", name))
			else
				self._set_del, self._set_del_at = name, sk_now()
				self:_say("Press × again to delete " .. name .. ".")
			end
		end
	end
end

-- ───────────────────── ❀ ─────────────────────
--  Buttons
-- ───────────────────── ❀ ─────────────────────

SkeletonKeyPoseView._buttons = function (self, input_service)
	local widgets = self._widgets_by_name
	local pose = mod.pose_state()
	local name = self:_picked_joint()

	if self:_pressed(widgets.button_tab_joints) then
		self:_go("joints")
	end

	if self:_pressed(widgets.button_tab_frames) then
		self:_go("frames")
	end

	if self:_pressed(widgets.button_tab_sets) then
		self:_go("sets")
	end

	if self:_pressed(widgets.button_tab_poses) then
		self:_go("poses")
	end

	if self:_pressed(widgets.button_zero) then
		mod.sk_pose("zero")
		self:_say("Every dial easing back to zero.")
	end

	local release = widgets.button_release

	if release then
		local holding = release.content.hotspot.is_hover and left_held()

		if holding and not pose.released then
			mod.sk_pose("release")
			self:_say("Showing them without your changes until you let go.")
		elseif not holding and pose.released then
			mod.sk_pose("release", "off")
			self:_say("Your changes are back.")
		end

		self:_pressed(release)
	end

	if self:_pressed(widgets.button_clear) then
		mod.opener_spend()
		self._opener = false
		self:_say(mod.sk_pose("clear"))
		self._joint = 1
	end

	if self:_pressed(widgets.button_hide_this) then
		self._lit_hide = sk_now()
		self:_say(mod.sk_hide("this"), "obj")
	end

	if self:_pressed(widgets.button_show_all) then
		self._lit_undo = sk_now()
		self:_say(self:_unhide_or_rehide(), "obj")
	end

	if self:_pressed(widgets.button_loop) then
		self:_say(mod.sk_keyframe("loop"))
	end

	if self:_pressed(widgets.button_anim_freeze) then
		self:_say(mod.sk_anim("freeze"))
	end

	if self:_pressed(widgets.button_anim_thaw) then
		self:_say(mod.sk_anim("thaw"))
	end

	if self:_pressed(widgets.button_equip) then
		self:_say(mod.sk_gun(pose.gun and "show" or "hide"))
	end

	-- ───────────────────── ❀ ─────────────────────
	--  Object Controls
	-- ───────────────────── ❀ ─────────────────────

	do
		local G2 = rawget(_G, "__skeletonkey")
		local pk = G2 and G2.pick
		local pose = mod.pose_state()

		if G2 and pk and pk.unit and (pk.at or 0) ~= (self._took_at or -1) then
			self._took_at = pk.at
			G2.pick_done = pk.at

			if not G2.SK.alive(pk.unit) then
				self:_say("Nothing there to pose or to move.", "obj")
			elseif G2.SK.pose_rig(pk.unit, pk.pos, true) then
			elseif self._person_at == pk.at then
			elseif self:_ctrl_held() and G2.SK.object_alive() then
				self:_say(mod.sk_object("add"), "obj")
			else
				local said, failed = mod.sk_object("target")

				if failed then
					self:_say(said, "obj")
				end
			end
		end

		if G2 and pk and (pk.missed_at or 0) ~= (self._missed_at or 0) then
			self._missed_at = pk.missed_at or 0

			if G2.SK.object_alive() then
				self:_say(mod.sk_object("clear"), "obj")
			end
		end

		if self:_pressed(widgets.button_obj_reset) then
			self:_say(mod.sk_object("reset"), "obj")
		end

		if self:_pressed(widgets.button_obj_drop) then
			self:_clear_one()
		end

		if self:_pressed(widgets.button_obj_add) then
			self:_say(mod.sk_object("keep"), "obj")
		end

		if self:_pressed(widgets.button_obj_copy) then
			local G4 = rawget(_G, "__skeletonkey")

			if G4 and G4.SK.clip then
				mod.paste_at_screen(RESOLUTION_LOOKUP.width * 0.5, RESOLUTION_LOOKUP.height * 0.5)
				self:_say("Pasting...", "obj")
			else
				self:_say(mod.sk_object("copy"), "obj")
			end
		end

		if self:_pressed(widgets.button_marks) then
			self:_say(mod.sk_marks(), "obj")
		end

		if self:_pressed(widgets.button_chat) then
			self:_chat()
		end

		if PHYS and PHYS.press then
			PHYS.press(self)
		end


		if self:_pressed(widgets.button_obj_back) then
			self:_say(mod.sk_object("back"), "obj")
		end

		if self:_pressed(widgets.button_obj_lock) then
			self._lit_lock = sk_now()
			self:_say(mod.sk_object(G2 and G2.SK.object_locked() and "unlock" or "lock"), "obj")
		end

		if self:_pressed(widgets.button_otab_move) then
			self._otab = "move"
		end

		if self:_pressed(widgets.button_otab_items) then
			self._otab = "items"
		end

		if self:_pressed(widgets.button_otab_groups) then
			self._otab = "groups"
		end

		if self._otab ~= "items" then
			self._gpick = nil
		end

		if self._otab == "items" then
			local kept = G2 and G2.SK.keep_list() or {}

			if self:_pressed(widgets.button_hold_all) then
				self:_say(mod.sk_object("holdall"), "obj")
			end

			if self:_pressed(widgets.button_path_go) then
				self:_spawn_path()
			end

			local blocked = self._gpick ~= nil or self._gpick_eat == true

			self._gpick_eat = nil

			if self:_pressed(widgets.button_grp_save) then
				if not (G2 and G2.SK.object_alive()) then
					self:_say("Hold something first, then Save As Group.", "obj")
				elseif self._gpick then
					self._gpick = nil
				else
					self._gpick = { down = true, top = 0 }
				end
			end

			if self._gpick and not (G2 and G2.SK.object_alive()) then
				self._gpick = nil
			end

			if self._gpick then
				local pick = self._gpick
				local gnames = self:_group_names()
				local took = false

				if self:_pressed(widgets.button_gpick_new) then
					took = true
					self._rename = { id = "newgroup", row = "" }
					widgets.rename_input.content.input_text = ""
					widgets.rename_input.content.is_writing = true
					widgets.rename_box.content.what = "a new group, or an old one to add to"
				else
					for k = 1, definitions.GPICK_ROWS do
						local name = gnames[k + (pick.top or 0)]

						if name and self:_pressed(widgets["button_gpick_" .. k]) then
							self:_say(mod.sk_object("save", name), "obj")
							took = true
						end
					end
				end

				local okw, axis = pcall(input_service.get, input_service, "scroll_axis")
				local notch = okw and axis and axis[2] or 0

				if notch ~= 0 then
					local most = math.max(0, #gnames - definitions.GPICK_ROWS)

					pick.top = math.max(0, math.min(most, (pick.top or 0) - (notch > 0 and 1 or -1)))
				end

				local down = left_held()
				local inside = hovered(widgets.button_grp_save) or hovered(widgets.button_gpick_new)
					or hovered(widgets.gpick_face)

				for k = 1, definitions.GPICK_ROWS do
					inside = inside or hovered(widgets["button_gpick_" .. k])
				end

				if took or (down and not pick.down and not inside) then
					self._gpick = nil
					self._gpick_eat = not took or nil
				else
					pick.down = down
				end
			end

			local top = self._itop or 0
			local over = false

			for r = 1, definitions.ITEM_ROWS do
				local i = top + r
				local row = widgets["item_" .. r]
				local x = not blocked and not self._gpick and self:_pressed(widgets["button_item" .. r .. "_x"])
				local held = not blocked and not self._gpick and self:_pressed(row)

				if kept[i] and x then
					self:_say(mod.sk_object("forget", i), "obj")
				elseif kept[i] and held then
					local anchor = self._ianchor

					if self:_ctrl_held() then
						self:_say(mod.sk_object("toggle", i), "obj")
						self._ianchor = i
					elseif shift_held() and anchor and kept[anchor] then
						local run = {}

						for j = math.min(anchor, i), math.max(anchor, i) do
							run[#run + 1] = j
						end

						self:_say(mod.sk_object("holdset", table.concat(run, ",")), "obj")
					else
						self:_say(mod.sk_object("kept", i), "obj")
						self._ianchor = i
					end
				end

				if row and row.content.hotspot and row.content.hotspot.is_hover then
					over = true
				end
			end

			local bar = widgets.item_scroll

			if bar and bar.content.hotspot and bar.content.hotspot.is_hover then
				over = true
			end

			if over and not self._gpick then
				local okw, axis = pcall(input_service.get, input_service, "scroll_axis")
				local notch = okw and axis and axis[2] or 0

				if notch ~= 0 then
					self._itop = top - (notch > 0 and 1 or -1)
				end
			end
		elseif self._otab == "groups" then
			local names = self:_group_names()
			local over_groups = false

			for r = 1, 7 do
				over_groups = over_groups or hovered(widgets["grp_" .. r])
			end

			if over_groups then
				local okw, axis = pcall(input_service.get, input_service, "scroll_axis")
				local notch = okw and axis and axis[2] or 0

				if notch ~= 0 then
					self._gtop = (self._gtop or 0) - (notch > 0 and 1 or -1)
				end
			end

			self._gtop = math.max(0, math.min(math.max(0, #names - 7), self._gtop or 0))
			self._gsel = self._gsel or {}

			for r = 1, 7 do
				local i = r + (self._gtop or 0)
				local name = names[i]
				local placed = not self._gpick and self:_pressed(widgets["button_grp" .. r .. "_load"])
				local synced = not self._gpick and self:_pressed(widgets["button_grp" .. r .. "_sync"])
				local picked = not self._gpick and self:_pressed(widgets["grp_" .. r])

				if name and synced then
					self:_say(mod.sk_object("sync", name), "obj")
				elseif name and placed then
					local out = G2 and G2.SK.group_loaded and G2.SK.group_loaded(name)

					self:_say(mod.sk_object(out and "unload" or "load", name), "obj")
				elseif name and picked then
					if self:_ctrl_held() then
						self._gsel[name] = not self._gsel[name] or nil
						self._ganchor = i
					elseif shift_held() and self._ganchor and names[self._ganchor] then
						self._gsel = {}

						for j = math.min(self._ganchor, i), math.max(self._ganchor, i) do
							self._gsel[names[j]] = true
						end
					else
						self._gsel = { [name] = true }
						self._ganchor = i
					end
				end
			end

			if self:_pressed(widgets.button_grp_export) then
				local said, count = nil, 0

				for _, name in ipairs(names) do
					if self._gsel[name] then
						said = mod.sk_object("export", name)
						count = count + 1
					end
				end

				if count == 0 then
					self:_say("Click a group first, then Export.", "obj")
				elseif count == 1 then
					self:_say(said, "obj")
				else
					self:_say("Exported " .. count .. " groups.", "obj")
				end
			end

			if self:_pressed(widgets.button_grp_folder) then
				self:_say(mod.sk_object("folder"), "obj")
			end

			if self:_pressed(widgets.button_grp_merge) then
				local chosen = {}

				for _, name in ipairs(names) do
					if self._gsel[name] then
						chosen[#chosen + 1] = name
					end
				end

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
		else
			self:_object_bars(input_service)
		end
	end

	if self._tab == "sets" then
		self:_sets_page(input_service)

		return
	end

	if self._tab == "poses" then
		self:_poses_page(input_service)

		return
	end

	if self._tab == "joints" then
		if self:_pressed(widgets.button_jzero) and name then
			mod.sk_pose(name, 0, 0, 0)
		end

		for a = 1, #AXES do
			if self:_pressed(widgets["hot_axis_" .. AXES[a]]) and name then
				self:_edit_begin("axis", a, "degrees for " .. string.upper(AXES[a]))
			end
		end

		return
	end

	-- ───────────────────── ❀ ─────────────────────
	--  Keyframes Page
	-- ───────────────────── ❀ ─────────────────────

	if self:_pressed(widgets.button_save) then
		local content = widgets.input.content
		local typed = content.input_text or ""

		self:_say(mod.sk_keyframe("save", typed ~= "" and typed or nil))
		self._chip = #pose.frames
	end

	if self:_pressed(widgets.button_play) then
		self:_say(mod.sk_keyframe(pose.play and "stop" or "play"))
	end

	local menu_ate = self._menu ~= nil or self._menu_eat == true

	self._menu_eat = nil

	if self._menu then
		local menu = self._menu
		local took = false

		if self:_pressed(widgets.button_menu_flip) then
			self:_say(mod.sk_group("flip", menu.group))
			took = true
		elseif self:_pressed(widgets.button_menu_delete) then
			self:_say(mod.sk_group("delete", menu.group))
			self._shut[menu.group] = nil
			took = true
		elseif self:_pressed(widgets.button_menu_rename) then
			self._rename = { id = "group", row = menu.group }
			widgets.rename_input.content.input_text = menu.group
			widgets.rename_input.content.is_writing = true
			widgets.rename_box.content.what = menu.group
			took = true
		end

		local down = left_held()
		local inside = hovered(widgets.button_menu_flip) or hovered(widgets.button_menu_rename)
			or hovered(widgets.button_menu_delete)

		if took or (down and not menu.down and not inside) then
			self._menu = nil
			self._menu_eat = not took or nil
		else
			menu.down = down
		end
	end

	do
		local okr, right = pcall(Mouse.button, RIGHT_BUTTON)
		local down = okr and right and right > 0 or false

		self._rmb_fresh = down and not self._rmb_was
		self._rmb_was = down
	end

	do
		local bar = widgets.scroll_frames
		local kmost, _, kspan = self:_frame_scroll_at(#self:_frame_rows())

		if bar and bar.content.hotspot.is_hover then
			self._hovering = true
		end

		if bar and bar.content.hotspot.on_pressed then
			bar.content.hotspot.on_pressed = false

			if kmost > 0 then
				local ok, cursor = pcall(input_service.get, input_service, "cursor")

				if ok and cursor then
					local scale = RESOLUTION_LOOKUP and RESOLUTION_LOOKUP.inverse_scale or 1

					self._fdrag = { y = cursor[2] * scale, top = self._frame_top }
				end
			end
		end

		if self._fdrag then
			if left_held() and kmost > 0 and kspan > 0 then
				local ok, cursor = pcall(input_service.get, input_service, "cursor")

				if ok and cursor then
					local scale = RESOLUTION_LOOKUP and RESOLUTION_LOOKUP.inverse_scale or 1
					local moved = cursor[2] * scale - self._fdrag.y

					self._frame_top = math.clamp(math.floor(self._fdrag.top + moved / kspan * kmost + 0.5), 0, kmost)
				end

				self._hovering = true
			else
				self._fdrag = nil
			end
		end
	end

	if self._clear_armed and sk_now() - self._clear_armed > CLEAR_ASKS_FOR then
		self._clear_armed = nil
	end

	if self:_pressed(widgets.button_frames_clear) then
		if self._clear_armed then
			self._clear_armed = nil
			self._chip = nil
			self._sel.frames = {}

			self:_say(mod.sk_keyframe("clear"))
		elseif #pose.frames > 0 then
			self._clear_armed = sk_now()

			self:_say("Press Confirm to delete your " .. (#pose.frames == 1 and "1 keyframe" or (#pose.frames .. " keyframes")) .. ".")
		else
			self:_say(mod.sk_keyframe("clear"))
		end
	end

	local input = widgets.input.content

	if input.hotspot and input.hotspot.is_hover then
		self._hovering = true
	end

	local okw, axis = pcall(input_service.get, input_service, "scroll_axis")
	local notch = okw and axis and axis[2] or 0

	local desc = self:_list_by_id("frames")

	local over_list = false

	for r = 1, KEY_ROWS do
		local row = widgets["frame_" .. r]

		if row and row.content.hotspot.is_hover then
			over_list = true
		end
	end

	local tree = self:_frame_rows()
	local most = math.max(0, #tree - KEY_ROWS)

	if notch ~= 0 and not over_list and hovered(widgets.plate) then
		self._frame_top = math.max(0, math.min(most, self._frame_top - notch))
	end

	if self._frame_top > most then
		self._frame_top = most
	end

	for r = 1, KEY_ROWS do
		local entry = tree[self._frame_top + r]
		local i = entry and entry.frame
		local frame = i and pose.frames[i]
		local row = widgets["frame_" .. r]

		local on_bar = row.content.bar and row.content.bar.is_hover

		if frame and notch ~= 0 and on_bar then
			mod.sk_keyframe("hold", i, (frame.hold or 2) + notch * HOLD_STEP)
		elseif entry and entry.head and notch ~= 0 and on_bar then
			mod.sk_group("time", entry.head, (mod.group_time(entry.head) or 0) + notch * HOLD_STEP)
		end

		if not menu_ate and frame and self:_pressed(row) then
			if self:_row_press(desc, i, input_service) then
				self._chip = i

				self:_say(mod.sk_keyframe("apply", i))
			end
		elseif not menu_ate and entry and entry.head and self:_pressed(row) then
			self._shut[entry.head] = not self._shut[entry.head] or nil
		end

		if entry and entry.head and row.content.hotspot.is_hover then
			if self._rmb_fresh then
				self._menu = { group = entry.head, y = (row.style.face.offset[2] or 0) + 28 }
			end
		end

		if not menu_ate and frame and self:_pressed(widgets["hot_hold_" .. r]) then
			self:_edit_begin("hold", i, "seconds for " .. frame.name, frame.name)
		elseif not menu_ate and entry and entry.head and self:_pressed(widgets["hot_hold_" .. r]) then
			self:_edit_begin("gtime", entry.head, "seconds for " .. entry.head)
		end

		for v = 1, #ROW_VERBS do
			local verb = ROW_VERBS[v]
			local widget = widgets["button_row" .. r .. "_" .. verb]

			if not menu_ate and self:_pressed(widget) and frame then
				if verb == "del" then
					self:_sel_of("frames")[i] = nil
					self._chip = nil

					self:_say(mod.sk_keyframe("delete", i))
				elseif verb == "over" then
					self:_say(mod.sk_keyframe("over", i))
				end
			end
		end
	end
end

-- ───────────────────── ❀ ─────────────────────
--  Fill Helpers
-- ───────────────────── ❀ ─────────────────────

local function show(widget, on)
	if widget then
		widget.content.visible = on and true or false
	end
end

local function lit_row(row, there, picked)
	local face = row and row.style.face.color

	if face then
		face[1] = there and 255 or 0
		face[2], face[3], face[4] = picked and 80 or 44, picked and 85 or 48, picked and 95 or 54
	end

	local sel = row and row.style.sel

	if sel then
		sel.color[1] = there and picked and 255 or 0
	end
end

local function place(widget, at)
	local face = widget and widget.style.face
	local dx, dy = face and at[1] - face.offset[1] or 0, face and at[2] - face.offset[2] or 0

	if dx ~= 0 or dy ~= 0 then
		for _, st in pairs(widget.style) do
			if type(st) == "table" and st.offset then
				st.offset[1], st.offset[2] = st.offset[1] + dx, st.offset[2] + dy
			end
		end
	end
end

SkeletonKeyPoseView._fill_items = function (self, items, kept, obj)
	local widgets = self._widgets_by_name
	local G = rawget(_G, "__skeletonkey")
	local SK = G and G.SK
	local rows = definitions.ITEM_ROWS
	local pitch = definitions.ITEM_PITCH
	local total = items and #kept or 0
	local most = math.max(0, total - rows)

	self._itop = math.max(0, math.min(most, self._itop or 0))

	local top = self._itop
	local shown = math.min(total, rows)

	show(widgets.item_head, items)

	if widgets.item_head then
		widgets.item_head.content.label = total == 0 and "Nothing on the list yet. S adds what you hold."
			or (total .. " on the list. Click one to hold it.")
	end

	for r = 1, rows do
		local one = items and kept[top + r] or nil
		local w = widgets["item_" .. r]
		local x = widgets["button_item" .. r .. "_x"]
		local hover = (w and w.content.hotspot and w.content.hotspot.is_hover)
			or (x and x.content.hotspot and x.content.hotspot.is_hover)

		show(w, one ~= nil)
		show(x, one ~= nil and hover or false)

		if w and one then
			local st = w.style
			local kind, dot = "", SK and SK.KIND_PROP

			if SK and SK.kind_of then
				kind, dot = SK.kind_of(one.unit)
			end

			local away = SK and SK.distance_to and SK.distance_to(one.unit)
			local held = false

			for i = 1, #((obj and obj.crew) or {}) do
				if obj.crew[i].unit == one.unit then
					held = true
				end
			end

			w.content.name = self:_fit_to(w, "name", shown_name(one.name), 24)
			w.content.kind = kind or ""
			w.content.away = away and (away .. " m") or ""

			if dot then
				st.dot.color[2], st.dot.color[3], st.dot.color[4] = dot[1], dot[2], dot[3]
			end

			st.held.color[1] = held and 255 or 0
			st.face.color[2] = held and 74 or (hover and 54 or 44)
			st.face.color[3] = held and 79 or (hover and 58 or 48)
			st.face.color[4] = held and 88 or (hover and 65 or 54)
		end
	end

	local bar = widgets.item_scroll

	show(bar, items and most > 0)

	if bar and most > 0 then
		local track = bar.style.track.size[2]
		local _, thumb, _, at = self:_scroll_at(total, rows, track, top, definitions.ITEM_Y)

		bar.style.thumb.size[2] = thumb
		bar.style.thumb.offset[2] = at
	end

	local base = definitions.OBJ_PANEL_H
	local say_y = definitions.OBJ_SAY_Y
	local h = base
	local empty = (self._otab or "move") == "move" and not (SK and SK.object_alive())

	place(widgets.button_obj_copy, empty and definitions.OBJ_EMPTY_COPY_AT or definitions.OBJ_COPY_AT)
	place(widgets.button_obj_back, empty and definitions.OBJ_EMPTY_BACK_AT or definitions.OBJ_BACK_AT)

	if empty then
		say_y = definitions.OBJ_EMPTY_COPY_AT[2] + definitions.OBJ_BTN_H + 12
		h = say_y + 22 + 14
	end

	if items then
		local bottom = definitions.ITEM_Y + math.max(shown, 1) * pitch
		local hold_y = bottom + 2

		local path_y = hold_y + 34

		pcall(self._set_scenegraph_position, self, "path_field", definitions.ITEM_X, path_y)
		place(widgets.button_path_go, { definitions.PATH_GO_X, path_y })

		say_y = path_y + 28 + 10
		h = say_y + 22 + 14

		self._hold_y = hold_y

		for _, name in ipairs({ "button_hold_all", "button_grp_save" }) do
			local hold = widgets[name]

			if hold then
				for id, st in pairs(hold.style) do
					if type(st) == "table" and st.offset then
						st.offset[2] = id == "edge" and (hold_y + 27) or hold_y
					end
				end
			end
		end
	end

	if widgets.obj_say then
		widgets.obj_say.style.label.offset[2] = say_y
	end

	local card = widgets.obj_plate

	if card then
		card.style.plate.size[2] = h

		if card.style.hotspot then
			card.style.hotspot.size[2] = h
		end

		card.style.dials.size[2] = items
			and (definitions.ITEM_Y + math.max(shown, 1) * pitch - (definitions.ITEM_Y - 34) + 4)
			or (self._otab == "groups" and definitions.OBJ_GROUPS_H)
			or (empty and definitions.OBJ_EMPTY_H)
			or definitions.OBJ_DIALS_H
	end

	if h ~= (self._obj_h or base) then
		self._obj_h = h
		self._obj_grow = (h - base) * 0.5

		pcall(self._set_scenegraph_size, self, "objkey", definitions.OBJ_PANEL_W, h)

		if not self._obj_parked then
			local at = self._at and self._at.objkey

			self:_place(at and at[1] or 0, at and at[2] or 0, "objkey")
		end
	end
end

-- ───────────────────── ❀ ─────────────────────
--  Fill
-- ───────────────────── ❀ ─────────────────────

SkeletonKeyPoseView._fill = function (self)
	local widgets = self._widgets_by_name
	local pose = mod.pose_state()
	local plate = widgets.plate.content
	local style = widgets.plate.style
	local name = self:_picked_joint()
	local joints = self._tab == "joints"
	local holding = (rawget(_G, "__skeletonkey") or {}).SK ~= nil
		and rawget(_G, "__skeletonkey").SK.object_alive() or false
	local frames = self._tab == "frames"
	local sets = self._tab == "sets"
	local poses = self._tab == "poses"
	local G = rawget(_G, "__skeletonkey")

	local held = 0

	for _, b in pairs(pose.bone or {}) do
		if b.held then
			held = held + 1
		end
	end

	local who = pose.unit and (pose.name ~= "" and string.match(pose.name, "([^/]+)$")
		or (held > 0 and (held .. " bones") or "posing")) or nil

	plate.target = self:_fit_to(widgets.plate, "target", who or "", NAME_CHARS)

	local playing = G and G.SK.anim_status() or ""
	local fresh = self._reply ~= "" and (sk_now() - (self._said_at or 0)) < SAY_HOLDS

	local locked_in = pose.unit and "Posing them. C or Clear Target lets them go." or nil
	local line = (fresh and self._reply) or self:_hint("pose") or (playing ~= "" and playing)
		or locked_in or "Left-click on a person to pose them."

	plate.reply = self:_fit_to(widgets.plate, "reply", line or "", FOOT_CHARS)

	if widgets.obj_say then
		local obj_reply = self._obj_reply or ""
		local obj_fresh = obj_reply ~= "" and (sk_now() - (self._obj_said_at or 0)) < SAY_HOLDS
		local obj_line = (obj_fresh and obj_reply) or self:_hint("obj") or obj_reply

		widgets.obj_say.content.label = self:_fit_to(widgets.obj_say, "label", obj_line or "", OBJ_SAY_CHARS)
	end

	if self._field_restore then
		self._field_restore = nil
		widgets.input.content.input_text = self._field[self._tab] or ""
	end

	local set_names = sets and G and G.SK.anim_index("sets") or {}
	local emotes = poses and self:_poses() or {}
	if frames and #pose.frames == 0 then
		plate.empty, plate.empty2 = "No keyframes yet.", "Pose a joint, then press Save Pose."
	elseif sets and #set_names == 0 then
		plate.empty, plate.empty2 = "No sets yet.", "Make keyframes, then Save Keyframes As Set."
	elseif poses and #emotes == 0 then
		plate.empty = self:_typed() and "Nothing matches that." or "No animations yet."
		plate.empty2 = self:_typed() and "Try fewer letters." or "The game has not loaded its item list yet."
	else
		plate.empty, plate.empty2 = "", ""
	end
	plate.col_name = (frames and #pose.frames > 0) and "Name" or ""
	plate.col_hold = (frames and #pose.frames > 0) and "Time" or ""
	local short = name and string.gsub(name, "^j_", "") or ""

	plate.joint = joints and name and (string.upper(string.sub(short, 1, 1)) .. string.sub(short, 2)) or ""

	style.list.color[1] = joints and 255 or 0
	style.dials.color[1] = joints and 255 or 0
	style.frames.color[1] = joints and 0 or 255

	for _, tab in ipairs({ "joints", "poses", "frames", "sets" }) do
		local widget = widgets["button_tab_" .. tab]
		local on = self._tab == tab
		local face = widget.style.face.color
		local sel = widget.style.sel.color

		face[2], face[3], face[4] = on and 35 or 27, on and 38 or 29, on and 43 or 33

		if on then
			face[1] = 255
		end

		sel[1] = on and 255 or 0
		widget.style.label.text_color[2] = on and 236 or 141
		widget.style.label.text_color[3] = on and 230 or 148
		widget.style.label.text_color[4] = on and 216 or 160
	end

	for i = 1, JOINT_SLOTS do
		local widget = widgets["button_joint_" .. i]
		local joint = pose.joints[i]
		local picked = i == self._joint and joint ~= nil

		show(widget, joints and joint ~= nil)

		if joint then
			local d = pose.dial[joint]

			widget.content.label = string.gsub(joint, "^j_", "")
			widget.content.dials = (d[1] ~= 0 or d[2] ~= 0 or d[3] ~= 0) and string.format("%d %d %d", d[1], d[2], d[3]) or ""
		end

		local face = widget.style.face.color

		if picked then
			face[1], face[2], face[3], face[4] = 255, 80, 85, 95
		else
			local lit = widget.content.hotspot.is_hover and joint

			face[1], face[2], face[3], face[4] = 255, lit and 60 or 44, lit and 65 or 48, lit and 73 or 54
		end

		if widget.style.sel then
			widget.style.sel.color[1] = picked and 255 or 0
		end
	end

	local has = {}

	for j, joint in ipairs(pose.joints or {}) do
		has[joint] = j
	end

	show(widgets.chart, joints and next(has) ~= nil)

	for i = 1, #CHART_NODES do
		local widget = widgets["button_node_" .. i]
		local joint = CHART_NODES[i]
		local there = joints and has[joint] ~= nil

		show(widget, there)

		if widget and there then
			local d = pose.dial[joint] or { 0, 0, 0 }
			local picked = has[joint] == self._joint
			local bent = d[1] ~= 0 or d[2] ~= 0 or d[3] ~= 0
			local lit = picked or widget.content.hotspot.is_hover
			local ring, hole, dot = widget.style.ring.color, widget.style.hole.color, widget.style.dot.color

			ring[1], hole[1] = lit and 255 or 0, lit and 255 or 0
			ring[2], ring[3], ring[4] = picked and 230 or 141, picked and 220 or 148, picked and 195 or 160
			dot[2], dot[3], dot[4] = bent and 230 or 58, bent and 220 or 63, bent and 195 or 71
		end
	end

	for a = 1, #AXES do
		local widget = widgets["slider_" .. AXES[a]]
		local value = name and pose.dial[name][a] or 0
		local at = (value + RANGE) / (RANGE * 2) * BAR_W

		show(widget, joints)
		widget.content.value = self:_edit_text("axis", a, tostring(value) .. "°")
		widget.style.knob.offset[1] = BAR_X + at - 7
		widget.style.fill.offset[1] = BAR_X + math.min(at, BAR_W * 0.5)
		widget.style.fill.size[1] = math.abs(at - BAR_W * 0.5)
	end

	show(widgets.button_jzero, joints)

	-- ───────────────────── ❀ ─────────────────────
	--  Object Card
	-- ───────────────────── ❀ ─────────────────────

	do
		local obj = G and G.object
		local RANGES = self.OBJ_RANGE
		local tab = self._otab or "move"
		local moving = tab == "move"
		local groups = tab == "groups"
		local items = tab == "items"
		local kept = items and (G and G.SK.keep_list()) or {}
		local names = groups and self:_group_names() or {}

		local boxing = self._box ~= nil and self._box.drawn == true
		local sliding = self:_out_of_way()
		local up = (holding or groups or items or self._opener == true) and not boxing and not sliding

		if sliding ~= (self._obj_parked == true) then
			self._obj_parked = sliding

			if sliding then
				pcall(self._set_scenegraph_position, self, "objkey", -4000, 0)
			else
				local at = self._at and self._at.objkey

				self:_place(at and at[1] or 0, at and at[2] or 0, "objkey")
			end
		end

		show(widgets.obj_plate, up)
		show(widgets.obj_grip, up)
		show(widgets.obj_empty, up and moving and not holding)
		show(widgets.grp_empty, up and groups and #names == 0)
		show(widgets.obj_say, up)
		show(widgets.button_otab_move, up)
		show(widgets.button_otab_items, up)
		show(widgets.button_otab_groups, up)

		for _, lit in ipairs({ { widgets.button_otab_move, moving }, { widgets.button_otab_items, items },
			{ widgets.button_otab_groups, groups } }) do
			local w = lit[1]

			if w then
				paint(w.style.edge.color, lit[2] and definitions.GOLD or definitions.LINE)
				paint(w.style.face.color, lit[2] and definitions.PANEL or definitions.BG)
			end
		end

		for r = 1, 6 do
			local widget = widgets["obj_" .. r]

			show(widget, holding and moving)

			if widget and holding then
				local value = r < 4 and obj.move[r] or obj.spin[r - 3]
				local drag = self._objdrag and self._objdrag[r]
				local lit = drag and drag.moved
				local face = widget.style.face.color

				widget.content.value = self:_edit_text("obj", r,
					G.SK.num(value) .. (r < 4 and " m" or "°"))
				face[2], face[3], face[4] = lit and 210 or 20, lit and 206 or 22, lit and 190 or 25
				widget.style.value.text_color[2] = lit and 20 or 232
				widget.style.value.text_color[3] = lit and 22 or 230
				widget.style.value.text_color[4] = lit and 25 or 225
			end
		end

		show(widgets.obj_heads, holding and moving)

		for r = 1, 7 do
			local row = widgets["grp_" .. r]
			local label = groups and names[r + (self._gtop or 0)] or nil

			show(row, label ~= nil)
			local G3 = rawget(_G, "__skeletonkey")
			local out = label ~= nil and G3 and G3.SK.group_loaded and G3.SK.group_loaded(label)

			show(widgets["button_grp" .. r .. "_load"], groups and label ~= nil)
			show(widgets["button_grp" .. r .. "_sync"], groups and out == true and G3.SK.group_sync ~= nil)

			if row and label then
				row.content.name = self:_fit_to(row, "name", label, 22)
			end

			if row then
				lit_row(row, true, label ~= nil and self._gsel ~= nil and self._gsel[label] == true)

				if row.style.dot then
					row.style.dot.color[1] = out == true and 255 or 0
				end
			end

			if label and widgets["button_grp" .. r .. "_load"] then
				widgets["button_grp" .. r .. "_load"].content.label = out and "Unload" or "Load"
			end
		end

		do
			local bar = widgets.grp_scroll
			local most, thumb, _, at = self:_scroll_at(#names, definitions.GROUP_ROWS,
				bar and bar.style.track.size[2] or 0, self._gtop or 0, definitions.GROUP_Y)

			show(bar, groups and most > 0)

			if bar and most > 0 then
				bar.style.thumb.size[2] = thumb
				bar.style.thumb.offset[2] = at
			end
		end

		show(widgets.button_grp_save, items and holding)

		do
			local open = items and self._gpick ~= nil
			local gnames = open and self:_group_names() or {}
			local gtop = self._gpick and self._gpick.top or 0

			local drop = (self._hold_y or definitions.ITEM_BTN_Y) - definitions.ITEM_BTN_Y

			for _, w in ipairs({ widgets.gpick_face or false, widgets.button_gpick_new or false }) do
				if w then
					w.offset = w.offset or { 0, 0, 0 }
					w.offset[2] = drop
				end
			end

			show(widgets.gpick_face, open)
			show(widgets.button_gpick_new, open)

			if widgets.gpick_face then
				local tall = (math.min(#gnames, definitions.GPICK_ROWS) + 1) * definitions.GPICK_H + 8
				local st = widgets.gpick_face.style

				st.face.size[2] = tall

				if st.hotspot then
					st.hotspot.size[2] = tall
				end
			end

			do
				local bar = widgets.gpick_scroll
				local most, thumb, _, at = self:_scroll_at(#gnames, definitions.GPICK_ROWS,
					bar and bar.style.track.size[2] or 0, gtop, definitions.GPICK_BAR_Y)

				show(bar, open and most > 0)

				if bar then
					bar.offset = bar.offset or { 0, 0, 0 }
					bar.offset[2] = drop

					if most > 0 then
						bar.style.thumb.size[2] = thumb
						bar.style.thumb.offset[2] = at
					end
				end
			end

			for k = 1, definitions.GPICK_ROWS do
				local w = widgets["button_gpick_" .. k]
				local name = gnames[k + gtop]

				if w then
					w.offset = w.offset or { 0, 0, 0 }
					w.offset[2] = drop
				end

				show(w, open and name ~= nil)

				if w and name then
					w.content.label = self:_fit_to(w, "label", name, 22)
				end
			end
		end

		do
			local picked = 0

			for _, name in ipairs(names) do
				if self._gsel and self._gsel[name] then
					picked = picked + 1
				end
			end

			show(widgets.button_grp_merge, groups)
			show(widgets.button_grp_export, groups)
			self:_dim(widgets.button_grp_merge, "grp_merge", picked < 2, "Ctrl+click two or more groups first.")
			self:_dim(widgets.button_grp_export, "grp_export", picked < 1, "Click a group first, then Export.")
			show(widgets.button_grp_folder, groups)

			local more = groups and (self._groups_elsewhere or 0) or 0
			local line = widgets.grp_more

			show(line, more > 0)

			if line and more > 0 then
				line.content.label = more == 1 and "1 more group saved in another level"
					or (more .. " more groups saved in other levels")
			end
		end
		show(widgets.button_hold_all, items)

		do
			local path_on = items and up and self._gpick == nil or false

			show(widgets.path_input, path_on)
			show(widgets.button_path_go, path_on)

			if not path_on then
				widgets.path_input.content.is_writing = false
			end
		end

		self:_dim(widgets.button_hold_all, "hold_all", #kept < 2, "Needs two or more things on the list.")
		self:_fill_items(items and up, kept, obj)

		do
			local widget = widgets.obj_7
			local value = holding and (obj.grow or 1) or 1

			show(widget, holding and moving)
			show(widgets.hot_obj_7, holding and moving)

			if widget then
				widget.content.value = self:_edit_text("obj", 7, G.SK.num(value) .. "×")
			end
		end

		show(widgets.button_obj_reset, holding and moving)
		show(widgets.button_obj_drop, holding and moving)
		show(widgets.button_obj_add, holding and moving)
		local clip = G and G.SK.clip ~= nil

		show(widgets.button_obj_copy, up and moving)
		self:_dim(widgets.button_obj_copy, "obj_copy", not (holding or clip), "Click something to copy first.")

		if widgets.button_obj_copy then
			widgets.button_obj_copy.content.label = clip and "Paste" or "Copy"
			widgets.button_obj_copy.content.head = clip and "Ctrl+V" or "Ctrl+C"
		end
		if G and G.SK.obj_past and #G.SK.obj_past > 0 then
			pcall(G.SK.past_prune)
		end

		show(widgets.button_obj_back, up and moving)
		self:_dim(widgets.button_obj_back, "obj_back", #((G and G.SK.obj_past) or {}) == 0, "Nothing to undo yet.")
		show(widgets.button_obj_lock, holding and moving)

		if widgets.button_obj_lock then
			local st = widgets.button_obj_lock.style
			local locked = G and G.SK.object_locked()
			local hot = self._lit_lock ~= nil and (sk_now() - self._lit_lock) < 0.25
			local face = st.face.color
			local ink = locked and { 255, 30, 28, 24 } or { 255, 236, 230, 216 }

			paint(st.edge.color, locked and definitions.GOLD or definitions.LINE)

			if locked then
				face[2], face[3], face[4] = 230, 220, 195
			else
				face[2], face[3], face[4] = hot and 96 or 44, hot and 92 or 48, hot and 80 or 54
			end

			local c = st.label and st.label.text_color

			if c then
				c[1], c[2], c[3], c[4] = ink[1], ink[2], ink[3], ink[4]
			end

			widgets.button_obj_lock.content.label = definitions.KEYWORD("Lock", locked and "90,78,40" or nil)
		end

		show(widgets.obj_note, holding)

		if widgets.obj_note then
			local crew = holding and #((obj and obj.crew) or {}) or 0

			widgets.obj_note.content.label = self:_fit_to(widgets.obj_note, "label", holding
				and (crew > 1 and (crew .. " things")
					or ((G and obj and G.SK.short_name and G.SK.short_name(obj.unit)) or "Unnamed Prop"))
				or "", 24)
		end
	end
	do
		local boxing = self._box ~= nil and self._box.drawn == true
		local sliding = self:_out_of_way()
		local away = boxing or sliding or (pose.unit == nil and not self._opener)

		if away ~= self._pose_parked then
			self._pose_parked = away

			if away then
				pcall(self._set_scenegraph_position, self, "pose", 4000, 0)
			else
				local at = self._at and self._at.pose

				self:_place(at and at[1] or 0, at and at[2] or 0, "pose")
			end
		end
	end

	-- ───────────────────── ❀ ─────────────────────
	--  Overlays
	-- ───────────────────── ❀ ─────────────────────

	do
		local pk = G and G.pick

		if pk and pk.paste_at and pk.paste_at ~= self._paste_said then
			self._paste_said = pk.paste_at

			if self._reply == "Pasting..." then
				self._reply = ""
			end

			self:_say(pk.paste_said, "obj")
		end
	end

	do
		local b = self._box
		local w = widgets.marquee

		show(w, b ~= nil and b.drawn == true)

		if w and b and b.drawn then
			local sc = RESOLUTION_LOOKUP and RESOLUTION_LOOKUP.inverse_scale or 1
			local x0, y0 = math.min(b.x0, b.x1) * sc, math.min(b.y0, b.y1) * sc
			local bw, bh = math.abs(b.x1 - b.x0) * sc, math.abs(b.y1 - b.y0) * sc

			w.style.fill.offset[1], w.style.fill.offset[2] = x0, y0
			w.style.fill.size[1], w.style.fill.size[2] = bw, bh

			for _, edge in ipairs({ { "top", x0, y0, bw, 1 }, { "bottom", x0, y0 + bh, bw, 1 },
				{ "left", x0, y0, 1, bh }, { "right", x0 + bw, y0, 1, bh } }) do
				local st = w.style[edge[1]]

				st.offset[1], st.offset[2] = edge[2], edge[3]
				st.size[1], st.size[2] = edge[4], edge[5]
			end
		end
	end

	do
		local f = G and G.SK.gyro_frame()
		local w = widgets.gyro
		local sliding = self:_out_of_way()

		show(w, f ~= nil and not sliding)

		if w and f and not sliding then
			local sc = RESOLUTION_LOOKUP and RESOLUTION_LOOKUP.inverse_scale or 1
			local ox, oy = f.ox * sc, f.oy * sc
			local line, rib, head = definitions.GYRO_LINE, definitions.GYRO_RIB, definitions.GYRO_HEAD

			local function lay(st, ax, ay, bx, by, thick)
				if not st then
					return
				end

				if not ax or not bx then
					st.offset[1], st.offset[2] = -400, -400
					st.size[1] = 1

					return
				end

				local dx, dy = bx - ax, by - ay
				local len = math.max(1, math.sqrt(dx * dx + dy * dy))

				st.size[1], st.size[2] = len, thick
				st.angle = -math.atan2(dy, dx)
				st.pivot[1], st.pivot[2] = len * 0.5, thick * 0.5
				st.offset[1] = (ax + bx) * 0.5 - len * 0.5
				st.offset[2] = (ay + by) * 0.5 - thick * 0.5
			end

			local hover = self._gyro_hover
			local base = definitions.GYRO_AXIS

			local function tint(st, c, hot)
				if not st then
					return
				end

				local k = hot and 0.55 or 0

				st.color[1] = 255
				st.color[2] = c[2] + (255 - c[2]) * k
				st.color[3] = c[3] + (255 - c[3]) * k
				st.color[4] = c[4] + (255 - c[4]) * k
			end

			for r = 1, 3 do
				local hot = hover == "r" .. r

				for d = 1, definitions.GYRO_RINGS do
					local a = f.ring[r] and f.ring[r][d]
					local b = f.ring[r] and f.ring[r][d % definitions.GYRO_RINGS + 1]
					local st = w.style[string.format("r%d_%d", r, d)]

					lay(st, a and a[1] * sc, a and a[2] * sc,
						b and b[1] * sc, b and b[2] * sc, hot and rib + 2 or rib)
					tint(st, base[r], hot)
				end
			end

			for a = 1, 3 do
				local tip = f.tip[a]
				local st = w.style["a" .. a]
				local hot = hover == a

				lay(st, ox, oy, tip and tip[1] * sc, tip and tip[2] * sc, hot and line + 2 or line)
				tint(st, base[a], hot)

				local hs = w.style["h" .. a]

				if tip then
					local tx, ty = tip[1] * sc, tip[2] * sc

					lay(hs, ox + (tx - ox) * 0.82, oy + (ty - oy) * 0.82, tx, ty, hot and head + 4 or head)
				else
					lay(hs, nil, nil, nil, nil, head)
				end

				tint(hs, base[a], hot)
			end
		end
	end

	do
		local pk = G and G.pick

		if pk and (pk.box_at or 0) ~= (self._box_said or 0) then
			self._box_said = pk.box_at
			local n = pk.box_took or 0

			self:_say(n == 0 and "The box caught nothing." or ("Holding " .. n .. (n == 1 and " thing" or " things") .. " from the box."), "obj")
		end
	end

	-- ───────────────────── ❀ ─────────────────────
	--  Page Widgets
	-- ───────────────────── ❀ ─────────────────────

	show(widgets.input, frames or sets or poses)
	widgets.input.content.placeholder_text = poses and "Filter" or "Name"
	show(widgets.button_save, frames)
	show(widgets.button_play, frames)
	show(widgets.button_frames_clear, frames)

	do
		local menu = frames and self._menu or nil

		for _, name in ipairs({ "menu_face", "button_menu_flip", "button_menu_rename", "button_menu_delete" }) do
			local w = widgets[name]

			if w then
				show(w, menu ~= nil)
				w.offset = w.offset or { 0, 0, 0 }
				w.offset[2] = menu and menu.y or 0
			end
		end
	end

	do
		local bar = widgets.scroll_frames
		local kmost, kthumb, _, kat = self:_frame_scroll_at(#self:_frame_rows())

		show(bar, frames and kmost > 0)

		if bar then
			bar.style.thumb.size[2] = kthumb
			bar.style.thumb.offset[2] = kat
		end
	end
	show(widgets.button_set_save, sets)
	show(widgets.button_loop, frames)
	do
		local hidden = G and G.SK.hidden and #G.SK.hidden or 0

		local okh, holding_any = pcall(function()
			return G and G.SK.selected_unit() ~= nil
		end)

		local sliding = self:_out_of_way()

		show(widgets.button_hide_this, (okh and holding_any or false) and not sliding)
		local again = G ~= nil and G.SK.unhidden ~= nil and #G.SK.unhidden > 0

		show(widgets.button_show_all, (hidden > 0 or again) and not sliding)

		if widgets.button_show_all then
			widgets.button_show_all.content.label = hidden > 0 and "Unhide" or "Rehide"
		end
		show(widgets.hide_note, hidden > 0 and not sliding)
		show(widgets.note, not sliding)

		do
			local okk, down = pcall(Keyboard.button, KEY_K)
			local held = KEY_K ~= nil and okk and down and down > 0 and not self:_typing()

			local hover = widgets.note and widgets.note.content.hotspot and widgets.note.content.hotspot.is_hover

			show(widgets.keysheet, (held or hover) and not sliding or false)
		end
		show(widgets.button_marks, not sliding)
		show(widgets.button_chat, not sliding)

		if widgets.button_chat then
			local on = self:_chatting()
			local face, ink = widgets.button_chat.style.face.color, widgets.button_chat.style.label.text_color

			face[2], face[3], face[4] = on and 230 or 26, on and 220 or 24, on and 195 or 22
			ink[2], ink[3], ink[4] = on and 27 or 141, on and 29 or 148, on and 33 or 160
		end

		if PHYS then
			PHYS.step(self, show, sliding)
		end

		do
			local w = widgets.held_path
			local obj = G and G.object
			local text = nil

			if w and obj and G.SK.object_alive() then
				local path = G.SK.unit_name and G.SK.unit_name(obj.unit)
				local crew = #(obj.crew or {})

				if path and string.find(path, "content/units/zz", 1, true) then
					path = ((G.SK.short_name and G.SK.short_name(obj.unit)) or "Unnamed Prop") .. "  (path unknown)"
				end

				text = (path or "Path unknown") .. (crew > 1 and ("   + " .. (crew - 1) .. " more") or "")
			end

			show(w, text ~= nil and not sliding)

			if w and text then
				w.content.label = text
			end
		end

		if widgets.button_marks then
			local on = mod.sk_marks("state") == "on"

			widgets.button_marks.content.label = on and "Hide Hidden Markers" or "Show Hidden Markers"

			local face = widgets.button_marks.style.face.color
			local ink = widgets.button_marks.style.label.text_color

			if on then
				face[1], face[2], face[3], face[4] = 255, 230, 220, 195
			end

			ink[2], ink[3], ink[4] = on and 27 or 236, on and 29 or 230, on and 33 or 216
		end


		for _, lit in ipairs({ { widgets.button_hide_this, self._lit_hide },
			{ widgets.button_show_all, self._lit_undo } }) do
			local w, when = lit[1], lit[2]

			if w then
				local hot = when ~= nil and (sk_now() - when) < 0.25
				local face = w.style.face.color

				face[2], face[3], face[4] = hot and 96 or 44, hot and 92 or 48, hot and 80 or 54
			end
		end

		if widgets.hide_note then
			widgets.hide_note.content.label = hidden == 1 and "1 hidden" or (hidden .. " hidden")
		end
	end
	show(widgets.button_anim_freeze, true)
	show(widgets.button_anim_thaw, true)
	show(widgets.button_equip, true)

	for _, lit in ipairs({ { widgets.button_loop, pose.loop }, { widgets.button_equip, pose.gun ~= nil } }) do
		local loop = lit[1]
		local face = loop.style.face.color
		local on = lit[2]

		face[1], face[2], face[3], face[4] = 255, on and 230 or 44, on and 220 or 48, on and 195 or 54
		loop.style.label.text_color[2] = on and 27 or 236
		loop.style.label.text_color[3] = on and 29 or 230
		loop.style.label.text_color[4] = on and 33 or 216
	end

	for a = 1, #AXES do
		show(widgets["hot_axis_" .. AXES[a]], joints and name ~= nil)
	end

	for r = 1, POSE_ROWS do
		local row = widgets["pose_" .. r]
		local e = emotes[self._pose_top + r]

		if row then
			show(row, poses)
			row.content.name = self:_fit_to(row, "name", e and (string.gsub(e.name, "_", " ")) or "", 22)
			row.content.breed = self:_fit_to(row, "breed", e and e.source or "", 12)
			row.style.face.color[1] = e and 255 or 0
			show(widgets["button_pose" .. r .. "_play"], poses and e ~= nil)
		end
	end
	do
		local up = self._rename ~= nil

		show(widgets.rename_veil, up)
		show(widgets.rename_box, up)

		if widgets.rename_box then
			local id = self._rename and self._rename.id

			widgets.rename_box.content.title = (id == "newgroup" or id == "mergegroup") and "Name" or "Rename"
		end
		show(widgets.rename_input, up)
	end

	do
		local bar = widgets.scroll
		local most, thumb, _, at = self:_scroll_at(#emotes)

		show(bar, poses and most > 0)

		if bar then
			bar.style.thumb.size[2] = thumb
			bar.style.thumb.offset[2] = at
		end
	end

	show(widgets.button_pose_rest, poses)

	do
		local tape = pose.tape
		local frames = tape and #tape.frames or 0
		local at = math.max(1, math.min(frames, pose.tape_i or 1))
		local along = frames > 1 and (at - 1) / (frames - 1) or 0
		local wide = along * definitions.TAPE_BAR_W

		show(widgets.tape, poses and frames > 0)
		show(widgets.button_tape_back, poses and frames > 0)
		show(widgets.button_tape_on, poses and frames > 0)
		show(widgets.button_tape_key, poses and frames > 0)
		show(widgets.button_tape_keyto, poses and frames > 0)
		widgets.button_tape_keyto.content.label = "Key " .. tostring(pose.tape_stride or 2) .. "s"

		if widgets.tape then
			local from = math.max(1, math.min(frames, pose.tape_in or 1))
			local in_along = frames > 1 and (from - 1) / (frames - 1) or 0
			local in_wide = in_along * definitions.TAPE_BAR_W

			widgets.tape.style.tcut.size[1] = in_wide
			widgets.tape.style.tfill.offset[1] = definitions.TAPE_BAR_X + in_wide
			widgets.tape.style.tfill.size[1] = math.max(0, wide - in_wide)
			widgets.tape.style.tinknob.offset[1] = definitions.TAPE_BAR_X + in_wide - 4
			if widgets.tape.style.inhot then
				widgets.tape.style.inhot.offset[1] = definitions.TAPE_BAR_X + in_wide - 10
			end
			widgets.tape.style.tknob.offset[1] = definitions.TAPE_BAR_X + wide - 4
			widgets.tape.content.at = frames > 0 and
				(pose.taping and "recording" or string.format("%ss - %ss / %ss",
					G.SK.num((from - 1) * tape.step), G.SK.num((at - 1) * tape.step), G.SK.num((frames - 1) * tape.step)))
				or ""
		end
	end
	show(widgets.button_pose_clip, poses and pose.anim ~= nil and pose.anim.event ~= nil)
	widgets.button_pose_clip.content.label = pose.frozen and "Save Held" or "Save Clip"
	for r = 1, SET_ROWS do
		local row = widgets["set_" .. r]
		local name = set_names[(self._set_top or 0) + r]

		local armed = name ~= nil and self._set_del ~= nil and sk_now() - (self._set_del_at or 0) < CLEAR_ASKS_FOR
			and string.find("," .. self._set_del .. ",", "," .. name .. ",", 1, true) ~= nil
		local loading = name ~= nil and self._set_load == name and sk_now() - (self._set_load_at or 0) < CLEAR_ASKS_FOR
		local del = widgets["button_set" .. r .. "_del"]
		local load = widgets["button_set" .. r .. "_load"]

		if row then
			show(row, sets and name ~= nil)
			row.content.name = self:_fit_to(row, "name", name or "", 16)
			row.content.ask = armed and "Press again to delete" or (loading and "Press again to load") or ""

			for _, button in ipairs({ armed and del or false, loading and load or false }) do
				if button then
					local c = button.style.face.color

					c[1], c[2], c[3], c[4] = 255, 192, 96, 78
				end
			end
			lit_row(row, name ~= nil, self:_sel_of("sets")[(self._set_top or 0) + r])

			for _, verb in ipairs({ "play", "load", "del" }) do
				show(widgets["button_set" .. r .. "_" .. verb], sets and name ~= nil)
			end

			show(widgets["button_set" .. r .. "_export"], sets and name ~= nil and not armed and not loading)
		end
	end

	do
		local bar = widgets.scroll_sets
		local most, thumb, _, at = self:_scroll_at(#set_names, SET_ROWS, definitions.KSCROLL_H, self._set_top or 0,
			definitions.KSCROLL_Y)

		show(bar, sets and most > 0)

		if bar and most > 0 then
			bar.style.thumb.size[2] = thumb
			bar.style.thumb.offset[2] = at
		end
	end

	widgets.button_play.content.label = pose.play and "Stop" or "Play"
	widgets.button_frames_clear.content.label = self._clear_armed and "Confirm" or "Clear"

	if self._clear_armed then
		local c = widgets.button_frames_clear.style.face.color

		c[1], c[2], c[3], c[4] = 255, 192, 96, 78
	end

	-- ───────────────────── ❀ ─────────────────────
	--  Keyframe Rows
	-- ───────────────────── ❀ ─────────────────────

	local tree = self:_frame_rows()

	for r = 1, KEY_ROWS do
		local entry = tree[self._frame_top + r]
		local i = entry and entry.frame
		local row = widgets["frame_" .. r]
		local frame = i and pose.frames[i]
		local on = frames and entry ~= nil

		show(row, on)

		if row and frame then
			local hold = frame.hold or 2
			local at = math.clamp(hold / HOLD_MAX, 0, 1) * HOLD_BAR_W
			row.style.name.offset[1] = definitions.NAME_X + (entry.inside and 14 or 0)
			row.style.name.size[1] = definitions.NAME_W - (entry.inside and 14 or 0)
			row.content.name = self:_fit_to(row, "name", string.format("%d  %s%s", i, frame.name, frame.anim and " ~" or ""), NAME_CHARS + 4)
			row.content.hold = self:_edit_text("hold", i, G.SK.num(hold) .. "s")
			row.style.hfill.size[1] = at
			row.style.hknob.offset[1] = definitions.HOLD_BAR_X + at - 5
		elseif row and entry and entry.head then
			local tail = string.format("  (%d)", entry.to - entry.from + 1)
			local tail_w = self._ui_renderer and text_w(self._ui_renderer, tail, row.style.name.font_size, row.style.name.font_type)
				or string.len(tail) * 7

			row.style.name.size[1] = definitions.NAME_W
			row.content.name = self:_fit(string.format("%s %s", entry.shut and "+" or "-", entry.head),
				definitions.NAME_W - tail_w, row.style.name.font_size, row.style.name.font_type,
				math.max(4, NAME_CHARS + 4 - string.len(tail))) .. tail
			row.content.hold = self:_edit_text("gtime", entry.head, G.SK.num(mod.group_time(entry.head) or 0) .. "s")
			row.style.name.offset[1] = definitions.NAME_X
			row.style.hfill.size[1] = 0
			row.style.hknob.offset[1] = -100
		elseif row then
			row.content.name = ""
			row.content.hold = ""
		end

		show(widgets["hot_hold_" .. r], frames and (frame ~= nil or (entry ~= nil and entry.head ~= nil)))

		local picked = frame and self:_sel_of("frames")[i]

		local lit = (frame and ((pose.play and pose.play.i == i) or self._chip == i)) or picked
		local face = row and row.style.face.color

		if face then
			face[1] = entry and 255 or 0
			face[2], face[3], face[4] = lit and 80 or 44, lit and 85 or 48, lit and 95 or 54
		end

		if row and row.style.sel then
			row.style.sel.color[1] = entry and lit and 255 or 0
		end

		for v = 1, #ROW_VERBS do
			show(widgets["button_row" .. r .. "_" .. ROW_VERBS[v]], frames and frame ~= nil)
		end
	end
end

-- ───────────────────── ❀ ─────────────────────
--  Closing
-- ───────────────────── ❀ ─────────────────────

SkeletonKeyPoseView.on_exit = function (self)
	do
		local G = rawget(_G, "__skeletonkey")

		self._gyro = false

		if G then
			pcall(G.SK.gyro_release)
		end
	end

	local widget = self._widgets_by_name.input

	if widget then
		self._field[self._tab] = widget.content.input_text or ""
		widget.content.is_writing = false
	end

	self._widgets_by_name.path_input.content.is_writing = false

	local G = rawget(_G, "__skeletonkey")

	if G then
		G.panel_at = { joint = self._joint, chip = self._chip, top = self._pose_top, frame_top = self._frame_top, field = self._field, shut = self._shut }
	end

	mod.panel_close(VIEW_NAME)

	SkeletonKeyPoseView.super.on_exit(self)
end

return SkeletonKeyPoseView
