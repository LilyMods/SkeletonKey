local mod = get_mod("SkeletonKey")

local widgets = {
	{
		setting_id = "pose_key",
		type = "keybind",
		default_value = {},
		keybind_global = false,
		keybind_trigger = "pressed",
		keybind_type = "view_toggle",
		view_name = "skeletonkey_pose_view",
	},
}

local okf, f = pcall(function()
	return Mods.lua.io.open("./../mods/SkeletonKey/scripts/mods/SkeletonKey/SkeletonKey_Three.lua", "r")
end)

if okf and f then
	pcall(function() f:close() end)

	widgets[#widgets + 1] = {
		setting_id = "panel_layout",
		type = "dropdown",
		default_value = "two",
		options = {
			{ text = "panel_layout_two", value = "two" },
			{ text = "panel_layout_three", value = "three" },
		},
	}
end

return {
	name = mod:localize("mod_name"),
	description = mod:localize("mod_description"),
	is_togglable = true,
	options = {
		widgets = widgets,
	},
}
