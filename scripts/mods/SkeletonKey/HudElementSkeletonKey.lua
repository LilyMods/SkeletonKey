local mod = get_mod("SkeletonKey")

require("scripts/ui/hud/elements/hud_element_base")
local UIWorkspaceSettings = require("scripts/settings/ui/ui_workspace_settings")
local UIWidget = require("scripts/managers/ui/ui_widget")

-- ───────────────────── ❀ ─────────────────────
--  Panel
-- ───────────────────── ❀ ─────────────────────

local PANEL_X = 48
local PANEL_Y = 132
local PANEL_W = 420
local PANEL_H = 40
local TAG_W = 130
local TEXT_X = 16 + TAG_W
local GOLD = { 255, 230, 220, 195 }

local panel_passes = {
	{
		pass_type = "rect",
		style_id = "plate",
		style = {
			color = { 235, 27, 29, 33 },
			size = { PANEL_W, PANEL_H },
			offset = { 0, 0, 0 },
		},
	},
	{
		pass_type = "rect",
		style_id = "bar",
		style = {
			color = GOLD,
			size = { 4, PANEL_H },
			offset = { 0, 0, 1 },
		},
	},
	{
		pass_type = "text",
		value = "SKELETON KEY",
		value_id = "tag",
		style_id = "tag",
		style = {
			font_type = "machine_medium",
			font_size = 18,
			drop_shadow = false,
			text_vertical_alignment = "center",
			text_horizontal_alignment = "left",
			text_color = GOLD,
			size = { TAG_W, PANEL_H },
			offset = { 16, 0, 2 },
		},
	},
	{
		pass_type = "text",
		value = "",
		value_id = "line",
		style_id = "line",
		style = {
			font_type = "proxima_nova_medium",
			font_size = 14,
			drop_shadow = false,
			text_vertical_alignment = "center",
			text_horizontal_alignment = "left",
			text_color = { 255, 236, 230, 216 },
			size = { PANEL_W - TEXT_X - 12, PANEL_H },
			offset = { TEXT_X, 0, 2 },
		},
	},
}

local definitions = {
	scenegraph_definition = {
		screen = UIWorkspaceSettings.screen,
		panel = {
			parent = "screen",
			horizontal_alignment = "left",
			vertical_alignment = "top",
			size = { PANEL_W, PANEL_H },
			position = { PANEL_X, PANEL_Y, 100 },
		},
	},
	widget_definitions = {
		panel = UIWidget.create_definition(panel_passes, "panel"),
	},
}

-- ───────────────────── ❀ ─────────────────────
--  Drawing
-- ───────────────────── ❀ ─────────────────────

local HudElementSkeletonKey = class("HudElementSkeletonKey", "HudElementBase")

HudElementSkeletonKey.init = function (self, parent, draw_layer, start_scale)
	HudElementSkeletonKey.super.init(self, parent, draw_layer, start_scale, definitions)
end

HudElementSkeletonKey.update = function (self, dt, t, ui_renderer, render_settings, input_service)
	HudElementSkeletonKey.super.update(self, dt, t, ui_renderer, render_settings, input_service)

	local widget = self._widgets_by_name.panel

	if not widget then
		return
	end

	local G = rawget(_G, "__skeletonkey")
	local hud = G and G.hud
	local now = Application.time_since_launch()
	local shown = hud and type(hud.text) == "string" and hud.text ~= "" and (hud.until_t or 0) > now

	widget.visible = shown and true or false
	widget.content.line = shown and hud.text or ""
end

return HudElementSkeletonKey
