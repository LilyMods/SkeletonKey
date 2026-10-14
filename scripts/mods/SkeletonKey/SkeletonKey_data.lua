local mod = get_mod("SkeletonKey")

return {
	name = mod:localize("mod_name"),
	description = mod:localize("mod_description"),
	is_togglable = true,
	options = {
		widgets = {
			{
				setting_id = "pose_key",
				type = "keybind",
				default_value = {},
				keybind_global = false,
				keybind_trigger = "pressed",
				keybind_type = "view_toggle",
				view_name = "skeletonkey_pose_view",
			},
		},
	},
}
