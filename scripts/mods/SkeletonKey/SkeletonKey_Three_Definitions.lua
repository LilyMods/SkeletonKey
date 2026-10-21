local mod = get_mod("SkeletonKey")
local UIWidget = require("scripts/managers/ui/ui_widget")

local base = mod:io_dofile("SkeletonKey/scripts/mods/SkeletonKey/SkeletonKey_Pose_Definitions")

-- ───────────────────── ❀ ─────────────────────
--  Sizes & Colours
-- ───────────────────── ❀ ─────────────────────

local PAD = 14
local HEAD_H = 40

local LW = 400
local LH = 750
local ANIM_ROWS = 18
local ANIM_Y = 84
local ANIM_PITCH = 32
local TAPE_Y = ANIM_Y + ANIM_ROWS * ANIM_PITCH + 14
local TAPE_X = PAD + 10
local TAPE_W = LW - PAD * 2 - 20
local GH = 136

local CW = 70
local DW = 930
local DH = 200
local KW = 550
local SX = KW + PAD + 30
local SW = DW - SX - PAD
local KF_SLOTS = 8
local KF_X = 40
local KF_W = KW - 52
local KF_Y = 52
local KF_H = 60
local DROWS = 4
local DPITCH = 34
local GROWS = 3
local CHAT_LINES = 8
local DOCK_X = 24 + LW + 16 + CW + DW * 0.5 - 960


local GLASS = { 200, 22, 25, 30 }
local DEEP = { 255, 31, 34, 38 }
local ROW = { 255, 44, 48, 54 }
local LINE = { 255, 58, 63, 71 }
local INK = { 255, 236, 230, 216 }
local DIM = { 255, 141, 148, 160 }
local GOLD = { 255, 230, 220, 195 }
local RED = { 255, 192, 96, 78 }
local GREEN = { 255, 120, 190, 120 }

local scenegraph_definition = {}

for k, v in pairs(base.scenegraph_definition) do
	scenegraph_definition[k] = v
end

local widget_definitions = {}

for k, v in pairs(base.widget_definitions) do
	widget_definitions[k] = v
end

local function node(name, parent, h_align, v_align, size, position)
	scenegraph_definition[name] = {
		parent = parent,
		horizontal_alignment = h_align,
		vertical_alignment = v_align,
		size = size,
		position = position,
	}
end

node("sk3_left", "screen", "left", "top", { LW, LH }, { 24, 24, 10 })
node("sk3_dock", "screen", "center", "bottom", { DW, DH }, { DOCK_X, -24, 8 })
node("sk3_filter_box", "sk3_left", "left", "top", { 196, 30 }, { PAD, 44, 12 })
node("sk3_path_box", "sk3_left", "left", "top", { 296, 30 }, { PAD, 48, 12 })
node("sk3_name_box", "sk3_dock", "left", "top", { 110, 30 }, { 166, 10, 12 })
node("sk3_chat_box", "sk3_dock", "left", "top", { DW - PAD * 2 - 156 - 88, 30 }, { PAD + 156, DH - 42, 12 })
node("sk3_sheet", "sk3_dock", "left", "top", { DW, DH }, { 0, 0, 30 })

-- ───────────────────── ❀ ─────────────────────
--  Helpers
-- ───────────────────── ❀ ─────────────────────

local function copy(c)
	return { c[1], c[2], c[3], c[4] }
end

local function text(value, value_id, size, offset, color, font_size, align, font)
	return {
		pass_type = "text",
		value = value,
		value_id = value_id,
		style_id = value_id,
		style = {
			font_type = font or "proxima_nova_medium",
			font_size = font_size or 14,
			drop_shadow = false,
			text_vertical_alignment = "center",
			text_horizontal_alignment = align or "left",
			text_color = copy(color or INK),
			size = size,
			offset = offset,
		},
	}
end

local function rect(style_id, color, size, offset)
	return { pass_type = "rect", style_id = style_id, style = { color = copy(color), size = size, offset = offset } }
end

local function hotspot(w, h, x, y)
	return { pass_type = "hotspot", content_id = "hotspot", style = { size = { w, h }, offset = { x, y, 6 } } }
end

local function button(name, label, x, y, w, h, where, edge, size)
	widget_definitions[name] = UIWidget.create_definition({
		hotspot(w, h, x, y),
		rect("face", ROW, { w, h }, { x, y, 2 }),
		rect("edge", edge or LINE, { w, 1 }, { x, y + h - 1, 3 }),
		text(label, "label", { w, h }, { x, y, 5 }, INK, size or 14, "center"),
	}, where)
end

local function moved(def, where)
	local out = {}

	for k, v in pairs(def) do
		out[k] = v
	end

	out.scenegraph_id = where

	return out
end

local function grip_dots(passes, y0)
	for i = 0, 5 do
		passes[#passes + 1] = rect("dot" .. i, DIM, { 3, 3 }, { PAD - 2 + (i % 2) * 5, y0 + math.floor(i / 2) * 5, 3 })
	end

	return passes
end

local function plate(name, where, w, h, title, sub)
	widget_definitions[name] = UIWidget.create_definition(grip_dots({
		hotspot(w, h, 0, 0),
		rect("plate", GLASS, { w, h }, { 0, 0, 0 }),
		rect("grip_hint", { 0, 230, 220, 195 }, { w, HEAD_H }, { 0, 0, 1 }),
		text(title or "", "title", { 220, HEAD_H }, { PAD + 14, 0, 3 }, INK, 18, "left", "proxima_nova_bold"),
		text(sub or "", "sub", { 220, HEAD_H }, { PAD + 132, 0, 3 }, DIM, 12),
	}, 13), where)
end

-- ───────────────────── ❀ ─────────────────────
--  Strip
-- ───────────────────── ❀ ─────────────────────

local SKG = rawget(_G, "__skeletonkey")
local PHYS = SKG and SKG.SK and SKG.SK.phys

-- One row centred over the gap between the side panels, in her order:
-- markers, collision, then Hide and Unhide.
local TOOLS = {}
local SW_W = 6

for _, t in ipairs({
	{ "sk3_marks", "Show Hidden Markers", 180 }, PHYS and { "sk3_phys", "Include Collision", 150 } or false,
	{ "sk3_hide", "Hide", 70 }, { "sk3_unhide", "Unhide", 110 },
}) do
	if t then
		TOOLS[#TOOLS + 1] = { t[1], t[2], SW_W, 6, t[3] }
		SW_W = SW_W + t[3] + 6
	end
end

local STRIP_AT = { 24 + LW + 16 + (1920 - 24 - 440 - 16 - (24 + LW + 16)) * 0.5 - 960, 16 }

node("sk3_strip", "screen", "center", "top", { SW_W, 44 }, { STRIP_AT[1], STRIP_AT[2], 20 })

widget_definitions.sk3_strip_plate = UIWidget.create_definition({
	{ pass_type = "hotspot", content_id = "hotspot", style_id = "hotspot", style = { size = { SW_W, 44 }, offset = { 0, 0, 6 } } },
	rect("plate", GLASS, { SW_W, 44 }, { 0, 0, 0 }),
}, "sk3_strip")

for _, t in ipairs(TOOLS) do
	button(t[1], t[2], t[3], t[4], t[5], 32, "sk3_strip", nil, 14)
end

-- KEY and CHAT sit in a column at the dock's left end, outside its content.
for i, t in ipairs({ { "sk3_key", "KEY" }, { "sk3_chat", "CHAT" } }) do
	local h = (DH - 16 - 6) / 2

	button(t[1], t[2], -CW + 8, 8 + (i - 1) * (h + 6), CW - 16, h, "sk3_dock", nil, 14)
	TOOLS[#TOOLS + 1] = { t[1], t[2] }
end

-- ───────────────────── ❀ ─────────────────────
--  Key Sheet
-- ───────────────────── ❀ ─────────────────────

-- The panel's own sheet read back and laid out to cover the dock, its five
-- columns side by side, with the longer words cut down to fit.
local SHORT = {
	["Fly down, fly up"] = "Down, up", ["Fly at 2x speed"] = "2x speed", ["Pick a person or prop"] = "Pick someone",
	["Box-select many"] = "Box-select", ["Add to what you hold"] = "Add to held", ["Paste where you point"] = "Paste",
	["Pick a run of rows"] = "Run of rows", ["Change a bar's time"] = "Bar's time", ["Unhide, then rehide"] = "Unhide",
	["Show this sheet"] = "This sheet", ["Hide the panels"] = "Hide panels", ["Close the mod"] = "Close",
}

do
	local def = base.widget_definitions.keysheet

	-- The game's create_definition moves each pass's value into the
	-- definition's content table, so read it from there.
	local function value_of(id)
		for _, p in ipairs(def.passes) do
			if p.style_id == id or p.value_id == id then
				if p.value ~= nil then
					return p.value
				end

				return def.content and def.content[p.value_id or id]
			end
		end

		return nil
	end

	local col = (DW - 28) / 5
	local cap = 58
	local passes = {
		{ pass_type = "hotspot", content_id = "hotspot", style = { size = { DW, DH }, offset = { 0, 0, 6 } } },
		rect("plate", { 250, 27, 29, 33 }, { DW, DH }, { 0, 0, 20 }),
		rect("bar", GOLD, { DW, 2 }, { 0, 0, 21 }),
	}

	for c = 1, 5 do
		local x = 14 + (c - 1) * col
		local row = 0

		passes[#passes + 1] = text(value_of("head" .. c) or "", "head" .. c, { col, 20 }, { x, 8, 22 }, DIM, 12)

		for r = 1, 20 do
			local key, word = value_of("k" .. c .. "_" .. r), value_of("w" .. c .. "_" .. r)

			if key and not (c == 4 and (key == "Del" or key == "F2" or key == "RMB")) then
				local y = 30 + row * 21
				local w = math.min(cap, 12 + #key * 7)

				row = row + 1
				passes[#passes + 1] = rect("c" .. c .. "_" .. r, { 255, 20, 22, 25 }, { w, 17 }, { x, y + 2, 21 })
				passes[#passes + 1] = rect("e" .. c .. "_" .. r, LINE, { w, 2 }, { x, y + 17, 21 })
				passes[#passes + 1] = text(key, "k" .. c .. "_" .. r, { w, 21 }, { x, y, 22 }, INK, 12, "center")
				passes[#passes + 1] = text(SHORT[word] or word or "", "w" .. c .. "_" .. r, { col - cap - 8, 21 }, { x + cap + 6, y, 22 }, INK, 12)
			end
		end
	end

	widget_definitions.sk3_keysheet = UIWidget.create_definition(passes, "sk3_sheet")
end

-- ───────────────────── ❀ ─────────────────────
--  Animations
-- ───────────────────── ❀ ─────────────────────

plate("sk3_anim_plate", "sk3_left", LW, LH, "Animations", "the game's own")
widget_definitions.sk3_filter = moved(base.widget_definitions.input, "sk3_filter_box")
button("sk3_rest", "Rest", PAD + 202, 44, 62, 30, "sk3_left")
button("sk3_clip", "Save Clip", PAD + 270, 44, 102, 30, "sk3_left")

for r = 1, ANIM_ROWS do
	local y = ANIM_Y + (r - 1) * ANIM_PITCH

	widget_definitions["sk3_anim_" .. r] = UIWidget.create_definition({
		hotspot(LW - PAD * 2 - 60, 28, PAD, y),
		rect("face", ROW, { LW - PAD * 2, 28 }, { PAD, y, 2 }),
		text("", "name", { 230, 28 }, { PAD + 10, y, 5 }, INK, 14),
		text("", "source", { 70, 28 }, { PAD + 244, y, 5 }, DIM, 12),
	}, "sk3_left")
	button("sk3_anim" .. r .. "_play", "Play", LW - PAD - 54, y + 2, 50, 24, "sk3_left", nil, 12)
end

widget_definitions.sk3_anim_empty = UIWidget.create_definition({
	text("", "line1", { LW - PAD * 2, 24 }, { PAD, ANIM_Y + 4, 3 }, INK, 14),
	text("", "line2", { LW - PAD * 2, 20 }, { PAD, ANIM_Y + 28, 3 }, DIM, 12),
}, "sk3_left")

-- Green is where keying starts and red where it stops; the stretch between
-- is green going forward and red going back.
widget_definitions.sk3_tape = UIWidget.create_definition({
	hotspot(TAPE_W + 20, 28, TAPE_X - 10, TAPE_Y),
	{ pass_type = "hotspot", content_id = "inhot", style_id = "inhot", style = { size = { 20, 28 }, offset = { TAPE_X - 10, TAPE_Y, 8 } } },
	rect("track", LINE, { TAPE_W, 5 }, { TAPE_X, TAPE_Y + 12, 2 }),
	rect("fill", GREEN, { 0, 5 }, { TAPE_X, TAPE_Y + 12, 3 }),
	rect("inknob", GREEN, { 8, 18 }, { TAPE_X - 4, TAPE_Y + 5, 4 }),
	rect("knob", RED, { 8, 18 }, { TAPE_X - 4, TAPE_Y + 5, 5 }),
	text("", "label", { TAPE_W, 16 }, { TAPE_X, TAPE_Y - 16, 3 }, { 255, 205, 200, 188 }, 12, "right"),
}, "sk3_left")

button("sk3_keyrange", "Key Range", PAD, TAPE_Y + 36, 120, 26, "sk3_left", nil, 14)
button("sk3_keyframe", "Key Frame", LW - PAD - 120, TAPE_Y + 36, 120, 26, "sk3_left", nil, 14)

-- ───────────────────── ❀ ─────────────────────
--  Get a Prop
-- ───────────────────── ❀ ─────────────────────

plate("sk3_get_plate", "sk3_left", LW, GH, "Get a Prop")
widget_definitions.sk3_path = moved(base.widget_definitions.path_input, "sk3_path_box")
button("sk3_spawn", "Spawn", PAD + 302, 48, LW - PAD * 2 - 302, 30, "sk3_left")
widget_definitions.sk3_get_hint = UIWidget.create_definition({
	text("Or click one in the world.", "line1", { LW - PAD * 2, 18 }, { PAD, 86, 3 }, DIM, 12),
	text("Ctrl+V pastes a copy where you look.", "line2", { LW - PAD * 2, 18 }, { PAD, 104, 3 }, DIM, 12),
}, "sk3_left")

-- ───────────────────── ❀ ─────────────────────
--  Dock
-- ───────────────────── ❀ ─────────────────────

widget_definitions.sk3_dock_plate = UIWidget.create_definition(grip_dots({
	hotspot(DW + CW, DH, -CW, 0),
	rect("plate", GLASS, { DW + CW, DH }, { -CW, 0, 0 }),
	rect("grip_hint", { 0, 230, 220, 195 }, { 160, HEAD_H + 10 }, { 0, 0, 1 }),
	rect("column", LINE, { 1, DH - 24 }, { 0, 12, 1 }),
	rect("split", LINE, { 1, DH - 24 }, { SX - 14, 12, 1 }),
	text("", "left", { 160, HEAD_H }, { PAD + 14, 5, 3 }, INK, 18, "left", "proxima_nova_bold"),
	text("", "sub", { 262, HEAD_H }, { PAD + 90, 5, 3 }, DIM, 12),
	text("", "right", { 160, HEAD_H }, { SX, 5, 3 }, INK, 18, "left", "proxima_nova_bold"),
}, 18), "sk3_dock")

widget_definitions.sk3_name = moved(base.widget_definitions.input, "sk3_name_box")
button("sk3_save", "Save Pose", 282, 10, 90, 30, "sk3_dock", GOLD)
button("sk3_play", "Play", 378, 10, 56, 30, "sk3_dock")
button("sk3_loop", "Loop", 440, 10, 56, 30, "sk3_dock")
button("sk3_kclear", "Clear", 502, 10, KW + PAD - 502, 30, "sk3_dock", RED)
button("sk3_kprev", "<", PAD, KF_Y, 22, KF_H, "sk3_dock")
button("sk3_knext", ">", KW + PAD - 22, KF_Y, 22, KF_H, "sk3_dock")

for k = 1, KF_SLOTS do
	widget_definitions["sk3_kf_" .. k] = UIWidget.create_definition({
		{ pass_type = "hotspot", content_id = "hotspot", style_id = "hotspot", style = { size = { 60, KF_H }, offset = { KF_X, KF_Y, 6 } } },
		rect("face", { 255, 52, 55, 60 }, { 60, KF_H }, { KF_X, KF_Y, 2 }),
		rect("start", GOLD, { 2, KF_H }, { KF_X, KF_Y, 3 }),
		rect("top", { 0, 230, 220, 195 }, { 60, 1 }, { KF_X, KF_Y, 4 }),
		rect("bottom", { 0, 230, 220, 195 }, { 60, 1 }, { KF_X, KF_Y + KF_H - 1, 4 }),
		text("", "name", { 60, 20 }, { KF_X + 8, KF_Y + 10, 5 }, INK, 14),
		text("", "hold", { 60, 18 }, { KF_X + 8, KF_Y + 32, 5 }, DIM, 12, "left", "machine_medium"),
	}, "sk3_dock")
end

widget_definitions.sk3_kinfo = UIWidget.create_definition({
	text("", "label", { 220, 26 }, { PAD, 122, 3 }, INK, 14, "left", "proxima_nova_bold"),
	text("Wheel on a bar changes its time.", "hint", { 270, 26 }, { KW + PAD - 270, 122, 3 }, DIM, 12, "right"),
	text("", "empty", { KF_W, 24 }, { KF_X + 8, KF_Y + 6, 3 }, INK, 14),
	text("", "empty2", { KF_W, 20 }, { KF_X + 8, KF_Y + 30, 3 }, DIM, 12),
}, "sk3_dock")

button("sk3_kupdate", "Replace", 240, 122, 66, 26, "sk3_dock", nil, 12)
button("sk3_kdel", "×", 312, 122, 28, 26, "sk3_dock", RED, 14)
button("sk3_setsave", "Save Keyframes As Set", DW - PAD - 176, 10, 176, 30, "sk3_dock", nil, 12)

for r = 1, DROWS do
	local y = 48 + (r - 1) * DPITCH

	widget_definitions["sk3_set_" .. r] = UIWidget.create_definition({
		hotspot(120, 30, SX, y),
		rect("face", ROW, { SW, 30 }, { SX, y, 2 }),
		text("", "name", { 112, 30 }, { SX + 10, y, 5 }, INK, 14),
	}, "sk3_dock")
	button("sk3_set" .. r .. "_play", "Play", SX + 126, y + 3, 42, 24, "sk3_dock", nil, 12)
	button("sk3_set" .. r .. "_load", "Load", SX + 172, y + 3, 44, 24, "sk3_dock", nil, 12)
	button("sk3_set" .. r .. "_export", "Export", SX + 220, y + 3, 56, 24, "sk3_dock", nil, 12)
	button("sk3_set" .. r .. "_del", "×", SX + SW - 30, y + 3, 26, 24, "sk3_dock", RED, 14)
end

widget_definitions.sk3_dempty = UIWidget.create_definition({
	text("", "line1", { SW, 24 }, { SX, 52, 3 }, INK, 14),
	text("", "line2", { SW, 20 }, { SX, 76, 3 }, DIM, 12),
}, "sk3_dock")

button("sk3_holdall", "Hold All", 370, 10, 80, 30, "sk3_dock", nil, 12)
button("sk3_grpsave", "Save As Group", 456, 10, KW + PAD - 456, 30, "sk3_dock", nil, 12)

for r = 1, DROWS do
	local y = 48 + (r - 1) * DPITCH

	widget_definitions["sk3_item_" .. r] = UIWidget.create_definition({
		hotspot(KW, 30, PAD, y),
		rect("face", ROW, { KW, 30 }, { PAD, y, 2 }),
		rect("held", { 0, 230, 220, 195 }, { 2, 30 }, { PAD, y, 3 }),
		rect("dot", { 255, 215, 205, 176 }, { 7, 7 }, { PAD + 12, y + 11.5, 3 }),
		text("", "name", { 250, 30 }, { PAD + 28, y, 5 }, INK, 14),
		text("", "kind", { 120, 30 }, { PAD + 284, y, 5 }, DIM, 12),
		text("", "away", { 60, 30 }, { PAD + 420, y, 5 }, DIM, 12, "right"),
	}, "sk3_dock")
	button("sk3_item" .. r .. "_x", "×", PAD + KW - 30, y + 3, 26, 24, "sk3_dock", RED, 14)
end

for r = 1, GROWS do
	local y = 48 + (r - 1) * DPITCH

	widget_definitions["sk3_grp_" .. r] = UIWidget.create_definition({
		hotspot(200, 30, SX, y),
		rect("face", ROW, { SW, 30 }, { SX, y, 2 }),
		rect("sel", { 0, 230, 220, 195 }, { 2, 30 }, { SX, y, 3 }),
		rect("dot", { 0, GREEN[2], GREEN[3], GREEN[4] }, { 7, 7 }, { SX + 10, y + 11.5, 4 }),
		text("", "name", { 150, 30 }, { SX + 24, y, 5 }, INK, 14),
	}, "sk3_dock")
	button("sk3_grp" .. r .. "_load", "Load", SX + SW - 114, y + 3, 62, 24, "sk3_dock", nil, 12)
	button("sk3_grp" .. r .. "_save", "Save", SX + SW - 48, y + 3, 46, 24, "sk3_dock", nil, 12)
end

do
	local w = (SW - 16) / 3
	local y = DH - 12 - 28

	button("sk3_merge", "Merge", SX, y, w, 28, "sk3_dock", nil, 12)
	button("sk3_export", "Export", SX + w + 8, y, w, 28, "sk3_dock", nil, 12)
	button("sk3_folder", "Folder", SX + (w + 8) * 2, y, w, 28, "sk3_dock", nil, 12)
end

-- ───────────────────── ❀ ─────────────────────
--  Chat
-- ───────────────────── ❀ ─────────────────────

for i = 1, CHAT_LINES do
	widget_definitions["sk3_chat_line_" .. i] = UIWidget.create_definition({
		text("", "label", { DW - PAD * 2 - 16, 17 }, { PAD + 16, 8 + (i - 1) * 18, 3 }, INK, 12),
	}, "sk3_dock")
end

widget_definitions.sk3_chat_in = moved(base.widget_definitions.input, "sk3_chat_box")
button("sk3_chat_ch", "", PAD, DH - 42, 150, 30, "sk3_dock", nil, 12)
button("sk3_chat_send", "Send", DW - PAD - 82, DH - 42, 82, 30, "sk3_dock", GOLD, 14)

local out = {}

for k, v in pairs(base) do
	out[k] = v
end

out.scenegraph_definition = scenegraph_definition
out.widget_definitions = widget_definitions
out.THREE = {
	TOOLS = TOOLS,
	TAPE_X = TAPE_X,
	TAPE_W = TAPE_W,
	STRIP_AT = STRIP_AT,
	STRIP_W = SW_W,
	LW = LW,
	LH = LH,
	GH = GH,
	DW = DW,
	DH = DH,
	ANIM_ROWS = ANIM_ROWS,
	KF_SLOTS = KF_SLOTS,
	KF_X = KF_X,
	KF_W = KF_W,
	KF_Y = KF_Y,
	KF_H = KF_H,
	DROWS = DROWS,
	GROWS = GROWS,
	LEFT_AT = { 24, 24 },
	DOCK_AT = { DOCK_X, -24 },
	CW = CW,
	CHAT_LINES = CHAT_LINES,
	GLASS_ALPHA = GLASS[1],
}

return out
