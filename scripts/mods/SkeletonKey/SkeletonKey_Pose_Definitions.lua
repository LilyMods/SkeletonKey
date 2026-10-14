local UIWidget = require("scripts/managers/ui/ui_widget")
local UIWorkspaceSettings = require("scripts/settings/ui/ui_workspace_settings")
local TextInputPassTemplates = require("scripts/ui/pass_templates/text_input_pass_templates")

-- ───────────────────── ❀ ─────────────────────
--  Sizes & Colours
-- ───────────────────── ❀ ─────────────────────

local W = 440
local PAD = 14
local TITLE_H = 40
local TOOL_H = 34
local TOOL_Y = TITLE_H
local TOOL2_Y = TOOL_Y + TOOL_H + 6
local STATUS_H = 22

local TAB_Y = TOOL2_Y + TOOL_H + 6
local TAB_H = 30
local LIST_Y = TAB_Y + TAB_H
local ROW_H = 26
local ROW_PITCH = 29
local JOINT_ROWS = 20
local CHART_W = 140
local LIST_H = PAD + JOINT_ROWS * ROW_PITCH - 3 + PAD
local DIAL_Y = LIST_Y + LIST_H + 10
local AXES = { "x", "y", "z" }
local AXIS_Y = DIAL_Y + 56
local AXIS_PITCH = 36
local JZERO_Y = AXIS_Y + AXIS_PITCH * 3 - 6
local BAR_X = PAD * 2 + 26
local BAR_W = W - BAR_X - PAD * 2 - 70
local BAR_H = 6
local DIAL_H = 56 + AXIS_PITCH * 3 + 40
local FOOT_H = 24
local H = DIAL_Y + DIAL_H + PAD + FOOT_H
local FOOT_Y = H - FOOT_H
local KEY_PITCH = 34
local KEY_Y = LIST_Y + PAD + 30 + 34
local HOLD_BAR_X = 108
local HOLD_BAR_W = 108
local HOLD_MAX = 5
local KEY_ROWS = math.floor((H - FOOT_H - KEY_Y - PAD) / KEY_PITCH)
local FRAME_Y = LIST_Y

local BG = { 245, 27, 29, 33 }
local PANEL = { 255, 35, 38, 43 }
local ROW = { 255, 44, 48, 54 }
local LINE = { 255, 58, 63, 71 }
local INK = { 255, 236, 230, 216 }
local DIM = { 255, 141, 148, 160 }
local GOLD = { 255, 230, 220, 195 }
local RED = { 255, 192, 96, 78 }
local GREEN = { 255, 120, 190, 120 }

local NOTE_W = 574
local NOTE_H = 40
local NOTE_TAG = 54

local OW = 330
local OBJ_Y = 104
local CELL_H = 30
local CELL_GAP = 6
local CELL_X = PAD * 2 + 22
local CELL_W = (OW - PAD * 4 - 22 - 8) / 2
local SCALE_Y = OBJ_Y + (CELL_H + CELL_GAP) * 3 + 26
local OBJ_DIALS_B = SCALE_Y + CELL_H + 10
local OBJ_BTN_Y = OBJ_DIALS_B + 12
local OBJ_SAY_Y = OBJ_BTN_Y + 3 * (34 + 6) + 6
local OH = OBJ_SAY_Y + 22 + PAD
local EMPTY_LAST_Y = OBJ_Y + 46
local OBJ_EMPTY_H = EMPTY_LAST_Y + 20 + 10 - (OBJ_Y - 34)
local OBJ_EMPTY_BTN_Y = OBJ_Y - 34 + OBJ_EMPTY_H + 12

-- ───────────────────── ❀ ─────────────────────
--  Scenegraph
-- ───────────────────── ❀ ─────────────────────

local scenegraph_definition = {
	screen = UIWorkspaceSettings.screen,
	pose = {
		parent = "screen",
		horizontal_alignment = "right",
		vertical_alignment = "center",
		size = { W, H },
		position = { -24, 0, 10 },
	},
	objkey = {
		parent = "screen",
		horizontal_alignment = "left",
		vertical_alignment = "center",
		size = { OW, OH },
		position = { 24, 0, 10 },
	},
	hidebar = {
		parent = "screen",
		horizontal_alignment = "center",
		vertical_alignment = "top",
		size = { 260, 70 },
		position = { 0, 16, 20 },
	},
	gyro = {
		parent = "screen",
		horizontal_alignment = "left",
		vertical_alignment = "top",
		size = { 1, 1 },
		position = { 0, 0, 40 },
	},
	corner = {
		parent = "screen",
		horizontal_alignment = "left",
		vertical_alignment = "bottom",
		size = { 1, 1 },
		position = { 0, 0, 30 },
	},
	marquee = {
		parent = "screen",
		horizontal_alignment = "left",
		vertical_alignment = "top",
		size = { 1, 1 },
		position = { 0, 0, 30 },
	},
	name = {
		parent = "pose",
		horizontal_alignment = "left",
		vertical_alignment = "top",
		size = { 176, 30 },
		position = { PAD * 2, LIST_Y + PAD, 12 },
	},
	rename = {
		parent = "screen",
		horizontal_alignment = "center",
		vertical_alignment = "center",
		size = { 300, 110 },
		position = { 0, 0, 40 },
	},
	rename_field = {
		parent = "rename",
		horizontal_alignment = "left",
		vertical_alignment = "top",
		size = { 272, 30 },
		position = { 14, 50, 41 },
	},
	path_field = {
		parent = "objkey",
		horizontal_alignment = "left",
		vertical_alignment = "top",
		size = { OW - PAD * 4 - 68, 28 },
		position = { PAD * 2, 0, 12 },
	},
	note = {
		parent = "screen",
		horizontal_alignment = "center",
		vertical_alignment = "bottom",
		size = { NOTE_W, NOTE_H },
		position = { 0, -40, 10 },
	},
}

-- ───────────────────── ❀ ─────────────────────
--  Panel Base
-- ───────────────────── ❀ ─────────────────────

local widget_definitions = {}

local function text(value, value_id, size, offset, color, font_size, align, font)
	return {
		pass_type = "text",
		value = value,
		value_id = value_id,
		style_id = value_id,
		style = {
			font_type = font or "proxima_nova_medium",
			font_size = font_size or 15,
			drop_shadow = false,
			text_vertical_alignment = "center",
			text_horizontal_alignment = align or "left",
			text_color = color or INK,
			size = size,
			offset = offset,
		},
	}
end

local function rect(style_id, color, size, offset)
	return { pass_type = "rect", style_id = style_id, style = { color = color, size = size, offset = offset } }
end

widget_definitions.plate = UIWidget.create_definition({
	{
		pass_type = "hotspot",
		content_id = "hotspot",
		style = { size = { W, H }, offset = { 0, 0, 0 } },
	},
	rect("plate", BG, { W, H }, { 0, 0, 0 }),
	rect("list", PANEL, { W - PAD * 2, LIST_H }, { PAD, LIST_Y, 1 }),
	rect("dials", PANEL, { W - PAD * 2, DIAL_H }, { PAD, DIAL_Y, 1 }),
	rect("frames", PANEL, { W - PAD * 2, H - LIST_Y - PAD - FOOT_H }, { PAD, FRAME_Y, 1 }),
	text("SKELETON KEY", "title", { 200, TITLE_H }, { PAD, 0, 3 }, GOLD, 18, "left", "machine_medium"),
	rect("foot", { 255, 24, 26, 30 }, { W, FOOT_H }, { 0, FOOT_Y, 1 }),
	rect("foot_edge", LINE, { W, 1 }, { 0, FOOT_Y, 2 }),
	text("", "reply", { W - PAD * 2, FOOT_H }, { PAD, FOOT_Y, 3 }, INK, 12),
	text("", "target", { 200, TITLE_H }, { W - PAD - 200, 0, 3 }, { 255, 236, 230, 216 }, 14, "right"),
	text("", "joint", { 300, 28 }, { PAD * 2, DIAL_Y + PAD - 2, 3 }, INK, 14, "left", "proxima_nova_bold"),

	text("", "empty", { W - PAD * 4, 24 }, { PAD * 2, LIST_Y + PAD + 60, 3 }, INK, 14, "left"),
	text("", "empty2", { W - PAD * 4, 20 }, { PAD * 2, LIST_Y + PAD + 86, 3 }, DIM, 12, "left"),
	text("", "col_name", { 150, 20 }, { PAD * 2 + 10, KEY_Y - 22, 3 }, DIM, 12),
	text("", "col_hold", { 60, 20 }, { PAD * 2 + 160, KEY_Y - 22, 3 }, DIM, 12, "right"),
}, "pose")

local function button(name, label, x, y, w, h, edge, node)
	widget_definitions["button_" .. name] = UIWidget.create_definition({
		{
			pass_type = "hotspot",
			content_id = "hotspot",
			style = { size = { w, h }, offset = { x, y, 4 } },
		},
		rect("face", { ROW[1], ROW[2], ROW[3], ROW[4] }, { w, h }, { x, y, 2 }),
		rect("edge", edge or LINE, { w, 1 }, { x, y + h - 1, 3 }),
		text(label, "label", { w, h }, { x, y, 5 }, INK, 14, "center"),
	}, node or "pose")
end

local function tab(name, label, x, y, w, h)
	widget_definitions["button_tab_" .. name] = UIWidget.create_definition({
		{
			pass_type = "hotspot",
			content_id = "hotspot",
			style = { size = { w, h }, offset = { x, y, 4 } },
		},
		rect("face", { 255, BG[2], BG[3], BG[4] }, { w, h }, { x, y, 2 }),
		rect("sel", { 0, GOLD[2], GOLD[3], GOLD[4] }, { w, 3 }, { x, y, 3 }),
		text(label, "label", { w, h }, { x, y, 5 }, DIM, 14, "center"),
	}, "pose")
end

widget_definitions.grip = UIWidget.create_definition({
	{
		pass_type = "hotspot",
		content_id = "hotspot",
		style = { size = { W, TITLE_H }, offset = { 0, 0, 4 } },
	},
	rect("hint", { 0, 230, 220, 195 }, { W, TITLE_H }, { 0, 0, 1 }),
	text("Drag to move", "label", { 100, TITLE_H }, { W - PAD - 100, 0, 3 }, { 0, 141, 148, 160 }, 12, "right"),
}, "pose")

widget_definitions.obj_grip = UIWidget.create_definition({
	{
		pass_type = "hotspot",
		content_id = "hotspot",
		style = { size = { OW, 34 }, offset = { 0, 0, 4 } },
	},
	rect("hint", { 0, 230, 220, 195 }, { OW, 34 }, { 0, 0, 1 }),
	text("Drag to move", "label", { 100, 34 }, { OW - PAD - 100, 0, 3 }, { 0, 141, 148, 160 }, 12, "right"),
}, "objkey")

-- ───────────────────── ❀ ─────────────────────
--  Overlays
-- ───────────────────── ❀ ─────────────────────

widget_definitions.marquee = UIWidget.create_definition({
	rect("fill", { 40, 230, 220, 195 }, { 1, 1 }, { 0, 0, 1 }),
	rect("top", GOLD, { 1, 1 }, { 0, 0, 2 }),
	rect("bottom", GOLD, { 1, 1 }, { 0, 0, 2 }),
	rect("left", GOLD, { 1, 1 }, { 0, 0, 2 }),
	rect("right", GOLD, { 1, 1 }, { 0, 0, 2 }),
}, "marquee")

local GYRO_RINGS = 18
local GYRO_LINE = 3
local GYRO_RIB = 2
local GYRO_HEAD = 11
local GYRO_AXIS = { { 255, 235, 205, 90 }, { 255, 110, 160, 235 }, { 255, 215, 90, 80 } }
local GYRO_FLAT = "content/ui/materials/backgrounds/default_square"

local function turned(style_id, color, w, h, z)
	return {
		pass_type = "rotated_texture",
		value = GYRO_FLAT,
		style_id = style_id,
		style = {
			color = { color[1], color[2], color[3], color[4] },
			size = { w, h },
			offset = { 0, 0, z },
			angle = 0,
			pivot = { 0, h * 0.5 },
		},
	}
end

do
	local passes = {}

	for r = 1, 3 do
		for d = 1, GYRO_RINGS do
			passes[#passes + 1] = turned(string.format("r%d_%d", r, d), GYRO_AXIS[r], 1, GYRO_RIB, 2)
		end
	end

	for a = 1, 3 do
		passes[#passes + 1] = turned("a" .. a, GYRO_AXIS[a], 1, GYRO_LINE, 3)
	end

	for a = 1, 3 do
		passes[#passes + 1] = turned("h" .. a, GYRO_AXIS[a], 1, GYRO_HEAD, 4)
	end

	widget_definitions.gyro = UIWidget.create_definition(passes, "gyro")
end

widget_definitions.held_path = UIWidget.create_definition({
	text("", "label", { 1600, 14 }, { 12, -22, 3 }, DIM, 12, "left"),
}, "corner")

-- ───────────────────── ❀ ─────────────────────
--  Key Sheet
-- ───────────────────── ❀ ─────────────────────

local SKG = rawget(_G, "__skeletonkey")
local PHYS = SKG and SKG.SK and SKG.SK.phys
local KEY_ROW_W = NOTE_TAG + 8 + 200 + (PHYS and 8 + NOTE_TAG or 0)
local KEY_ROW_X = (NOTE_W - KEY_ROW_W) * 0.5

widget_definitions.note = UIWidget.create_definition({
	{
		pass_type = "hotspot",
		content_id = "hotspot",
		style = { size = { NOTE_TAG, NOTE_H }, offset = { KEY_ROW_X, 0, 4 } },
	},
	rect("tag", { 255, 26, 24, 22 }, { NOTE_TAG, NOTE_H }, { KEY_ROW_X, 0, 1 }),
	rect("bar", { 255, 230, 220, 195 }, { NOTE_TAG, 2 }, { KEY_ROW_X, 0, 2 }),
	text("KEY", "tag_text", { NOTE_TAG, NOTE_H }, { KEY_ROW_X, 0, 3 }, DIM, 14,
		"center", "machine_medium"),
}, "note")

button("marks", "Show Hidden Markers", KEY_ROW_X + NOTE_TAG + 8, 0, 200, NOTE_H, nil, "note")

if PHYS then
	widget_definitions.button_phys = PHYS.widget(UIWidget, rect, text, KEY_ROW_X + NOTE_TAG + 216, NOTE_TAG, NOTE_H)
end

local SHEET = {
	{ "CAMERA", { { "RMB", "Hold to fly" }, { "WASD", "Fly about" }, { "Q, E", "Fly down, fly up" },
		{ "Wheel", "Flight speed" }, { "Shift", "Fly at 2x speed" } } },
	{ "SELECT", { { "LMB", "Pick a person or prop" }, { "Drag", "Box-select many" }, { "Ctrl+LMB", "Add to what you hold" },
		{ "Ctrl+A", "Hold All" } } },
	{ "OBJECT", { { "S", "Save Item" }, { "L", "Lock" }, { "R", "Reset" }, { "C", "Clear Target" }, { "Ctrl+C", "Copy" },
		{ "Ctrl+V", "Paste where you point" }, { "Ctrl+Z", "Undo" } } },
	{ "LISTS", { { "Shift+LMB", "Pick a run of rows" }, { "Del", "Delete picked rows" }, { "F2", "Rename picked row" },
		{ "RMB", "Folder menu" }, { "Wheel", "Change a bar's time" } } },
	{ "SCREEN", { { "H", "Hide selected" }, { "U", "Unhide, then rehide" }, { "K", "Show this sheet" },
		{ "Esc", "Hide the panels" }, { "Esc x2", "Close the mod" } } },
}
local SHEET_ROW = 21
local SHEET_KEY = 72
local SHEET_LABEL = 136
local SHEET_COL = SHEET_KEY + 8 + SHEET_LABEL
local SHEET_ROWS = 0

for c = 1, #SHEET do
	SHEET_ROWS = math.max(SHEET_ROWS, #SHEET[c][2])
end

local SHEET_W = SHEET_COL * #SHEET + 28
local SHEET_H = 14 + 24 + SHEET_ROWS * SHEET_ROW + 12
local SHEET_X = (NOTE_W - SHEET_W) * 0.5
local SHEET_Y = -SHEET_H - 8

do
	local passes = {
		rect("plate", BG, { SHEET_W, SHEET_H }, { SHEET_X, SHEET_Y, 20 }),
		rect("bar", GOLD, { SHEET_W, 2 }, { SHEET_X, SHEET_Y, 21 }),
	}

	for c = 1, #SHEET do
		local x = SHEET_X + 14 + (c - 1) * SHEET_COL
		local col = SHEET[c]

		if c > 1 then
			passes[#passes + 1] = rect("rule" .. c, LINE, { 1, SHEET_H - 28 }, { x - 10, SHEET_Y + 14, 21 })
		end

		passes[#passes + 1] = text(col[1], "head" .. c, { SHEET_COL, 20 }, { x, SHEET_Y + 12, 22 }, DIM, 12, "left")

		for r = 1, #col[2] do
			local row = col[2][r]
			local y = SHEET_Y + 12 + 24 + (r - 1) * SHEET_ROW

			local cap = math.min(SHEET_KEY - 6, 12 + #row[1] * 7)

			passes[#passes + 1] = rect("c" .. c .. "_" .. r, { 255, 20, 22, 25 }, { cap, SHEET_ROW - 4 }, { x, y + 2, 21 })
			passes[#passes + 1] = rect("e" .. c .. "_" .. r, LINE, { cap, 2 }, { x, y + SHEET_ROW - 4, 21 })
			passes[#passes + 1] = text(row[1], "k" .. c .. "_" .. r, { cap, SHEET_ROW }, { x, y, 22 }, INK, 12, "center")
			passes[#passes + 1] = text(row[2], "w" .. c .. "_" .. r, { SHEET_LABEL, SHEET_ROW },
				{ x + SHEET_KEY, y, 22 }, INK, 12, "left")
		end
	end

	widget_definitions.keysheet = UIWidget.create_definition(passes, "note")
end

-- ───────────────────── ❀ ─────────────────────
--  Tabs
-- ───────────────────── ❀ ─────────────────────

local TAB_W = (W - PAD * 2 - 18) / 4
tab("poses", "Animations", PAD, TAB_Y, TAB_W, TAB_H)
tab("joints", "Pose", PAD + (TAB_W + 6), TAB_Y, TAB_W, TAB_H)
tab("frames", "Keyframes", PAD + (TAB_W + 6) * 2, TAB_Y, TAB_W, TAB_H)
tab("sets", "Sets", PAD + (TAB_W + 6) * 3, TAB_Y, TAB_W, TAB_H)

local function hot(name, x, y, w, h, node)
	widget_definitions["hot_" .. name] = UIWidget.create_definition({
		{
			pass_type = "hotspot",
			content_id = "hotspot",
			style = { size = { w, h }, offset = { x, y, 6 } },
		},
	}, node or "pose")
end

-- ───────────────────── ❀ ─────────────────────
--  Animations Page
-- ───────────────────── ❀ ─────────────────────

local POSE_Y = LIST_Y + PAD + 30 + 12
local POSE_ROWS = math.floor((H - FOOT_H - POSE_Y - PAD) / KEY_PITCH) - 1
local TAPE_Y = POSE_Y + POSE_ROWS * KEY_PITCH
local TAPE_BAR_X = PAD * 2 + 72
local TAPE_BAR_W = W - PAD * 4 - 72 - 202

for r = 1, POSE_ROWS do
	local x = PAD * 2
	local y = POSE_Y + (r - 1) * KEY_PITCH
	local w = W - PAD * 4

	widget_definitions["pose_" .. r] = UIWidget.create_definition({
		rect("face", { ROW[1], ROW[2], ROW[3], ROW[4] }, { w, 28 }, { x, y, 2 }),
		text("", "name", { 170, 28 }, { x + 10, y, 5 }, INK, 14),
		text("", "breed", { 76, 28 }, { x + 186, y, 5 }, DIM, 12),
	}, "pose")

	button("pose" .. r .. "_play", "Play", x + w - 52, y + 2, 46, 24)
end

button("pose_rest", "Rest", PAD * 2 + 190, LIST_Y + PAD, 60, 30)

button("pose_clip", "Save Clip", PAD * 2 + 256, LIST_Y + PAD, 100, 30)

button("tape_back", "<", PAD * 2, TAPE_Y + 2, 30, 24)
button("tape_on", ">", PAD * 2 + 34, TAPE_Y + 2, 30, 24)
button("tape_keyto", "Key To", W - PAD * 2 - 116, TAPE_Y + 2, 56, 24)
button("tape_key", "Key", W - PAD * 2 - 54, TAPE_Y + 2, 54, 24)

widget_definitions.tape = UIWidget.create_definition({
	{
		pass_type = "hotspot",
		content_id = "hotspot",
		style = { size = { TAPE_BAR_W, 28 }, offset = { TAPE_BAR_X, TAPE_Y, 4 } },
	},
	rect("ttrack", LINE, { TAPE_BAR_W, 5 }, { TAPE_BAR_X, TAPE_Y + 12, 3 }),
	{
		pass_type = "hotspot",
		content_id = "inhot",
		style_id = "inhot",
		style = { size = { 20, 28 }, offset = { TAPE_BAR_X - 10, TAPE_Y, 8 } },
	},
	rect("tcut", { 255, 60, 62, 70 }, { 0, 5 }, { TAPE_BAR_X, TAPE_Y + 12, 4 }),
	rect("tfill", GOLD, { 0, 5 }, { TAPE_BAR_X, TAPE_Y + 12, 5 }),
	rect("tinknob", GREEN, { 8, 18 }, { TAPE_BAR_X - 4, TAPE_Y + 5, 6 }),
	rect("tknob", RED, { 8, 18 }, { TAPE_BAR_X - 4, TAPE_Y + 5, 7 }),
	text("", "at", { TAPE_BAR_X + TAPE_BAR_W - PAD * 2, 18 }, { PAD * 2, TAPE_Y + 28, 5 }, DIM, 12, "right"),
}, "pose")

local SCROLL_X = W - PAD - 12
local SCROLL_W = 6
local SCROLL_Y = POSE_Y
local SCROLL_H = POSE_ROWS * KEY_PITCH - (KEY_PITCH - 28)

-- ───────────────────── ❀ ─────────────────────
--  Folder Menu
-- ───────────────────── ❀ ─────────────────────

local MENU_W = 120
local MENU_X = W - PAD * 2 - MENU_W - 12

widget_definitions.menu_face = UIWidget.create_definition({
	rect("face", { 255, 35, 38, 43 }, { MENU_W, 3 * 26 + 8 }, { MENU_X, 0, 30 }),
	rect("edge", GOLD, { MENU_W, 2 }, { MENU_X, 0, 31 }),
}, "pose")

local function menu_button(name, label, y, edge)
	local x, w, h = MENU_X + 4, MENU_W - 8, 24

	widget_definitions["button_" .. name] = UIWidget.create_definition({
		{
			pass_type = "hotspot",
			content_id = "hotspot",
			style = { size = { w, h }, offset = { x, y, 34 } },
		},
		rect("face", { ROW[1], ROW[2], ROW[3], ROW[4] }, { w, h }, { x, y, 32 }),
		rect("edge", edge or LINE, { w, 1 }, { x, y + h - 1, 33 }),
		text(label, "label", { w, h }, { x, y, 35 }, INK, 14, "center"),
	}, "pose")
end

menu_button("menu_flip", "Reverse", 6)
menu_button("menu_rename", "Rename", 32)
menu_button("menu_delete", "Delete", 58, RED)

-- ───────────────────── ❀ ─────────────────────
--  Hide Bar
-- ───────────────────── ❀ ─────────────────────

local function hidebutton(name, key, label, x, w)
	widget_definitions["button_" .. name] = UIWidget.create_definition({
		{
			pass_type = "hotspot",
			content_id = "hotspot",
			style = { size = { w, 34 }, offset = { x, 0, 4 } },
		},
		rect("face", { 255, 44, 48, 54 }, { w, 34 }, { x, 0, 2 }),
		rect("edge", GOLD, { w, 1 }, { x, 33, 3 }),
		rect("cap", { 255, 20, 22, 25 }, { 20, 20 }, { x + 10, 7, 3 }),
		text(key, "key", { 20, 20 }, { x + 10, 7, 5 }, GOLD, 12, "center"),
		text(label, "label", { w - 42, 34 }, { x + 36, 0, 5 }, INK, 14, "left"),
	}, "hidebar")
end

hidebutton("hide_this", "H", "Hide", 8, 92)
hidebutton("show_all", "U", "Unhide", 108, 110)

widget_definitions.hide_note = UIWidget.create_definition({
	text("", "label", { 260, 22 }, { 0, 38, 3 }, DIM, 12, "center"),
}, "hidebar")

-- ───────────────────── ❀ ─────────────────────
--  Scrollbars
-- ───────────────────── ❀ ─────────────────────

local KSCROLL_Y = KEY_Y
local KSCROLL_H = KEY_ROWS * KEY_PITCH - (KEY_PITCH - 28)

widget_definitions.scroll_frames = UIWidget.create_definition({
	{
		pass_type = "hotspot",
		content_id = "hotspot",
		style = { size = { 16, KSCROLL_H }, offset = { W - PAD - 12 - 5, KSCROLL_Y, 4 } },
	},
	rect("track", LINE, { 6, KSCROLL_H }, { W - PAD - 12, KSCROLL_Y, 2 }),
	rect("thumb", DIM, { 6, 40 }, { W - PAD - 12, KSCROLL_Y, 3 }),
}, "pose")

widget_definitions.scroll_sets = UIWidget.create_definition({
	rect("track", LINE, { 6, KSCROLL_H }, { W - PAD - 12, KSCROLL_Y, 2 }),
	rect("thumb", DIM, { 6, 40 }, { W - PAD - 12, KSCROLL_Y, 3 }),
}, "pose")

widget_definitions.scroll = UIWidget.create_definition({
	{
		pass_type = "hotspot",
		content_id = "hotspot",
		style = { size = { 16, SCROLL_H }, offset = { SCROLL_X - 5, SCROLL_Y, 4 } },
	},
	rect("track", LINE, { SCROLL_W, SCROLL_H }, { SCROLL_X, SCROLL_Y, 2 }),
	rect("thumb", DIM, { SCROLL_W, 40 }, { SCROLL_X, SCROLL_Y, 3 }),
}, "pose")

-- ───────────────────── ❀ ─────────────────────
--  Sets Page
-- ───────────────────── ❀ ─────────────────────

local SET_ROWS = KEY_ROWS
local SET_Y = LIST_Y + PAD + 30 + 34
button("set_save", "Save Keyframes As Set", PAD * 2 + 190, LIST_Y + PAD, W - PAD * 4 - 190, 30)

for r = 1, SET_ROWS do
	local x = PAD * 2
	local y = SET_Y + (r - 1) * KEY_PITCH
	local w = W - PAD * 4

	widget_definitions["set_" .. r] = UIWidget.create_definition({
		{
			pass_type = "hotspot",
			content_id = "hotspot",
			style = { size = { 120, 28 }, offset = { x, y, 4 } },
		},
		rect("face", { ROW[1], ROW[2], ROW[3], ROW[4] }, { w, 28 }, { x, y, 2 }),
		rect("sel", { 0, GOLD[2], GOLD[3], GOLD[4] }, { 2, 28 }, { x, y, 3 }),
		text("", "name", { 110, 28 }, { x + 10, y, 5 }, INK, 14),
		text("", "ask", { 124, 28 }, { x + w - 160, y, 5 }, RED, 12, "right"),
	}, "pose")

	button("set" .. r .. "_play", "Play", x + 126, y + 2, 44, 24)
	button("set" .. r .. "_load", "Load", x + 174, y + 2, 44, 24)
	button("set" .. r .. "_export", "Export", x + 222, y + 2, 52, 24)
	button("set" .. r .. "_del", "×", x + w - 30, y + 2, 26, 24, RED)
end

-- ───────────────────── ❀ ─────────────────────
--  Tools & Joints
-- ───────────────────── ❀ ─────────────────────

button("equip", "Hide Weapon", W - PAD - 118, TOOL_Y, 118, TOOL_H)
button("clear", "{#color(141,148,160)}C{#reset()}lear Target", PAD, TOOL_Y, 100, TOOL_H, RED)

button("anim_freeze", "Freeze", PAD, TOOL2_Y, 72, TOOL_H)
button("anim_thaw", "Thaw", PAD + 78, TOOL2_Y, 72, TOOL_H)

button("zero", "Zero All", PAD + 156, TOOL2_Y, 76, TOOL_H)
button("release", "Release All", PAD + 238, TOOL2_Y, 96, TOOL_H)

for i = 1, JOINT_ROWS do
	local x = PAD * 2 + CHART_W + 8
	local y = LIST_Y + PAD + (i - 1) * ROW_PITCH
	local w = W - PAD * 4 - CHART_W - 8

	widget_definitions["button_joint_" .. i] = UIWidget.create_definition({
		{
			pass_type = "hotspot",
			content_id = "hotspot",
			style = { size = { w, ROW_H }, offset = { x, y, 4 } },
		},
		rect("face", { ROW[1], ROW[2], ROW[3], ROW[4] }, { w, ROW_H }, { x, y, 2 }),
		rect("sel", { 0, GOLD[2], GOLD[3], GOLD[4] }, { 2, ROW_H }, { x, y, 3 }),
		text("", "label", { w - 110, ROW_H }, { x + 10, y, 5 }, INK, 14),
		text("", "dials", { 100, ROW_H }, { x + w - 110, y, 5 }, DIM, 14, "right"),
	}, "pose")
end

local CHART_X = PAD * 2 + CHART_W * 0.5
local CHART_Y = LIST_Y + PAD + 30
local CHART_NODES = {
	{ "j_head", 0, 40 }, { "j_neck", 0, 78 }, { "j_spine2", 0, 112 }, { "j_spine1", 0, 150 },
	{ "j_spine", 0, 188 }, { "j_hips", 0, 226 },
	{ "j_leftshoulder", -22, 98 }, { "j_leftarm", -42, 108 }, { "j_leftforearm", -52, 176 }, { "j_lefthand", -58, 240 },
	{ "j_rightshoulder", 22, 98 }, { "j_rightarm", 42, 108 }, { "j_rightforearm", 52, 176 }, { "j_righthand", 58, 240 },
	{ "j_leftupleg", -18, 246 }, { "j_leftleg", -22, 348 }, { "j_leftfoot", -24, 446 },
	{ "j_rightupleg", 18, 246 }, { "j_rightleg", 22, 348 }, { "j_rightfoot", 24, 446 },
}
local CHART_BONES = {
	{ "j_neck", "j_spine2" }, { "j_spine2", "j_spine1" }, { "j_spine1", "j_spine" }, { "j_spine", "j_hips" },
	{ "j_spine2", "j_leftshoulder" }, { "j_leftshoulder", "j_leftarm" }, { "j_leftarm", "j_leftforearm" },
	{ "j_leftforearm", "j_lefthand" }, { "j_spine2", "j_rightshoulder" }, { "j_rightshoulder", "j_rightarm" },
	{ "j_rightarm", "j_rightforearm" }, { "j_rightforearm", "j_righthand" }, { "j_hips", "j_leftupleg" },
	{ "j_leftupleg", "j_leftleg" }, { "j_leftleg", "j_leftfoot" }, { "j_hips", "j_rightupleg" },
	{ "j_rightupleg", "j_rightleg" }, { "j_rightleg", "j_rightfoot" },
}
local CHART_HEAD = 16
local CHART_NAMES = {}

local function bar(style_id, ax, ay, bx, by, thick, color, z)
	local dx, dy = bx - ax, by - ay
	local len = math.max(1, math.sqrt(dx * dx + dy * dy))

	return {
		pass_type = "rotated_texture",
		value = "content/ui/materials/backgrounds/default_square",
		style_id = style_id,
		style = {
			color = { color[1], color[2], color[3], color[4] },
			size = { len, thick },
			offset = { (ax + bx) * 0.5 - len * 0.5, (ay + by) * 0.5 - thick * 0.5, z },
			angle = -math.atan2(dy, dx),
			pivot = { len * 0.5, thick * 0.5 },
		},
	}
end

local function diamond(style_id, x, y, s, color, z)
	return {
		pass_type = "rotated_texture",
		value = "content/ui/materials/backgrounds/default_square",
		style_id = style_id,
		style = {
			color = { color[1], color[2], color[3], color[4] },
			size = { s, s },
			offset = { x - s * 0.5, y - s * 0.5, z },
			angle = math.pi * 0.25,
			pivot = { s * 0.5, s * 0.5 },
		},
	}
end

do
	local at = {}

	for i, n in ipairs(CHART_NODES) do
		at[n[1]] = { CHART_X + n[2], CHART_Y + n[3] }
		CHART_NAMES[i] = n[1]
	end

	local head, neck = at.j_head, at.j_neck
	local passes = { bar("bone_0", head[1], head[2] + CHART_HEAD, neck[1], neck[2], 2, LINE, 2) }

	for i, b in ipairs(CHART_BONES) do
		local a, c = at[b[1]], at[b[2]]

		passes[#passes + 1] = bar("bone_" .. i, a[1], a[2], c[1], c[2], 2, LINE, 2)
	end

	for s = 1, 16 do
		local t0, t1 = (s - 1) / 16 * math.pi * 2, s / 16 * math.pi * 2

		passes[#passes + 1] = bar("head_" .. s, head[1] + math.cos(t0) * CHART_HEAD, head[2] + math.sin(t0) * CHART_HEAD,
			head[1] + math.cos(t1) * CHART_HEAD, head[2] + math.sin(t1) * CHART_HEAD, 2, LINE, 2)
	end

	passes[#passes + 1] = text("L", "left", { 20, 16 }, { PAD * 2 + 4, CHART_Y - 24, 3 }, DIM, 12, "left")
	passes[#passes + 1] = text("R", "right", { 20, 16 }, { PAD * 2 + CHART_W - 24, CHART_Y - 24, 3 }, DIM, 12, "right")
	passes[#passes + 1] = text("Seen from behind", "caption", { CHART_W, 16 }, { PAD * 2, CHART_Y + 474, 3 }, DIM, 12,
		"center")

	widget_definitions.chart = UIWidget.create_definition(passes, "pose")

	for i, n in ipairs(CHART_NODES) do
		local x, y = at[n[1]][1], at[n[1]][2]

		widget_definitions["button_node_" .. i] = UIWidget.create_definition({
			{
				pass_type = "hotspot",
				content_id = "hotspot",
				style = { size = { 24, 24 }, offset = { x - 12, y - 12, 6 } },
			},
			diamond("ring", x, y, 18, { 0, GOLD[2], GOLD[3], GOLD[4] }, 3),
			diamond("hole", x, y, 12, { 0, PANEL[2], PANEL[3], PANEL[4] }, 4),
			diamond("dot", x, y, 8, LINE, 5),
		}, "pose")
	end
end

for a = 1, #AXES do
	local axis = AXES[a]
	local y = AXIS_Y + (a - 1) * AXIS_PITCH

	widget_definitions["slider_" .. axis] = UIWidget.create_definition({
		{
			pass_type = "hotspot",
			content_id = "hotspot",
			style = { size = { BAR_W, 28 }, offset = { BAR_X, y - 14, 4 } },
		},
		rect("track", LINE, { BAR_W, BAR_H }, { BAR_X, y - BAR_H / 2, 2 }),
		rect("fill", GOLD, { 0, BAR_H }, { BAR_X, y - BAR_H / 2, 3 }),
		rect("zero", DIM, { 1, 14 }, { BAR_X + BAR_W * 0.5, y - 7, 4 }),
		rect("knob", GOLD, { 14, 14 }, { BAR_X - 7, y - 7, 5 }),
		text(string.upper(axis), "label", { 22, 28 }, { PAD * 2, y - 14, 3 }, INK, 14, "left", "proxima_nova_bold"),
		rect("box", { 255, 20, 22, 25 }, { 60, 28 }, { BAR_X + BAR_W + 12, y - 14, 2 }),
		text("0", "value", { 60, 28 }, { BAR_X + BAR_W + 12, y - 14, 3 }, INK, 14, "center"),
	}, "pose")

	hot("axis_" .. axis, BAR_X + BAR_W + 12, y - 14, 60, 28)
end

button("jzero", "Zero This Joint", PAD * 2, JZERO_Y, 170, 30)

-- ───────────────────── ❀ ─────────────────────
--  Object Key
-- ───────────────────── ❀ ─────────────────────

widget_definitions.obj_plate = UIWidget.create_definition({
	{
		pass_type = "hotspot",
		content_id = "hotspot",
		style_id = "hotspot",
		style = { size = { OW, OH }, offset = { 0, 0, 0 } },
	},
	rect("plate", BG, { OW, OH }, { 0, 0, 0 }),
	rect("dials", PANEL, { OW - PAD * 2, OBJ_DIALS_B - OBJ_Y + 34 }, { PAD, OBJ_Y - 34, 1 }),
	text("OBJECT KEY", "title", { 200, 34 }, { PAD, 0, 3 }, GOLD, 18, "left", "machine_medium"),
}, "objkey")

local function cell(r, x, y)
	widget_definitions["obj_" .. r] = UIWidget.create_definition({
		{
			pass_type = "hotspot",
			content_id = "hotspot",
			style = { size = { CELL_W, CELL_H }, offset = { x, y, 4 } },
		},
		rect("face", { 255, 20, 22, 25 }, { CELL_W, CELL_H }, { x, y, 2 }),
		rect("edge", LINE, { CELL_W, 1 }, { x, y + CELL_H - 1, 3 }),
		text("0", "value", { CELL_W, CELL_H }, { x, y, 5 }, INK, 14, "center"),
	}, "objkey")
end

widget_definitions.obj_heads = UIWidget.create_definition({
	text("Move", "move", { CELL_W, 18 }, { CELL_X, OBJ_Y - 18, 3 }, DIM, 12, "center"),
	text("Turn", "turn", { CELL_W, 18 }, { CELL_X + CELL_W + 8, OBJ_Y - 18, 3 }, DIM, 12, "center"),
	text("X", "x", { 18, CELL_H }, { PAD * 2, OBJ_Y, 3 }, INK, 14, "left"),
	text("Y", "y", { 18, CELL_H }, { PAD * 2, OBJ_Y + CELL_H + CELL_GAP, 3 }, INK, 14, "left"),
	text("Z", "z", { 18, CELL_H }, { PAD * 2, OBJ_Y + (CELL_H + CELL_GAP) * 2, 3 }, INK, 14, "left"),
	text("Drag a number sideways, or click it to type.", "hint",
		{ OW - PAD * 4, 20 }, { PAD * 2, OBJ_Y + (CELL_H + CELL_GAP) * 3 + 2, 3 }, DIM, 12, "left"),
	text("Scale", "scale", { 60, CELL_H }, { PAD * 2, SCALE_Y, 3 }, INK, 14, "left"),
}, "objkey")

for r = 1, 3 do
	local y = OBJ_Y + (r - 1) * (CELL_H + CELL_GAP)

	cell(r, CELL_X, y)
	cell(r + 3, CELL_X + CELL_W + 8, y)
end

local SCALE_X = PAD * 2 + 60
local SCALE_W = CELL_X + CELL_W * 2 + 8 - SCALE_X

widget_definitions.obj_7 = UIWidget.create_definition({
	rect("box", { 255, 20, 22, 25 }, { SCALE_W, CELL_H }, { SCALE_X, SCALE_Y, 2 }),
	text("1x", "value", { SCALE_W, CELL_H }, { SCALE_X, SCALE_Y, 3 }, INK, 14, "center"),
}, "objkey")

hot("obj_7", SCALE_X, SCALE_Y, SCALE_W, CELL_H, "objkey")

-- ───────────────────── ❀ ─────────────────────
--  Object Controls
-- ───────────────────── ❀ ─────────────────────

local BTN_W = (OW - PAD * 4 - 8) / 2
local BTN_H = 34

local function obtn(name, label, col, row, edge)
	button(name, label, PAD * 2 + (col - 1) * (BTN_W + 8), OBJ_BTN_Y + (row - 1) * (BTN_H + 6),
		BTN_W, BTN_H, edge, "objkey")
end

do
	local x = PAD * 2
	local y = OBJ_BTN_Y

	widget_definitions.button_obj_copy = UIWidget.create_definition({
		{
			pass_type = "hotspot",
			content_id = "hotspot",
			style = { size = { BTN_W, BTN_H }, offset = { x, y, 4 } },
		},
		rect("face", { ROW[1], ROW[2], ROW[3], ROW[4] }, { BTN_W, BTN_H }, { x, y, 2 }),
		rect("edge", LINE, { BTN_W, 1 }, { x, y + BTN_H - 1, 3 }),
		text("Ctrl+C", "head", { BTN_W, 12 }, { x, y + 3, 5 }, DIM, 12, "center"),
		text("Copy", "label", { BTN_W, BTN_H - 14 }, { x, y + 13, 5 }, INK, 14, "center"),
	}, "objkey")
end

do
	local x = PAD * 2
	local y = OBJ_BTN_Y + 2 * (BTN_H + 6)

	widget_definitions.button_obj_back = UIWidget.create_definition({
		{
			pass_type = "hotspot",
			content_id = "hotspot",
			style = { size = { BTN_W, BTN_H }, offset = { x, y, 4 } },
		},
		rect("face", { ROW[1], ROW[2], ROW[3], ROW[4] }, { BTN_W, BTN_H }, { x, y, 2 }),
		rect("edge", LINE, { BTN_W, 1 }, { x, y + BTN_H - 1, 3 }),
		text("Ctrl+Z", "head", { BTN_W, 12 }, { x, y + 3, 5 }, DIM, 12, "center"),
		text("Undo", "label", { BTN_W, BTN_H - 14 }, { x, y + 13, 5 }, INK, 14, "center"),
	}, "objkey")
end
local KEY_GREY = "141,148,160"

local function keyword(word, grey)
	return "{#color(" .. (grey or KEY_GREY) .. ")}" .. string.sub(word, 1, 1) .. "{#reset()}" .. string.sub(word, 2)
end

local function keybutton(name, word, col, row, edge)
	local x = PAD * 2 + (col - 1) * (BTN_W + 8)
	local y = OBJ_BTN_Y + (row - 1) * (BTN_H + 6)

	widget_definitions["button_" .. name] = UIWidget.create_definition({
		{
			pass_type = "hotspot",
			content_id = "hotspot",
			style = { size = { BTN_W, BTN_H }, offset = { x, y, 4 } },
		},
		rect("face", { ROW[1], ROW[2], ROW[3], ROW[4] }, { BTN_W, BTN_H }, { x, y, 2 }),
		rect("edge", edge or LINE, { BTN_W, 1 }, { x, y + BTN_H - 1, 3 }),
		text("", "head", { BTN_W, 12 }, { x, y + 3, 5 }, DIM, 12, "center"),
		text(keyword(word), "label", { BTN_W, BTN_H }, { x, y, 5 }, { INK[1], INK[2], INK[3], INK[4] }, 14, "center"),
	}, "objkey")
end

keybutton("obj_lock", "Lock", 2, 3)

keybutton("obj_drop", "Clear Target", 2, 2, RED)

keybutton("obj_add", "Save Item", 2, 1)

keybutton("obj_reset", "Reset", 1, 2)

local OTAB_Y = 44

local function otab(name, label, x, w)
	widget_definitions["button_otab_" .. name] = UIWidget.create_definition({
		{
			pass_type = "hotspot",
			content_id = "hotspot",
			style = { size = { w, 26 }, offset = { x, OTAB_Y, 4 } },
		},
		rect("face", PANEL, { w, 26 }, { x, OTAB_Y, 2 }),
		rect("edge", GOLD, { w, 2 }, { x, OTAB_Y, 3 }),
		text(label, "label", { w, 26 }, { x, OTAB_Y, 5 }, INK, 14, "center"),
	}, "objkey")
end

otab("move", "Move", PAD, 88)
otab("items", "Items", PAD + 92, 88)
otab("groups", "Groups", PAD + 184, 88)

-- ───────────────────── ❀ ─────────────────────
--  Groups Tab
-- ───────────────────── ❀ ─────────────────────

local GROUP_ROWS = 7
local GROUP_PITCH = 34

for r = 1, GROUP_ROWS do
	local y = OBJ_Y - 8 + (r - 1) * GROUP_PITCH

	widget_definitions["grp_" .. r] = UIWidget.create_definition({
		{
			pass_type = "hotspot",
			content_id = "hotspot",
			style = { size = { OW - PAD * 4, 28 }, offset = { PAD * 2, y, 4 } },
		},
		rect("face", { ROW[1], ROW[2], ROW[3], ROW[4] }, { OW - PAD * 4, 28 }, { PAD * 2, y, 2 }),
		rect("sel", { 0, GOLD[2], GOLD[3], GOLD[4] }, { 2, 28 }, { PAD * 2, y, 3 }),
		rect("dot", { 0, GREEN[2], GREEN[3], GREEN[4] }, { 7, 7 }, { PAD * 2 + 9, y + 10.5, 4 }),
		text("", "name", { OW - PAD * 4 - 106 - 26, 28 }, { PAD * 2 + 22, y, 5 }, INK, 14, "left"),
	}, "objkey")

	button("grp" .. r .. "_load", "Load", OW - PAD * 2 - 106, y, 62, 28, nil, "objkey")
	button("grp" .. r .. "_sync", "Save", OW - PAD * 2 - 40, y, 40, 28, nil, "objkey")
end

widget_definitions.grp_scroll = UIWidget.create_definition({
	rect("track", LINE, { 4, GROUP_ROWS * GROUP_PITCH - 6 }, { OW - PAD * 2 + 7, OBJ_Y - 8, 2 }),
	rect("thumb", DIM, { 4, 40 }, { OW - PAD * 2 + 7, OBJ_Y - 8, 3 }),
}, "objkey")

local LIST_BTN_Y = OBJ_Y - 8 + GROUP_ROWS * GROUP_PITCH + 6
local LIST_BTN_W3 = (OW - PAD * 4 - 16) / 3

button("grp_merge", "Merge", PAD * 2, LIST_BTN_Y, LIST_BTN_W3, 30, nil, "objkey")
button("grp_export", "Export", PAD * 2 + LIST_BTN_W3 + 8, LIST_BTN_Y, LIST_BTN_W3, 30, nil, "objkey")
button("grp_folder", "Folder", PAD * 2 + (LIST_BTN_W3 + 8) * 2, LIST_BTN_Y, LIST_BTN_W3, 30, nil, "objkey")

widget_definitions.grp_more = UIWidget.create_definition({
	text("", "label", { OW - PAD * 4, 18 }, { PAD * 2, LIST_BTN_Y + 36, 3 }, DIM, 12, "left"),
}, "objkey")


-- ───────────────────── ❀ ─────────────────────
--  Items Tab
-- ───────────────────── ❀ ─────────────────────

local ITEM_ROWS = 8
local ITEM_H = 38
local ITEM_PITCH = 43
local ITEM_Y = OBJ_Y
local ITEM_X = PAD * 2
local ITEM_W = OW - PAD * 4

widget_definitions.item_head = UIWidget.create_definition({
	text("", "label", { ITEM_W, 16 }, { ITEM_X, ITEM_Y - 20, 3 }, DIM, 12, "left"),
}, "objkey")

for r = 1, ITEM_ROWS do
	local y = ITEM_Y + (r - 1) * ITEM_PITCH

	widget_definitions["item_" .. r] = UIWidget.create_definition({
		{
			pass_type = "hotspot",
			content_id = "hotspot",
			style = { size = { ITEM_W, ITEM_H }, offset = { ITEM_X, y, 4 } },
		},
		rect("face", { ROW[1], ROW[2], ROW[3], ROW[4] }, { ITEM_W, ITEM_H }, { ITEM_X, y, 2 }),
		rect("held", { 0, 230, 220, 195 }, { 2, ITEM_H }, { ITEM_X, y, 3 }),
		rect("dot", { 255, 215, 205, 176 }, { 7, 7 }, { ITEM_X + 10, y + (ITEM_H - 7) * 0.5, 3 }),
		text("", "name", { ITEM_W - 90, 20 }, { ITEM_X + 26, y + 3, 5 }, INK, 14, "left"),
		text("", "kind", { ITEM_W - 90, 14 }, { ITEM_X + 26, y + 21, 5 }, DIM, 12, "left"),
		text("", "away", { 52, ITEM_H }, { ITEM_X + ITEM_W - 88, y, 5 }, DIM, 12, "right"),
	}, "objkey")

	button("item" .. r .. "_x", "×", ITEM_X + ITEM_W - 30, y + 5, 26, 28, RED, "objkey")
end

widget_definitions.item_scroll = UIWidget.create_definition({
	{
		pass_type = "hotspot",
		content_id = "hotspot",
		style = { size = { 14, ITEM_ROWS * ITEM_PITCH - 5 }, offset = { ITEM_X + ITEM_W + 2, ITEM_Y, 4 } },
	},
	rect("track", LINE, { 4, ITEM_ROWS * ITEM_PITCH - 5 }, { ITEM_X + ITEM_W + 7, ITEM_Y, 2 }),
	rect("thumb", DIM, { 4, 40 }, { ITEM_X + ITEM_W + 7, ITEM_Y, 3 }),
}, "objkey")

local ITEM_HALF = (ITEM_W - 8) / 2
local ITEM_BTN_Y = ITEM_Y + ITEM_ROWS * ITEM_PITCH + 2

button("hold_all", "Hold All", ITEM_X, ITEM_BTN_Y, ITEM_HALF, 28, nil, "objkey")
button("grp_save", "Save As Group", ITEM_X + ITEM_HALF + 8, ITEM_BTN_Y, ITEM_HALF, 28, nil, "objkey")

local GPICK_ROWS = 7
local GPICK_W = 180
local GPICK_H = 26
local GPICK_X = ITEM_X + ITEM_W - GPICK_W
local GPICK_Y = ITEM_BTN_Y + 32

widget_definitions.gpick_face = UIWidget.create_definition({
	{
		pass_type = "hotspot",
		content_id = "hotspot",
		style_id = "hotspot",
		style = { size = { GPICK_W, (GPICK_ROWS + 1) * GPICK_H + 8 }, offset = { GPICK_X, GPICK_Y, 30 } },
	},
	rect("face", { 255, 35, 38, 43 }, { GPICK_W, (GPICK_ROWS + 1) * GPICK_H + 8 }, { GPICK_X, GPICK_Y, 30 }),
	rect("edge", GOLD, { GPICK_W, 2 }, { GPICK_X, GPICK_Y, 31 }),
}, "objkey")

local function gpick_button(name, label, k)
	local x, w, h = GPICK_X + 4, GPICK_W - 8, GPICK_H - 2
	local y = GPICK_Y + 4 + (k - 1) * GPICK_H

	widget_definitions["button_" .. name] = UIWidget.create_definition({
		{
			pass_type = "hotspot",
			content_id = "hotspot",
			style = { size = { w, h }, offset = { x, y, 34 } },
		},
		rect("face", { ROW[1], ROW[2], ROW[3], ROW[4] }, { w, h }, { x, y, 32 }),
		rect("edge", LINE, { w, 1 }, { x, y + h - 1, 33 }),
		text(label, "label", { w, h }, { x, y, 35 }, INK, 14, "center"),
	}, "objkey")
end

gpick_button("gpick_new", "New", 1)

widget_definitions.gpick_scroll = UIWidget.create_definition({
	rect("track", LINE, { 4, GPICK_ROWS * GPICK_H - 2 }, { ITEM_X + ITEM_W + 7, GPICK_Y + 4 + GPICK_H, 36 }),
	rect("thumb", DIM, { 4, 40 }, { ITEM_X + ITEM_W + 7, GPICK_Y + 4 + GPICK_H, 37 }),
}, "objkey")

for k = 1, GPICK_ROWS do
	gpick_button("gpick_" .. k, "", k + 1)
end

widget_definitions.obj_empty = UIWidget.create_definition({
	text("Nothing held yet.", "line1", { OW - PAD * 4, 22 }, { PAD * 2, OBJ_Y - 20, 3 }, INK, 14, "left"),
	text("Click a prop in the world to hold it.", "line2", { OW - PAD * 4, 20 }, { PAD * 2, OBJ_Y + 6, 3 }, DIM, 12, "left"),
	text("Drag an arrow to slide it, the ball to turn it.", "line3", { OW - PAD * 4, 20 }, { PAD * 2, OBJ_Y + 26, 3 },
		DIM, 12, "left"),
	text("S saves it to the Items list.", "line4", { OW - PAD * 4, 20 }, { PAD * 2, EMPTY_LAST_Y, 3 }, DIM, 12, "left"),
}, "objkey")

widget_definitions.grp_empty = UIWidget.create_definition({
	text("No groups in this level yet.", "line1", { OW - PAD * 4, 22 }, { PAD * 2, OBJ_Y - 8, 3 }, INK, 14, "left"),
	text("Hold things, then Save As Group on Items.", "line2", { OW - PAD * 4, 20 }, { PAD * 2, OBJ_Y + 16, 3 },
		DIM, 12, "left"),
}, "objkey")

widget_definitions.obj_say = UIWidget.create_definition({
	text("", "label", { OW - PAD * 4, 22 }, { PAD * 2, OBJ_SAY_Y, 3 }, DIM, 12, "left"),
}, "objkey")

widget_definitions.obj_note = UIWidget.create_definition({
	text("", "label", { 170, 34 }, { OW - PAD - 170, 0, 3 }, { 255, 236, 230, 216 }, 14, "right"),
}, "objkey")

-- ───────────────────── ❀ ─────────────────────
--  Keyframes Page
-- ───────────────────── ❀ ─────────────────────

button("save", "Save Pose", PAD * 2 + 190, LIST_Y + PAD, 76, 30)
button("play", "Play", PAD * 2 + 270, LIST_Y + PAD, 44, 30)
button("loop", "Loop", PAD * 2 + 320, LIST_Y + PAD, 64, 30)
button("frames_clear", "Clear", W - PAD * 2 - 66, KEY_Y - 24, 66, 22, RED)

for r = 1, KEY_ROWS do
	local x = PAD * 2
	local y = KEY_Y + (r - 1) * KEY_PITCH
	local w = W - PAD * 4

	widget_definitions["frame_" .. r] = UIWidget.create_definition({
		{
			pass_type = "hotspot",
			content_id = "hotspot",
			style = { size = { 100, 28 }, offset = { x, y, 4 } },
		},
		{
			pass_type = "hotspot",
			content_id = "bar",
			style = { size = { HOLD_BAR_W, 28 }, offset = { x + HOLD_BAR_X, y, 4 } },
		},
		rect("face", { ROW[1], ROW[2], ROW[3], ROW[4] }, { w, 28 }, { x, y, 2 }),
		rect("sel", { 0, GOLD[2], GOLD[3], GOLD[4] }, { 2, 28 }, { x, y, 3 }),
		text("", "name", { 96, 28 }, { x + 10, y, 5 }, INK, 14),
		rect("htrack", LINE, { HOLD_BAR_W, 5 }, { x + HOLD_BAR_X, y + 12, 3 }),
		rect("hfill", GOLD, { 0, 5 }, { x + HOLD_BAR_X, y + 12, 4 }),
		rect("hknob", GOLD, { 10, 10 }, { x + HOLD_BAR_X - 5, y + 9, 5 }),
		rect("hbox", { 255, 20, 22, 25 }, { 50, 24 }, { x + 226, y + 2, 3 }),
		text("", "hold", { 50, 24 }, { x + 226, y + 2, 5 }, INK, 12, "center"),
	}, "pose")

	hot("hold_" .. r, x + 226, y + 2, 50, 24)
	button("row" .. r .. "_over", "Update", x + 282, y + 2, 56, 24)
	button("row" .. r .. "_del", "×", x + w - 30, y + 2, 26, 24, RED)
end

-- ───────────────────── ❀ ─────────────────────
--  Text Fields
-- ───────────────────── ❀ ─────────────────────

local function update_writing_state(hotspot_content)
	if not hotspot_content.on_pressed then
		return
	end

	hotspot_content.double_click_timer = 0

	local content = hotspot_content.parent

	if not content.is_writing then
		content.is_writing = true
	elseif content.selected_text and content.selected_text ~= "" then
		content.selected_text = nil
		content._selection_start = nil
		content._selection_end = nil
	else
		content.is_writing = false
	end
end

local input_passes = table.clone(TextInputPassTemplates.simple_input_field)

for i = 1, #input_passes do
	local pass = input_passes[i]

	if pass.pass_type == "hotspot" then
		pass.change_function = update_writing_state
	end
end

for i = #input_passes, 1, -1 do
	if input_passes[i].value_id == "limit_text" then
		table.remove(input_passes, i)
	end
end

widget_definitions.input = UIWidget.create_definition(input_passes, "name", {
	input_text = "",
	placeholder_text = "Name",
	max_length = 12,
	is_writing = false,
})

widget_definitions.rename_veil = UIWidget.create_definition({
	{
		pass_type = "hotspot",
		content_id = "hotspot",
		style = { size = { W, H }, offset = { 0, 0, 38 } },
	},
	rect("veil", { 190, 18, 20, 23 }, { W, H }, { 0, 0, 37 }),
}, "pose")

widget_definitions.rename_box = UIWidget.create_definition({
	rect("face", { 255, 35, 38, 43 }, { 300, 110 }, { 0, 0, 1 }),
	rect("edge", GOLD, { 300, 2 }, { 0, 0, 2 }),
	text("Rename", "title", { 280, 26 }, { 14, 10, 3 }, GOLD, 18, "left", "machine_medium"),
	text("", "what", { 280, 22 }, { 14, 32, 3 }, DIM, 12),
	text("Enter to keep it, Escape to leave it", "hint", { 280, 20 }, { 14, 86, 3 }, DIM, 12),
}, "rename")

local rename_passes = table.clone(input_passes)

widget_definitions.rename_input = UIWidget.create_definition(rename_passes, "rename_field", {
	input_text = "",
	placeholder_text = "New name",
	max_length = 24,
	is_writing = false,
})

widget_definitions.path_input = UIWidget.create_definition(table.clone(input_passes), "path_field", {
	input_text = "",
	placeholder_text = "Unit path",
	max_length = 200,
	is_writing = false,
})

button("path_go", "Spawn", OW - PAD * 2 - 60, 0, 60, 28, nil, "objkey")

return {
	scenegraph_definition = scenegraph_definition,
	widget_definitions = widget_definitions,
	AXES = AXES,
	JOINT_SLOTS = JOINT_ROWS,
	CHART_NODES = CHART_NAMES,
	KEY_ROWS = KEY_ROWS,
	SET_ROWS = SET_ROWS,
	POSE_ROWS = POSE_ROWS,
	OBJ_SCALE_W = SCALE_W,
	GYRO_RINGS = GYRO_RINGS,
	GYRO_LINE = GYRO_LINE,
	GYRO_RIB = GYRO_RIB,
	GYRO_HEAD = GYRO_HEAD,
	GYRO_AXIS = GYRO_AXIS,
	KEYWORD = keyword,
	ITEM_ROWS = ITEM_ROWS,
	GPICK_ROWS = GPICK_ROWS,
	ITEM_BTN_Y = ITEM_BTN_Y,
	ITEM_Y = ITEM_Y,
	ITEM_X = ITEM_X,
	PATH_GO_X = OW - PAD * 2 - 60,
	ITEM_PITCH = ITEM_PITCH,
	OBJ_SAY_Y = OBJ_SAY_Y,
	OBJ_BTN_H = BTN_H,
	OBJ_DIALS_H = OBJ_DIALS_B - OBJ_Y + 34,
	OBJ_EMPTY_H = OBJ_EMPTY_H,
	OBJ_COPY_AT = { PAD * 2, OBJ_BTN_Y },
	OBJ_BACK_AT = { PAD * 2, OBJ_BTN_Y + 2 * (BTN_H + 6) },
	OBJ_EMPTY_COPY_AT = { PAD * 2, OBJ_EMPTY_BTN_Y },
	OBJ_EMPTY_BACK_AT = { PAD * 2 + BTN_W + 8, OBJ_EMPTY_BTN_Y },
	OBJ_GROUPS_H = GROUP_ROWS * GROUP_PITCH + 28,
	GOLD = GOLD,
	LINE = LINE,
	PANEL = PANEL,
	BG = BG,
	PANEL_W = W,
	PANEL_H = H,
	OBJ_PANEL_W = OW,
	OBJ_PANEL_H = OH,
	TAPE_BAR_X = TAPE_BAR_X,
	TAPE_BAR_W = TAPE_BAR_W,
	SCROLL_X = SCROLL_X,
	SCROLL_Y = SCROLL_Y,
	SCROLL_H = SCROLL_H,
	KSCROLL_Y = KSCROLL_Y,
	GROUP_ROWS = GROUP_ROWS,
	GROUP_Y = OBJ_Y - 8,
	GPICK_H = GPICK_H,
	GPICK_BAR_Y = GPICK_Y + 4 + GPICK_H,
	KSCROLL_H = KSCROLL_H,
	INPUT_HOME = { PAD * 2, LIST_Y + PAD },
	INPUT_JOINTS = { PAD * 2 + 178, AXIS_Y + AXIS_PITCH * 3 - 6 },
	ROW_VERBS = { "over", "del" },
	KEY_PITCH = KEY_PITCH,
	NAME_X = PAD * 2 + 10,
	NAME_W = 96,
	MENU_X = MENU_X,
	HOLD_BAR_X = PAD * 2 + HOLD_BAR_X,
	HOLD_BAR_W = HOLD_BAR_W,
	HOLD_MAX = HOLD_MAX,
	BAR_W = BAR_W,
	BAR_X = BAR_X,
}
