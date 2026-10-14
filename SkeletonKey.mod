return {
	run = function()
		fassert(rawget(_G, "new_mod"), "`SkeletonKey` encountered an error loading the Darktide Mod Framework.")

		new_mod("SkeletonKey", {
			mod_script       = "SkeletonKey/scripts/mods/SkeletonKey/SkeletonKey",
			mod_data         = "SkeletonKey/scripts/mods/SkeletonKey/SkeletonKey_data",
			mod_localization = "SkeletonKey/scripts/mods/SkeletonKey/SkeletonKey_localization",
		})
	end,
	packages = {},
}
