local mod = get_mod("SkeletonKey")

-- ───────────────────── ❀ ─────────────────────
--  State & Helpers
-- ───────────────────── ❀ ─────────────────────

local G = rawget(_G, "__skeletonkey")
if not G then
	G = {}
	rawset(_G, "__skeletonkey", G)
end

local SK = G.SK or {}
G.SK = SK
SK.VERSION = "0.5.0"

SK.now = function()
	local ok, t = pcall(Application.time_since_launch)
	return ok and t or 0
end

SK.level_world = function()
	local ok, world = pcall(function()
		return Managers.world and Managers.world:world("level_world")
	end)

	return ok and world or nil
end

SK.level_name = function()
	local ok, name = pcall(function()
		return Managers.state.mission and Managers.state.mission:mission_name()
	end)

	return ok and type(name) == "string" and name ~= "" and name or nil
end

SK.level_title = function(level)
	local ok, title = pcall(function()
		local t = require("scripts/settings/mission/mission_templates")[level]

		return t and t.mission_name and Localize(t.mission_name)
	end)

	if ok and type(title) == "string" and title ~= "" and string.sub(title, 1, 1) ~= "<" then
		return title
	end

	return tostring(level)
end

SK.level_fits_in = function(level, here)
	return type(level) ~= "string" or level == "" or here == nil or level == here
end

SK.level_fits = function(level)
	return SK.level_fits_in(level, SK.level_name())
end

SK.alive = function(unit)
	if unit == nil then
		return false
	end

	local ok, alive = pcall(Unit.alive, unit)

	return ok and alive == true
end

SK.is_folder = function(path)
	local ffi = Mods and Mods.lua and Mods.lua.ffi

	if not ffi then
		return true
	end

	pcall(ffi.cdef, "unsigned long GetFileAttributesA(const char* name);")

	local ok, attrs = pcall(function()
		return tonumber(ffi.C.GetFileAttributesA(path))
	end)

	if not ok or type(attrs) ~= "number" then
		return true
	end

	return attrs ~= 4294967295 and math.floor(attrs / 16) % 2 == 1
end

SK.home_root = function()
	local okg, root = pcall(os.getenv, "APPDATA")

	if okg and type(root) == "string" and root ~= "" and not string.find(root, "?", 1, true)
		and SK.is_folder(root .. "\\Fatshark\\Darktide") then
		return root .. "\\Fatshark\\Darktide\\SkeletonKey"
	end

	return nil
end

SK.HOME = SK.home_root()

SK.spawnable = function(key)
	if type(key) ~= "string" or key == "" then
		return false
	end

	local ok, can = pcall(Application.can_get_resource, "unit", key)

	return ok and can == true
end

SK.node_ok = function(unit, node)
	if type(node) ~= "number" or node < 1 or node % 1 ~= 0 then
		return false
	end

	local ok, n = pcall(Unit.num_scene_graph_items, unit)

	return ok and type(n) == "number" and node <= n
end

SK.numbers = function(list, count)
	if type(list) ~= "table" then
		return false
	end

	for i = 1, count do
		local v = list[i]

		if type(v) ~= "number" or v ~= v or v == math.huge or v == -math.huge then
			return false
		end
	end

	return true
end

SK.player_unit = function()
	local ok, unit = pcall(function()
		local player = Managers.player and Managers.player:local_player(1)

		return player and player.player_unit
	end)

	return ok and unit or nil
end

SK.player_alive = function()
	return SK.alive(SK.player_unit())
end

SK.in_hub = function()
	local ok, name = pcall(function()
		return Managers.state.game_mode:game_mode_name()
	end)

	return ok and name == "hub"
end

SK.networked = function(unit)
	local spawner = Managers.state and Managers.state.unit_spawner

	if not spawner or not spawner.game_object_id then
		return false
	end

	local ok, id = pcall(spawner.game_object_id, spawner, unit)

	return ok and id ~= nil
end

SK.tail = function(s, cap)
	s = tostring(s or "")
	if #s <= cap then
		return s
	end
	return "..." .. string.sub(s, -(cap - 3))
end

SK.trim = function(s)
	return (string.gsub(tostring(s or ""), "^%s*(.-)%s*$", "%1"))
end

SK.compile = function(source, name)
	local loader = (Mods and Mods.lua and Mods.lua.loadstring) or rawget(_G, "loadstring")
	if not loader then
		return nil, "no loadstring available"
	end
	if type(source) ~= "string" or string.byte(source, 1) == 27 then
		return nil, "not Lua text"
	end
	local chunk, err = loader(source, name or "=sk")
	if not chunk then
		return nil, tostring(err)
	end
	return chunk
end

SK.say = function(line)
	pcall(mod.info, mod, tostring(line))
end

SK.hud = function(line_a, line_b, ttl)
	G.hud = { text = tostring(line_a or ""), until_t = SK.now() + (tonumber(ttl) or 1.5) }
end

SK.secs = function(v)
	return tonumber(string.format("%.3f", tonumber(v) or 0)) or 0
end

SK.num = function(v)
	local s = string.format("%.2f", tonumber(v) or 0)
	s = string.gsub(s, "0+$", "")
	s = string.gsub(s, "%.$", "")
	return s
end

SK.count = function(n, word)
	return n .. " " .. word .. (n == 1 and "" or "s")
end

SK.finite = function(v, fallback)
	v = tonumber(v)

	if v == nil or v ~= v or v == math.huge or v == -math.huge then
		return fallback
	end

	return v
end

SK.fine = function(v, places)
	local s = string.format("%." .. places .. "f", tonumber(v) or 0)

	s = string.gsub(s, "0+$", "")
	s = string.gsub(s, "%.$", "")

	return s == "-0" and "0" or s
end

SK.blocked = function()
	local ok, blocked = pcall(function()
		local ui = Managers and Managers.ui
		return ui and ui.chat_using_input and ui:chat_using_input() or false
	end)
	return ok and blocked or false
end

-- ───────────────────── ❀ ─────────────────────
--  Free Flight
-- ───────────────────── ❀ ─────────────────────

SK.RIGHT_BUTTON = Mouse and Mouse.button_index and Mouse.button_index("right") or nil
SK.STILL = { move_forward = true, move_backward = true, move_left = true, move_right = true, jump = true, jump_held = true,
	crouch = true, crouching = true, sprint = true, sprinting = true, dodge = true }
SK.FLY_ORPHAN = 30

if not Managers.free_flight then
	local ok, FreeFlightManager = pcall(require, "scripts/foundation/managers/free_flight/free_flight_manager")
	if ok and FreeFlightManager then
		local made, manager = pcall(FreeFlightManager.new, FreeFlightManager)
		if made and manager then
			Managers.free_flight = manager
			manager.STD_MINIMUM_SPEED = 0.5
			manager.STD_MAXIMUM_SPEED = 30
		end
	end
end

SK.FLY_KEYS = { look = true, move_forward = true, move_backward = true, move_left = true, move_right = true,
	move_up = true, move_down = true, move_controller = true, speed_change = true }

SK.nothing = function(value)
	local kind = type(value)

	if kind == "number" then
		return 0
	elseif kind == "boolean" then
		return false
	elseif kind == "userdata" then
		return Vector3(0, 0, 0)
	end

	return value
end

SK.fly_get = function(get, real, action_name, ...)
	if not G.fly_want then
		return get(real, action_name, ...)
	end
	if action_name == "roll_left" or action_name == "roll_right" then
		return 0
	end
	if not real[action_name] then
		return false
	end
	local value = get(real, action_name, ...)
	if not G.fly_free or not SK.FLY_KEYS[action_name] then
		return SK.nothing(value)
	end
	return value
end

SK.fly_input_make = function(real)
	local stand_in = { _sk_real = real }
	stand_in.get = function(_, action_name, ...)
		return SK.fly_get(real.get, real, action_name, ...)
	end
	stand_in.null_service = function()
		return stand_in
	end
	return setmetatable(stand_in, { __index = real })
end

SK.fly_adopt_input = function()
	local ff = Managers.free_flight
	if ff and ff._input and not ff._input._sk_real then
		ff._input = SK.fly_input_make(ff._input)
	end
end

SK.fly_shift = function()
	for _, name in ipairs({ "left shift", "right shift" }) do
		local oki, index = pcall(Keyboard.button_index, name)

		if oki and index then
			local okb, down = pcall(Keyboard.button, index)

			if okb and down and down > 0 then
				return true
			end
		end
	end

	return false
end

SK.fly_boost = function(ff)
	local cam = ff._free_flight_cameras and ff._free_flight_cameras.global

	if not cam or type(cam.translation_speed) ~= "number" then
		return
	end

	local fast = SK.fly_shift()

	if type(ff.STD_MAXIMUM_SPEED) == "number" then
		if fast then
			G.fly_cap = G.fly_cap or ff.STD_MAXIMUM_SPEED
			ff.STD_MAXIMUM_SPEED = G.fly_cap * 2
		elseif G.fly_cap then
			ff.STD_MAXIMUM_SPEED = G.fly_cap
			G.fly_cap = nil
		end
	end

	if fast then
		if not G.fly_base or cam.translation_speed ~= G.fly_fast then
			G.fly_base = cam.translation_speed
		end

		G.fly_fast = G.fly_base * 2
		cam.translation_speed = G.fly_fast
	elseif G.fly_base then
		if cam.translation_speed == G.fly_fast then
			cam.translation_speed = G.fly_base
		end

		G.fly_base, G.fly_fast = nil, nil
	end
end

SK.other_flight = function()
	local ok, data = pcall(function()
		local cf = rawget(_G, "get_mod") and get_mod("camera_freeflight")

		return cf and cf:persistent_table("freeflight_data")
	end)

	return ok and type(data) == "table" and data or nil
end

SK.other_drives = function()
	if SK.windows_open() > 0 then
		return false
	end

	local data = SK.other_flight()

	return data ~= nil and data.enable_freeflight == true
end

SK.other_stand_down = function()
	local data = SK.other_flight()

	if data and data.enable_freeflight then
		data.enable_freeflight = false

		return true
	end

	return false
end

SK.fly_update = function(dt)
	local ff = Managers.free_flight
	if not ff or not G.fly_want then
		return
	end
	SK.fly_adopt_input()
	SK.fly_boost(ff)

	if SK.windows_open() > 0 then
		SK.other_stand_down()
	end

	if SK.other_drives() then
		return
	end

	local t = Managers.time and Managers.time:time("main") or 0
	pcall(ff.update, ff, dt, t)
end

SK.ingame_input = function()
	if not SK.ingame_svc then
		local ok, svc = pcall(function()
			return Managers.input and Managers.input:get_input_service("Ingame")
		end)

		SK.ingame_svc = ok and svc or nil
	end

	return SK.ingame_svc
end

SK.STILL_PASS = { voip_push_to_talk = true, spectate_next = true }

SK.still_input = function(func, self, action_name, ...)
	if G.fly_want and not SK.STILL_PASS[action_name]
		and (SK.STILL[action_name] or (self ~= nil and self == SK.ingame_input())) then
		local value = func(self, action_name, ...)
		local kind = type(value)

		if kind == "boolean" then
			return false
		elseif kind == "number" then
			return 0
		elseif kind == "userdata" then
			return Vector3(0, 0, 0)
		end

		return value
	end
	if SK.WALL_MOVES and SK.WALL_MOVES[action_name] then
		return SK.wall_input(func, self, action_name, ...)
	end
	return func(self, action_name, ...)
end

-- ───────────────────── ❀ ─────────────────────
--  Walls
-- ───────────────────── ❀ ─────────────────────

SK.EXPORT_WALLS = [=[
local SK = ...

SK.now = SK.now or function()
	local ok, t = pcall(Application.time_since_launch)

	return ok and t or 0
end

SK.alive = SK.alive or function(unit)
	if unit == nil then
		return false
	end

	local ok, alive = pcall(Unit.alive, unit)

	return ok and alive == true
end

SK.player_unit = SK.player_unit or function()
	local ok, unit = pcall(function()
		local player = Managers.player and Managers.player:local_player(1)

		return player and player.player_unit
	end)

	return ok and unit or nil
end

SK.in_hub = SK.in_hub or function()
	local ok, name = pcall(function()
		return Managers.state.game_mode:game_mode_name()
	end)

	return ok and name == "hub"
end

SK.WALL_MOVES = { move_forward = true, move_backward = true, move_left = true, move_right = true }
SK.WALL_FILTER = "filter_player_mover"
SK.WALL_BODY = 0.47
SK.WALL_KEEP = 0.55
SK.WALL_PER_SPEED = 0.045
SK.WALL_SLOWING = 6
SK.WALL_STANDING = 0.5
SK.WALL_TICK = 0.1
SK.WALL_HALT = 1
SK.WALL_HEIGHTS = { 0.3, 0.9, 1.5 }
SK.WALL_BALLS = { 0.52, 0.95, 1.38 }
SK.WALL_EVERY = 0.25
SK.WALL_FRAME = 1 / 120
SK.WALL_TOUCH = 0.02
SK.WALL_INSIDE = 3
SK.WALL_SLIDE = 0.35
SK.WALL_SLIVER = 0.1
SK.WALL_INWARD = 0.5
SK.WALL_GRAZE = 0.05
SK.WALL_EXIT = 2
SK.WALL_HITS = 16
SK.WALL_GROUND = 0.3
SK.WALL_NEAR = 0.1
SK.WALL_BACK = 0.82

SK.wall_hosting = function()
	local session = Managers.state and Managers.state.game_session

	if not session then
		return true
	end

	local ok, server = pcall(session.is_server, session)

	return not ok or server == true
end

SK.wall_set = function(now, me)
	local seen = SK.wall_seen

	if seen and seen.me == me and now >= seen.at and now - seen.at < SK.WALL_EVERY then
		return seen.units, seen.any, seen.mine
	end

	local units, any, mine = {}, false, {}
	local more = SK.wall_more and SK.wall_more()

	for _, list in ipairs({ SK.copies or {}, more ~= SK.copies and more or {} }) do
		for _, unit in ipairs(list) do
			if SK.alive(unit) then
				units[unit], any = true, true
			end
		end
	end

	if not any and SK.wall_prune then
		SK.wall_prune()
	end

	local function walk(unit, depth)
		if depth > 8 or not SK.alive(unit) then
			return
		end

		mine[unit] = true

		local ok, kids = pcall(Unit.get_child_units, unit)

		for _, kid in ipairs(ok and type(kids) == "table" and kids or {}) do
			walk(kid, depth + 1)
		end
	end

	if any then
		walk(me, 0)
	end

	SK.wall_seen = { at = now, me = me, units = units, any = any, mine = mine }

	return units, any, mine
end

SK.wall_velocity = function(me)
	local ok, vel = pcall(function()
		return Vector3.flat(ScriptUnit.extension(me, "unit_data_system"):read_component("locomotion").velocity_current)
	end)

	return ok and vel or nil
end

SK.wall_position = function(me)
	local ok, at = pcall(function()
		local p = ScriptUnit.extension(me, "unit_data_system"):read_component("locomotion").position

		return Vector3(p.x, p.y, p.z)
	end)

	if ok and at then
		return at
	end

	return SK.node_ok and SK.node_ok(me, 1) and Unit.world_position(me, 1) or nil
end

SK.wall_state = function(me)
	local ok, state, data, halt = pcall(function()
		local templates = require("scripts/settings/player_character/hub_movement_settings_templates")
		local data = ScriptUnit.extension(me, "unit_data_system")
		local breed = data.breed and data:breed()
		local set = templates[breed and breed.name or "human"] or templates.human

		return set.move_states[data:read_component("hub_jog_character_state").move_state], data,
			set.shared and set.shared.stop_move_speed_threshold
	end)

	if not ok or type(state) ~= "table" then
		return nil
	end

	local pace = { halt = type(halt) == "number" and halt >= 0 and halt or SK.WALL_HALT }

	for _, key in ipairs({ "repeat_move_input_timer", "acceleration", "move_speed", "deceleration" }) do
		if type(state[key]) ~= "number" or state[key] < 0 then
			return nil
		end

		pace[key] = state[key]
	end

	return (pace.acceleration > 0 and pace.deceleration > 0) and pace or nil, data
end

SK.wall_brake = function(state, v)
	local slid = 0

	for _ = 1, 100 do
		v = v - state.deceleration * SK.WALL_TICK

		if v < (state.halt or SK.WALL_HALT) then
			break
		end

		slid = slid + v * SK.WALL_TICK
	end

	return slid
end

SK.wall_next = function(state, speed)
	return state and math.max(speed, math.min(speed + state.acceleration * SK.WALL_TICK, state.move_speed)) or speed
end

SK.wall_stop = function(state, speed)
	if not state then
		return SK.WALL_PER_SPEED * speed * speed
	end

	local v = SK.wall_next(state, speed)

	return v * SK.WALL_TICK + SK.wall_brake(state, v)
end

SK.wall_start = function(state, speed)
	local v, went = speed, 0

	for step = 1, math.min(100, math.floor(state.repeat_move_input_timer / SK.WALL_TICK - 1e-6) + 1) do
		if step == 1 then
			v = v - state.deceleration * SK.WALL_TICK
			v = v < state.halt and 0 or v
		elseif v > state.move_speed then
			v = math.max(state.move_speed, v - state.deceleration * SK.WALL_TICK)
		else
			v = math.min(state.move_speed, v + state.acceleration * SK.WALL_TICK)
		end

		went = went + v * SK.WALL_TICK
	end

	return went + SK.wall_brake(state, v)
end

SK.wall_stopped = function(data)
	local ok, still = pcall(function()
		local steer = data:read_component("locomotion_steering")

		return steer.local_move_x == 0 and steer.local_move_y == 0
	end)

	return ok and still == true
end

SK.wall_world = function(me)
	local ok, ext = pcall(ScriptUnit.extension, me, "smart_targeting_system")

	return ok and ext and ext._physics_world or nil
end

SK.wall_ground = function(units, unit, normal)
	return units ~= nil and not units[unit] and normal ~= nil and normal.z > SK.WALL_GROUND
end

SK.wall_first = function(world, from, dir, reach, mine, overlaps, units)
	local ok, hits, n = pcall(PhysicsWorld.raycast, world, from, dir, reach, "all", "types", "both", "max_hits",
		SK.WALL_HITS, "collision_filter", SK.WALL_FILTER)

	for i = 1, (ok and type(hits) == "table") and (n or #hits) or 0 do
		local hit = hits[i]
		local owned, unit = pcall(Actor.unit, hit[4])
		local t = tonumber(hit[2]) or 0

		if owned and unit ~= nil and not mine[unit] and (overlaps or t > SK.WALL_TOUCH)
			and not SK.wall_ground(units, unit, hit[3]) then
			return unit, hit[3], t
		end
	end

	return nil
end

SK.wall_inside = function(world, center, dir, units, mine)
	local ok, hits, n = pcall(PhysicsWorld.raycast, world, center, dir, SK.WALL_TOUCH, "all", "types", "both", "max_hits",
		SK.WALL_HITS, "collision_filter", SK.WALL_FILTER)

	for i = 1, (ok and type(hits) == "table") and (n or #hits) or 0 do
		local owned, unit = pcall(Actor.unit, hits[i][4])

		if owned and unit ~= nil and not mine[unit] and units[unit] and (tonumber(hits[i][2]) or 1) < 1e-3 then
			return unit
		end
	end

	return nil
end

SK.wall_exit = function(world, center, unit, mine)
	local best, way = math.huge, nil

	for k = 0, 7 do
		local a = k * math.pi / 4
		local out = Vector3(math.cos(a), math.sin(a), 0)
		local ok, hits, n = pcall(PhysicsWorld.raycast, world, center + out * SK.WALL_EXIT, out * -1, SK.WALL_EXIT, "all",
			"types", "both", "max_hits", SK.WALL_HITS, "collision_filter", SK.WALL_FILTER)
		local depth

		for i = 1, (ok and type(hits) == "table") and (n or #hits) or 0 do
			local owned, met = pcall(Actor.unit, hits[i][4])
			local t = tonumber(hits[i][2]) or 0

			if owned and met == unit and t > SK.WALL_TOUCH then
				depth = SK.WALL_EXIT - t

				break
			end
		end

		if depth and depth < best
			and SK.wall_first(world, center + out * (depth + SK.WALL_TOUCH), out, SK.WALL_KEEP, mine, true) == nil then
			best, way = depth, out
		end
	end

	return way
end

SK.wall_ball = function(world, from, dir, reach, mine, units)
	local ok, hits = pcall(PhysicsWorld.linear_sphere_sweep, world, from, from + dir * math.max(reach, SK.WALL_TOUCH),
		SK.WALL_BODY, SK.WALL_HITS, "types", "both", "collision_filter", SK.WALL_FILTER)
	local best, unit, normal = math.huge, nil, nil

	for _, hit in ipairs(ok and type(hits) == "table" and hits or {}) do
		local owned, met = pcall(Actor.unit, hit.actor)
		local t = tonumber(hit.distance) or 0

		if owned and met ~= nil and not mine[met] and t > 1e-4 and t < best
			and not SK.wall_ground(units, met, hit.normal) then
			best, unit, normal = t, met, hit.normal
		end
	end

	return unit, normal, best + SK.WALL_BODY
end

SK.wall_ring = function(world, at, dir, units, mine)
	local ring, side = {}, Vector3(-dir.y, dir.x, 0)

	for _, out in ipairs({ side, side * -1, Vector3.normalize(dir + side), Vector3.normalize(dir - side) }) do
		for i = 1, 2 do
			local unit, normal = SK.wall_first(world, at + Vector3(0, 0, SK.WALL_HEIGHTS[i]), out,
				SK.WALL_BODY + SK.WALL_TOUCH, mine, false, units)

			if unit ~= nil and units[unit] then
				ring[#ring + 1] = { unit, normal }
			end
		end
	end

	return ring
end

SK.wall_normals = function(world, at, dir, units, mine, reach, ring)
	local found, far, near, behind = {}, {}, math.huge, nil
	local center = at + Vector3(0, 0, SK.WALL_HEIGHTS[2])

	local function take(unit, normal, t)
		if unit == nil or not units[unit] or not normal then
			return
		end

		if behind == nil then
			behind = SK.wall_first(world, center, dir * -1, SK.WALL_INSIDE, mine, true) or false
		end

		if behind ~= unit then
			local flat = Vector3(normal.x, normal.y, 0)
			local len = Vector3.length(flat)

			found[#found + 1] = len > 0.01 and flat * (1 / len) or Vector3(0, 0, 0)
			far[#found] = t
			near = math.min(near, t or near)
		end
	end

	local side = Vector3(-dir.y, dir.x, 0)

	for _, h in ipairs(SK.WALL_HEIGHTS) do
		for s = -1, 1 do
			take(SK.wall_first(world, at + Vector3(0, 0, h) + side * (s * SK.WALL_BODY), dir, reach, mine, false, units))
		end
	end

	for _, h in ipairs(SK.WALL_BALLS) do
		take(SK.wall_ball(world, at + Vector3(0, 0, h), dir, reach - SK.WALL_BODY, mine, units))
	end

	for _, hit in ipairs(ring) do
		take(hit[1], hit[2])
	end

	local kept = {}

	for i, n in ipairs(found) do
		if not far[i] or far[i] <= near + SK.WALL_NEAR then
			kept[#kept + 1] = n
		end
	end

	return kept
end

SK.wall_cut = function(x, y, right, fwd, normals)
	local d = right * x + fwd * y

	for _ = 1, 2 do
		for _, n in ipairs(normals) do
			local into = Vector3.dot(d, n)

			if into < 0 then
				d = d - n * into
			end
		end
	end

	for _, n in ipairs(normals) do
		if Vector3.dot(d, n) < -1e-6 then
			return 0, 0
		end
	end

	return Vector3.dot(d, right), Vector3.dot(d, fwd)
end

SK.wall_compute = function(func, self, now, me, at)
	if not me or (SK.wall_off and SK.wall_off()) or SK.wall_hosting() then
		return nil
	end

	local units, any, mine = SK.wall_set(now, me)

	if not any then
		return nil
	end

	local f, b = tonumber(func(self, "move_forward")) or 0, tonumber(func(self, "move_backward")) or 0
	local l, r = tonumber(func(self, "move_left")) or 0, tonumber(func(self, "move_right")) or 0
	local x, y = r - l, f - b

	if x == 0 and y == 0 then
		return nil
	end

	local cm = Managers.state and Managers.state.camera
	local rot = cm and cm:camera_rotation("player1")
	local world = SK.wall_world(me)

	if not at or not rot or not world then
		return nil
	end

	local fwd = Vector3.normalize(Vector3.flat(Quaternion.forward(rot)))
	local right = Vector3.normalize(Vector3.flat(Quaternion.right(rot)))
	local dir = Vector3.normalize(right * x + fwd * y)
	local vel = SK.wall_velocity(me)
	local speed = vel and Vector3.length(vel) or 0
	local held = math.max(speed, (SK.wall_held or 0) - SK.WALL_SLOWING * math.max(0, now - (SK.wall_held_at or now)))

	SK.wall_held, SK.wall_held_at = held, now

	local state, data = SK.wall_state(me)
	local reach = SK.WALL_KEEP + SK.wall_stop(state, held)

	if state and (speed < SK.WALL_STANDING or SK.wall_stopped(data)) and SK.in_hub() then
		reach = math.max(reach, SK.WALL_KEEP + SK.wall_start(state, speed))
	end

	local center = at + Vector3(0, 0, SK.WALL_HEIGHTS[2])
	local within = SK.wall_inside(world, center, dir, units, mine)

	if within then
		local way = SK.wall_exit(world, center, within, mine)

		if way and Vector3.dot(dir, way) < 0.5 then
			SK.walls_cut = (SK.walls_cut or 0) + 1

			return { move_forward = 0, move_backward = 0, move_right = 0, move_left = 0 }
		end
	end

	local ring = SK.wall_ring(world, at, dir, units, mine)
	local normals = SK.wall_normals(world, at, dir, units, mine, reach, ring)
	local inward = 0

	if speed > 0 and Vector3.dot(dir, vel) > -SK.WALL_BACK * speed then
		local ahead = vel * (SK.wall_next(state, speed) / speed)

		for _, n in ipairs(SK.wall_normals(world, at, vel * (1 / speed), units, mine, reach, ring)) do
			inward = math.max(inward, -Vector3.dot(ahead, n))
		end
	end

	if #normals == 0 and inward <= SK.WALL_INWARD then
		return nil
	end

	local nx, ny = SK.wall_cut(x, y, right, fwd, normals)
	local least = inward > SK.WALL_SLIVER and SK.WALL_SLIDE or SK.WALL_SLIVER

	if inward > SK.WALL_INWARD or nx * nx + ny * ny < least * least * (x * x + y * y) then
		nx, ny = 0, 0
	else
		local along = Vector3.normalize(right * nx + fwd * ny)

		for _, n in ipairs(SK.wall_normals(world, at, along, units, mine, reach, ring)) do
			if Vector3.dot(along, n) < -SK.WALL_GRAZE then
				nx, ny = 0, 0

				break
			end
		end
	end

	SK.walls_cut = (SK.walls_cut or 0) + 1

	return {
		move_forward = ny > 0 and ny or 0, move_backward = ny < 0 and -ny or 0,
		move_right = nx > 0 and nx or 0, move_left = nx < 0 and -nx or 0,
	}
end

SK.wall_input = function(func, self, action_name, ...)
	local raw = func(self, action_name, ...)
	local more = SK.wall_more and SK.wall_more()

	if type(raw) ~= "number" or (#(SK.copies or {}) == 0 and #(more or {}) == 0) then
		return raw
	end

	local now = SK.now()
	local w = SK.wall_frame
	local me = SK.player_unit()
	local alive = SK.alive(me)
	local place = alive and SK.wall_position(me) or nil
	local px, py = place and place.x, place and place.y

	if not (w and w.service == self and now >= w.at and now - w.at < SK.WALL_FRAME and w.x == px and w.y == py) then
		local ok, cut = pcall(SK.wall_compute, func, self, now, alive and me, place)

		w = { at = now, service = self, x = px, y = py, cut = ok and cut or nil }
		SK.wall_frame = w
	end

	return w.cut and w.cut[action_name] or raw
end

SK.WALL_VERSION = 2

return SK
]=]

SK.wall_off = function()
	return G.fly_want
end

SK.wall_more = function()
	local shared = rawget(_G, "__skeletonkey_walls")

	return type(shared) == "table" and shared.copies or nil
end

do
	local walls, err = SK.compile(SK.EXPORT_WALLS, "@SkeletonKey walls")

	if walls then
		walls(SK)
	else
		SK.say("walls|off|" .. tostring(err))
	end
end

-- ───────────────────── ❀ ─────────────────────
--  Hooks
-- ───────────────────── ❀ ─────────────────────

do
	local dmf_now = rawget(_G, "get_mod") and get_mod("DMF") or nil

	if G.hooks_for ~= dmf_now then
		G.hooks_for = dmf_now
		G.hud_hooked, G.fly_hooked, G.fly_hooked_input, G.chat_hooked, G.world_hooked = nil, nil, nil, nil, nil
		G.keys_hooked, G.hooked, G.hud_registered = nil, nil, nil
	end
end

if not G.hud_hooked and rawget(_G, "CLASS") and CLASS.UIHud then
	G.hud_hooked = true

	mod:hook_safe(CLASS.UIHud, "_update_element_visibility", function(hud)
		SK.hud_hide_now(hud)
	end)
end

if not G.fly_hooked and rawget(_G, "CLASS") and CLASS.StateGame and CLASS.FreeFlightDefaultInput then
	G.fly_hooked = true
	mod:hook_safe(CLASS.StateGame, "update", function(self, dt)
		SK.fly_update(dt)
	end)
	mod:hook(CLASS.FreeFlightDefaultInput, "get", function(func, self, action_name, ...)
		return SK.fly_get(func, self, action_name, ...)
	end)
end

if not G.world_hooked and rawget(_G, "CLASS") and CLASS.WorldManager then
	G.world_hooked = true
	mod:hook(CLASS.WorldManager, "destroy_world", function(func, self, world_or_name, ...)
		pcall(SK.world_ending, world_or_name)

		return func(self, world_or_name, ...)
	end)
end

if not G.fly_hooked_input and rawget(_G, "CLASS") and CLASS.FreeFlightManager and CLASS.InputService then
	G.fly_hooked_input = true
	mod:hook(CLASS.FreeFlightManager, "_get_input", function(func, self, ...)
		return self._input or func(self, ...)
	end)
	mod:hook(CLASS.InputService, "_get", function(func, self, action_name, ...)
		return SK.still_input(func, self, action_name, ...)
	end)
	mod:hook(CLASS.InputService, "_get_simulate", function(func, self, action_name, ...)
		return SK.still_input(func, self, action_name, ...)
	end)
end

-- ───────────────────── ❀ ─────────────────────
--  Key Guards
-- ───────────────────── ❀ ─────────────────────

SK.keys_in = false

local function keybind_is_ours(who)
	local name = type(who) == "table" and type(who.get_name) == "function" and who:get_name() or who

	return name == "SkeletonKey"
end

SK.keybind_blocked = function(who, is_pressed)
	if not SK.keys_in or is_pressed == false then
		return false
	end

	if keybind_is_ours(who) then
		return G.view_typing == true
	end

	return SK.windows_open() > 0
end

SK.guard_keybinds = function(dmf, hook)
	hook(dmf, "check_keybinds", function(func, ...)
		SK.keys_in = true

		local ok, err = pcall(func, ...)

		SK.keys_in = false

		if not ok then
			error(err, 0)
		end
	end)
	hook(dmf, "safe_call_nr", function(func, who, prefix, fn, ...)
		if SK.keybind_blocked(who, (...)) then
			return
		end

		return func(who, prefix, fn, ...)
	end)
	hook(dmf, "keybind_toggle_view", function(func, who, view, data, can, pressed)
		if SK.keybind_blocked(who, pressed) then
			return
		end

		return func(who, view, data, can, pressed)
	end)
	hook(dmf, "mod_state_changed", function(func, name, enabled)
		if SK.keybind_blocked(name, true) then
			return
		end

		return func(name, enabled)
	end)
end

SK.chat_shut = function()
	return SK.windows_open() > 0 and not SK.chat_let
end

SK.guard_chat = function(chat, hook)
	hook(chat, "_start_chatting", function(func, ...)
		if SK.chat_shut() then
			return
		end

		return func(...)
	end)
end

SK.chat_parts = function()
	local ok, chat, elements = pcall(function()
		local ui = Managers.ui
		local ce = ui and ui.ui_constant_elements and ui:ui_constant_elements()

		return ce and ce.element and ce:element("ConstantElementChat"), ce
	end)

	if not ok then
		return nil, nil
	end

	return chat, elements
end

mod.chat_typing = function()
	return SK.blocked()
end

mod.chat_open = function()
	local chat, elements = SK.chat_parts()

	if not (chat and chat._start_chatting and chat.set_visible and elements.ui_renderer) then
		return "Chat is not ready yet. Try again soon."
	end

	if SK.blocked() then
		return nil
	end

	if not chat._is_visible then
		G.chat_shown = true

		pcall(chat.set_visible, chat, true)
	end

	SK.chat_let = true

	local ok = pcall(chat._start_chatting, chat, elements:ui_renderer())

	SK.chat_let = nil

	if not (ok and SK.blocked()) then
		return "Chat would not open. Try again."
	end

	return nil
end

SK.chat_tick = function(now)
	if not G.chat_shown or (SK.blocked() and not now) then
		return
	end

	G.chat_shown = nil

	local _, elements = SK.chat_parts()

	if elements then
		elements._current_group_name = nil
	end
end

if not G.chat_hooked then
	local chat = rawget(_G, "CLASS") and CLASS.ConstantElementChat

	if chat and chat._start_chatting then
		G.chat_hooked = true
		SK.guard_chat(chat, function(obj, name, fn) mod:hook(obj, name, fn) end)
	end
end

if not G.keys_hooked then
	local dmf = rawget(_G, "get_mod") and get_mod("DMF")

	if dmf and dmf.check_keybinds and dmf.safe_call_nr and dmf.keybind_toggle_view and dmf.mod_state_changed then
		G.keys_hooked = true
		SK.guard_keybinds(dmf, function(obj, name, fn) mod:hook(obj, name, fn) end)
	end
end

-- ───────────────────── ❀ ─────────────────────
--  Hidden HUD
-- ───────────────────── ❀ ─────────────────────

SK.HUD_HIDDEN = { "HudElementTeamPanelHandler", "HudElementWorldMarkers",
	"HudElementInteraction", "HudElementNameplates" }

SK.hud_hide_now = function(hud)
	if not hud then
		return
	end

	if not G.fly_want then
		if G.hud_hid then
			G.hud_hid = nil
			hud._current_group_name = nil
			hud._refresh_retained = true
		end

		return
	end

	local visible = hud._currently_visible_elements

	if not visible then
		return
	end

	for i = 1, #SK.HUD_HIDDEN do
		if visible[SK.HUD_HIDDEN[i]] then
			visible[SK.HUD_HIDDEN[i]] = false
			hud._refresh_retained = true
			G.hud_hid = true
		end
	end
end

-- ───────────────────── ❀ ─────────────────────
--  Windows
-- ───────────────────── ❀ ─────────────────────

SK.free_flight = function(on)
	G.fly_want = on and true or nil
	SK.ingame_svc = nil
	if not on then
		G.fly_free = nil
	end

	local ff = Managers.free_flight
	local cam = ff and ff._free_flight_cameras and ff._free_flight_cameras.global
	if not ff or not cam then
		return false
	end
	if on and not ff:is_in_free_flight() then
		return pcall(ff._enter_global_free_flight, ff, cam)
	elseif not on and ff:is_in_free_flight() then
		local name = cam.viewport_world_name
		local okh, there = pcall(function()
			return name ~= nil and Managers.world and Managers.world:has_world(name)
		end)

		if okh and there and pcall(ff._exit_global_free_flight, ff, cam) and not cam.active then
			return true
		end

		cam.active = false
		cam.viewport_world_name = nil

		return true
	end
	return true
end

SK.world_ending = function(world_or_name)
	local name = type(world_or_name) == "string" and world_or_name or nil

	if not name then
		local ok, got = pcall(World.get_data, world_or_name, "name")

		name = ok and got or nil
	end

	local ff = Managers.free_flight
	local cam = ff and ff._free_flight_cameras and ff._free_flight_cameras.global

	if not name or not cam or not cam.active or cam.viewport_world_name ~= name then
		return
	end

	G.peek, G.peek_views, G.peek_world, G.fly_home_in = nil, nil, nil, nil
	SK.free_flight(false)
end

SK.WINDOWS = { "skeletonkey_pose_view" }

SK.windows_open = function()
	local ui = Managers.ui
	local n = 0
	for i = 1, #SK.WINDOWS do
		if ui and ui:view_active(SK.WINDOWS[i]) then
			n = n + 1
		end
	end
	return n
end

mod.panel_open = function(view_name)
	SK.free_flight(true)

	return "camera out"
end

mod.panel_close = function(view_name)
	if G.peek then
		return "peeking"
	end
	if SK.windows_open() > 1 then
		return "another window is open"
	end

	mod.opener_reset()

	G.fly_home_in = 2

	return "camera home soon"
end

-- ───────────────────── ❀ ─────────────────────
--  Peek & Opener
-- ───────────────────── ❀ ─────────────────────

mod.opener_on = function()
	return not G.opener_spent
end

mod.opener_spend = function()
	G.opener_spent = true
end

mod.opener_reset = function()
	G.opener_spent = nil
end

mod.peek_begin = function(view_name)
	if not SK.RIGHT_BUTTON or not Managers.ui then
		return "no mouse"
	end
	if G.peek then
		return "peeking"
	end
	local ui = Managers.ui
	local hidden = {}
	for i = 1, #SK.WINDOWS do
		if ui:view_active(SK.WINDOWS[i]) then
			hidden[#hidden + 1] = SK.WINDOWS[i]
		end
	end
	G.peek = view_name
	G.peek_views = hidden
	G.peek_world = SK.level_world()
	G.fly_free = true
	G.peek_count = (G.peek_count or 0) + 1
	for i = 1, #hidden do
		pcall(ui.close_view, ui, hidden[i])
	end
	return "peeking"
end

SK.WHEEL_AXIS = Mouse and Mouse.axis_index and Mouse.axis_index("wheel") or nil
SK.FLY_STEP = 1.1

SK.fly_speed_tick = function()
	local ff = Managers.free_flight
	local cam = ff and ff._free_flight_cameras and ff._free_flight_cameras.global
	if not cam or not ff:is_in_free_flight() then
		return
	end
	G.fly_speed = G.fly_speed or cam.translation_speed or 3
	if SK.WHEEL_AXIS then
		local ok, axis = pcall(Mouse.axis, SK.WHEEL_AXIS)
		local notch = ok and axis and axis.y or 0
		if notch ~= 0 then
			G.fly_speed = G.fly_speed * (SK.FLY_STEP ^ notch)
			G.fly_speed = math.max(ff.STD_MINIMUM_SPEED or 0.5, math.min(ff.STD_MAXIMUM_SPEED or 30, G.fly_speed))
			SK.hud(string.format("Fly speed %.1f", G.fly_speed), "", 1.5, "LT")
		end
	end
	cam.translation_speed = G.fly_speed
end

SK.peek_tick = function()
	if G.fly_home_in then
		G.fly_home_in = G.fly_home_in - 1
		if G.fly_home_in <= 0 then
			G.fly_home_in = nil
			SK.free_flight(false)
		end
	end
	if G.fly_want and not G.peek and not G.fly_home_in and SK.windows_open() == 0 then
		G.fly_orphan = (G.fly_orphan or 0) + 1

		if G.fly_orphan > SK.FLY_ORPHAN then
			G.fly_orphan = nil
			SK.free_flight(false)
		end
	else
		G.fly_orphan = nil
	end
	if not G.peek then
		return
	end
	local ok, held = pcall(Mouse.button, SK.RIGHT_BUTTON)
	if ok and held and held > 0 then
		SK.fly_speed_tick()
		return
	end
	local views = G.peek_views or { G.peek }
	local same = G.peek_world ~= nil and G.peek_world == SK.level_world()
	G.peek = nil
	G.peek_views = nil
	G.peek_world = nil
	G.fly_free = nil
	if not same or not SK.player_alive() then
		SK.free_flight(false)

		return
	end
	for i = 1, #views do
		if Managers.ui and not Managers.ui:view_active(views[i]) then
			pcall(Managers.ui.open_view, Managers.ui, views[i])
		end
	end
end

-- ───────────────────── ❀ ─────────────────────
--  Pick
-- ───────────────────── ❀ ─────────────────────

SK.PICK_REACH = 20
SK.PICK_HITS = 64
SK.PICK_FILTER = "filter_player_character_shooting_raycast"

G.pick = G.pick or { armed = false, at = 0, hex = "", name = "", pkg = "", dist = 0, pos = "", said = "", node = nil }

local pick = G.pick

SK.xyz = function(v)
	local ok, x, y, z = pcall(Vector3.to_elements, v)

	return ok and x and { x, y, z } or nil
end

SK.pick_run = function(me)
	if SK.object_locked() then
		return "locked"
	end

	local ok, ext = pcall(ScriptUnit.extension, me, "smart_targeting_system")

	if not ok or not ext or type(ext._targeting_parameters) ~= "function" or not ext._physics_world then
		return "no aim ray"
	end

	local aimed, origin, forward = pcall(ext._targeting_parameters, ext)

	if pick.ray then
		origin, forward = pick.ray.from:unbox(), pick.ray.dir:unbox()
		pick.ray = nil
		aimed = true
	end

	if not aimed or not origin or not forward then
		return "no aim ray"
	end

	local cast, hits, n = pcall(PhysicsWorld.raycast, ext._physics_world, origin, forward, SK.PICK_REACH,
		"all", "types", "both", "max_hits", SK.PICK_HITS, "collision_filter", SK.PICK_FILTER)

	local meshy, meshy_at = SK.pick_meshy(origin, forward, SK.PICK_REACH)

	if cast and hits then
		for i = 1, n or 0 do
		local hit = hits[i]
		local owned, unit = pcall(Actor.unit, hit[4])

		local reached = hit[2] or 0

		if owned and unit and unit ~= me and not SK.is_hidden(unit)
			and not (meshy and meshy_at and meshy_at < reached) then
			local hex = tostring(Unit.debug_name(unit)):match("%[(%x+)%]") or "?"
			local at = hit[1]
			local x, y, z = 0, 0, 0

			if at then
				local ok2, ex, ey, ez = pcall(Vector3.to_elements, at)

				if ok2 then
					x, y, z = ex, ey, ez
				end
			end

			local okn, node = pcall(Actor.node, hit[4])

			pick.node = okn and node or nil
			pick.unit = unit
			pick.hex = hex
			pick.name = ""
			pick.pkg = ""
			pick.dist = hit[2] or 0
			pick.pos = string.format("%.1f %.1f %.1f", x, y, z)
			pick.ray_o, pick.ray_d, pick.along = SK.xyz(origin), SK.xyz(forward), reached
			pick.at = SK.now()

			return nil
		end
		end
	end

	if meshy then
		local okd, debug_name = pcall(Unit.debug_name, meshy)
		local okp, at = pcall(function()
			return Mesh.world_position(Unit.mesh(meshy, 1))
		end)
		local mx, my, mz = 0, 0, 0

		if okp and at then
			local oke, ex, ey, ez = pcall(Vector3.to_elements, at)

			if oke then
				mx, my, mz = ex, ey, ez
			end
		end

		pick.unit = meshy
		pick.node = 1
		pick.hex = okd and tostring(debug_name):match("%[(%x+)%]") or ""
		pick.name = ""
		pick.pkg = ""
		pick.dist = 0
		pick.pos = string.format("%.1f %.1f %.1f", mx, my, mz)
		pick.ray_o, pick.ray_d, pick.along = SK.xyz(origin), SK.xyz(forward), meshy_at or 0
		pick.at = SK.now()

		return nil
	end

	pick.unit, pick.node = nil, nil
	pick.ray_o, pick.ray_d, pick.along = nil, nil, nil
	pick.at = SK.now()

	local o = G.object

	if o then
		o.unit, o.node, o.from, o.turn, o.crew = nil, nil, nil, nil, nil
	end

	return "nothing within " .. SK.PICK_REACH .. "m"
end

SK.MESH_REACH = 1.5

SK.MESH_SPAN_CAP = 4

SK.BUILD = 6

SK.MESH_LIST_FOR = 60

-- ───────────────────── ❀ ─────────────────────
--  Scene Marks
-- ───────────────────── ❀ ─────────────────────

SK.MARKS = { "/gizmos/", "reflection_probe", "core/units/camera", "core/gwnav/", "core/units/wwise" }

SK.marks_on = SK.marks_on or false

SK.mark_shape = function(u, name, half)
	if name and not string.find(name, "content/units/zz", 1, true) then
		return false
	end

	if half == nil then
		local okb, _, h = pcall(Unit.box, u)

		half = okb and h or nil
	end

	if not half or half.z <= 0.6 or half.z >= 2 or half.x >= 1.6 then
		return false
	end

	local oka, actors = pcall(Unit.num_actors, u)

	return oka and actors == 0
end

SK.marks_each = function(fn)
	local okw, world = pcall(function()
		return Managers.world and Managers.world:world("level_world")
	end)

	if not okw or not world then
		return 0
	end

	local oku, units = pcall(World.units, world)

	if not oku or type(units) ~= "table" then
		return 0
	end

	local n = 0

	for _, u in pairs(units) do
		local okm, meshes = pcall(Unit.num_meshes, u)

		if okm and meshes and meshes > 0 then
			local name = SK.unit_name(u)
			local mark = false

			for i = 1, #SK.MARKS do
				if name and string.find(name, SK.MARKS[i], 1, true) then
					mark = true
				end
			end

			if not mark and SK.mark_shape(u, name) then
				mark = true
			end

			if not mark and SK.unit_label(u, true) then
				mark = true
			end

			if mark then
				fn(u)
				n = n + 1
			end
		end
	end

	return n
end

SK.marks_show = function(on)
	SK.marks_on = on and true or false
	SK.marks_world = SK.marks_on and SK.level_world() or nil
	SK.marks_some = {}
	SK.meshy = nil

	return SK.marks_each(function(u)
		if #SK.marks_some < 8 then
			SK.marks_some[#SK.marks_some + 1] = u
		end

		pcall(Unit.set_unit_visibility, u, SK.marks_on)
	end)
end

SK.marks_here = function()
	if not SK.marks_on then
		return false
	end

	local some = SK.marks_some or {}
	local left = #some == 0

	for i = 1, #some do
		if SK.alive(some[i]) then
			left = true

			break
		end
	end

	if SK.marks_world ~= SK.level_world() or not left then
		SK.marks_on, SK.marks_world, SK.marks_some, SK.meshy = false, nil, nil, nil
	end

	return SK.marks_on
end

mod.sk_marks = function(what)
	if what == "state" then
		return SK.marks_here() and "on" or "off"
	end

	local n = SK.marks_show(not SK.marks_here())

	return SK.marks_on and ("Showing " .. SK.count(n, "hidden marker") .. ".") or ("Hid " .. SK.count(n, "marker") .. " again.")
end

-- ───────────────────── ❀ ─────────────────────
--  Mesh Candidates
-- ───────────────────── ❀ ─────────────────────

SK.meshy_list = function()
	local now = SK.now()
	local okw, world = pcall(function()
		return Managers.world and Managers.world:world("level_world")
	end)

	if not okw or not world then
		return nil
	end

	local marks_shown = SK.marks_here()

	local function measure(u)
		local okm, meshes = pcall(Unit.num_meshes, u)

		if not okm or not meshes or meshes == 0 then
			return nil
		end

		local okx, mesh = pcall(Unit.mesh, u, 1)

		if not okx or not mesh then
			return nil
		end

		local name = SK.unit_name(u)
		local mine = not name
			or (not string.find(name, "/characters/", 1, true)
				and not string.find(name, "/weapons/", 1, true)
				and not string.find(name, "/gizmos/", 1, true)
				and not string.find(name, "reflection_probe", 1, true)
				and not string.find(name, "core/units/camera", 1, true)
				and not string.find(name, "core/gwnav/", 1, true)
				and not string.find(name, "core/units/wwise", 1, true))

		if mine and SK.unit_label(u, true) then
			mine = false
		end

		if not mine then
			return nil
		end

		local okb, _, half = pcall(Unit.box, u)

		if not marks_shown and SK.mark_shape(u, name, okb and half or nil) then
			return nil
		end

		local okp, at = pcall(Unit.world_position, u, 1)

		if not okp or not at then
			okp, at = pcall(Mesh.world_position, mesh)
		end

		if not okp or not at then
			return nil
		end

		local span = SK.MESH_REACH

		if okb and half then
			local okl, wide = pcall(Vector3.length, half)

			if okl and wide and wide > 0 then
				span = math.min(wide + 0.3, SK.MESH_SPAN_CAP)
			end
		end

		return { unit = u, at = Vector3Box(at), span = span }
	end

	if SK.meshy and SK.meshy_of and SK.meshy_world == world and (now - (SK.meshy_at or 0)) < SK.MESH_LIST_FOR then
		local moved = SK.meshy_moved or {}

		SK.meshy_moved = nil

		for u in pairs(moved) do
			local one = SK.alive(u) and measure(u) or nil
			local was = SK.meshy_of[u]

			if one and was then
				was.at, was.span = one.at, one.span
			elseif one then
				SK.meshy[#SK.meshy + 1] = one
				SK.meshy_of[u] = one
			end
		end

		return SK.meshy
	end

	SK.meshy_world = world
	SK.meshy_moved = nil

	local oku, units = pcall(World.units, world)

	if not oku or type(units) ~= "table" then
		return nil
	end

	local out, of = {}, {}

	for _, u in pairs(units) do
		local one = measure(u)

		if one then
			out[#out + 1] = one
			of[u] = one
		end
	end

	SK.meshy, SK.meshy_of, SK.meshy_at = out, of, now

	return out
end

SK.meshy_touch = function(unit)
	if SK.meshy and unit ~= nil then
		SK.meshy_moved = SK.meshy_moved or {}
		SK.meshy_moved[unit] = true
	end
end

SK.pick_meshy = function(from, dir, reach)
	local list = SK.meshy_list()

	if not list then
		return nil
	end

	local gone = {}

	for i = 1, #(SK.hidden or {}) do
		local parts = SK.hidden[i].parts or {}

		for j = 1, #parts do
			gone[parts[j]] = true
		end
	end

	local near = {}

	for i = 1, #list do
		local one = list[i]

		if not gone[one.unit] then
			local to = one.at:unbox() - from
			local along = Vector3.dot(to, dir)

			if along > 0 and along < reach then
				local off = Vector3.length(to - dir * along)

				if off < (one.span or SK.MESH_REACH) then
					near[#near + 1] = { unit = one.unit, along = along }
				end
			end
		end
	end

	table.sort(near, function(a, b) return a.along < b.along end)

	for i = 1, #near do
		if SK.alive(near[i].unit) then
			return near[i].unit, near[i].along
		end
	end

	return nil
end

-- ───────────────────── ❀ ─────────────────────
--  Pick Rays
-- ───────────────────── ❀ ─────────────────────

SK.PICK_STALE = 1

SK.pick_now = function(me)
	if pick.armed_at and SK.now() - pick.armed_at > SK.PICK_STALE then
		pick.paste, pick.box, pick.ray = nil, nil, nil

		return "stale"
	end

	if pick.paste then
		local ok, why = pcall(SK.paste_run, me)

		if not ok then
			SK.say("paste|" .. tostring(why))
		end

		pick.said = ok and tostring(why) or "Something went wrong with the paste."
		pick.paste_said, pick.paste_at = pick.said, SK.now()

		return pick.said
	end

	if pick.box then
		local okb, _, took = pcall(SK.box_run, me)

		pick.box_took = okb and took or 0
		pick.box_at = SK.now()
		pick.said = "boxed " .. tostring(pick.box_took)

		return pick.said
	end

	local why = SK.pick_run(me)
	if why then
		pick.said = "ERR " .. why
		if why ~= "locked" then
			pick.missed_at = SK.now()
		end

		return pick.said
	end
	pick.said = string.format("hex=%s dist=%.1f pos=%s", pick.hex, pick.dist, pick.pos)
	return pick.said
end

SK.pick_camera = function()
	local ff = Managers.free_flight
	if ff and ff:is_in_free_flight() then
		local ok, cam = pcall(function()
			local ScriptWorld = require("scripts/foundation/utilities/script_world")
			local ScriptViewport = require("scripts/foundation/utilities/script_viewport")
			local world = Managers.world:world("level_world")
			local viewport = ScriptWorld.global_free_flight_viewport(world)
			return viewport and ScriptViewport.camera(viewport)
		end)
		if ok and cam then
			return cam, Camera.world_position(cam), Camera.world_rotation(cam)
		end
	end
	local cm = Managers.state and Managers.state.camera
	if not cm or not cm.camera then
		return nil
	end
	local ok, cam = pcall(cm.camera, cm, "player1")
	if not ok or not cam then
		return nil
	end
	return cam, cm:camera_position("player1"), cm:camera_rotation("player1")
end

SK.pick_ray_at = function(x, y)
	local cam, pos, rot = SK.pick_camera()
	if not cam then
		return nil
	end
	local okf, fov = pcall(Camera.vertical_fov, cam)
	if not okf or not fov then
		return nil
	end
	local w, h = RESOLUTION_LOOKUP.width, RESOLUTION_LOOKUP.height
	local nx = (x / w) * 2 - 1
	local ny = 1 - (y / h) * 2
	local half = math.tan(fov / 2)
	local dir = Quaternion.forward(rot) + Quaternion.right(rot) * (half * (w / h) * nx) + Quaternion.up(rot) * (half * ny)
	return pos, Vector3.normalize(dir)
end

-- ───────────────────── ❀ ─────────────────────
--  Box Select
-- ───────────────────── ❀ ─────────────────────

SK.BOX_GRID = 64

SK.BOX_REACH = 150

SK.box_run = function(me)
	local b = pick.box

	pick.box = nil

	if not b then
		return nil
	end

	local ok, ext = pcall(ScriptUnit.extension, me, "smart_targeting_system")

	if not ok or not ext or not ext._physics_world then
		return "no aim ray"
	end

	local x0, y0 = math.min(b[1], b[3]), math.min(b[2], b[4])
	local x1, y1 = math.max(b[1], b[3]), math.max(b[2], b[4])
	local n = SK.BOX_GRID
	local seen, found = {}, {}

	for i = 0, n - 1 do
		for j = 0, n - 1 do
			local x = x0 + (x1 - x0) * (i / (n - 1))
			local y = y0 + (y1 - y0) * (j / (n - 1))
			local from, dir = SK.pick_ray_at(x, y)

			if from then
				local cast, hits, got = pcall(PhysicsWorld.raycast, ext._physics_world, from, dir,
					SK.BOX_REACH, "all", "types", "both", "max_hits", SK.PICK_HITS,
					"collision_filter", SK.PICK_FILTER)

				for h = 1, (cast and got or 0) do
					local owned, unit = pcall(Actor.unit, hits[h][4])
					local noded, node = pcall(Actor.node, hits[h][4])

					if owned and unit and noded and node
						and not seen[unit] and not SK.is_hidden(unit) then
						seen[unit] = true
						found[#found + 1] = { unit = unit, node = node }
					end
				end
			end
		end
	end

	pick.at = SK.now()

	pick.unit, pick.node = nil, nil

	G.object.unit, G.object.node, G.object.from, G.object.turn = nil, nil, nil, nil
	G.object.crew = nil
	G.object.move, G.object.spin, G.object.grow = { 0, 0, 0 }, { 0, 0, 0 }, 1

	do
		local c = {}

		for _, xy in ipairs({ { x0, y0 }, { x1, y0 }, { x1, y1 }, { x0, y1 } }) do
			local _, d = SK.pick_ray_at(xy[1], xy[2])

			c[#c + 1] = d
		end

		local eye, ahead = SK.pick_ray_at(RESOLUTION_LOOKUP.width * 0.5, RESOLUTION_LOOKUP.height * 0.5)

		if eye and ahead and #c == 4 then
			local planes = {}

			for i = 1, 4 do
				planes[i] = Vector3.cross(c[i], c[i % 4 + 1])
			end

			local list = SK.meshy_list() or {}

			for i = 1, #list do
				local one = list[i]

				if not seen[one.unit] and SK.alive(one.unit) and not SK.is_hidden(one.unit) then
					local to = one.at:unbox() - eye
					local pos, neg = 0, 0

					for j = 1, 4 do
						if Vector3.dot(planes[j], to) >= 0 then
							pos = pos + 1
						else
							neg = neg + 1
						end
					end

					if (pos == 4 or neg == 4) and Vector3.dot(to, ahead) > 0 and Vector3.length(to) < SK.BOX_REACH then
						seen[one.unit] = true
						found[#found + 1] = { unit = one.unit, node = 1 }
					end
				end
			end
		end
	end

	local took = 0
	local people = SK.rig_parts()

	for i = 1, #found do
		if not people[found[i].unit] and not SK.pose_is_rig(found[i].unit) then
			if took == 0 and not SK.object_alive() then
				if SK.object_take(found[i].unit, found[i].node) then
					took = 1
				end
			elseif SK.object_add(found[i].unit, found[i].node) then
				took = took + 1
			end
		end
	end

	G.object.boxed = took > 1 or nil

	return nil, took
end

-- ───────────────────── ❀ ─────────────────────
--  Screen Clicks
-- ───────────────────── ❀ ─────────────────────

mod.pick_at_screen = function(x, y)
	if SK.object_locked() then
		return "locked"
	end

	local from, dir = SK.pick_ray_at(x, y)
	if not from then
		return "no camera"
	end
	pick.ray = { from = Vector3Box(from), dir = Vector3Box(dir) }
	pick.quiet = true
	pick.armed, pick.armed_at = true, SK.now()
	return "armed"
end

SK.PASTE_OUT = 5

mod.paste_at_screen = function(x, y)
	local from, dir = SK.pick_ray_at(x, y)

	if not from then
		return "no camera"
	end

	pick.paste = { from = Vector3Box(from), dir = Vector3Box(dir) }
	pick.armed, pick.armed_at = true, SK.now()

	return "armed"
end

SK.path_key = function(typed)
	local key = string.lower(tostring(typed or ""))

	key = string.gsub(key, "\\", "/")
	key = string.gsub(key, "^[%s\"']+", "")
	key = string.gsub(key, "[%s\"']+$", "")
	key = string.gsub(key, "%.unit$", "")

	return key ~= "" and key or nil
end

mod.spawn_at_screen = function(typed, x, y)
	local key = SK.path_key(typed)

	if not key then
		return "Type or paste a unit path first."
	end

	if not SK.spawnable(key) then
		return "That path is not loaded in this level."
	end

	local from, dir = SK.pick_ray_at(x, y)

	if not from then
		return "There is no camera to place it from."
	end

	SK.names_load()

	local hashed, id = pcall(Application.resource_id, key)

	if hashed and type(id) == "string" then
		SK.names[id] = key
	end

	pick.paste = { from = Vector3Box(from), dir = Vector3Box(dir),
		clip = { label = string.match(key, "[^/]+$"), members = { { name = key, node = 1, off = { 0, 0, 0 } } } } }
	pick.armed, pick.armed_at = true, SK.now()

	return nil
end

SK.paste_run = function(me)
	local p = pick.paste

	pick.paste = nil

	if not p then
		return "nothing to paste"
	end

	local from, dir = p.from:unbox(), p.dir:unbox()
	local at = from + dir * SK.PASTE_OUT
	local ok, ext = pcall(ScriptUnit.extension, me, "smart_targeting_system")

	if ok and ext and ext._physics_world then
		local cast, hits, got = pcall(PhysicsWorld.raycast, ext._physics_world, from, dir, SK.PICK_REACH,
			"all", "types", "both", "max_hits", SK.PICK_HITS, "collision_filter", SK.PICK_FILTER)
		local best = nil

		for h = 1, (cast and got or 0) do
			local hit = hits[h]
			local owned, unit = pcall(Actor.unit, hit[4])

			if owned and unit and unit ~= me and not SK.unit_under(me, unit) and not SK.is_hidden(unit)
				and (not best or hit[2] < best[2]) then
				best = hit
			end
		end

		if best then
			at = best[1]
		end
	end

	local clip = p.clip or SK.clip
	local made, why, held = SK.paste_at(at, clip)
	local did = p.clip and "Spawned" or "Pasted"

	if not made then
		return tostring(why)
	end

	if not held then
		return did .. ", but it could not be held."
	end

	return did .. " " .. SK.shown_name(clip and clip.label) .. "."
end

mod.box_at_screen = function(x0, y0, x1, y1)
	if SK.object_locked() then
		return "locked"
	end

	pick.box = { x0, y0, x1, y1 }
	pick.armed, pick.armed_at = true, SK.now()

	return "armed"
end

mod.sk_pick = function(what)
	if what == "arm" then
		pick.armed, pick.armed_at = true, SK.now()
		return "armed"
	end
	if pick.said == "" then
		return "nothing picked yet"
	end
	return string.format("age=%.1fs %s", SK.now() - pick.at, pick.said)
end

-- ───────────────────── ❀ ─────────────────────
--  Joints
-- ───────────────────── ❀ ─────────────────────

SK.JOINTS = {
	"j_head", "j_neck", "j_spine2", "j_spine1", "j_spine", "j_hips",
	"j_leftshoulder", "j_leftarm", "j_leftforearm", "j_lefthand",
	"j_rightshoulder", "j_rightarm", "j_rightforearm", "j_righthand",
	"j_leftupleg", "j_leftleg", "j_leftfoot",
	"j_rightupleg", "j_rightleg", "j_rightfoot",
}
SK.EXTRA = {
	"j_left_hand_ik_handle", "j_left_hand_ik_transform",
	"j_right_hand_ik_handle", "j_right_hand_ik_transform",
	"j_aim_target", "j_head_end",
	"j_lefttoebase", "j_righttoebase",
	"j_leftweaponattach", "j_rightweaponattach",
	"j_hips_handle", "j_backpackoffset",
}

for _, side in ipairs({ "left", "right" }) do
	for _, digit in ipairs({ "thumb", "index", "middle", "ring", "pinky" }) do
		for k = 1, 4 do
			SK.EXTRA[#SK.EXTRA + 1] = string.format("j_%shand%s%d", side, digit, k)
		end
	end
end

SK.POSE_RATE = 90
SK.POSE_SLACK = 0.001
SK.POSE_LIMIT = 180

G.pose = G.pose or { unit = nil, hex = "", name = "", joints = {}, dial = {}, have = {}, leg = {}, bone = {}, rate = SK.POSE_RATE, frames = {}, at = 0, play = nil }

local pose = G.pose

pose.leg = pose.leg or {}

SK.pose_alive = function()
	local unit = pose.unit
	local ok, alive = pcall(Unit.alive, unit)
	return unit ~= nil and ok and alive == true
end

SK.pose_release = function()
	SK.machine_on()

	if SK.pose_alive() then
		for name, b in pairs(pose.bone) do
			if b.held then
				pcall(Unit.set_animation_bone_mode, pose.unit, "position_and_rotation", Unit.node(pose.unit, name))
			end
		end
	end
	pose.bone = {}
	pose.frozen = nil
	pose.anim = nil
	pose.machine = nil
	pose.released = nil
	pose.taping = nil
	pose.rest, pose.fixed, pose.play = nil, nil, nil
	pose.leg = {}
	SK.tape_clear()
	if pose.gun then
		SK.gun_show(pose.gun)
		pose.gun = nil
	end
end

SK.pose_joints = function(unit)
	local joints = {}
	for i = 1, #SK.JOINTS do
		local name = SK.JOINTS[i]
		local ok, has = pcall(Unit.has_node, unit, name)
		if ok and has then
			joints[#joints + 1] = name
		end
	end
	return joints
end

SK.pose_extra = function(unit)
	local out = {}

	for i = 1, #SK.EXTRA do
		local ok, has = pcall(Unit.has_node, unit, SK.EXTRA[i])

		if ok and has then
			out[#out + 1] = SK.EXTRA[i]
		end
	end

	return out
end

-- ───────────────────── ❀ ─────────────────────
--  Rigs
-- ───────────────────── ❀ ─────────────────────

SK.RIG_REACH = 3
SK.RIG_MIN = 6

SK.pose_is_rig = function(unit)
	local okm, has = pcall(Unit.has_animation_state_machine, unit)

	if not okm or not has then
		return false
	end

	return #SK.pose_joints(unit) >= SK.RIG_MIN
end

SK.unit_under = function(top, unit)
	if top == unit then
		return true
	end

	local ok, kids = pcall(Unit.get_child_units, top)

	if not ok or type(kids) ~= "table" then
		return false
	end

	for i = 1, #kids do
		if SK.unit_under(kids[i], unit) then
			return true
		end
	end

	return false
end

SK.RIG_SKIN = 1
SK.RIG_BONES = { "j_hips", "j_spine", "j_head", "j_leftshoulder", "j_rightshoulder",
	"j_lefthand", "j_righthand", "j_leftknee", "j_rightknee", "j_leftfoot", "j_rightfoot" }

SK.RAY_SKIN = 0.35

SK.person_ahead = function()
	local o, d, far = pick.ray_o, pick.ray_d, pick.along

	if not o or not d or not far or far <= 0 then
		return nil
	end

	local world = SK.level_world()
	local okw, units = pcall(World.units, world)

	if not world or not okw or type(units) ~= "table" then
		return nil
	end

	local me = SK.player_unit()
	local skin = SK.RAY_SKIN * SK.RAY_SKIN

	for _, rig in pairs(units) do
		if rig ~= me and SK.alive(rig) and SK.pose_is_rig(rig) and not SK.is_hidden(rig) then
			for i = 1, #SK.RIG_BONES do
				local okh, has = pcall(Unit.has_node, rig, SK.RIG_BONES[i])
				local okn, node = false, nil

				if okh and has then
					okn, node = pcall(Unit.node, rig, SK.RIG_BONES[i])
				end

				local okp, p = false, nil

				if okn and node then
					okp, p = pcall(Unit.world_position, rig, node)
				end

				local at = okp and p and SK.xyz(p)

				if at then
					local px, py, pz = at[1] - o[1], at[2] - o[2], at[3] - o[3]
					local along = px * d[1] + py * d[2] + pz * d[3]

					if along > 0 and along < far - 0.2 then
						local qx, qy, qz = px - d[1] * along, py - d[2] * along, pz - d[3] * along

						if qx * qx + qy * qy + qz * qz < skin then
							return rig
						end
					end
				end
			end
		end
	end

	return nil
end

SK.bone_reach = function(rig, at)
	local best = math.huge

	for i = 1, #SK.RIG_BONES do
		local name = SK.RIG_BONES[i]
		local okh, has = pcall(Unit.has_node, rig, name)

		if okh and has then
			local okn, node = pcall(Unit.node, rig, name)

			if okn and node then
				local okp, p = pcall(Unit.world_position, rig, node)

				if okp and p then
					local okd, d = pcall(Vector3.distance, p, at)

					if okd and d and d < best then
						best = d
					end
				end
			end
		end
	end

	return best
end

SK.rig_owning = function(unit)
	local world = Managers.world and Managers.world:world("level_world")

	if not world then
		return nil
	end

	local okw, units = pcall(World.units, world)

	if not okw or type(units) ~= "table" then
		return nil
	end

	for _, other in pairs(units) do
		if other ~= unit and SK.pose_is_rig(other) and SK.unit_under(other, unit) then
			return other
		end
	end

	return nil
end

SK.rig_parts = function()
	local parts = {}

	local function under(top)
		local ok, kids = pcall(Unit.get_child_units, top)

		if not ok or type(kids) ~= "table" then
			return
		end

		for i = 1, #kids do
			if not parts[kids[i]] then
				parts[kids[i]] = true
				under(kids[i])
			end
		end
	end

	if SK.pose_alive() then
		under(pose.unit)
	end

	local world = SK.level_world()

	if not world then
		return parts
	end

	local okw, units = pcall(World.units, world)

	if not okw or type(units) ~= "table" then
		return parts
	end

	for _, other in pairs(units) do
		if SK.pose_is_rig(other) and not SK.is_hidden(other) then
			under(other)
		end
	end

	return parts
end

SK.pose_rig = function(unit, pos_text, strict)
	local me = SK.player_unit()

	if SK.pose_is_rig(unit) then
		if unit == me and not strict then
			return nil
		end

		return unit
	end

	if strict then
		if pose.unit and SK.pose_alive() and SK.unit_under(pose.unit, unit) then
			local hex = tostring(Unit.debug_name(pose.unit)):match("%[(%x+)%]") or "?"

			return pose.unit, hex
		end

		local owner = SK.rig_owning(unit)

		if owner and not SK.is_hidden(owner) then
			local hex = tostring(Unit.debug_name(owner)):match("%[(%x+)%]") or "?"

			return owner, hex
		end

		return nil
	end
	local px, py, pz = string.match(tostring(pos_text or ""), "([-%d.]+) ([-%d.]+) ([-%d.]+)")
	local world = Managers.world and Managers.world:world("level_world")
	if not px or not world then
		return nil
	end
	local at = Vector3(tonumber(px), tonumber(py), tonumber(pz))
	local best, best_d = nil, SK.RIG_REACH
	for _, other in pairs(World.units(world)) do
		local oka, alive = pcall(Unit.alive, other)
		if oka and alive and other ~= me and SK.pose_is_rig(other) and not SK.is_hidden(other) then
			local d = Vector3.distance(Unit.world_position(other, 1), at)
			if d < best_d then
				best, best_d = other, d
			end
		end
	end
	if not best then
		return nil
	end
	if not SK.unit_under(best, unit) and SK.bone_reach(best, at) > SK.RIG_SKIN then
		return nil
	end
	if SK.is_hidden(best) then
		return nil
	end

	local hex = tostring(Unit.debug_name(best)):match("%[(%x+)%]") or "?"
	return best, hex
end

SK.pose_target = function(unit, hex, name, keep_object)
	SK.pose_release()
	if not keep_object then
		G.object.unit, G.object.node, G.object.from, G.object.turn = nil, nil, nil, nil
	end
	pose.unit = unit
	pose.find, pose.mark_at, pose.refind_at = nil, nil, nil
	pose.machine = SK.moved_machine and SK.moved_machine[unit] or nil
	SK.tape_clear()
	pose.hex = hex or ""
	pose.name = name or ""
	pose.joints = SK.pose_joints(unit)
	pose.extra = SK.pose_extra(unit)
	pose.dial, pose.have = {}, {}
	for i = 1, #pose.joints do
		pose.dial[pose.joints[i]] = { 0, 0, 0 }
		pose.have[pose.joints[i]] = { 0, 0, 0 }
	end
	pose.at = SK.now()
	return #pose.joints
end

-- ───────────────────── ❀ ─────────────────────
--  Finding Again
-- ───────────────────── ❀ ─────────────────────

SK.REFIND_REACH = 3
SK.REFIND_EVERY = 1
SK.REFIND_FOR = 10
SK.MARK_EVERY = 0.5

SK.pose_vo = function(unit)
	local ok, has = pcall(ScriptUnit.has_extension, unit, "dialogue_system")

	if not ok or not has then
		return ""
	end

	local got, ext = pcall(ScriptUnit.extension, unit, "dialogue_system")

	return got and ext and ext._vo_profile_name or ""
end

SK.pose_mark = function(t)
	local unit = pose.unit

	if not unit or (pose.mark_at and t - pose.mark_at < SK.MARK_EVERY) then
		return
	end

	pose.mark_at = t

	local ok, at = pcall(Unit.world_position, unit, 1)

	if ok and at then
		local okw, world = pcall(function()
			return Managers.world and Managers.world:world("level_world")
		end)

		pose.find = pose.find or { vo = SK.pose_vo(unit) }
		pose.find.at = Vector3Box(at)
		pose.find.world = okw and world or pose.find.world
		pose.find.level = SK.level_name() or pose.find.level
	end
end

SK.pose_forget = function()
	pose.rest, pose.fixed, pose.play = nil, nil, nil
	pose.leg = {}
end

SK.refind_quit = function()
	pose.picked, pose.find = nil, nil

	if not SK.pose_alive() then
		SK.pose_forget()
	end
end

SK.pose_refind = function(t)
	local find = pose.find

	if not pose.picked or SK.pose_alive() or not find or not find.at then
		return nil
	end

	if pose.refind_at and t - pose.refind_at < SK.REFIND_EVERY then
		return nil
	end

	pose.refind_at = t

	local world = Managers.world and Managers.world:world("level_world")

	if not world then
		return nil
	end

	if world == find.world then
		SK.refind_quit()

		return nil
	end

	if not SK.player_alive() then
		return nil
	end

	if find.level and SK.level_name() ~= find.level then
		SK.refind_quit()

		return nil
	end

	find.since = find.since or t

	if t - find.since > SK.REFIND_FOR then
		SK.refind_quit()

		return nil
	end

	local at = find.at:unbox()
	local best, best_d = nil, SK.REFIND_REACH

	for _, other in pairs(World.units(world)) do
		local oka, alive = pcall(Unit.alive, other)

		if oka and alive and SK.pose_is_rig(other) and (find.vo == "" or SK.pose_vo(other) == find.vo)
			and not SK.networked(other) then
			local okp, p = pcall(Unit.world_position, other, 1)

			if okp and p then
				local d = Vector3.distance(p, at)

				if d < best_d then
					best, best_d = other, d
				end
			end
		end
	end

	if not best then
		return nil
	end

	pose.unit = best
	find.world, find.since = world, nil
	pose.bone, pose.leg, pose.rest, pose.frozen = {}, {}, nil, nil
	pose.anim, pose.gun, pose.fixed = nil, nil, nil
	pose.machine = SK.moved_machine and SK.moved_machine[best] or nil
	pose.joints = SK.pose_joints(best)
	pose.extra = SK.pose_extra(best)

	for i = 1, #pose.joints do
		local name = pose.joints[i]

		pose.dial[name] = pose.dial[name] or { 0, 0, 0 }
		pose.have[name] = pose.have[name] or { 0, 0, 0 }
	end

	SK.say("pose|refound|joints=" .. #pose.joints)

	return best
end

-- ───────────────────── ❀ ─────────────────────
--  Easing
-- ───────────────────── ❀ ─────────────────────

SK.pose_curve = function(u)
	if u <= 0 then return 0 end
	if u >= 1 then return 1 end

	return u * u * (3 - 2 * u)
end

SK.pose_leg = function(name, have, want, rate, now, span)
	local leg = pose.leg[name]

	if leg and leg.to[1] == want[1] and leg.to[2] == want[2] and leg.to[3] == want[3] then
		return leg
	end

	local far = 0

	for a = 1, 3 do
		far = math.max(far, math.abs(want[a] - have[a]))
	end

	leg = {
		from = { have[1], have[2], have[3] },
		to = { want[1], want[2], want[3] },
		t0 = now,
		span = span or far / math.max(1, rate),
	}
	pose.leg[name] = leg

	return leg
end

SK.blend_rest = function(name, t)
	local play = pose.play
	local to_r = pose.rest and pose.rest[name]
	local to_p = pose.fixed and pose.fixed[name]

	if play and play.from_base and play.t0 and play.span and play.span > 0 then
		local u = SK.pose_curve((t - play.t0) / play.span)
		local fr = play.from_base[name]
		local fp = play.from_sits and play.from_sits[name]

		if fr and to_r and u < 1 then
			to_r = QuaternionBox(Quaternion.lerp(fr:unbox(), to_r:unbox(), u))
		end

		if fp and to_p and u < 1 then
			to_p = Vector3Box(Vector3.lerp(fp:unbox(), to_p:unbox(), u))
		end
	end

	return to_r, to_p
end

SK.pose_rot = function(base, x, y, z)
	local q = base
	if x ~= 0 then q = Quaternion.multiply(q, Quaternion.axis_angle(Vector3(1, 0, 0), math.rad(x))) end
	if y ~= 0 then q = Quaternion.multiply(q, Quaternion.axis_angle(Vector3(0, 1, 0), math.rad(y))) end
	if z ~= 0 then q = Quaternion.multiply(q, Quaternion.axis_angle(Vector3(0, 0, 1), math.rad(z))) end
	return q
end

SK.pose_dial_of = function(base, live)
	local d = Quaternion.multiply(Quaternion.inverse(base), live)
	local right, fwd, up = Quaternion.right(d), Quaternion.forward(d), Quaternion.up(d)
	local sy = math.max(-1, math.min(1, up.x))
	local y = math.asin(sy)
	local x, z

	if math.abs(sy) > 0.99999 then
		x = math.atan2(fwd.z, fwd.y)
		z = 0
	else
		x = math.atan2(-up.y, up.z)
		z = math.atan2(-fwd.x, right.x)
	end

	return math.deg(x), math.deg(y), math.deg(z)
end

SK.pose_overwritten = function(wrote, now, slack)
	local wx, wy, wz, ww = Quaternion.to_elements(wrote)
	local nx, ny, nz, nw = Quaternion.to_elements(now)
	return math.abs(wx * nx + wy * ny + wz * nz + ww * nw) < 1 - slack
end

-- ───────────────────── ❀ ─────────────────────
--  Weapon
-- ───────────────────── ❀ ─────────────────────

SK.gun_holders = function(unit)
	local slotted = {}
	local ok, ext = pcall(ScriptUnit.extension, unit, "component_system")

	if ok and ext and ext._components then
		for _, component in pairs(ext._components) do
			if component._units_by_slot_name then
				for _, child in pairs(component._units_by_slot_name) do
					slotted[child] = true
				end
			end
		end
	end

	return slotted
end

SK.gun_tree = function(unit, hidden)
	if not SK.alive(unit) then
		return
	end

	for _, child in ipairs(Unit.get_child_units(unit) or {}) do
		if Unit.alive(child) then
			pcall(Unit.set_unit_visibility, child, false)
			hidden[#hidden + 1] = child
			SK.gun_tree(child, hidden)
		end
	end
end

SK.gun_hide = function(unit)
	if not SK.alive(unit) then
		return {}
	end

	local slotted = SK.gun_holders(unit)
	local hidden = {}

	for _, child in ipairs(Unit.get_child_units(unit) or {}) do
		local holder = not slotted[child] and Unit.num_meshes(child) == 0
			and #(Unit.get_child_units(child) or {}) > 0

		if holder and Unit.alive(child) then
			pcall(Unit.set_unit_visibility, child, false)
			hidden[#hidden + 1] = child
			SK.gun_tree(child, hidden)
		end
	end

	return hidden
end

SK.gun_show = function(hidden)
	local shown = 0

	for i = 1, #(hidden or {}) do
		local child = hidden[i]

		if child and Unit.alive(child) then
			pcall(Unit.set_unit_visibility, child, true)
			shown = shown + 1
		end
	end

	return shown
end

-- ───────────────────── ❀ ─────────────────────
--  Pose Tick
-- ───────────────────── ❀ ─────────────────────

SK.pose_tick = function(dt, t)
	pcall(SK.collide_tick)

	if not SK.pose_alive() then
		pose.unit = nil
		pose.bone = {}
		pose.taping = nil

		if not (pose.picked and pose.find) then
			SK.pose_forget()
		end

		return
	end
	local unit = pose.unit
	local play = pose.play
	if play then
		local guard = 0

		while pose.play and t >= play.until_t and guard < 600 do
			guard = guard + 1
			local due = play.until_t

			if t - due > 0.25 then
				due = t
			end

			play.due = due
			play.i = play.i + 1
			local list = play.list or pose.frames
			local frame = list[play.i]
			if not frame and play.loop and #list > 0 then
				play.i = 1
				frame = list[1]
			end
			if frame then
				play.from_base, play.from_sits, play.t0 = pose.rest, pose.fixed, play.due or t
				SK.pose_apply(frame)
				play.span = frame.hold or 2
				play.until_t = (play.due or t) + play.span
			else
				pose.play = nil
				if play.release then
					for i = 1, #pose.joints do pose.dial[pose.joints[i]] = { 0, 0, 0 } end
				end
			end
		end
	end
	if pose.released then
		for name, b in pairs(pose.bone) do
			if b.held then
				pcall(Unit.set_animation_bone_mode, unit, "position_and_rotation", Unit.node(unit, name))
			end
			b.held, b.base, b.wrote = nil, nil, nil
		end
		return
	end
	local anim = pose.anim
	if anim and anim.freeze_at and not pose.frozen and t - anim.fired_t >= anim.freeze_at then
		anim.at = anim.freeze_at
		SK.pose_freeze()
	end
	local tp = pose.taping
	if tp then
		while t >= tp.next_t and tp.next_t <= tp.until_t do
			SK.tape_frame()
			tp.next_t = tp.next_t + tp.step
		end
		if t >= tp.until_t then
			pose.taping = nil
			SK.tape_seek(#(pose.tape and pose.tape.frames or {}))
		end
	end
	for i = 1, #pose.joints do
		local name = pose.joints[i]
		local want = pose.dial[name]
		local have = pose.have[name]
		local b = pose.bone[name] or {}
		pose.bone[name] = b
		local leg = SK.pose_leg(name, have, want, pose.rate, t, play and play.span)
		local along = SK.pose_curve(leg.span > 0 and (t - leg.t0) / leg.span or 1)

		for a = 1, 3 do
			have[a] = leg.from[a] + (leg.to[a] - leg.from[a]) * along
		end
		local frozen = pose.frozen and pose.frozen[name]
		local kept = pose.rest and pose.rest[name]
		local idle = have[1] == 0 and have[2] == 0 and have[3] == 0
			and want[1] == 0 and want[2] == 0 and want[3] == 0
		local node = b.node or Unit.node(unit, name)

		b.node = node
		if idle and not frozen and not kept then
			if b.held then
				pcall(Unit.set_animation_bone_mode, unit, "position_and_rotation", node)
			end
			b.held, b.base, b.wrote = nil, nil, nil
		else
			local live = Unit.local_rotation(unit, node)
			local lost = b.held and b.wrote and SK.pose_overwritten(b.wrote:unbox(), live, SK.POSE_SLACK)
			local rest, sits = SK.blend_rest(name, t)

			if pcall(Unit.set_animation_bone_mode, unit, "ignore", node) then
				if not b.held or lost then
					b.held = true
					b.base = rest or frozen or b.base or QuaternionBox(live)
					b.retakes = (b.retakes or 0) + (lost and 1 or 0)
				end
			end
			if rest then
				b.base = rest
			elseif frozen then
				b.base = frozen
			end
			if b.held then
				local q = SK.pose_rot(b.base:unbox(), have[1], have[2], have[3])
				pcall(Unit.set_local_rotation, unit, node, q)
				if b.wrote then
					b.wrote:store(q)
				else
					b.wrote = QuaternionBox(q)
				end
				sits = sits or (pose.fixed and pose.fixed[name])
				if sits then
					pcall(Unit.set_local_position, unit, node, sits:unbox())
				end
			end
		end
	end
	SK.extra_tick(unit, t)
end

SK.extra_tick = function(unit, t)
	local frozen = pose.frozen

	for i = 1, #(pose.extra or {}) do
		local name = pose.extra[i]
		local want, sits = nil, nil

		if pose.play then
			want, sits = SK.blend_rest(name, t or SK.now())
		end

		if not want then
			want = frozen and frozen[name]
			sits = pose.fixed and pose.fixed[name]

			if not want then
				want, sits = SK.blend_rest(name, t or SK.now())
			end
		end

		local b = pose.bone[name] or {}
		local node = b.node or Unit.node(unit, name)

		pose.bone[name], b.node = b, node

		if want then
			if pcall(Unit.set_animation_bone_mode, unit, "ignore", node) then
				b.held = true
			end

			if b.held then
				pcall(Unit.set_local_rotation, unit, node, want:unbox())
				b.wrote = want

				if sits then
					pcall(Unit.set_local_position, unit, node, sits:unbox())
				end
			end
		elseif b.held then
			pcall(Unit.set_animation_bone_mode, unit, "position_and_rotation", node)
			b.held, b.wrote = nil, nil
		end
	end
end

-- ───────────────────── ❀ ─────────────────────
--  Pose Verb
-- ───────────────────── ❀ ─────────────────────

SK.pose_line = function()
	local out = { "unit=" .. (pose.name ~= "" and SK.tail(pose.name, 40) or (pose.hex ~= "" and ("#" .. pose.hex) or "-")), "rate=" .. tostring(pose.rate) }
	for i = 1, #pose.joints do
		local name = pose.joints[i]
		local d = pose.dial[name]
		out[#out + 1] = string.format("%s=%s,%s,%s", name, tostring(d[1]), tostring(d[2]), tostring(d[3]))
	end
	return table.concat(out, " ")
end

SK.pose_clamp = function(v)
	v = tonumber(v) or 0
	if v > SK.POSE_LIMIT then v = SK.POSE_LIMIT end
	if v < -SK.POSE_LIMIT then v = -SK.POSE_LIMIT end
	return v
end

mod.sk_pose = function(what, x, y, z)
	if what == nil or what == "" then
		if not pose.unit then return "no unit: pick one, then pose target" end
		return SK.pose_line()
	end
	if what == "target" then
		if not pick.unit then return "ERR nothing picked yet" end
		local ok, alive = pcall(Unit.alive, pick.unit)
		if not ok or not alive then return "ERR the pick is gone" end
		local unit, hex, name = SK.pose_rig(pick.unit, pick.pos)
		if not unit then
			return "nothing to pose there"
		end
		if unit ~= pick.unit then
			hex, name = hex, ""
		else
			hex, name = pick.hex, pick.name
		end
		local n = SK.pose_target(unit, hex, name)
		pose.picked = true
		SK.say("pose|target=" .. (name ~= "" and name or hex) .. "|joints=" .. n)
		return string.format("posing %s, %d joints", name ~= "" and SK.tail(name, 40) or ("#" .. hex), n)
	end
	if what == "release" then
		if x == "off" or x == false then
			pose.released = nil
			return "held again"
		end
		pose.released = true
		return "released"
	end
	if what == "clear" then
		SK.pose_release()
		G.object.unit, G.object.node, G.object.from, G.object.turn = nil, nil, nil, nil
		G.object.crew = nil
		pick.unit, pick.node = nil, nil
		pose.unit = nil
		pose.hex, pose.name = "", ""
		pose.picked = nil
		pose.joints, pose.dial, pose.have = {}, {}, {}
		pose.play = nil
		return "Target cleared."
	end
	if not pose.unit then return "ERR no unit: pick one, then pose target" end
	if what == "rate" then
		pose.rate = math.max(1, tonumber(x) or SK.POSE_RATE)
		return "rate=" .. pose.rate
	end
	if what == "zero" then
		for i = 1, #pose.joints do pose.dial[pose.joints[i]] = { 0, 0, 0 } end
		return pose.frozen and "all dials to 0, still frozen" or "all dials to 0"
	end
	if pose.dial[what] == nil then
		return "ERR no joint called " .. tostring(what)
	end
	pose.dial[what] = { SK.pose_clamp(x), SK.pose_clamp(y), SK.pose_clamp(z) }
	return string.format("%s=%s,%s,%s", what, tostring(pose.dial[what][1]), tostring(pose.dial[what][2]), tostring(pose.dial[what][3]))
end

-- ───────────────────── ❀ ─────────────────────
--  Keyframe Strip
-- ───────────────────── ❀ ─────────────────────

SK.FRAMES_IDLE = 0.5

SK.frames_save = function()
	local keep = {}

	for i = 1, #pose.frames do
		keep[i] = pose.frames[i]
	end

	pose.frames_due = keep
	pose.frames_due_at = SK.now()
end

SK.frames_flush = function()
	local due = pose.frames_due

	if not due then
		return
	end

	pose.frames_due = nil
	SK.frames_write(SK.frames_text(due))
end

SK.frames_tick = function(t)
	if pose.frames_due and t - (pose.frames_due_at or 0) >= SK.FRAMES_IDLE then
		SK.frames_flush()
	end
end

SK.strip_safe = function(text)
	return (string.gsub(tostring(text or ""), "[|;]", " "))
end

SK.frames_text = function(frames)
	local rows = {}
	for i = 1, #frames do
		local f = frames[i]
		local parts = { SK.strip_safe(f.name), SK.fine(f.hold or 2, 4) }
		if f.group then
			parts[#parts + 1] = "group=" .. SK.strip_safe(f.group)
		end
		if f.anim and f.anim.event then
			local at = f.anim.at ~= nil and SK.fine(f.anim.at, 4) or ""

			parts[#parts + 1] = string.format("anim=%s,%s,%s", f.anim.event, at, f.anim.machine or "")
		end
		for name, d in pairs(f.dial) do
			parts[#parts + 1] = string.format("%s=%s,%s,%s", name, tostring(d[1]), tostring(d[2]), tostring(d[3]))
		end
		for name, q in pairs(f.base or {}) do
			local r = q:unbox()

			local qx, qy, qz, qw = Quaternion.to_elements(r)

			parts[#parts + 1] = string.format("from_%s=%s,%s,%s,%s", name,
				tostring(qx), tostring(qy), tostring(qz), tostring(qw))
		end
		for name, v in pairs(f.sits or {}) do
			local p = v:unbox()

			parts[#parts + 1] = string.format("at_%s=%s,%s,%s", name,
				tostring(p.x), tostring(p.y), tostring(p.z))
		end
		rows[#rows + 1] = table.concat(parts, "|")
	end
	return table.concat(rows, ";;")
end

SK.WORKING = SK.HOME and (SK.HOME .. "\\_working.txt") or "./../mods/SkeletonKey/anim/sets/_working.txt"

SK.FRAME_CAP = 3000

SK.frames_write = function(text)
	pcall(function()
		local f = Mods.lua.io.open(SK.WORKING, "w")

		if not f then
			SK.home_make()
			f = Mods.lua.io.open(SK.WORKING, "w")
		end

		if not f then
			return
		end

		f:write(text)
		f:close()
	end)
end

SK.frames_read = function()
	SK.frames_flush()

	local ok, text = pcall(function()
		local f = Mods.lua.io.open(SK.WORKING, "r")

		if not f then
			return nil
		end

		local body = f:read("*a")

		f:close()

		return body
	end)

	return ok and type(text) == "string" and text or ""
end

SK.frames_load = function()
	local text = SK.frames_read()
	if text == "" then return end
	pose.frames = {}
	for row in string.gmatch(text .. ";;", "(.-);;") do
		local fields = {}
		for field in string.gmatch(row .. "|", "(.-)|") do fields[#fields + 1] = field end
		if fields[1] then
			local f = { name = fields[1], hold = SK.finite(fields[2], 2), dial = {} }
			for i = 3, #fields do
				local group = string.match(fields[i], "^group=(.+)$")
				local rate = string.match(fields[i], "^rate=(.+)$")
				local ev, at, machine = string.match(fields[i], "^anim=(.-),(.-),(.*)$")
				local from, fx, fy, fz, fw = string.match(fields[i], "^from_(.-)=(.-),(.-),(.-),(.-)$")
				local sits, sx, sy, sz = string.match(fields[i], "^at_(.-)=(.-),(.-),(.-)$")
				local name, a, b, c = string.match(fields[i], "^(.-)=(.-),(.-),(.-)$")
				if group then
					f.group = group
				elseif sits then
					f.sits = f.sits or {}
					f.sits[sits] = Vector3Box(Vector3(SK.finite(sx, 0), SK.finite(sy, 0), SK.finite(sz, 0)))
				elseif from then
					f.base = f.base or {}
					f.base[from] = QuaternionBox(Quaternion.from_elements(SK.finite(fx, 0), SK.finite(fy, 0), SK.finite(fz, 0), SK.finite(fw, 1)))
				elseif rate then
				elseif ev then
					f.anim = { event = ev, at = SK.finite(at, nil), machine = machine }
				elseif name then
					f.dial[name] = { SK.finite(a, 0), SK.finite(b, 0), SK.finite(c, 0) }
				end
			end
			pose.frames[#pose.frames + 1] = f
		end
	end
end

SK.pose_apply = function(frame)
	if frame.anim and frame.anim.event then
		SK.anim_play(frame.anim.event, frame.anim.machine, frame.anim.at)
	end
	pose.rest = frame.base
	if frame.sits then
		pose.fixed = frame.sits
	end
	for i = 1, #pose.joints do
		local name = pose.joints[i]
		local d = frame.dial[name]
		pose.dial[name] = d and { d[1], d[2], d[3] } or { 0, 0, 0 }
	end
end

-- ───────────────────── ❀ ─────────────────────
--  Keyframe Verb
-- ───────────────────── ❀ ─────────────────────

SK.frame_find = function(key)
	local n = tonumber(key)
	if n and pose.frames[n] then return n end
	for i = 1, #pose.frames do
		if pose.frames[i].name == key then return i end
	end
	return nil
end

mod.sk_keyframe = function(what, key, extra)
	if not pose.loaded then
		pose.loaded = true
		SK.frames_load()
	end
	if what == nil or what == "" then
		if #pose.frames == 0 then return "no keyframes" end
		local out = {}
		for i = 1, #pose.frames do
			out[#out + 1] = string.format("%d:%s(%ss)", i, pose.frames[i].name, SK.num(pose.frames[i].hold))
		end
		return table.concat(out, " ")
	end
	if what == "stop" then
		pose.play = nil
		return "Stopped."
	end
	if what == "clear" then
		local had = #pose.frames
		pose.frames = {}
		pose.play = nil
		SK.frames_save()
		return had > 0 and ("Deleted " .. SK.count(had, "keyframe") .. ".") or "No keyframes to clear."
	end
	local no_unit_ok = { folders = true, flip = true, loop = true, hold = true, delete = true, move = true, name = true, up = true }
	if not pose.unit and not no_unit_ok[what] then return "Nobody is posed. Left-click a person first." end
	if what == "save" then
		if #pose.frames >= SK.FRAME_CAP then
			return "The keyframe list is full. Delete some first."
		end
		local name = SK.unique_name(key ~= nil and tostring(key) or ("frame " .. (#pose.frames + 1)), SK.frame_names(), " ")
		local f = { name = name, hold = tonumber(extra) or 2, dial = {} }
		local baked, from, sits = SK.pose_bake()

		if baked then
			f.dial = baked
			f.base = from
			f.sits = sits
		else
			for i = 1, #pose.joints do
				local d = pose.dial[pose.joints[i]]
				f.dial[pose.joints[i]] = { d[1], d[2], d[3] }
			end
		end
		pose.frames[#pose.frames + 1] = f
		SK.frames_save()
		return string.format("Saved %s as keyframe %d.", name, #pose.frames)
	end
	if what == "clip" then
		if not pose.anim or not pose.anim.event then
			return "Nothing is playing. Play an animation first."
		end
		if #pose.frames >= SK.FRAME_CAP then
			return "The keyframe list is full. Delete some first."
		end
		local f = {
			name = SK.unique_name(tostring(key or pose.anim.event), SK.frame_names(), " "),
			hold = tonumber(extra) or 2,
			dial = {},
			anim = SK.anim_of_now(),
		}
		if not pose.frozen then
			f.anim.at = nil
		end
		for i = 1, #pose.joints do
			f.dial[pose.joints[i]] = { 0, 0, 0 }
		end
		pose.frames[#pose.frames + 1] = f
		SK.frames_save()
		return f.anim.at and string.format("Saved %s as keyframe %d, held at %ss.", f.name, #pose.frames, SK.num(f.anim.at))
			or string.format("Saved %s as keyframe %d, whole clip.", f.name, #pose.frames)
	end
	if what == "folders" then
		local seen, out = {}, {}
		for i = 1, #pose.frames do
			local g = pose.frames[i].group
			if g and not seen[g] then
				seen[g] = true
				out[#out + 1] = g
			end
		end
		return #out > 0 and table.concat(out, ", ") or "no folders"
	end
	if what == "flip" then
		local a = math.floor(tonumber(key) or 0)
		local b = math.floor(tonumber(extra) or 0)
		if a > b then a, b = b, a end
		if a < 1 or b > #pose.frames or b - a < 1 then
			return "ERR pick a run of two or more keyframes"
		end
		local run, holds = {}, {}
		for i = a, b do
			run[#run + 1] = pose.frames[i]
			holds[#holds + 1] = pose.frames[i].hold or 2
		end
		local n = #run
		for k = 1, n do
			pose.frames[a + k - 1] = run[n - k + 1]
		end
		pose.frames[a].hold = holds[1]
		for k = 2, n do
			pose.frames[a + k - 1].hold = holds[n - k + 2]
		end
		SK.frames_save()
		return string.format("Reversed keyframes %d to %d.", a, b)
	end
	if what == "play" then
		if #pose.frames == 0 then return "No keyframes to play yet. Save Pose adds one." end
		SK.pose_apply(pose.frames[1])
		pose.play = { i = 1, until_t = SK.now() + (pose.frames[1].hold or 2), loop = pose.loop }
		return "Playing " .. SK.count(#pose.frames, "keyframe") .. (pose.loop and " on a loop." or ".")
	end
	if what == "loop" then
		pose.loop = not pose.loop
		if pose.play then pose.play.loop = pose.loop end
		return pose.loop and "Loop on. Play goes round until Stop." or "Loop off. Play goes through once."
	end
	local i = SK.frame_find(key)
	if not i then return "Keyframe " .. tostring(key) .. " is not there." end
	local f = pose.frames[i]
	if what == "apply" then
		pose.play = nil
		SK.pose_apply(f)
		return "Showing " .. f.name .. "."
	elseif what == "over" then
		f.anim = nil
		f.dial, f.base, f.sits = SK.pose_bake()

		if not f.dial then
			f.base, f.sits = nil, nil
			f.dial = {}

			for j = 1, #pose.joints do
				local d = pose.dial[pose.joints[j]]
				f.dial[pose.joints[j]] = { d[1], d[2], d[3] }
			end
		end
		SK.frames_save()
		return "Saved this pose over " .. f.name .. "."
	elseif what == "hold" then
		f.hold = math.max(0, math.floor((tonumber(extra) or 2) * 10 + 0.5) / 10)
		SK.frames_save()
		return f.name .. " holds " .. f.hold .. "s"
	elseif what == "delete" then
		table.remove(pose.frames, i)
		SK.frames_save()
		return "Deleted " .. f.name .. "."
	elseif what == "move" then
		local to = math.max(1, math.min(#pose.frames, math.floor(tonumber(extra) or i)))
		if to ~= i then
			table.remove(pose.frames, i)
			table.insert(pose.frames, to, f)
			SK.frames_save()
		end
		return string.format("%s is %d of %d", f.name, to, #pose.frames)
	elseif what == "name" then
		local text = tostring(extra or "")
		if not SK.frame_name_ok(text) then
			return "Not renamed. Use letters, digits, spaces, _ and -."
		end
		local was = f.name
		f.name = text
		SK.frames_save()
		return string.format("Renamed %s to %s.", was, text)
	elseif what == "up" then
		if i > 1 then
			pose.frames[i], pose.frames[i - 1] = pose.frames[i - 1], pose.frames[i]
			SK.frames_save()
		end
		return f.name .. " is " .. math.max(1, i - 1)
	end
	return "ERR keyframe verbs: save clip over apply hold name move delete flip up play stop clear"
end

-- ───────────────────── ❀ ─────────────────────
--  Animations
-- ───────────────────── ❀ ─────────────────────

SK.emote_cache = nil

SK.emotes = function()
	if SK.emote_cache then
		return SK.emote_cache
	end
	local list = {}
	local okr, MI = pcall(require, "scripts/backend/master_items")
	local items = okr and type(MI) == "table" and type(MI.get_cached) == "function" and MI.get_cached() or nil
	if type(items) == "table" then
		for _, item in pairs(items) do
			if type(item) == "table" and item.item_type == "EMOTE" and item.animation_event and item.animation_event ~= "" then
				local machine = tostring(item.state_machine or "")
				local okl, name = pcall(Localize, tostring(item.display_name or ""))
				if not okl or type(name) ~= "string" or name == "" or string.find(name, "^<") then
					name = tostring(item.dev_name or item.animation_event)
				end
				list[#list + 1] = {
					event = tostring(item.animation_event),
					machine = machine,
					breed = string.find(machine, "ogryn", 1, true) and "ogryn" or "human",
					name = name,
					seconds = tonumber(item.animation_duration) or 0,
				}
			end
		end
	end
	table.sort(list, function(a, b)
		if a.breed ~= b.breed then return a.breed < b.breed end
		return a.name < b.name
	end)
	if #list > 0 then
		SK.emote_cache = list
	end
	return list
end

SK.ANIMATIONS = "SkeletonKey/scripts/mods/SkeletonKey/SkeletonKey_Animations"

SK.animations = function()
	if SK.anim_book then
		return SK.anim_book
	end
	local ok, book = pcall(function () return mod:io_dofile(SK.ANIMATIONS) end)
	SK.anim_book = (ok and type(book) == "table") and book or {}
	return SK.anim_book
end

SK.NET_SAYS = "The online game moves them, so this cannot play."
SK.LOADING_SAYS = "Loading that animation. Press it again in a moment."
SK.moved_machine = SK.moved_machine or setmetatable({}, { __mode = "k" })

SK.hold_package = function(machine)
	local packages = Managers.package

	SK.held_packages = SK.held_packages or {}

	if packages and machine and machine ~= "" and not SK.held_packages[machine] then
		local ok, id = pcall(function () return packages:load(machine, "SkeletonKey", nil, true) end)

		SK.held_packages[machine] = ok and id or nil
	end
end

SK.anim_machine = function(unit, machine)
	local packages = Managers.package
	if not packages or not machine or machine == "" then
		return nil, "no machine to move to"
	end
	if SK.networked(unit) then
		return nil, SK.NET_SAYS
	end
	SK.hold_package(machine)
	if not packages:has_loaded(machine) then
		return nil, SK.LOADING_SAYS
	end
	local okm, has = pcall(Unit.has_animation_state_machine, unit)

	if not okm or not has then
		return nil, "That is not a whole person, so it cannot play this."
	end

	if not pcall(Unit.set_animation_state_machine, unit, machine) then
		return nil, "This person cannot take that animation."
	end
	if unit == pose.unit then
		pose.machine = machine
	end
	SK.moved_machine[unit] = machine
	return true
end

SK.anim_ready = function(unit, event, machine)
	local okh, has = pcall(Unit.has_animation_event, unit, event)

	if okh and has then
		return true
	end

	if not machine or machine == "" then
		return nil, "They cannot play " .. tostring(event) .. "."
	end

	if SK.networked(unit) then
		return nil, SK.NET_SAYS
	end

	SK.hold_package(machine)

	if not (Managers.package and Managers.package:has_loaded(machine)) then
		return nil, SK.LOADING_SAYS
	end

	return true
end

SK.anim_fire = function(unit, event, machine)
	local okh, has = pcall(Unit.has_animation_event, unit, event)
	if not (okh and has) and machine and machine ~= "" then
		local moved, why = SK.anim_machine(unit, machine)
		if not moved then
			return nil, why
		end
		okh, has = pcall(Unit.has_animation_event, unit, event)
	end
	if not (okh and has) then
		return nil, "They cannot play " .. tostring(event) .. "."
	end
	local okf, err = pcall(Unit.animation_event, unit, event)
	if not okf then
		SK.say("anim|" .. tostring(event) .. "|" .. tostring(err))
		return nil, "The game would not play that animation."
	end
	return true
end

-- ───────────────────── ❀ ─────────────────────
--  Freeze & Rest
-- ───────────────────── ❀ ─────────────────────

SK.pose_freeze = function()
	if not SK.pose_alive() then
		return "Nobody is posed. Left-click a person first."
	end
	pose.machine_off = not SK.networked(pose.unit)
		and pcall(Unit.disable_animation_state_machine, pose.unit)
		and pose.unit or nil
	pose.frozen = {}
	pose.rest = nil
	pose.fixed = {}
	local function take(name)
		local node = Unit.node(pose.unit, name)
		local ok, q = pcall(Unit.local_rotation, pose.unit, node)
		if ok and q then
			pose.frozen[name] = QuaternionBox(q)
		end
		local okp, p = pcall(Unit.local_position, pose.unit, node)
		if okp and p then
			pose.fixed[name] = Vector3Box(p)
		end
	end
	for i = 1, #pose.joints do
		take(pose.joints[i])
	end
	for i = 1, #(pose.extra or {}) do
		take(pose.extra[i])
	end
	for i = 1, #pose.joints do
		local name = pose.joints[i]
		pose.dial[name] = { 0, 0, 0 }
		pose.have[name] = { 0, 0, 0 }
	end
	pose.leg = {}
	if pose.anim and not pose.anim.at then
		pose.anim.at = tonumber(SK.num(SK.now() - pose.anim.fired_t)) or 0
	end
	return pose.anim and string.format("Frozen %ss into %s.", SK.num(pose.anim.at), pose.anim.event) or "Frozen where they stand."
end

SK.pose_rest = function()
	if not SK.pose_alive() then
		return "Nobody is posed. Left-click a person first."
	end

	SK.pose_thaw()
	pose.play = nil

	if not pose.machine then
		return "Standing with nothing playing."
	end

	local home = SK.home_machine(pose.unit)

	if not home then
		return "Standing with nothing playing."
	end

	if pose.machine == home then
		pose.machine = nil
		SK.moved_machine[pose.unit] = nil

		return "Standing with nothing playing."
	end

	local moved, why = SK.anim_machine(pose.unit, home)

	if not moved then
		return tostring(why)
	end

	pose.machine = nil
	SK.moved_machine[pose.unit] = nil

	return "Standing, back on the hub animations."
end

SK.home_machine = function(unit)
	local breed = string.find(tostring(SK.unit_name(unit) or ""), "ogryn", 1, true) and "ogryn" or "human"

	for _, e in ipairs(SK.emotes()) do
		if e.breed == breed then
			return e.machine
		end
	end

	return nil
end

SK.machine_on = function()
	local was = pose.machine_off

	pose.machine_off = nil

	if was then
		local ok, alive = pcall(Unit.alive, was)

		if ok and alive then
			pcall(Unit.enable_animation_state_machine, was)
		end
	end
end

SK.pose_thaw = function()
	SK.machine_on()

	pose.frozen = nil
	pose.fixed = nil
	pose.anim = nil
	pose.rest = nil
	return "Thawed. They move again."
end

SK.anim_play = function(event, machine, freeze_at)
	if not SK.pose_alive() then
		return "Nobody is posed. Left-click a person first.", true
	end
	local ready, why = SK.anim_ready(pose.unit, event, machine)
	if not ready then
		return tostring(why), true
	end
	SK.pose_thaw()

	local was = {}

	for i = 1, #pose.joints do
		local name = pose.joints[i]
		local b = pose.bone[name]

		if b and b.held and b.base then
			was[name] = b.base
		elseif Unit.has_node(pose.unit, name) then
			was[name] = QuaternionBox(Unit.local_rotation(pose.unit, Unit.node(pose.unit, name)))
		end
	end

	local ok, err = SK.anim_fire(pose.unit, event, machine)
	if not ok then
		return tostring(err), true
	end

	for i = 1, #pose.joints do
		local name = pose.joints[i]

		pose.dial[name] = { 0, 0, 0 }
		pose.have[name] = { 0, 0, 0 }
		pose.leg[name] = nil
	end

	pose.anim = { event = event, machine = machine or "", fired_t = SK.now(), freeze_at = tonumber(freeze_at), was = was }
	return "playing " .. event .. (freeze_at and (", freezing at " .. SK.num(freeze_at) .. "s") or "")
end

-- ───────────────────── ❀ ─────────────────────
--  Tape
-- ───────────────────── ❀ ─────────────────────

SK.TAPE_SECONDS = 3
SK.TAPE_STEP = 1 / 60

SK.tape_frame = function()
	local tape = pose.tape

	if not tape or not SK.pose_alive() then
		return
	end

	local shot = { rot = {}, pos = {} }

	local function take(name)
		if Unit.has_node(pose.unit, name) then
			local node = Unit.node(pose.unit, name)
			local ok, q = pcall(Unit.local_rotation, pose.unit, node)

			if ok and q then
				shot.rot[name] = QuaternionBox(q)
			end

			local okp, p = pcall(Unit.local_position, pose.unit, node)

			if okp and p then
				shot.pos[name] = Vector3Box(p)
			end
		end
	end

	for i = 1, #pose.joints do
		take(pose.joints[i])
	end

	for i = 1, #(pose.extra or {}) do
		take(pose.extra[i])
	end

	tape.frames[#tape.frames + 1] = shot
end

SK.tape_record = function(event, machine, seconds)
	if not SK.pose_alive() then
		return "Nobody is posed. Left-click a person first.", true
	end

	local said, failed = SK.anim_play(event, machine, nil)

	if failed then
		return said, true
	end

	pose.play = nil
	pose.leg = {}

	seconds = tonumber(seconds)
	seconds = (seconds and seconds > 0) and seconds or SK.TAPE_SECONDS

	local t = SK.now()

	pose.tape = { event = event, machine = machine, step = SK.TAPE_STEP, seconds = seconds, frames = {} }
	pose.taping = { next_t = t, until_t = t + seconds, step = SK.TAPE_STEP }
	pose.tape_i = nil

	return string.format("Playing %s and recording %ss.", event, SK.num(seconds))
end

SK.tape_show = function(i)
	local tape = pose.tape

	if not tape or #tape.frames == 0 then
		return "ERR nothing recorded yet"
	end

	i = math.max(1, math.min(#tape.frames, math.floor(tonumber(i) or 1)))
	pose.frozen = tape.frames[i].rot
	pose.fixed = tape.frames[i].pos
	pose.rest = nil

	if pose.anim then
		pose.anim.at = tonumber(SK.num((i - 1) * tape.step)) or 0
	end

	return string.format("%ss of %ss", SK.num((i - 1) * tape.step), SK.num((#tape.frames - 1) * tape.step))
end

SK.tape_seek = function(i)
	local tape = pose.tape

	if not tape or #tape.frames == 0 then
		return "Nothing recorded yet. Play an animation first."
	end

	i = math.max(1, math.min(#tape.frames, math.floor(tonumber(i) or 1)))
	pose.tape_i = i
	pose.frozen = tape.frames[i].rot
	pose.fixed = tape.frames[i].pos
	pose.rest = nil

	if pose.anim then
		pose.anim.at = tonumber(SK.num((i - 1) * tape.step)) or 0
	end

	return string.format("At %ss of %ss.", SK.num((i - 1) * tape.step), SK.num((#tape.frames - 1) * tape.step))
end

SK.tape_step_by = function(by)
	if not pose.tape then
		return "Nothing recorded yet. Play an animation first."
	end

	return SK.tape_seek((pose.tape_i or 1) + (tonumber(by) or 0))
end

-- ───────────────────── ❀ ─────────────────────
--  Tape Keys
-- ───────────────────── ❀ ─────────────────────

SK.tape_key = function(name, quiet)
	local tape = pose.tape

	if not tape or #tape.frames == 0 then
		return "Nothing recorded yet. Play an animation first."
	end

	if #pose.frames >= SK.FRAME_CAP then
		return "The keyframe list is full. Delete some first."
	end

	local i = pose.tape_i or 1
	local frame = tape.frames[i]
	local gap = tape.keyed_at and (i - tape.keyed_at) * tape.step or nil
	local f = {
		name = SK.unique_name(name ~= nil and tostring(name) ~= "" and tostring(name)
			or (SK.num((i - 1) * tape.step) .. "s"),
			SK.frame_names(), " "),
		hold = gap and math.max(1 / 240, SK.secs(math.abs(gap))) or 0.5,
		dial = {},
		base = frame.rot,
		sits = frame.pos,
		group = SK.group_of(tape.event),
	}

	for j = 1, #pose.joints do
		f.dial[pose.joints[j]] = { 0, 0, 0 }
	end

	tape.keyed_at = i
	pose.frames[#pose.frames + 1] = f

	if not quiet then
		SK.frames_save()
	end

	return gap and string.format("Added %s as keyframe %d, %ss after the last.", f.name, #pose.frames, SK.num(f.hold))
		or string.format("Added %s as keyframe %d.", f.name, #pose.frames)
end

SK.TAPE_STRIDE = 1
pose.tape_stride = pose.tape_stride or SK.TAPE_STRIDE

SK.tape_key_to = function(stride)
	local tape = pose.tape

	if not tape or #tape.frames == 0 then
		return "Nothing recorded yet. Play an animation first."
	end

	stride = math.max(1, math.floor(tonumber(stride) or pose.tape_stride or SK.TAPE_STRIDE))

	local lo = math.max(1, math.min(#tape.frames, pose.tape_in or 1))
	local to = math.max(1, math.min(#tape.frames, pose.tape_i or #tape.frames))
	local back = lo > to
	local last = tape.range_end
	local keyed = last and (back and last <= lo and last >= to or not back and last >= lo and last <= to) and last or nil
	local from = keyed and (keyed + (back and -stride or stride)) or lo

	if back and to > from or not back and to < from then
		return "Nothing new to key. Move the bar past the last key."
	end

	local room = SK.FRAME_CAP - #pose.frames

	if room <= 0 then
		return "The keyframe list is full. Delete some first."
	end

	local n = 0
	local i = from
	local way = back and -stride or stride

	while (back and i >= to or not back and i <= to) and n < room do
		SK.tape_seek(i)
		SK.tape_key(nil, true)
		n = n + 1
		i = i + way
	end

	if tape.keyed_at ~= to and n < room then
		SK.tape_seek(to)
		SK.tape_key(nil, true)
		n = n + 1
	end

	tape.range_end = tape.keyed_at
	SK.frames_save()

	if tape.keyed_at ~= to then
		return string.format("Added %s, then the keyframe list was full.", SK.count(n, "keyframe"))
	end

	return string.format("Added %s, %s to %ss.", SK.count(n, "keyframe"), back and "back" or "up", SK.num((to - 1) * tape.step))
end

SK.group_of = function(event)
	local name = string.gsub(tostring(event or "clip"), "[|;=,]", " ")

	name = string.match(name, "^%s*(.-)%s*$")

	return name ~= "" and string.sub(name, 1, 20) or "clip"
end

SK.tape_clear = function()
	pose.tape, pose.taping, pose.tape_i = nil, nil, nil
end

-- ───────────────────── ❀ ─────────────────────
--  Panel Verbs
-- ───────────────────── ❀ ─────────────────────

SK.anim_status = function()
	if pose.anim and pose.frozen then
		return string.format("Frozen %ss into %s.", SK.num(pose.anim.at or 0), pose.anim.event)
	elseif pose.anim then
		return string.format("Playing %s, %ss in.", pose.anim.event, SK.num(SK.now() - pose.anim.fired_t))
	elseif pose.frozen then
		return "Frozen where they stand."
	end
	return ""
end

mod.sk_gun = function(what)
	if not SK.pose_alive() then
		return "Nobody is posed. Left-click a person first."
	end

	if what == "hide" then
		if pose.gun then
			return "already hidden, " .. #pose.gun .. " parts"
		end

		pose.gun = SK.gun_hide(pose.unit)

		return "Hid their weapon, " .. SK.count(#pose.gun, "part") .. "."
	end

	if what == "show" then
		if not pose.gun then
			return "nothing was hidden"
		end

		local shown = SK.gun_show(pose.gun)

		pose.gun = nil

		return "Their weapon is back, " .. SK.count(shown, "part") .. "."
	end

	return pose.gun and ("hidden, " .. #pose.gun .. " parts") or "not hidden"
end

SK.poses = function(filter)
	local out = {}
	local want = (filter and filter ~= "") and string.lower(filter) or nil
	local function keep(row)
		if not want then
			return true
		end
		return string.find(string.lower(row.name), want, 1, true) ~= nil
			or string.find(string.lower(row.source), want, 1, true) ~= nil
	end
	local emotes = SK.emotes()
	for i = 1, #emotes do
		local e = emotes[i]
		local row = { event = e.event, machine = e.machine, name = e.name, source = e.breed, seconds = e.seconds }
		if keep(row) then out[#out + 1] = row end
	end
	local book = SK.animations()
	for i = 1, #book do
		local m = book[i]
		for j = 1, #(m.events or {}) do
			local row = { event = m.events[j], machine = m.machine, name = m.events[j], source = m.short, seconds = 0 }
			if keep(row) then out[#out + 1] = row end
		end
	end
	return out
end

SK.TAPE_BUSY = { seek = true, ["in"] = true, step = true, key = true, keyto = true }

mod.sk_tape = function(what, a, b)
	if pose.taping and SK.TAPE_BUSY[what] then
		return "Still recording. Wait for it to finish."
	end
	if what == "record" then
		if not a or a == "" then return "That row has no animation to play." end
		return SK.tape_record(tostring(a), b and tostring(b) or nil, nil)
	end
	if what == "seek" then
		return SK.tape_seek(a)
	end
	if what == "in" then
		local frames = pose.tape and #pose.tape.frames or 0

		if frames == 0 then
			return "ERR record something first"
		end

		pose.tape_in = math.max(1, math.min(frames, math.floor(tonumber(a) or 1)))

		SK.tape_show(pose.tape_in)

		if pose.tape.keyed_at and pose.tape_in ~= pose.tape.keyed_at then
			pose.tape.keyed_at = nil
		end

		pose.tape.range_end = nil

		return string.format("from %ss", SK.num((pose.tape_in - 1) * pose.tape.step))
	end
	if what == "step" then
		return SK.tape_step_by(a)
	end
	if what == "key" then
		return SK.tape_key(a)
	end
	if what == "keyto" then
		return SK.tape_key_to(a)
	end
	if what == "stride" then
		pose.tape_stride = math.max(1, math.min(4, math.floor(tonumber(a) or SK.TAPE_STRIDE)))
		return pose.tape_stride == 1 and "Now keys every frame."
			or ("Now keys every " .. ({ "", "2nd", "3rd", "4th" })[pose.tape_stride] .. " frame.")
	end
	if what == "clear" then
		SK.tape_clear()
		return "tape cleared"
	end
	if not pose.tape then
		return "nothing recorded"
	end
	if pose.taping then
		return "recording " .. pose.tape.event
	end
	return string.format("%s: %ss of %ss", pose.tape.event,
		SK.num(((pose.tape_i or 1) - 1) * pose.tape.step),
		SK.num((#pose.tape.frames - 1) * pose.tape.step))
end

-- ───────────────────── ❀ ─────────────────────
--  Keyframe Folders
-- ───────────────────── ❀ ─────────────────────

SK.group_time = function(name)
	local a, b = SK.group_span(name)
	if not a then
		return nil
	end
	local total = 0
	for i = a, b do
		total = total + (pose.frames[i].hold or 2)
	end
	return total
end

SK.group_span = function(name)
	local a, b = nil, nil
	for i = 1, #pose.frames do
		if pose.frames[i].group == name then
			a = a or i
			b = i
		elseif a then
			break
		end
	end
	return a, b
end

mod.sk_group = function(what, name, extra)
	if what == nil or what == "" then
		return mod.sk_keyframe("folders")
	end
	local a, b = SK.group_span(tostring(name or ""))
	if not a then
		return "There is no folder called " .. tostring(name) .. "."
	end
	if what == "flip" then
		if b == a then
			return "Only one keyframe here, so nothing to reverse."
		end
		return mod.sk_keyframe("flip", a, b)
	end
	if what == "delete" then
		for _ = a, b do
			table.remove(pose.frames, a)
		end
		SK.frames_save()
		return string.format("Deleted %s and its %s.", name, SK.count(b - a + 1, "keyframe"))
	end
	if what == "rename" then
		local text = tostring(extra or "")
		if not SK.frame_name_ok(text) then
			return "Not renamed. Use letters, digits, spaces, _ and -."
		end
		for i = a, b do
			pose.frames[i].group = text
		end
		SK.frames_save()
		return string.format("Renamed %s to %s.", name, text)
	end
	if what == "time" then
		local total = 0
		for i = a, b do
			total = total + (pose.frames[i].hold or 2)
		end
		local want = math.max(1 / 240, tonumber(extra) or total)
		if total <= 0 then
			return "ERR the folder has no time to scale"
		end
		local by = want / total
		for i = a, b do
			pose.frames[i].hold = math.max(1 / 240, SK.secs((pose.frames[i].hold or 2) * by))
		end
		SK.frames_save()
		return string.format("%s takes %ss", name, SK.num(want))
	end
	if what == "loose" then
		for i = a, b do
			pose.frames[i].group = nil
		end
		SK.frames_save()
		return string.format("%s is loose, %s", name, SK.count(b - a + 1, "keyframe"))
	end
	return "ERR group verbs: flip delete rename loose"
end

mod.group_time = function(name)
	return SK.group_time(tostring(name or ""))
end

-- ───────────────────── ❀ ─────────────────────
--  Anim Verb
-- ───────────────────── ❀ ─────────────────────

mod.sk_play_pose = function(event, machine)
	if not event or event == "" then
		return "ERR nothing to play"
	end
	return SK.anim_play(tostring(event), machine and tostring(machine) or nil, nil)
end

mod.sk_anim = function(what, a, b)
	if what == nil or what == "" then
		local list = SK.emotes()
		if #list == 0 then return "no emotes found" end
		local out = {}
		for i = 1, #list do
			out[#out + 1] = string.format("%d:%s(%s,%ss)", i, list[i].name, list[i].breed, SK.num(list[i].seconds))
		end
		return table.concat(out, " ")
	end
	if what == "status" then
		return SK.anim_status() ~= "" and SK.anim_status() or "nothing playing"
	end
	if what == "freeze" then
		return SK.pose_freeze()
	end
	if what == "thaw" then
		return SK.pose_thaw()
	end
	if what == "rest" then
		return SK.pose_rest()
	end
	if what == "play" then
		local n = tonumber(a)
		if n then
			local e = SK.emotes()[n]
			if not e then return "ERR no emote " .. tostring(a) end
			return SK.anim_play(e.event, e.machine, tonumber(b))
		end
		if a == nil or a == "" then return "ERR anim play N or EVENT" end
		return SK.anim_play(tostring(a), nil, tonumber(b))
	end
	return "ERR anim, anim play N|EVENT [AT], freeze, thaw, rest, status"
end

SK.pose_bake = function()
	local a = pose.anim

	if (not a or not a.was) and pose.frozen and SK.pose_alive() then
		local out, base = {}, {}

		for i = 1, #pose.joints do
			local name = pose.joints[i]
			local d = pose.dial[name] or { 0, 0, 0 }

			out[name] = { d[1], d[2], d[3] }
			base[name] = pose.frozen[name]
		end

		return out, base, pose.fixed
	end

	if not a or not a.was or not SK.pose_alive() then
		return nil
	end

	local out, base = {}, {}

	for i = 1, #pose.joints do
		local name = pose.joints[i]
		local was = a.was[name]

		if was and Unit.has_node(pose.unit, name) then
			local x, y, z = SK.pose_dial_of(was:unbox(), Unit.local_rotation(pose.unit, Unit.node(pose.unit, name)))

			out[name] = { SK.pose_clamp(SK.num(x)), SK.pose_clamp(SK.num(y)), SK.pose_clamp(SK.num(z)) }
			base[name] = was
		else
			out[name] = { 0, 0, 0 }
		end
	end

	return out, base
end

SK.anim_of_now = function()
	if not pose.anim then
		return nil
	end
	return { event = pose.anim.event, machine = pose.anim.machine or "", at = pose.anim.at or (tonumber(SK.num(SK.now() - pose.anim.fired_t)) or 0) }
end

-- ───────────────────── ❀ ─────────────────────
--  Object & Names
-- ───────────────────── ❀ ─────────────────────

G.object = G.object or { unit = nil, node = nil, from = nil, turn = nil, move = { 0, 0, 0 }, spin = { 0, 0, 0 } }
local object = G.object

SK.object_alive = function()
	local ok, alive = pcall(Unit.alive, object.unit)

	return object.unit ~= nil and object.node ~= nil and ok and alive == true
end

SK.NAME_CATALOG = "./../mods/ResourceLoader/scripts/mods/ResourceLoader/catalog/resources/unit_%03d.lua"

SK.OUR_NAMES = "SkeletonKey/anim/unit_names"

SK.names_load = function()
	if SK.names then
		return SK.names_n
	end

	local names, n = {}, 0

	local okn, ours = pcall(function()
		return mod:io_dofile(SK.OUR_NAMES)
	end)

	if okn and type(ours) == "table" then
		for id, path in pairs(ours) do
			if type(id) == "string" and type(path) == "string" then
				names[id] = path
				n = n + 1
			end
		end
	end

	for i = 1, 99 do
		local ok, body = pcall(function()
			local f = Mods.lua.io.open(string.format(SK.NAME_CATALOG, i), "r")

			if not f then
				return nil
			end

			local text = f:read("*a")

			f:close()

			return text
		end)

		if not ok or type(body) ~= "string" then
			break
		end

		local chunk = SK.compile(body, "=catalog_unit_" .. i)
		local loaded, t = pcall(chunk or error)

		if loaded and type(t) == "table" and type(t.resources) == "table" then
			for _, row in ipairs(t.resources) do
				local key = row[1]

				if type(key) == "string" and not key:match("^#ID%[%x+%]$") then
					local hashed, id = pcall(Application.resource_id, key)

					if hashed and type(id) == "string" then
						names[id] = key
						n = n + 1
					end
				end
			end
		end
	end

	SK.names, SK.names_n = names, n

	return n
end

SK.unit_name = function(unit)
	SK.names_load()

	local ok, debug_name = pcall(Unit.debug_name, unit)
	local hex = ok and tostring(debug_name):match("%[(%x+)%]")

	return hex and SK.names and SK.names[hex] or nil
end

-- ───────────────────── ❀ ─────────────────────
--  Paste
-- ───────────────────── ❀ ─────────────────────

SK.paste_at = function(at, clip)
	clip = clip or SK.clip

	if not clip or not clip.members then
		return nil, "Nothing to paste. Copy something first."
	end

	local okw, world = pcall(function()
		return Managers.world and Managers.world:world("level_world")
	end)

	if not okw or not world then
		return nil, "There is no level to paste into right now."
	end

	local oke, ax, ay, az = pcall(Vector3.to_elements, at)

	if not oke then
		return nil, "Could not find where to put it."
	end

	local made_all, first_held = {}, nil

	for i = 1, #clip.members do
		local m = clip.members[i]
		local turn = m.turn and m.turn:unbox() or Quaternion.identity()
		local where = Vector3(ax + m.off[1], ay + m.off[2], az + m.off[3])
		local made, copy = false, nil

		if SK.spawnable(m.name) then
			made, copy = pcall(World.spawn_unit_ex, world, m.name, nil, where, turn)
		end

		if made and copy then
			SK.copies = SK.copies or {}
			SK.copies[#SK.copies + 1] = copy
			SK.meshy_touch(copy)

			if m.node and m.size and SK.node_ok(copy, m.node) then
				pcall(Unit.set_local_scale, copy, m.node, Vector3(m.size[1], m.size[2], m.size[3]))
				SK.collide_pending[copy] = SK.now()
				SK.collide_built[copy] = m.size[1]
			end

			made_all[#made_all + 1] = { unit = copy, node = m.node }
		end
	end

	if #made_all == 0 then
		return nil, "That is not loaded in this level."
	end

	local units = {}

	for i = 1, #made_all do
		units[i] = made_all[i].unit
	end

	SK.obj_mark("spawn", units)

	local held = false

	object.unit, object.node, object.crew = nil, nil, nil

	for i = 1, #made_all do
		local one = made_all[i]

		if one.node then
			local ok = held and SK.object_add(one.unit, one.node) or (not held and SK.object_take(one.unit, one.node))

			if ok then
				held = true
				SK.keep_add(one.unit, one.node)
			end
		end
	end

	return made_all[1].unit, nil, held
end

-- ───────────────────── ❀ ─────────────────────
--  Items & Labels
-- ───────────────────── ❀ ─────────────────────

SK.kept = SK.kept or {}

SK.KINDS = {
	{ "player_spawner_system", "Spawn Point" },
	{ "minion_spawner_system", "Enemy Spawn" },
	{ "cinematic_scene_system", "Scene Mark" },
	{ "companion_spawner_system", "Companion Spawn" },
	{ "side_mission_spawner_system", "Side Mission Spawn" },
}

SK.unit_kind = function(unit)
	for i = 1, #SK.KINDS do
		local ok, ext = pcall(ScriptUnit.has_extension, unit, SK.KINDS[i][1])

		if ok and ext then
			return SK.KINDS[i][2]
		end
	end

	return nil
end

SK.LABELS = {}

SK.VFX_MATERIAL = "12d542c0"

SK.is_vfx_sign = function(unit)
	local okn, n = pcall(Unit.num_meshes, unit)

	if not okn or n ~= 1 then
		return false
	end

	local okm, mesh = pcall(Unit.mesh, unit, 1)

	if not okm or not mesh then
		return false
	end

	local okt, mat = pcall(Mesh.material, mesh, 1)

	return okt and mat ~= nil and string.find(tostring(mat), SK.VFX_MATERIAL, 1, true) ~= nil
end

SK.unit_label = function(unit, marks_only)
	if SK.is_vfx_sign(unit) then
		return "VFX Marker"
	end

	if next(SK.LABELS) == nil then
		return nil
	end

	local ok, d = pcall(Unit.debug_name, unit)
	local hex = ok and tostring(d):match("%[(%x+)%]")
	local one = hex and SK.LABELS[hex]

	if not one or (marks_only and not one.mark) then
		return nil
	end

	return one[1]
end

SK.keep_name = function(unit)
	local path = SK.unit_name(unit)

	local made_up = path and string.find(path, "content/units/zz", 1, true)

	if path and not made_up then
		return SK.tail(string.match(path, "([^/]+)$") or path, 22)
	end

	local kind = SK.unit_kind(unit) or SK.unit_label(unit)

	if kind then
		return kind
	end

	local ok, d = pcall(Unit.debug_name, unit)

	return "#" .. (ok and tostring(d):match("%[(%x+)%]") or "?")
end

SK.KIND_PROP = { 215, 205, 176 }
SK.KIND_MARK = { 120, 190, 120 }
SK.KIND_SOUND = { 110, 160, 235 }
SK.KIND_UNKNOWN = { 141, 148, 160 }

SK.kind_of = function(unit)
	local path = SK.unit_name(unit)
	local job = SK.unit_kind(unit)

	if job then
		return job, SK.KIND_MARK
	end

	if path and string.find(path, "core/units/wwise", 1, true) then
		return "Sound source", SK.KIND_SOUND
	end

	if path and string.find(path, "core/gwnav/", 1, true) then
		return "Nav marker", SK.KIND_MARK
	end

	if path and (string.find(path, "/gizmos/", 1, true) or string.find(path, "reflection_probe", 1, true)
		or string.find(path, "core/units/camera", 1, true)) then
		return "Level marker", SK.KIND_MARK
	end

	if SK.unit_label(unit, true) then
		return "Hidden marker", SK.KIND_MARK
	end

	if not path or string.find(path, "content/units/zz", 1, true) then
		return "Path unknown", SK.KIND_UNKNOWN
	end

	return "Prop", SK.KIND_PROP
end

SK.distance_to = function(unit)
	local cf = SK.cam_frame()
	local okp, at = pcall(Unit.world_position, unit, 1)

	if not cf or not okp or not at then
		return nil
	end

	local okd, d = pcall(Vector3.distance, cf.pos, at)

	return okd and d and math.floor(d + 0.5) or nil
end

SK.shown_name = function(name)
	if type(name) ~= "string" or name == "" or string.sub(name, 1, 1) == "#" then
		return "Unnamed Prop"
	end

	return name
end

SK.short_name = function(unit)
	local name = SK.keep_name(unit)

	if not name or string.sub(name, 1, 1) == "#" then
		return nil
	end

	return name
end

SK.keep_add = function(unit, node)
	if not unit then
		return nil, "nothing to keep"
	end

	for i = 1, #SK.kept do
		if SK.kept[i].unit == unit then
			return nil, "that one is on the list already"
		end
	end

	SK.kept[#SK.kept + 1] = { unit = unit, node = node, name = SK.keep_name(unit) }

	return #SK.kept
end

SK.keep_list = function()
	for i = #SK.kept, 1, -1 do
		local ok, alive = pcall(Unit.alive, SK.kept[i].unit)

		if not ok or not alive then
			table.remove(SK.kept, i)
		end
	end

	return SK.kept
end

-- ───────────────────── ❀ ─────────────────────
--  Undo
-- ───────────────────── ❀ ─────────────────────

SK.obj_past = SK.obj_past or {}
SK.OBJ_PAST_MOST = 24

SK.OBJ_MOVE_MOST = 1000

SK.UNDO_WORDS = { spawn = "paste", gyro = "drag", add = "Ctrl+click", reset = "Reset", scale = "size change",
	move = "move", turn = "turn" }

SK.obj_mark = function(kind, made)
	local last = SK.obj_past[#SK.obj_past]

	if last and kind ~= "spawn" and last.kind == kind and last.unit == object.unit and (SK.now() - (last.at or 0)) < 0.5 then
		last.at = SK.now()

		return
	end

	local crew = {}

	for i = 1, #(object.crew or {}) do
		local one = object.crew[i]

		crew[i] = { unit = one.unit, node = one.node, from = one.from, turn = one.turn, size = one.size }
	end

	SK.obj_past[#SK.obj_past + 1] = {
		kind = kind,
		at = SK.now(),
		made = made,
		unit = object.unit,
		node = object.node,
		from = object.from,
		turn = object.turn,
		move = { object.move[1], object.move[2], object.move[3] },
		spin = { object.spin[1], object.spin[2], object.spin[3] },
		grow = object.grow or 1,
		crew = crew,
	}

	while #SK.obj_past > SK.OBJ_PAST_MOST do
		table.remove(SK.obj_past, 1)
	end
end

SK.past_alive = function(was)
	if SK.alive(was.unit) then
		return true
	end

	for _, one in ipairs(was.crew or {}) do
		if SK.alive(one.unit) then
			return true
		end
	end

	for _, made in ipairs(type(was.made) == "table" and was.made or {}) do
		if SK.alive(made) then
			return true
		end
	end

	return false
end

SK.past_prune = function()
	while #SK.obj_past > 0 and not SK.past_alive(SK.obj_past[#SK.obj_past]) do
		table.remove(SK.obj_past)
	end
end

SK.undo_last = function()
	SK.hidden_prune()
	SK.past_prune()

	local last_obj = SK.obj_past[#SK.obj_past]
	local last_hide = SK.hidden[#SK.hidden]

	if last_hide and (not last_obj or (last_hide.when or 0) >= (last_obj.at or 0)) then
		local shown = SK.gun_show(last_hide.parts)

		if SK.phys then
			SK.phys.give_back(last_hide)
		end

		table.remove(SK.hidden)

		return string.format("Brought back %s. %s", SK.count(shown, "part"),
			#SK.hidden > 0 and (SK.count(#SK.hidden, "thing") .. " still hidden.") or "Nothing else is hidden.")
	end

	return SK.obj_back()
end

SK.obj_back = function()
	SK.past_prune()

	local was = table.remove(SK.obj_past)

	if not was then
		return "Nothing to undo."
	end

	if type(was.made) == "table" then
		local okw, world = pcall(function()
			return Managers.world and Managers.world:world("level_world")
		end)

		for _, made in ipairs(was.made) do
			if okw and world and SK.alive(made) then
				pcall(World.destroy_unit, world, made)
			end
		end
	end

	if was.unit ~= object.unit then
		object.lock = nil
	end

	object.unit, object.node = was.unit, was.node
	object.from, object.turn = was.from, was.turn
	object.move = { was.move[1], was.move[2], was.move[3] }
	object.spin = { was.spin[1], was.spin[2], was.spin[3] }
	object.grow = was.grow
	object.crew = was.crew
	SK.crew_prune()

	if SK.object_alive() then
		SK.object_place()
	else
		object.unit, object.node, object.from, object.turn, object.crew = nil, nil, nil, nil, nil
	end

	return "Undid the " .. (SK.UNDO_WORDS[was.kind] or was.kind) .. "."
end

-- ───────────────────── ❀ ─────────────────────
--  Take & Add
-- ───────────────────── ❀ ─────────────────────

SK.unit_size = function(unit, node)
	local ok, v = pcall(Unit.local_scale, unit, node)

	if not ok or not v then
		return { 1, 1, 1 }
	end

	local oke, x, y, z = pcall(Vector3.to_elements, v)

	if not oke then
		return { 1, 1, 1 }
	end

	return { x, y, z }
end

SK.top_node = function(unit, node)
	local at, guard = node, 0

	while at and guard < 64 do
		guard = guard + 1

		local ok, up = pcall(Unit.scene_graph_parent, unit, at)

		if not ok or not up or up == at then
			break
		end

		at = up
	end

	return at or node
end

SK.first_size = SK.first_size or setmetatable({}, { __mode = "k" })

SK.object_take = function(unit, node)
	if node == nil then
		return nil, "no node for that one"
	end

	node = SK.top_node(unit, node)

	local okp, p = pcall(Unit.local_position, unit, node)
	local okr, r = pcall(Unit.local_rotation, unit, node)

	if not okp or not p or not okr or not r then
		return nil, "The game will not let that be held."
	end

	if object.unit ~= unit then
		object.lock = nil
	end

	object.unit, object.node = unit, node
	object.from, object.turn = Vector3Box(p), QuaternionBox(r)
	object.move, object.spin = { 0, 0, 0 }, { 0, 0, 0 }
	local now = SK.unit_size(unit, node)
	local first = SK.first_size[unit]

	if not first then
		first = { now[1], now[2], now[3] }
		SK.first_size[unit] = first
	end

	SK.collide_built[unit] = SK.collide_built[unit] or now[1]

	if SK.phys then
		SK.phys.taken(unit)
	end

	object.grow = (first[1] ~= 0) and (now[1] / first[1]) or 1
	object.boxed = nil
	object.crew = { { unit = unit, node = node, from = Vector3Box(p), turn = QuaternionBox(r),
		size = first } }

	return true
end

SK.base_size = function(unit, node)
	local now = SK.unit_size(unit, node)
	local grow = object.grow or 1

	if grow == 0 then
		return now
	end

	return { now[1] / grow, now[2] / grow, now[3] / grow }
end

SK.object_add = function(unit, node)
	if not SK.object_alive() then
		return nil, "Nothing is held to add to. Click something first."
	end

	node = SK.top_node(unit, node)

	local okp, p = pcall(Unit.local_position, unit, node)
	local okr, r = pcall(Unit.local_rotation, unit, node)

	if not okp or not p or not okr or not r then
		return nil, "The game will not let that be added."
	end

	for i = 1, #(object.crew or {}) do
		if object.crew[i].unit == unit and object.crew[i].node == node then
			return nil, "That is already held."
		end
	end

	object.crew = object.crew or {}
	object.crew[#object.crew + 1] = { unit = unit, node = node, from = Vector3Box(p), turn = QuaternionBox(r),
		size = SK.base_size(unit, node) }
	SK.collide_built[unit] = SK.collide_built[unit] or SK.unit_size(unit, node)[1]

	if SK.phys then
		SK.phys.taken(unit)
	end

	return #object.crew
end

SK.hold_kept = function(rows)
	local kept = SK.keep_list()

	object.unit, object.node, object.crew = nil, nil, nil
	object.lock = nil

	local n = 0

	for _, i in ipairs(rows) do
		local one = kept[i]

		if one then
			if n == 0 then
				if SK.object_take(one.unit, one.node) then
					n = 1
				end
			elseif SK.object_add(one.unit, one.node) then
				n = n + 1
			end
		end
	end

	return n
end

SK.crew_prune = function()
	local crew = object.crew

	for i = #(crew or {}), 1, -1 do
		if object.crew and crew[i] and not SK.alive(crew[i].unit) then
			SK.crew_drop(i)
		end
	end
end

SK.crew_drop = function(i)
	local crew = object.crew

	if not crew or not crew[i] then
		return
	end

	table.remove(crew, i)

	if #crew == 0 then
		object.unit, object.node, object.from, object.turn, object.crew = nil, nil, nil, nil, nil
		object.lock = nil

		return
	end

	local first = crew[1]

	object.unit, object.node, object.from, object.turn = first.unit, first.node, first.from, first.turn
end

-- ───────────────────── ❀ ─────────────────────
--  Collision & Place
-- ───────────────────── ❀ ─────────────────────

SK.COLLIDE_SETTLE = 0.3
SK.collide_pending = SK.collide_pending or setmetatable({}, { __mode = "k" })
SK.collide_built = SK.collide_built or setmetatable({}, { __mode = "k" })

SK.ACTOR_OWNERS = { "destructible_system", "hazard_prop_system", "unit_data_system", "door_system",
	"pickup_system", "interactee_system", "health_system" }

SK.game_owns = function(unit)
	for _, system in ipairs(SK.ACTOR_OWNERS) do
		local ok, has = pcall(ScriptUnit.has_extension, unit, system)

		if ok and has then
			return true
		end
	end

	return false
end

SK.rebuild_actors = function(unit)
	local ok, alive = pcall(Unit.alive, unit)

	if not ok or not alive or SK.game_owns(unit) then
		return 0
	end

	local okn, n = pcall(Unit.num_actors, unit)

	if not okn or type(n) ~= "number" then
		return 0
	end

	local okw, world = pcall(function()
		return Managers.world and Managers.world:world("level_world")
	end)

	if okw and world then
		pcall(World.update_unit, world, unit)
	end

	local done = 0

	for i = 1, n do
		local oka, actor = pcall(Unit.actor, unit, i)

		if oka and actor then
			local okd, moving = pcall(Actor.is_dynamic, actor)

			if not (okd and moving) then
				pcall(Unit.destroy_actor, unit, i)
				pcall(Unit.create_actor, unit, i)
				done = done + 1
			end
		end
	end

	if SK.phys then
		SK.phys.rebuilt(unit)
	end

	return done
end

SK.collide_tick = function()
	local now = SK.now()

	for unit, at in pairs(SK.collide_pending) do
		if now - at >= SK.COLLIDE_SETTLE then
			SK.collide_pending[unit] = nil
			SK.rebuild_actors(unit)
		end
	end
end

SK.object_place = function()
	if not SK.object_alive() or not object.from then
		return false
	end

	local crew = object.crew

	if not crew or #crew == 0 then
		crew = { { unit = object.unit, node = object.node, from = object.from, turn = object.turn } }
	end

	for i = 1, #crew do
		local one = crew[i]
		local ok, alive = pcall(Unit.alive, one.unit)

		if ok and alive and one.from then
			local from = one.from:unbox()
			local to = Vector3(from.x + object.move[1], from.y + object.move[2], from.z + object.move[3])

			pcall(Unit.set_local_position, one.unit, one.node, to)

			if one.turn then
				pcall(Unit.set_local_rotation, one.unit, one.node,
					SK.pose_rot(one.turn:unbox(), object.spin[1], object.spin[2], object.spin[3]))
			end

			local grow = object.grow or 1
			local size = one.size or { 1, 1, 1 }

			pcall(Unit.set_local_scale, one.unit, one.node,
				Vector3(size[1] * grow, size[2] * grow, size[3] * grow))

			local built = SK.collide_built[one.unit]

			if not built or math.abs(built - size[1] * grow) > 0.0001 then
				SK.collide_built[one.unit] = size[1] * grow
				SK.collide_pending[one.unit] = SK.now()
			end

			if SK.phys then
				SK.phys.placed(one.unit)
			end

			SK.meshy_touch(one.unit)
		end
	end

	return true
end

SK.object_line = function()
	if not SK.object_alive() then
		return "nothing held"
	end

	return string.format("move=%s,%s,%s turn=%s,%s,%s",
		SK.num(object.move[1]), SK.num(object.move[2]), SK.num(object.move[3]),
		SK.num(object.spin[1]), SK.num(object.spin[2]), SK.num(object.spin[3]))
end

-- ───────────────────── ❀ ─────────────────────
--  Gyro
-- ───────────────────── ❀ ─────────────────────

SK.GYRO_PIX = 120
SK.GYRO_BALL = 46
SK.GYRO_GRAB = 12
SK.GYRO_RINGS = 18
SK.GYRO_FLAT = 0.02

G.gyro = G.gyro or { hold = nil, frame = nil }

local gyro = G.gyro

SK.cam_frame = function()
	local cam, pos, rot = SK.pick_camera()

	if not cam or not pos or not rot then
		return nil
	end

	local okf, fov = pcall(Camera.vertical_fov, cam)

	if not okf or not fov then
		return nil
	end

	return {
		pos = pos,
		fwd = Quaternion.forward(rot),
		right = Quaternion.right(rot),
		up = Quaternion.up(rot),
		half = math.tan(fov / 2),
		w = RESOLUTION_LOOKUP.width,
		h = RESOLUTION_LOOKUP.height,
	}
end

SK.world_to_screen = function(cf, p)
	if not cf or not p then
		return nil
	end

	local v = p - cf.pos
	local f = Vector3.dot(v, cf.fwd)

	if f <= 0.05 then
		return nil
	end

	local nx = Vector3.dot(v, cf.right) / (f * cf.half * (cf.w / cf.h))
	local ny = Vector3.dot(v, cf.up) / (f * cf.half)

	return (nx + 1) * 0.5 * cf.w, (1 - ny) * 0.5 * cf.h, f
end

SK.gyro_scale = function(cf, depth, pixels)
	return pixels * depth * cf.half * 2 / cf.h
end

SK.object_centre = function()
	SK.crew_prune()

	if not object.from then
		return nil
	end

	local crew = object.crew

	if not crew or #crew == 0 then
		crew = { { unit = object.unit, node = object.node, from = object.from } }
	end

	local sx, sy, sz, n = 0, 0, 0, 0

	for i = 1, #crew do
		local one = crew[i]
		local okw, w = pcall(Unit.world_position, one.unit, one.node)
		local x, y, z

		if okw and w then
			local oke, ex, ey, ez = pcall(Vector3.to_elements, w)

			if oke then
				x, y, z = ex, ey, ez
			end
		end

		if not x and one.from then
			local okv, fx, fy, fz = pcall(Vector3.to_elements, one.from:unbox())

			if okv then
				x, y, z = fx + object.move[1], fy + object.move[2], fz + object.move[3]
			end
		end

		if x then
			sx, sy, sz, n = sx + x, sy + y, sz + z, n + 1
		end
	end

	if n == 0 then
		return nil
	end

	return Vector3(sx / n, sy / n, sz / n)
end

SK.object_axes = function()
	local crew = object.crew
	local one = crew and crew[1] or { unit = object.unit, node = object.node, turn = object.turn }
	local okw, q = pcall(Unit.world_rotation, one.unit, one.node)

	if not okw or not q then
		local turn = one.turn or object.turn

		if turn then
			okw, q = pcall(SK.pose_rot, turn:unbox(), object.spin[1], object.spin[2], object.spin[3])
		end
	end

	if okw and q then
		return Quaternion.right(q), Quaternion.forward(q), Quaternion.up(q)
	end

	return Vector3(1, 0, 0), Vector3(0, 1, 0), Vector3(0, 0, 1)
end

SK.object_into_parent = function()
	local crew = object.crew
	local one = crew and crew[1] or { unit = object.unit, node = object.node }
	local okw, w = pcall(Unit.world_rotation, one.unit, one.node)
	local okl, l = pcall(Unit.local_rotation, one.unit, one.node)

	if not okw or not w or not okl or not l then
		return nil
	end

	local okp, parent = pcall(Quaternion.multiply, w, Quaternion.inverse(l))

	if not okp or not parent then
		return nil
	end

	local oki, back = pcall(Quaternion.inverse, parent)

	return oki and back or nil
end

SK.gyro_frame = function()
	if SK.object_alive() and SK.is_hidden(object.unit) then
		object.lock = nil
	end

	if object.boxed and not object.lock and #(object.crew or {}) > 1 then
		gyro.frame = nil

		return nil
	end

	if not SK.object_alive() or SK.is_hidden(object.unit) then
		gyro.frame = nil

		return nil
	end

	local cf = SK.cam_frame()
	local o = cf and SK.object_centre()

	if not o then
		gyro.frame = nil

		return nil
	end

	local ox, oy, depth = SK.world_to_screen(cf, o)

	if not ox then
		gyro.frame = nil

		return nil
	end

	local len = SK.gyro_scale(cf, depth, SK.GYRO_PIX)
	local rad = SK.gyro_scale(cf, depth, SK.GYRO_BALL)
	local a1, a2, a3 = SK.object_axes()
	local ax = { a1, a2, a3 }
	local out = { ox = ox, oy = oy, ring = {}, tip = {}, locked = SK.object_locked() }

	for a = 1, 3 do
		local x, y = SK.world_to_screen(cf, o + ax[a] * len)

		out.tip[a] = x and { x, y } or false
	end

	for r = 1, 3 do
		local u, v = ax[r % 3 + 1], ax[(r + 1) % 3 + 1]
		local row = {}

		for d = 1, SK.GYRO_RINGS do
			local a = (d / SK.GYRO_RINGS) * math.pi * 2
			local x, y = SK.world_to_screen(cf, o + u * (rad * math.cos(a)) + v * (rad * math.sin(a)))

			row[d] = x and { x, y } or false
		end

		out.ring[r] = row
	end

	gyro.frame = out

	return out
end

-- ───────────────────── ❀ ─────────────────────
--  Gyro Hit
-- ───────────────────── ❀ ─────────────────────

local function seg_gap(px, py, x0, y0, x1, y1)
	local dx, dy = x1 - x0, y1 - y0
	local len2 = dx * dx + dy * dy
	local t = 0

	if len2 > 0 then
		t = ((px - x0) * dx + (py - y0) * dy) / len2
		t = math.max(0, math.min(1, t))
	end

	local gx, gy = x0 + dx * t - px, y0 + dy * t - py

	return math.sqrt(gx * gx + gy * gy)
end

SK.gyro_hit = function(x, y)
	local f = gyro.frame

	if not f then
		return nil
	end

	local away = math.sqrt((x - f.ox) * (x - f.ox) + (y - f.oy) * (y - f.oy))
	local best, gap = nil, SK.GYRO_GRAB

	for r = 1, 3 do
		local row = f.ring[r] or {}

		for d = 1, #row do
			local a, b = row[d], row[d % #row + 1]

			if a and b then
				local g = seg_gap(x, y, a[1], a[2], b[1], b[2])

				if g < gap then
					best, gap = "r" .. r, g
				end
			end
		end
	end

	if away > SK.GYRO_BALL * 1.15 then
		for a = 1, 3 do
			local tip = f.tip[a]

			if tip then
				local d = seg_gap(x, y, f.ox, f.oy, tip[1], tip[2])

				if d < gap then
					best, gap = a, d
				end
			end
		end
	end

	return best
end

SK.gyro_along = function(dir, anchor, x, y)
	local from, ray = SK.pick_ray_at(x, y)

	if not from or not ray then
		return nil
	end

	local b = Vector3.dot(dir, ray)
	local denom = 1 - b * b

	if denom < SK.GYRO_FLAT then
		return nil
	end

	local w0 = anchor - from

	return (b * Vector3.dot(ray, w0) - Vector3.dot(dir, w0)) / denom
end

-- ───────────────────── ❀ ─────────────────────
--  Gyro Drag
-- ───────────────────── ❀ ─────────────────────

SK.gyro_grab = function(what, x, y)
	SK.crew_prune()

	local f = gyro.frame

	if not f or not what or not SK.object_alive() then
		return false
	end

	local hold = {
		what = what,
		x0 = x,
		y0 = y,
		move = { object.move[1], object.move[2], object.move[3] },
		spin = { object.spin[1], object.spin[2], object.spin[3] },
	}

	if type(what) == "number" then
		local o = SK.object_centre()
		local a1, a2, a3 = SK.object_axes()
		local dir = ({ a1, a2, a3 })[what]

		if not o or not dir then
			return false
		end

		local t = SK.gyro_along(dir, o, x, y)

		if not t then
			return false
		end

		hold.anchor, hold.dir, hold.t0 = Vector3Box(o), Vector3Box(dir), t

		local back = SK.object_into_parent()

		hold.back = back and QuaternionBox(back) or nil
	else
		local r = tonumber(string.match(tostring(what), "^r(%d)$"))
		local crew = object.crew
		local turn = (crew and crew[1] and crew[1].turn) or object.turn

		if not r or not turn then
			return false
		end

		local okq, q = pcall(SK.pose_rot, turn:unbox(), object.spin[1], object.spin[2], object.spin[3])

		if not okq or not q then
			return false
		end

		local a1, a2, a3 = SK.object_axes()
		local axis = ({ a1, a2, a3 })[r]
		local cf = SK.cam_frame()
		local facing = (cf and axis) and Vector3.dot(axis, cf.fwd) or 1

		hold.ring = r
		hold.base = turn
		hold.q0 = QuaternionBox(q)
		hold.sign = facing < 0 and -1 or 1
		hold.last = math.atan2(y - f.oy, x - f.ox)
		hold.sweep = 0
	end

	SK.obj_mark("gyro", nil)

	gyro.hold = hold

	return true
end

SK.gyro_drag = function(x, y)
	local hold = gyro.hold

	if not hold then
		return false
	end

	if type(hold.what) == "number" then
		local dir = hold.dir:unbox()
		local t = SK.gyro_along(dir, hold.anchor:unbox(), x, y)

		if not t then
			return false
		end

		local d = t - hold.t0
		local shift = dir * d

		if hold.back then
			local okr, turned = pcall(Quaternion.rotate, hold.back:unbox(), shift)

			if okr and turned then
				shift = turned
			end
		end

		local okv, dx, dy, dz = pcall(Vector3.to_elements, shift)

		if not okv then
			return false
		end

		local most = SK.OBJ_MOVE_MOST

		object.move[1] = math.max(-most, math.min(most, hold.move[1] + dx))
		object.move[2] = math.max(-most, math.min(most, hold.move[2] + dy))
		object.move[3] = math.max(-most, math.min(most, hold.move[3] + dz))
	else
		local f = gyro.frame
		local cx, cy = (f and f.ox) or hold.x0, (f and f.oy) or hold.y0
		local now = math.atan2(y - cy, x - cx)
		local step = now - (hold.last or now)

		while step > math.pi do
			step = step - math.pi * 2
		end

		while step < -math.pi do
			step = step + math.pi * 2
		end

		hold.last = now
		hold.sweep = (hold.sweep or 0) + step

		local own = ({ Vector3(1, 0, 0), Vector3(0, 1, 0), Vector3(0, 0, 1) })[hold.ring]
		local okq, q = pcall(Quaternion.multiply, hold.q0:unbox(),
			Quaternion.axis_angle(own, hold.sign * hold.sweep))

		if not okq or not q then
			return false
		end

		local okd, dx, dy, dz = pcall(SK.pose_dial_of, hold.base:unbox(), q)

		if not okd or not dx then
			return false
		end

		object.spin[1], object.spin[2], object.spin[3] = dx, dy, dz
	end

	SK.object_place()

	return true
end

SK.gyro_release = function()
	local was = gyro.hold ~= nil

	gyro.hold = nil

	return was
end

SK.gyro_busy = function()
	return gyro.hold ~= nil
end

SK.object_lock = function(on)
	if on == nil then
		on = not object.lock
	end

	if on and not SK.object_alive() then
		return false
	end

	object.lock = on and true or nil

	if not object.lock then
		gyro.hold, gyro.frame = nil, nil
	end

	return object.lock == true
end

SK.object_locked = function()
	if not SK.object_alive() then
		object.lock = nil

		return false
	end

	return object.lock == true and not SK.is_hidden(object.unit)
end

-- ───────────────────── ❀ ─────────────────────
--  Object Verb
-- ───────────────────── ❀ ─────────────────────

mod.sk_object = function(what, x, y, z)
	if what == nil or what == "" then
		return SK.object_line()
	end

	if what == "target" then
		if not pick.unit then
			return "ERR nothing picked yet", true
		end

		local ok, alive = pcall(Unit.alive, pick.unit)

		if not ok or not alive then
			return "That is gone now.", true
		end

		if not pick.node then
			return "The game will not let that be held.", true
		end

		if SK.object_alive() then
			for i = 1, #(object.crew or {}) do
				if object.crew[i].unit == pick.unit and object.crew[i].node == SK.top_node(pick.unit, pick.node) then
					return "holding it"
				end
			end
		end

		local took, why = SK.object_take(pick.unit, pick.node)

		if not took then
			return tostring(why), true
		end

		return "holding it"
	end

	if what == "clear" then
		object.lock = nil
		object.unit, object.node, object.from, object.turn = nil, nil, nil, nil
		object.crew = nil

		return "Let it go. It stays where it is."
	end

	if what == "lock" or what == "unlock" then
		local on = SK.object_lock(what == "lock")

		if on then
			return "Locked. Arrows slide it, the ball turns."
		end

		return SK.object_alive() and "Unlocked. Clicks pick things again." or "Nothing to lock. Click something first."
	end

	-- ───────────────────── ❀ ─────────────────────
	--  Copy
	-- ───────────────────── ❀ ─────────────────────

	if what == "copy" then
		if not SK.object_alive() then
			return "Nothing to copy. Click something first."
		end

		SK.crew_prune()

		local crew = object.crew

		if not crew or #crew == 0 then
			crew = { { unit = object.unit, node = object.node } }
		end

		local members, sx, sy, low, n = {}, 0, 0, nil, 0

		for i = 1, #crew do
			local one = crew[i]
			local name = SK.unit_name(one.unit)
			local okp, pos = pcall(Unit.world_position, one.unit, one.node)
			local okr, r = pcall(Unit.world_rotation, one.unit, one.node)

			if name and okp and pos then
				local oke, x, y, z = pcall(Vector3.to_elements, pos)

				if oke then
					members[#members + 1] = {
						name = name,
						node = one.node,
						at = { x, y, z },
						turn = okr and r and QuaternionBox(r) or nil,
						size = SK.unit_size(one.unit, one.node),
						label = SK.keep_name(one.unit),
					}
					sx, sy, n = sx + x, sy + y, n + 1
					low = low and math.min(low, z) or z
				end
			end
		end

		if n == 0 then
			return "The tool cannot make a copy of that."
		end

		for i = 1, #members do
			local m = members[i]

			m.off = { m.at[1] - sx / n, m.at[2] - sy / n, m.at[3] - low }
		end

		SK.clip = { members = members, label = n > 1 and (n .. " things") or members[1].label }

		return "Copied " .. SK.shown_name(SK.clip.label) .. "."
	end

	-- ───────────────────── ❀ ─────────────────────
	--  Saved Groups
	-- ───────────────────── ❀ ─────────────────────

	if what == "save" then
		return SK.group_add(tostring(x or ""))
	end

	if what == "load" then
		return SK.group_load(tostring(x or ""))
	end

	if what == "unload" then
		return SK.group_unload(tostring(x or ""))
	end

	if what == "sync" then
		return SK.group_sync(tostring(x or ""))
	end

	if what == "export" then
		return SK.group_export(tostring(x or ""))
	end

	if what == "folder" then
		local path = SK.groups_folder()

		if not path then
			return "No AppData folder was found."
		end

		if SK.open_folder(path) then
			return "Opened the groups folder."
		end

		local ok = pcall(Clipboard.put, path)

		SK.say("folder|" .. path)

		if ok then
			return "Could not open it. Its path is copied instead."
		end

		return SK.HOME and "Could not open it. It is in AppData\\Fatshark." or "Could not open it. It is in the mod's anim folder."
	end

	if what == "merge" then
		local from = {}

		for one in string.gmatch(tostring(y or ""), "[^,]+") do
			from[#from + 1] = one
		end

		return SK.group_merge(tostring(x or ""), from)
	end

	if what == "groups" then
		local names = SK.anim_index("groups")

		return #names > 0 and table.concat(names, ", ") or "no groups saved"
	end

	-- ───────────────────── ❀ ─────────────────────
	--  Kept Items
	-- ───────────────────── ❀ ─────────────────────

	if what == "keep" then
		local crew = object.crew

		if SK.object_alive() and (not crew or #crew == 0) then
			crew = { { unit = object.unit, node = object.node } }
		end

		if not SK.object_alive() then
			crew = {}
		end

		local added, already = 0, 0

		for i = 1, #crew do
			local u, node = crew[i].unit, crew[i].node
			local ok, alive = pcall(Unit.alive, u)

			if u and node and ok and alive then
				if SK.keep_add(u, node) then
					added = added + 1
				else
					already = already + 1
				end
			end
		end

		if added == 0 then
			return already > 0 and "That is on the Items list already." or "Nothing is held to save. Click something first."
		end

		return string.format("Saved %d to the Items list, %d on it now.", added, #SK.kept)
	end

	if what == "kept" then
		local one = SK.keep_list()[math.floor(tonumber(x) or 0)]

		if not one then
			return "Nothing in that row now."
		end

		local took, why = SK.object_take(one.unit, one.node)

		if not took then
			return tostring(why)
		end

		return "Holding " .. SK.shown_name(one.name) .. "."
	end

	if what == "holdall" then
		local kept = SK.keep_list()

		if #kept == 0 then
			return "The Items list is empty. S adds what you hold."
		end

		local all = {}

		for i = 1, #kept do
			all[i] = i
		end

		local n = SK.hold_kept(all)

		return n > 0 and string.format("Holding all %d together.", n) or "None of them could be held."
	end

	if what == "holdset" then
		local rows = {}

		for i in string.gmatch(tostring(x or ""), "%d+") do
			rows[#rows + 1] = tonumber(i)
		end

		local n = SK.hold_kept(rows)

		return n > 0 and string.format("Holding %d together.", n) or "None of them could be held."
	end

	if what == "toggle" then
		local one = SK.keep_list()[math.floor(tonumber(x) or 0)]

		if not one then
			return "Nothing in that row now."
		end

		if SK.object_alive() then
			for i = 1, #(object.crew or {}) do
				if object.crew[i].unit == one.unit then
					SK.crew_drop(i)

					return SK.object_alive() and ("Holding " .. #object.crew .. " now.") or "Let go. Nothing is held now."
				end
			end

			local n, why = SK.object_add(one.unit, one.node)

			return n and ("Holding " .. n .. " now.") or tostring(why)
		end

		local took, why = SK.object_take(one.unit, one.node)

		return took and ("Holding " .. SK.shown_name(one.name) .. ".") or tostring(why)
	end

	if what == "forget" then
		local i = math.floor(tonumber(x) or 0)
		local one = SK.keep_list()[i]

		if not one then
			return "Nothing in that row now."
		end

		table.remove(SK.kept, i)

		local ours = false

		for c = 1, #(SK.copies or {}) do
			if SK.copies[c] == one.unit then
				ours = true
				table.remove(SK.copies, c)

				break
			end
		end

		if not ours then
			return "Off the list. It stays in the level."
		end

		for c = #(object.crew or {}), 1, -1 do
			if object.crew and object.crew[c] and object.crew[c].unit == one.unit then
				SK.crew_drop(c)
			end
		end

		if object.unit == one.unit then
			object.unit, object.node, object.from, object.turn = nil, nil, nil, nil
			object.crew = nil
		end

		local okw, world = pcall(function()
			return Managers.world and Managers.world:world("level_world")
		end)

		if okw and world and SK.alive(one.unit) then
			pcall(World.destroy_unit, world, one.unit)
		end

		return "Removed the copy. " .. #SK.kept .. " left on the list."
	end

	-- ───────────────────── ❀ ─────────────────────
	--  Moves & Undo
	-- ───────────────────── ❀ ─────────────────────

	if what == "back" then
		return SK.obj_back()
	end

	if what == "undo" then
		return SK.undo_last()
	end

	if what == "add" then
		if not pick.unit or not pick.node then
			return "That cannot be added to what you hold."
		end

		SK.obj_mark("add")

		local n, why = SK.object_add(pick.unit, pick.node)

		if not n then
			return tostring(why)
		end

		return string.format("Added. Holding %d together.", n)
	end

	if not SK.object_alive() then
		return "Nothing is held. Click something first.", true
	end

	if what == "reset" then
		SK.obj_mark("reset")
		object.move, object.spin, object.grow = { 0, 0, 0 }, { 0, 0, 0 }, 1
		SK.object_place()

		return "Back where you found it."
	end

	if what == "scale" then
		SK.obj_mark("scale")
		object.grow = math.max(0.05, math.min(20, tonumber(x) or 1))
		SK.object_place()

		return string.format("Scaled to %sx.", SK.num(object.grow))
	end

	if what == "move" or what == "turn" then
		SK.obj_mark(what)

		local into = what == "move" and object.move or object.spin
		local cap = what == "move" and SK.OBJ_MOVE_MOST or 360

		into[1] = math.max(-cap, math.min(cap, tonumber(x) or into[1]))
		into[2] = math.max(-cap, math.min(cap, tonumber(y) or into[2]))
		into[3] = math.max(-cap, math.min(cap, tonumber(z) or into[3]))
		SK.object_place()

		return SK.object_line()
	end

	return "ERR object verbs: target add copy move turn scale reset clear back undo keep kept forget save load groups"
end

-- ───────────────────── ❀ ─────────────────────
--  Hiding
-- ───────────────────── ❀ ─────────────────────

SK.hidden = SK.hidden or {}

SK.is_hidden = function(unit)
	for i = 1, #(SK.hidden or {}) do
		local parts = SK.hidden[i].parts

		for j = 1, #parts do
			if parts[j] == unit then
				return true
			end
		end
	end

	return false
end

SK.hide_unit = function(unit)
	if not SK.alive(unit) then
		return {}
	end

	local parts = { unit }

	pcall(Unit.set_unit_visibility, unit, false)
	SK.gun_tree(unit, parts)

	return parts
end

SK.hidden_prune = function()
	for i = #(SK.hidden or {}), 1, -1 do
		if not SK.alive(SK.hidden[i].unit) then
			table.remove(SK.hidden, i)
		end
	end
end

SK.hold_hideable = function()
	if not SK.object_alive() then
		return false
	end

	local crew = object.crew or { { unit = object.unit } }

	for i = 1, #crew do
		local u = crew[i].unit

		if SK.alive(u) and not SK.is_hidden(u) then
			return true
		end
	end

	return false
end

-- ───────────────────── ❀ ─────────────────────
--  Selection
-- ───────────────────── ❀ ─────────────────────

SK.selected_unit = function()
	SK.hidden_prune()

	local last = SK.hidden[#SK.hidden]
	local other = SK.hold_hideable()

	if last and not other and (pick.at or 0) <= (last.after or 0) then
		return last.unit, last.kind or "pick"
	end

	if SK.object_alive() and not SK.is_hidden(object.unit) then
		return object.unit, "object"
	end

	if SK.pose_alive() and not SK.is_hidden(pose.unit) then
		return pose.unit, "person"
	end

	if pick.unit and not SK.is_hidden(pick.unit) then
		local ok, alive = pcall(Unit.alive, pick.unit)

		if ok and alive then
			return pick.unit, "pick"
		end
	end

	if SK.pose_alive() and SK.is_hidden(pose.unit) then
		return pose.unit, "person"
	end
	return nil
end

SK.selected_units = function()
	SK.hidden_prune()

	local last = SK.hidden[#SK.hidden]
	local other = SK.hold_hideable()

	if last and not other and (pick.at or 0) <= (last.after or 0) then
		local same = {}

		for i = 1, #SK.hidden do
			if SK.hidden[i].press == last.press then
				same[#same + 1] = { unit = SK.hidden[i].unit, kind = SK.hidden[i].kind or "pick" }
			end
		end

		return same
	end

	local out = {}

	if SK.object_alive() then
		local crew = object.crew or { { unit = object.unit } }
		local seen = {}

		for i = 1, #crew do
			local u = crew[i].unit
			local ok, alive = pcall(Unit.alive, u)

			if u and ok and alive and not seen[u] and not SK.is_hidden(u) then
				seen[u] = true
				out[#out + 1] = { unit = u, kind = "object" }
			end
		end
	end

	if SK.pose_alive() and not SK.is_hidden(pose.unit) then
		out[#out + 1] = { unit = pose.unit, kind = "person" }
	end

	if #out == 0 then
		local unit, kind = SK.selected_unit()

		if unit then
			out[1] = { unit = unit, kind = kind }
		end
	end

	if #out == 0 and SK.pose_alive() and SK.is_hidden(pose.unit) then
		out[1] = { unit = pose.unit, kind = "person" }
	end

	return out
end

-- ───────────────────── ❀ ─────────────────────
--  Hide Verb
-- ───────────────────── ❀ ─────────────────────

mod.sk_hide = function(what, how)
	if what == "all" then
		local shown = 0

		for i = #SK.hidden, 1, -1 do
			shown = shown + SK.gun_show(SK.hidden[i].parts)

			if SK.phys then
				SK.phys.give_back(SK.hidden[i])
			end
		end

		if #SK.hidden > 0 then
			SK.unhidden = SK.hidden
		end

		SK.hidden = {}

		return shown > 0 and ("Brought back everything hidden, " .. SK.count(shown, "part") .. ".") or "Nothing is hidden."
	end

	if what == "rehide" then
		local was = SK.unhidden or {}
		local parts = 0

		SK.unhidden = nil

		for i = 1, #was do
			local one = was[i]
			local ok, alive = pcall(Unit.alive, one.unit)

			if ok and alive then
				for j = 1, #(one.parts or {}) do
					local okp, there = pcall(Unit.alive, one.parts[j])

					if okp and there then
						pcall(Unit.set_unit_visibility, one.parts[j], false)
						parts = parts + 1
					end
				end

				if SK.phys then
					SK.phys.take_again(one)
				end

				one.after = -1
				SK.hidden[#SK.hidden + 1] = one
			end
		end

		return parts > 0 and string.format("Hid %s again. %s hidden now.", SK.count(parts, "part"), SK.count(#SK.hidden, "thing"))
			or "Nothing left to hide again."
	end

	if what == "this" then
		local picked = SK.selected_units()

		if #picked == 0 then
			return "Nothing to hide. Click something, then H."
		end

		local shown = 0

		for p = 1, #picked do
			for i = #SK.hidden, 1, -1 do
				local was = SK.hidden[i]

				if was.unit == picked[p].unit then
					shown = shown + SK.gun_show(was.parts)

					if SK.phys then
						SK.phys.give_back(was)
					end

					table.remove(SK.hidden, i)
				end
			end
		end

		if shown > 0 then
			return string.format("Brought back %s. %s", SK.count(shown, "part"),
				#SK.hidden > 0 and (SK.count(#SK.hidden, "thing") .. " still hidden.") or "Nothing else is hidden.")
		end

		local parts = {}
		local wanted = SK.phys ~= nil and SK.phys.wanted(how)
		local ghost = wanted and SK.phys.hosting()
		local first

		SK.hide_press = (SK.hide_press or 0) + 1

		for p = 1, #picked do
			local mine = SK.hide_unit(picked[p].unit)

			SK.hidden[#SK.hidden + 1] = { unit = picked[p].unit, parts = mine,
				kind = picked[p].kind, after = pick.at or 0, when = SK.now(),
				press = SK.hide_press, ghost = ghost and SK.phys.take(mine) or nil }
			first = first or SK.hidden[#SK.hidden]

			for i = 1, #mine do
				parts[#parts + 1] = mine[i]
			end
		end

		if wanted then
			local took = 0

			for i = 1, #SK.hidden do
				if SK.hidden[i].press == SK.hide_press then
					took = took + #(SK.hidden[i].ghost or {})
				end
			end

			if ghost and took == 0 then
				return string.format("Hid %s, but the game keeps collision.", SK.count(#parts, "part"))
			end

			return SK.phys.says(ghost, #parts, #SK.hidden)
		end

		return string.format("Hid %s. %s hidden now.", SK.count(#parts, "part"), SK.count(#SK.hidden, "thing"))
	end

	return #SK.hidden > 0 and string.format("%d hidden", #SK.hidden) or "nothing hidden"
end

-- ───────────────────── ❀ ─────────────────────
--  Saved Files
-- ───────────────────── ❀ ─────────────────────

SK.ANIM = SK.HOME and (string.gsub(SK.HOME, "%%", "%%%%") .. "\\%s\\%s.lua") or "./../mods/SkeletonKey/anim/%s/%s.lua"

SK.FALLBACK = "./../mods/SkeletonKey/anim"

SK.home_make = function(kind)
	local win = SK.win32()

	if not win then
		return false
	end

	if not SK.HOME then
		pcall(win.mkdir, SK.FALLBACK, nil)

		for _, folder in ipairs({ "sets", "groups", "exports", "exports/anim", "exports/objects" }) do
			pcall(win.mkdir, SK.FALLBACK .. "/" .. folder, nil)
		end

		return true
	end

	local pieces = {}

	for piece in string.gmatch(SK.HOME .. "\\" .. (kind or ""), "[^\\]+") do
		pieces[#pieces + 1] = piece
	end

	local unc = string.sub(SK.HOME, 1, 2) == "\\\\"
	local path = unc and ("\\\\" .. tostring(pieces[1]) .. "\\" .. tostring(pieces[2])) or tostring(pieces[1])

	for i = unc and 3 or 2, #pieces do
		path = path .. "\\" .. pieces[i]
		pcall(win.mkdir, path, nil)
	end

	return true
end

SK.unique_name = function(name, taken, joiner)
	local used = {}
	for i = 1, #taken do
		used[string.lower(taken[i])] = true
	end
	if not used[string.lower(name)] then
		return name
	end
	local n = 2
	while used[string.lower(name .. joiner .. n)] do
		n = n + 1
	end
	return name .. joiner .. n
end

SK.name_taken = function(name, taken)
	local want = string.lower(tostring(name or ""))

	for i = 1, #taken do
		if string.lower(taken[i]) == want then
			return taken[i]
		end
	end

	return nil
end

SK.frame_names = function()
	local names = {}
	for i = 1, #pose.frames do
		names[i] = pose.frames[i].name
	end
	return names
end

SK.anim_name_ok = function(name)
	return type(name) == "string" and name ~= "" and string.match(name, "^[%w_%-]+$") ~= nil
		and string.lower(name) ~= "index"
end

SK.frame_name_ok = function(name)
	return type(name) == "string" and string.match(name, "^[%w_%- ]+$") ~= nil and string.match(name, "%S") ~= nil
end

SK.name_rule = function(name)
	if type(name) == "string" and string.lower(name) == "index" then
		return "That name is kept for the tool. Pick another."
	end

	return "Use only letters, digits, _ and - in a name."
end

SK.anim_read = function(kind, name)
	if not SK.anim_name_ok(name) then
		return nil, "bad name"
	end
	local path = string.format(SK.ANIM, kind, name)
	local ok, body = pcall(function()
		local f = Mods.lua.io.open(path, "r")
		if not f then return nil end
		local text = f:read("*a")
		f:close()
		return text
	end)
	if not ok or type(body) ~= "string" then
		return nil, "no such " .. kind
	end
	local chunk, err = SK.compile(body, "=" .. kind .. "_" .. name)
	if not chunk then
		return nil, err
	end
	local fenv = rawget(_G, "setfenv")
	if not fenv or not pcall(fenv, chunk, {}) then
		return nil, "unreadable " .. kind
	end
	local dbg = rawget(_G, "debug")
	local strings = getmetatable("")
	local methods = strings and strings.__index

	local compiler = rawget(_G, "jit")

	if compiler and compiler.off then
		pcall(compiler.off, chunk, true)
	end

	local limited = dbg and dbg.sethook and dbg.gethook() == nil

	if limited then
		dbg.sethook(function() error("too long") end, "", SK.READ_STEPS)
	end

	if strings then
		strings.__index = {}
	end

	local loaded, t = pcall(chunk)

	if strings then
		strings.__index = methods
	end

	if limited then
		dbg.sethook()
	end

	if not loaded or type(t) ~= "table" then
		return nil, "unreadable " .. kind
	end
	return t
end

SK.READ_STEPS = 20000000

SK.anim_write = function(kind, name, text)
	if not SK.anim_name_ok(name) then
		return false, SK.name_rule(name)
	end

	return SK.anim_put(kind, name, text)
end

SK.anim_put = function(kind, name, text)
	SK.index_forget(kind)

	if kind == "groups" and SK.group_levels then
		SK.group_levels[string.lower(tostring(name))] = nil
	end

	local path = string.format(SK.ANIM, kind, name)
	local function put()
		local f = Mods.lua.io.open(path, "w")

		if not f then
			return false
		end

		f:write(text)
		f:close()

		return true
	end

	local ok, done = pcall(put)

	if ok and not done then
		SK.home_make(kind)
		ok, done = pcall(put)
	end

	if not ok or not done then
		SK.say("write|" .. path .. (ok and "" or ("|" .. tostring(done))))

		return false, "Could not write the file."
	end

	return true
end

-- ───────────────────── ❀ ─────────────────────
--  Folder Listing
-- ───────────────────── ❀ ─────────────────────

SK.FIND_NAME_AT = 44
SK.FIND_SIZE_AT = 32
SK.FIND_MAX = 5000
SK.STUB = "-- deleted" .. string.char(10) .. "return nil" .. string.char(10)

SK.win32 = function()
	local ffi = Mods and Mods.lua and Mods.lua.ffi

	if not ffi then
		return nil
	end

	if SK.find_at == nil then
		local ok, calls = pcall(function()
			pcall(ffi.cdef, "void* FindFirstFileA(const char* name, void* data);")
			pcall(ffi.cdef, "int FindNextFileA(void* find, void* data);")
			pcall(ffi.cdef, "int FindClose(void* find);")
			pcall(ffi.cdef, "int DeleteFileA(const char* name);")
			pcall(ffi.cdef, "int CreateDirectoryA(const char* name, void* security);")

			return {
				first = ffi.cast("void* (*)(const char*, void*)", ffi.C.FindFirstFileA),
				next = ffi.cast("int (*)(void*, void*)", ffi.C.FindNextFileA),
				shut = ffi.cast("int (*)(void*)", ffi.C.FindClose),
				delete = ffi.cast("int (*)(const char*)", ffi.C.DeleteFileA),
				mkdir = ffi.cast("int (*)(const char*, void*)", ffi.C.CreateDirectoryA),
			}
		end)

		SK.find_at = ok and calls or false
	end

	return SK.find_at or nil, ffi
end

SK.anim_is_stub = function(kind, name)
	local ok, head = pcall(function()
		local f = Mods.lua.io.open(string.format(SK.ANIM, kind, name), "r")

		if not f then
			return nil
		end

		local text = f:read("*a")

		f:close()

		return text
	end)

	return ok and type(head) == "string" and string.find(head, "^%-%- deleted") ~= nil
end

SK.folder_list = function(kind)
	local win, ffi = SK.win32()

	if not win then
		return nil
	end

	local ok, names = pcall(function()
		local buf = ffi.new("uint8_t[?]", 320)
		local h = win.first(string.format(SK.ANIM, kind, "*"), buf)

		if tonumber(ffi.cast("intptr_t", h)) == -1 then
			return nil
		end

		local at = ffi.cast("char*", buf) + SK.FIND_NAME_AT
		local size = ffi.cast("uint32_t*", buf + SK.FIND_SIZE_AT)
		local out, n = {}, 0

		repeat
			local name = ffi.string(at):match("^(.+)%.lua$")

			if name and SK.anim_name_ok(name) and not (size[0] < 64 and SK.anim_is_stub(kind, name)) then
				out[#out + 1] = name
			end

			n = n + 1
		until win.next(h, buf) == 0 or n >= SK.FIND_MAX

		win.shut(h)
		table.sort(out)

		return out
	end)

	return ok and type(names) == "table" and names or nil
end

SK.anim_delete = function(kind, name)
	if not SK.anim_name_ok(name) then
		return false
	end

	SK.index_forget(kind)

	if kind == "groups" and SK.group_levels then
		SK.group_levels[string.lower(tostring(name))] = nil
	end

	local win = SK.win32()

	if win then
		local ok, done = pcall(win.delete, string.format(SK.ANIM, kind, name))

		if ok and done ~= 0 then
			return true
		end
	end

	return SK.anim_write(kind, name, SK.STUB)
end

SK.INDEX_FOR = 1

SK.index_forget = function(kind)
	if SK.index_seen then
		SK.index_seen[kind] = nil
	end
end

SK.anim_index = function(kind)
	SK.index_seen = SK.index_seen or {}

	local seen, now = SK.index_seen[kind], SK.now()

	if not (seen and now >= seen.at and now - seen.at < SK.INDEX_FOR) then
		seen = { at = now, names = SK.anim_index_read(kind) }
		SK.index_seen[kind] = seen
	end

	local copy = {}

	for i = 1, #seen.names do
		copy[i] = seen.names[i]
	end

	return copy
end

SK.anim_index_read = function(kind)
	return SK.folder_list(kind) or {}
end

-- ───────────────────── ❀ ─────────────────────
--  Set Files
-- ───────────────────── ❀ ─────────────────────

SK.LUA_WORDS = {}

for word in string.gmatch("and break do else elseif end false for function goto if in local nil not or repeat return then true until while", "%a+") do
	SK.LUA_WORDS[word] = true
end

SK.joint_name_ok = function(j)
	return type(j) == "string" and string.match(j, "^[%a_][%w_]*$") ~= nil and not SK.LUA_WORDS[j]
end

SK.set_rows = function(out, frames, groups)
	for i = 1, #frames do
		local f = frames[i]

		local folder = groups and f.group and string.format(" group = %q,", f.group) or ""

		out[#out + 1] = string.format("\t\t(function() return { name = %q, hold = %s,%s dial = {", f.name, SK.fine(f.hold or 2, 4), folder)
		local joints = {}
		for j in pairs(f.dial) do if SK.joint_name_ok(j) then joints[#joints + 1] = j end end
		table.sort(joints)
		for _, j in ipairs(joints) do
			local d = f.dial[j]
			if d[1] ~= 0 or d[2] ~= 0 or d[3] ~= 0 then
				out[#out + 1] = string.format("\t\t\t%s = { %s, %s, %s },", j, tostring(d[1]), tostring(d[2]), tostring(d[3]))
			end
		end
		local anim = ""
		if f.anim and f.anim.event then
			local at = f.anim.at ~= nil and string.format(" at = %s,", SK.fine(f.anim.at, 4)) or ""

			anim = string.format(", anim = { event = %q,%s machine = %q }", f.anim.event, at, f.anim.machine or "")
		end
		if f.base then
			local names = {}

			for j in pairs(f.base) do if SK.joint_name_ok(j) then names[#names + 1] = j end end

			table.sort(names)
			out[#out + 1] = "		}, from = {"

			for _, j in ipairs(names) do
				local qx, qy, qz, qw = Quaternion.to_elements(f.base[j]:unbox())

				out[#out + 1] = string.format("			%s = { %s, %s, %s, %s },", j, tostring(qx), tostring(qy), tostring(qz), tostring(qw))
			end
		end
		if f.sits then
			local names = {}

			for j in pairs(f.sits) do if SK.joint_name_ok(j) then names[#names + 1] = j end end

			table.sort(names)
			out[#out + 1] = "		}, at = {"

			for _, j in ipairs(names) do
				local p = f.sits[j]:unbox()

				out[#out + 1] = string.format("			%s = { %s, %s, %s },", j, tostring(p.x), tostring(p.y), tostring(p.z))
			end
		end

		out[#out + 1] = "		}" .. anim .. " } end)(),"
	end
end

SK.set_text = function(name, rate, frames)
	local out = { "-- An animation set made with Skeleton Key: keyframes in order, each a pose (degrees about each joint's own axes) held for its seconds.", "return {", string.format("\tname = %q,", name), string.format("\trate = %s,", tostring(rate)), "\tframes = {" }

	SK.set_rows(out, frames, true)
	out[#out + 1] = "\t},"
	out[#out + 1] = "}"
	out[#out + 1] = ""
	return table.concat(out, string.char(10))
end

SK.set_save = function(name)
	if #pose.frames == 0 then
		return "No keyframes to save yet. Make them on Keyframes."
	end
	local over = SK.name_taken(name, SK.anim_index("sets"))

	name = over or name
	local ok, err = SK.anim_write("sets", name, SK.set_text(name, pose.rate, pose.frames))
	if not ok then
		return tostring(err)
	end
	if over then
		return string.format("Replaced set %s with %s.", name, SK.count(#pose.frames, "keyframe"))
	end
	return string.format("Saved %s as set %s.", SK.count(#pose.frames, "keyframe"), name)
end

SK.set_unread = function(name, why)
	if why == "no such sets" then
		return tostring(name) .. " is not in the sets folder."
	end

	SK.say("set|" .. tostring(name) .. "|" .. tostring(why))

	return tostring(name) .. " could not be read."
end

-- ───────────────────── ❀ ─────────────────────
--  Group Files
-- ───────────────────── ❀ ─────────────────────

SK.group_text = function(name, rows, level)
	local out = { "-- A group of things and where they stand, saved by Skeleton Key.",
		"-- Deleting or renaming this file is safe. Editing inside it can stop it loading.",
		"return {", string.format("	name = %q,", name) }

	if level then
		out[#out + 1] = string.format("	level = %q,", level)
	end

	out[#out + 1] = "	things = {"

	for i = 1, #rows do
		local r = rows[i]
		local size = SK.numbers(r.size, 3) and r.size or { 1, 1, 1 }

		out[#out + 1] = string.format("		{ key = %q, node = %d, at = { %s, %s, %s }, turn = { %s, %s, %s, %s }, size = { %s, %s, %s } },",
			r.key, math.floor(tonumber(r.node) or 1),
			SK.fine(r.at[1], 3), SK.fine(r.at[2], 3), SK.fine(r.at[3], 3),
			SK.fine(r.turn[1], 4), SK.fine(r.turn[2], 4), SK.fine(r.turn[3], 4), SK.fine(r.turn[4], 4),
			SK.fine(size[1], 3), SK.fine(size[2], 3), SK.fine(size[3], 3))
	end

	out[#out + 1] = "	},"
	out[#out + 1] = "}"

	local nl = string.char(10)

	return table.concat(out, nl) .. nl
end

SK.rows_ok = function(things)
	if type(things) ~= "table" then
		return false
	end

	for i = 1, #things do
		local r = things[i]

		if type(r) ~= "table" or type(r.key) ~= "string" or not SK.numbers(r.at, 3) or not SK.numbers(r.turn, 4) then
			return false
		end
	end

	return true
end

SK.level_here_ok = function(t)
	if type(t) ~= "table" or (type(t.level) == "string" and t.level ~= "") then
		return true
	end

	for i = 1, #(type(t.things) == "table" and t.things or {}) do
		if not SK.spawnable(t.things[i].key) then
			return false
		end
	end

	return true
end

SK.group_unreadable = function(name, t, why)
	if t == nil and why ~= nil and why ~= "no such groups" and why ~= "bad name" then
		return tostring(name) .. " could not be read. Not saved."
	end

	if type(t) == "table" and not SK.rows_ok(t.things) then
		return "Part of " .. tostring(name) .. " will not read. Not saved."
	end

	return nil
end

SK.group_level = function(name)
	SK.group_levels = SK.group_levels or {}

	local key = string.lower(tostring(name))
	local had = SK.group_levels[key]

	if had == nil then
		had = false

		if SK.anim_name_ok(name) then
			local ok, head = pcall(function()
				local f = Mods.lua.io.open(string.format(SK.ANIM, "groups", name), "r")

				if not f then
					return nil
				end

				local text = f:read(512)

				f:close()

				return text
			end)

			had = ok and type(head) == "string" and string.match(head, 'level = "([^"]*)"') or false
		end

		SK.group_levels[key] = had
	end

	return had or nil
end

SK.group_names_here = function()
	local here = SK.level_name()
	local names, elsewhere = {}, 0

	for _, name in ipairs(SK.anim_index("groups")) do
		if SK.level_fits_in(SK.group_level(name), here) then
			names[#names + 1] = name
		else
			elsewhere = elsewhere + 1
		end
	end

	return names, elsewhere
end

SK.unit_row = function(unit, node, known)
	local key = SK.alive(unit) and (known or SK.unit_name(unit)) or nil

	if not key or not node then
		return nil
	end

	local okp, p = pcall(Unit.world_position, unit, node)
	local okr, r = pcall(Unit.world_rotation, unit, node)
	local oke, x, y, z = false, 0, 0, 0

	if okp then
		oke, x, y, z = pcall(Vector3.to_elements, p)
	end

	if not oke then
		return nil
	end

	local okq, qx, qy, qz, qw = pcall(Quaternion.to_elements, r)

	return {
		unit = unit,
		key = key,
		node = node,
		at = { x, y, z },
		turn = okq and { qx, qy, qz, qw } or { 0, 0, 0, 1 },
		size = SK.unit_size(unit, node),
	}
end

SK.group_rows = function()
	local crew = object.crew or {}
	local rows = {}

	for i = 1, #crew do
		rows[#rows + 1] = SK.unit_row(crew[i].unit, crew[i].node)
	end

	return rows
end

SK.SIZE_LEAST, SK.SIZE_MOST = 0.001, 1000

SK.size_fit = function(v)
	return math.max(SK.SIZE_LEAST, math.min(SK.SIZE_MOST, tonumber(v) or 1))
end

SK.same_row = function(h, r)
	if h.key ~= r.key then
		return false
	end

	for a = 1, 3 do
		if math.abs(h.at[a] - r.at[a]) >= 0.01 then
			return false
		end
	end

	local function upright(t)
		if not SK.numbers(t, 4) or (t[1] == 0 and t[2] == 0 and t[3] == 0 and t[4] == 0) then
			return { 0, 0, 0, 1 }
		end

		return t
	end

	local ht, rt = upright(h.turn), upright(r.turn)
	local dot = ht[1] * rt[1] + ht[2] * rt[2] + ht[3] * rt[3] + ht[4] * rt[4]
	local len = math.sqrt((ht[1] ^ 2 + ht[2] ^ 2 + ht[3] ^ 2 + ht[4] ^ 2) * (rt[1] ^ 2 + rt[2] ^ 2 + rt[3] ^ 2 + rt[4] ^ 2))
	local hs, rs = SK.numbers(h.size, 3) and h.size or { 1, 1, 1 }, SK.numbers(r.size, 3) and r.size or { 1, 1, 1 }

	return len > 0 and math.abs(dot) / len > 0.9999
		and math.abs(hs[1] - rs[1]) < 0.001 and math.abs(hs[2] - rs[2]) < 0.001 and math.abs(hs[3] - rs[3]) < 0.001
end

SK.group_add = function(name)
	if not SK.object_alive() then
		return "Nothing is held to save. Click something first."
	end

	local rows = SK.group_rows()

	if #rows == 0 then
		return "The tool cannot make those again. Not saved."
	end

	local over = SK.name_taken(name, SK.anim_index("groups"))

	name = over or name

	local had = {}
	local t, why = SK.anim_read("groups", name)
	local bad = SK.group_unreadable(name, t, why)

	if bad then
		return bad
	end

	if type(t) == "table" then
		if not SK.level_fits(t.level) then
			return "Another level has a group with that name."
		end

		if not SK.level_here_ok(t) then
			return "Its things are not in this level. Not saved."
		end

		over = over or name

		for i = 1, #(type(t.things) == "table" and t.things or {}) do
			had[#had + 1] = t.things[i]
		end
	end

	local before, added, moved = #had, 0, 0
	local claimed, slots = {}, {}

	SK.placed_from = SK.placed_from or {}

	for unit in pairs(SK.placed_from) do
		if not SK.alive(unit) then
			SK.placed_from[unit] = nil
		end
	end

	for i = 1, #rows do
		local r = rows[i]
		local from = r.unit and SK.placed_from[r.unit]
		local slot = nil

		if over and from and string.lower(tostring(from.group)) == string.lower(name)
			and had[from.index] and not claimed[from.index] then
			slot = from.index
		end

		if slot then
			had[slot] = r
			claimed[slot] = true
			moved = moved + 1
			slots[#slots + 1] = { unit = r.unit, index = slot }
		else
			local same = false

			for j = 1, #had do
				local h = had[j]

				if SK.same_row(h, r) then
					same = true
				end
			end

			if not same then
				had[#had + 1] = r
				added = added + 1
				slots[#slots + 1] = { unit = r.unit, index = #had }
			end
		end
	end

	local ok, err = SK.anim_write("groups", name, SK.group_text(name, had, SK.level_name() or (type(t) == "table" and t.level or nil)))

	if not ok then
		return tostring(err)
	end

	for i = 1, #slots do
		if slots[i].unit then
			SK.placed_from[slots[i].unit] = { group = name, index = slots[i].index, world = SK.level_world() }
		end
	end

	if before == 0 then
		return string.format("Saved %s as group %s.", SK.count(#had, "thing"), name)
	end

	if moved > 0 then
		return string.format("Saved %s: %d updated, %d added.", name, moved, added)
	end

	return string.format("Added %d to %s, %s now.", added, name, SK.count(#had, "thing"))
end

SK.group_merge = function(name, from)
	local all, took = {}, 0
	local into = {}
	local listed = false

	for _, one in ipairs(from) do
		listed = listed or string.lower(one) == string.lower(name)
		into[#into + 1] = one
	end

	local target, why = SK.anim_read("groups", name)
	local bad = SK.group_unreadable(name, target, why)

	if bad then
		return bad
	end

	if type(target) == "table" and not SK.level_fits(target.level) then
		return "Another level has a group with that name."
	end

	if not SK.level_here_ok(target) then
		return "Its things are not in this level. Not saved."
	end

	if not listed and type(target) == "table" then
		table.insert(into, 1, name)
	end

	from = into

	for _, one in ipairs(from) do
		local t = SK.anim_read("groups", one)

		if type(t) == "table" and (not SK.level_fits(t.level) or not SK.level_here_ok(t)) then
			return "Only groups from this level can be merged."
		end

		if type(t) == "table" and not SK.rows_ok(t.things) then
			return "Part of " .. tostring(one) .. " will not read. Not saved."
		end

		if t and t.things then
			took = took + 1

			for i = 1, #t.things do
				local r = t.things[i]
				local same = false

				for j = 1, #all do
					local h = all[j]

					if SK.same_row(h, r) then
						same = true
					end
				end

				if not same then
					all[#all + 1] = r
				end
			end
		end
	end

	if took == 0 or #all == 0 then
		return "None of those groups could be read."
	end

	local over = SK.name_taken(name, SK.anim_index("groups"))

	name = over or name

	local ok, err = SK.anim_write("groups", name, SK.group_text(name, all, SK.level_name() or (type(target) == "table" and target.level or nil)))

	if not ok then
		return tostring(err)
	end

	local old = type(target) == "table" and type(target.things) == "table" and target.things or {}
	local want = string.lower(name)

	for unit, bound in pairs(SK.placed_from or {}) do
		if string.lower(tostring(bound.group)) == want then
			local was, found = old[bound.index], nil

			for j = 1, type(was) == "table" and SK.numbers(was.at, 3) and #all or 0 do
				local h = all[j]

				if SK.same_row(h, was) then
					found = j

					break
				end
			end

			if found then
				bound.index = found
			else
				SK.placed_from[unit] = nil
			end
		end
	end

	return string.format("Merged %s into %s, %s.", SK.count(took, "group"), name, SK.count(#all, "thing"))
end

-- ───────────────────── ❀ ─────────────────────
--  Open Folder
-- ───────────────────── ❀ ─────────────────────

SK.open_folder = function(path)
	local ffi = Mods and Mods.lua and Mods.lua.ffi

	if not ffi or not path then
		return false
	end

	if not SK.shell32 then
		pcall(ffi.cdef, "void* ShellExecuteA(void* hwnd, const char* op, const char* file, const char* params, const char* dir, int show);")

		local okl, lib = pcall(ffi.load, "shell32")

		if not okl or not lib then
			return false
		end

		SK.shell32 = lib
	end

	local okc, answer = pcall(function()
		return tonumber(ffi.cast("intptr_t", SK.shell32.ShellExecuteA(nil, "open", path, nil, nil, 1)))
	end)

	return okc and answer ~= nil and answer > 32
end

SK.groups_folder = function()
	SK.home_make("groups")

	return SK.HOME and (SK.HOME .. "\\groups") or "..\\mods\\SkeletonKey\\anim\\groups"
end

-- ───────────────────── ❀ ─────────────────────
--  Load & Play
-- ───────────────────── ❀ ─────────────────────

SK.copy_set = function()
	local set = {}

	for i = 1, #(SK.copies or {}) do
		set[SK.copies[i]] = true
	end

	return set
end

SK.group_loaded = function(name)
	local want = string.lower(tostring(name or ""))
	local copies = SK.copy_set()

	for unit, from in pairs(SK.placed_from or {}) do
		if copies[unit] and string.lower(tostring(from.group)) == want and SK.alive(unit) then
			return true
		end
	end

	return false
end

SK.group_unload = function(name)
	local want = string.lower(tostring(name or ""))
	local okw, world = pcall(function()
		return Managers.world and Managers.world:world("level_world")
	end)

	if not okw or not world then
		return "There is no level to unload from right now."
	end

	local gone = 0
	local copies = SK.copy_set()

	for unit, from in pairs(SK.placed_from or {}) do
		local ours = string.lower(tostring(from.group)) == want

		if ours and not SK.alive(unit) then
			SK.placed_from[unit] = nil
		elseif ours and copies[unit] then
			SK.placed_from[unit] = nil

			for c = #(object.crew or {}), 1, -1 do
				if object.crew and object.crew[c] and object.crew[c].unit == unit then
					SK.crew_drop(c)
				end
			end

			if object.unit == unit then
				object.unit, object.node, object.from, object.turn, object.crew = nil, nil, nil, nil, nil
			end

			for c = #(SK.copies or {}), 1, -1 do
				if SK.copies[c] == unit then
					table.remove(SK.copies, c)
				end
			end

			pcall(World.destroy_unit, world, unit)
			gone = gone + 1
		end
	end

	if gone == 0 then
		return "Nothing of " .. tostring(name) .. " is loaded."
	end

	return string.format("Unloaded %s, %s.", name, SK.count(gone, "thing"))
end

SK.EXPORT_PLACER = [=[
local function level_world()
	local manager = Managers.world

	return manager and manager:has_world("level_world") and manager:world("level_world") or nil
end

local function level_name()
	local ok, name = pcall(function()
		return Managers.state.mission:mission_name()
	end)

	return ok and name or nil
end

local function rebuild_actors(world, unit)
	pcall(World.update_unit, world, unit)

	local okn, count = pcall(Unit.num_actors, unit)

	for i = 1, okn and count or 0 do
		local oka, actor = pcall(Unit.actor, unit, i)
		local okd, moving = false, false

		if oka and actor then
			okd, moving = pcall(Actor.is_dynamic, actor)
		end

		if oka and actor and not (okd and moving) then
			pcall(Unit.destroy_actor, unit, i)
			pcall(Unit.create_actor, unit, i)
		end
	end
end

function group.place(world)
	world = world or level_world()

	local made = {}

	if not world or (group.level and group.level ~= level_name()) then
		return made
	end

	for _, thing in ipairs(group.things) do
		local okc, can = pcall(Application.can_get_resource, "unit", thing.key)

		if okc and can then
			local at = Vector3(thing.at[1], thing.at[2], thing.at[3])
			local q = thing.turn
			local turn = (q[1] == 0 and q[2] == 0 and q[3] == 0 and q[4] == 0) and Quaternion.identity()
				or Quaternion.from_elements(q[1], q[2], q[3], q[4])
			local oks, unit = pcall(World.spawn_unit_ex, world, thing.key, nil, at, turn)

			if oks and unit then
				local s = {}

				for a = 1, 3 do
					s[a] = math.max(0.001, math.min(1000, thing.size[a]))
				end

				if s[1] ~= 1 or s[2] ~= 1 or s[3] ~= 1 then
					local okn, nodes = pcall(Unit.num_scene_graph_items, unit)
					local node = okn and type(nodes) == "number" and thing.node >= 1 and thing.node <= nodes and thing.node or 1

					pcall(Unit.set_local_scale, unit, node, Vector3(s[1], s[2], s[3]))
					rebuild_actors(world, unit)
				end

				made[#made + 1] = unit
			end
		end
	end

	return made
end

function group.remove(units, world)
	world = world or level_world()

	for _, unit in ipairs(units or {}) do
		local ok, alive = pcall(Unit.alive, unit)

		if world and ok and alive then
			pcall(World.destroy_unit, world, unit)
		end
	end
end
]=]

SK.EXPORT_SOLID_HEAD = [=[
local walls = rawget(_G, "__skeletonkey_walls") or { copies = {} }

rawset(_G, "__skeletonkey_walls", walls)

local function take_walls(...)
]=]

SK.EXPORT_SOLID_TAIL = [=[
end

if (tonumber(walls.WALL_VERSION) or 0) < take_walls({}).WALL_VERSION then
	walls.now, walls.alive, walls.player_unit, walls.in_hub = nil, nil, nil, nil
	take_walls(walls)
end

local function route(func, self, action_name, ...)
	if walls.WALL_MOVES and walls.WALL_MOVES[action_name] and walls.wall_input then
		return walls.wall_input(func, self, action_name, ...)
	end

	return func(self, action_name, ...)
end

local function forget(units)
	for c = #walls.copies, 1, -1 do
		local ok, alive = pcall(Unit.alive, walls.copies[c])
		local gone = not (ok and alive)

		for _, unit in ipairs(units or {}) do
			gone = gone or walls.copies[c] == unit
		end

		if gone then
			table.remove(walls.copies, c)
		end
	end
end

walls.wall_prune = function()
	forget(nil)
end

function group.solid(mod, units)
	if type(mod) ~= "table" or type(mod.hook) ~= "function" then
		error("group.solid(mod, units): pass your mod object first", 2)
	end

	forget(nil)

	for _, unit in ipairs(units or {}) do
		local held = false

		for _, copy in ipairs(walls.copies) do
			held = held or copy == unit
		end

		if not held then
			walls.copies[#walls.copies + 1] = unit
		end
	end

	if not rawget(mod, "__skeletonkey_walls_hooked") and rawget(_G, "CLASS") and CLASS.InputService then
		rawset(mod, "__skeletonkey_walls_hooked", true)
		mod:hook(CLASS.InputService, "_get", route)
		mod:hook(CLASS.InputService, "_get_simulate", route)
	end
end

local placed_remove = group.remove

function group.remove(units, world)
	forget(units)
	placed_remove(units, world)
end

return group
]=]

SK.export_text = function(name, things, level)
	local title = level and (string.gsub(string.gsub(SK.level_title(level), "%c", " "), "^The ", "")) or nil
	local out = {
		"-- " .. name .. (title and (" - " .. title) or ""),
		"-- Made with Skeleton Key.",
		"--",
		"-- For mod makers, put this file in your mod and add:",
		"--   local group = mod:io_dofile(\"YourMod/" .. name .. "\")",
		"--   local units = group.place()",
		"--   group.solid(mod, units)",
		"--   group.remove(units)",
		"",
		"local group = {",
		string.format("\tname = %q,", name),
	}

	if level then
		out[#out + 1] = string.format("\tlevel = %q,", level)
	end

	out[#out + 1] = "\tthings = {"

	for i = 1, #things do
		local r = things[i]
		local size = SK.numbers(r.size, 3) and r.size or { 1, 1, 1 }

		out[#out + 1] = string.format("\t\t{ key = %q, node = %d, at = { %s, %s, %s }, turn = { %s, %s, %s, %s }, size = { %s, %s, %s } },",
			r.key, math.floor(tonumber(r.node) or 1),
			SK.fine(r.at[1], 3), SK.fine(r.at[2], 3), SK.fine(r.at[3], 3),
			SK.fine(r.turn[1], 4), SK.fine(r.turn[2], 4), SK.fine(r.turn[3], 4), SK.fine(r.turn[4], 4),
			SK.fine(size[1], 3), SK.fine(size[2], 3), SK.fine(size[3], 3))
	end

	out[#out + 1] = "\t},"
	out[#out + 1] = "}"

	return table.concat(out, string.char(10)) .. string.char(10) .. string.char(10) .. SK.EXPORT_PLACER .. string.char(10)
		.. SK.EXPORT_SOLID_HEAD .. SK.EXPORT_WALLS .. SK.EXPORT_SOLID_TAIL
end

SK.EXPORTS = { sets = "exports\\anim", groups = "exports\\objects" }

SK.exports_folder = function(which)
	local kind = SK.EXPORTS[which]

	SK.home_make(kind)

	return SK.HOME and (SK.HOME .. "\\" .. kind) or ("..\\mods\\SkeletonKey\\anim\\" .. kind)
end

SK.exports_open = function(which)
	local folder = SK.exports_folder(which)

	SK.exports_shown = SK.exports_shown or {}

	if folder and SK.now() - (SK.exports_shown[which] or -10) > 2 then
		SK.exports_shown[which] = SK.now()
		SK.open_folder(folder)
	end
end

SK.group_export = function(name)
	local t = SK.anim_read("groups", name)

	if type(t) ~= "table" or type(t.things) ~= "table" then
		return tostring(name) .. " could not be read."
	end

	local things = {}

	for _, r in ipairs(t.things) do
		if type(r) == "table" and type(r.key) == "string" and SK.numbers(r.at, 3) and SK.numbers(r.turn, 4) then
			things[#things + 1] = r
		end
	end

	if #things == 0 then
		return tostring(name) .. " has nothing in it to export."
	end

	local ok, err = SK.anim_write(SK.EXPORTS.groups, name, SK.export_text(name, things, t.level))

	if not ok then
		return tostring(err)
	end

	SK.exports_open("groups")

	return string.format("Exported %s, %s.", name, SK.count(#things, "thing"))
end

SK.group_sync = function(name)
	local t = SK.anim_read("groups", name)

	if type(t) ~= "table" or not SK.rows_ok(t.things) then
		return tostring(name) .. " could not be read."
	end

	if not SK.level_fits(t.level) then
		return "Only saves in " .. SK.level_title(t.level) .. "."
	end

	local world = SK.level_world()
	local want = string.lower(tostring(name))
	local bound = {}

	for unit, from in pairs(SK.placed_from or {}) do
		if string.lower(tostring(from.group)) == want and world and from.world == world and t.things[from.index] then
			bound[from.index] = bound[from.index] or {}
			bound[from.index][#bound[from.index] + 1] = unit
		end
	end

	if next(bound) == nil then
		return tostring(name) .. " is not loaded here. Load it first."
	end

	local out, slots, dropped = {}, {}, 0

	for i = 1, #t.things do
		local units = bound[i]

		if not units then
			out[#out + 1] = t.things[i]
		else
			local kept = 0

			for _, unit in ipairs(units) do
				local node = SK.alive(unit) and SK.node_ok(unit, t.things[i].node) and t.things[i].node or 1
				local row = SK.unit_row(unit, node, t.things[i].key)

				if row then
					out[#out + 1] = row
					slots[#slots + 1] = { unit = unit, index = #out }
					kept = kept + 1
				end
			end

			if kept == 0 then
				dropped = dropped + 1
			end
		end
	end

	local ok, err = SK.anim_write("groups", name, SK.group_text(name, out, SK.level_name() or t.level))

	if not ok then
		return tostring(err)
	end

	for unit, from in pairs(SK.placed_from) do
		if string.lower(tostring(from.group)) == want and from.world == world then
			SK.placed_from[unit] = nil
		end
	end

	for i = 1, #slots do
		SK.placed_from[slots[i].unit] = { group = name, index = slots[i].index, world = world }
	end

	return string.format("Saved %s: %s, %d removed.", name, SK.count(#out, "thing"), dropped)
end

SK.group_load = function(name)
	local t, err = SK.anim_read("groups", name)

	if not t then
		return err == "no such groups" and ("There is no group called " .. tostring(name) .. ".") or (tostring(name) .. " could not be read.")
	end

	if not SK.level_fits(t.level) then
		return "Only loads in " .. SK.level_title(t.level) .. "."
	end

	local okw, world = pcall(function()
		return Managers.world and Managers.world:world("level_world")
	end)

	if not okw or not world then
		return "There is no level to load into right now."
	end

	local made, left = 0, 0
	local copies = SK.copy_set()
	local want = string.lower(tostring(name))

	for unit, from in pairs(SK.placed_from or {}) do
		if string.lower(tostring(from.group)) == want and from.world == world and not copies[unit] then
			SK.placed_from[unit] = nil
		end
	end

	object.unit, object.node, object.from, object.turn, object.crew = nil, nil, nil, nil, nil

	for i = 1, #(type(t.things) == "table" and t.things or {}) do
		local r = t.things[i]
		local okm, unit = false, nil

		if type(r) == "table" and SK.numbers(r.at, 3) and SK.numbers(r.turn, 4) and SK.spawnable(r.key) then
			local at = Vector3(r.at[1], r.at[2], r.at[3])
			local turn = Quaternion.from_elements(r.turn[1], r.turn[2], r.turn[3], r.turn[4])

			if r.turn[1] == 0 and r.turn[2] == 0 and r.turn[3] == 0 and r.turn[4] == 0 then
				turn = Quaternion.identity()
			end

			okm, unit = pcall(World.spawn_unit_ex, world, r.key, nil, at, turn)
		end

		if okm and unit then
			local node = SK.node_ok(unit, r.node) and r.node or 1

			SK.placed_from = SK.placed_from or {}
			SK.placed_from[unit] = { group = name, index = i, world = world }
			SK.copies = SK.copies or {}
			SK.copies[#SK.copies + 1] = unit
			SK.meshy_touch(unit)
			SK.keep_add(unit, node)

			if SK.numbers(r.size, 3) then
				local sx, sy, sz = SK.size_fit(r.size[1]), SK.size_fit(r.size[2]), SK.size_fit(r.size[3])

				pcall(Unit.set_local_scale, unit, node, Vector3(sx, sy, sz))
				SK.collide_built[unit] = sx

				if sx ~= 1 or sy ~= 1 or sz ~= 1 then
					SK.collide_pending[unit] = SK.now()
				end
			end

			made = made + 1

			if made == 1 then
				SK.object_take(unit, node)
			else
				SK.object_add(unit, node)
			end
		else
			left = left + 1
		end
	end

	if made == 0 then
		return "None of its things are loaded in this level."
	end

	if left > 0 then
		return string.format("Loaded %d of %s, %d not in this level.", made, name, left)
	end

	return string.format("Loaded %s, %s.", name, SK.count(made, "thing"))
end

SK.set_load = function(name)
	local t, err = SK.anim_read("sets", name)
	if not t then
		return nil, err
	end
	local frames = {}
	for i = 1, #(type(t.frames) == "table" and t.frames or {}) do
		local f = type(t.frames[i]) == "table" and t.frames[i] or {}
		local frame = { name = tostring(f.name or ("frame " .. i)), hold = SK.finite(f.hold, 2), dial = {},
			group = type(f.group) == "string" and f.group ~= "" and f.group or nil }

		for j, d in pairs(type(f.dial) == "table" and f.dial or {}) do
			if SK.joint_name_ok(j) and type(d) == "table" then
				frame.dial[j] = { SK.finite(d[1], 0), SK.finite(d[2], 0), SK.finite(d[3], 0) }
			end
		end
		if type(f.from) == "table" then
			frame.base = {}

			for j, q in pairs(f.from) do
				if SK.joint_name_ok(j) and type(q) == "table" then
					frame.base[j] = QuaternionBox(Quaternion.from_elements(SK.finite(q[1], 0), SK.finite(q[2], 0), SK.finite(q[3], 0), SK.finite(q[4], 1)))
				end
			end
		end
		if type(f.at) == "table" then
			frame.sits = {}

			for j, p in pairs(f.at) do
				if SK.joint_name_ok(j) and type(p) == "table" then
					frame.sits[j] = Vector3Box(Vector3(SK.finite(p[1], 0), SK.finite(p[2], 0), SK.finite(p[3], 0)))
				end
			end
		end
		if type(f.anim) == "table" and f.anim.event then
			frame.anim = { event = tostring(f.anim.event), at = SK.finite(f.anim.at, nil), machine = tostring(f.anim.machine or "") }
		end
		frames[#frames + 1] = frame
	end
	return frames, SK.finite(t.rate, SK.POSE_RATE)
end

SK.play_list = function(unit, list, rate, release, loop)
	if unit and unit == pose.unit and pose.picked then
		return "ERR the panel has that one"
	end
	if unit and unit ~= pose.unit then
		if pose.unit and pose.picked and #pose.joints > 0 then
			return "ERR the panel has a target"
		end
		local ok, alive = pcall(Unit.alive, unit)
		if not ok or not alive then
			return "ERR that unit is gone"
		end
		if not SK.pose_is_rig(unit) then
			return "ERR that is not a person"
		end
		local hex = tostring(Unit.debug_name(unit)):match("%[(%x+)%]") or ""
		SK.pose_target(unit, hex, "", true)
		pose.picked = nil
	end
	if not pose.unit then
		return "Nobody is posed. Left-click a person first."
	end
	if #list == 0 then
		return "That set has no keyframes to play."
	end
	if rate then
		pose.rate = rate
	end
	SK.pose_apply(list[1])
	pose.play = { i = 1, until_t = SK.now() + (list[1].hold or 2), list = list, release = release, loop = loop }
	return string.format("Playing %s%s", SK.count(#list, "keyframe"), loop and " on a loop." or ".")
end

mod.play_set = function(unit, name, loop)
	local frames, rate = SK.set_load(name)
	if not frames then
		return SK.set_unread(name, rate)
	end
	return SK.play_list(unit, frames, rate, false, loop and true or nil)
end

-- ───────────────────── ❀ ─────────────────────
--  Set Export
-- ───────────────────── ❀ ─────────────────────

SK.EXPORT_PLAYER = [=[
local held = {}

local function num(v, fallback)
	v = tonumber(v)

	if v == nil or v ~= v or v == math.huge or v == -math.huge then
		return fallback
	end

	return v
end

local function alive(unit)
	local ok, yes = pcall(Unit.alive, unit)

	return unit ~= nil and ok and yes == true
end

local function networked(unit)
	local spawner = Managers.state and Managers.state.unit_spawner

	if not spawner or not spawner.game_object_id then
		return false
	end

	local ok, id = pcall(spawner.game_object_id, spawner, unit)

	return ok and id ~= nil
end

local function nodes(unit, names)
	local out = {}

	for i = 1, #names do
		local ok, has = pcall(Unit.has_node, unit, names[i])

		if ok and has then
			out[#out + 1] = names[i]
		end
	end

	return out
end

local function frames_of(list)
	local out = {}

	for i = 1, #(list or {}) do
		local f = list[i]
		local frame = { hold = num(f.hold, 2), dial = {} }

		for j, d in pairs(f.dial or {}) do
			frame.dial[j] = { num(d[1], 0), num(d[2], 0), num(d[3], 0) }
		end

		if type(f.from) == "table" then
			frame.base = {}

			for j, q in pairs(f.from) do
				frame.base[j] = QuaternionBox(Quaternion.from_elements(num(q[1], 0), num(q[2], 0), num(q[3], 0), num(q[4], 1)))
			end
		end

		if type(f.at) == "table" then
			frame.sits = {}

			for j, v in pairs(f.at) do
				frame.sits[j] = Vector3Box(Vector3(num(v[1], 0), num(v[2], 0), num(v[3], 0)))
			end
		end

		if type(f.anim) == "table" and f.anim.event then
			frame.anim = { event = tostring(f.anim.event), at = num(f.anim.at, nil), machine = tostring(f.anim.machine or "") }
		end

		out[#out + 1] = frame
	end

	return out
end

local function curve(u)
	if u <= 0 then
		return 0
	end

	if u >= 1 then
		return 1
	end

	return u * u * (3 - 2 * u)
end

local function turned(base, x, y, z)
	local q = base

	if x ~= 0 then
		q = Quaternion.multiply(q, Quaternion.axis_angle(Vector3(1, 0, 0), math.rad(x)))
	end

	if y ~= 0 then
		q = Quaternion.multiply(q, Quaternion.axis_angle(Vector3(0, 1, 0), math.rad(y)))
	end

	if z ~= 0 then
		q = Quaternion.multiply(q, Quaternion.axis_angle(Vector3(0, 0, 1), math.rad(z)))
	end

	return q
end

local function leg_of(p, name, have, want, span)
	local leg = p.leg[name]

	if leg and leg.to[1] == want[1] and leg.to[2] == want[2] and leg.to[3] == want[3] then
		return leg
	end

	local far = 0

	for a = 1, 3 do
		far = math.max(far, math.abs(want[a] - have[a]))
	end

	leg = {
		from = { have[1], have[2], have[3] },
		to = { want[1], want[2], want[3] },
		t0 = p.clock,
		span = span or far / math.max(1, p.rate),
	}
	p.leg[name] = leg

	return leg
end

local function blended(p, name)
	local play = p.play
	local to_r = p.rest and p.rest[name]
	local to_p = p.fixed and p.fixed[name]

	if play and play.from_base and play.t0 and play.span and play.span > 0 then
		local u = curve((p.clock - play.t0) / play.span)
		local fr = play.from_base[name]
		local fp = play.from_sits and play.from_sits[name]

		if fr and to_r and u < 1 then
			to_r = QuaternionBox(Quaternion.lerp(fr:unbox(), to_r:unbox(), u))
		end

		if fp and to_p and u < 1 then
			to_p = Vector3Box(Vector3.lerp(fp:unbox(), to_p:unbox(), u))
		end
	end

	return to_r, to_p
end

local function machine_on(p)
	local was = p.machine_off

	p.machine_off = nil

	if was and alive(was) then
		pcall(Unit.enable_animation_state_machine, was)
	end
end

local function freeze(p)
	local unit = p.unit

	p.machine_off = not networked(unit) and pcall(Unit.disable_animation_state_machine, unit) and unit or nil
	p.frozen, p.rest, p.fixed = {}, nil, {}

	local function take(name)
		local node = Unit.node(unit, name)
		local ok, q = pcall(Unit.local_rotation, unit, node)

		if ok and q then
			p.frozen[name] = QuaternionBox(q)
		end

		local okp, at = pcall(Unit.local_position, unit, node)

		if okp and at then
			p.fixed[name] = Vector3Box(at)
		end
	end

	for i = 1, #p.joints do
		take(p.joints[i])
	end

	for i = 1, #p.extra do
		take(p.extra[i])
	end

	for i = 1, #p.joints do
		p.dial[p.joints[i]] = { 0, 0, 0 }
		p.have[p.joints[i]] = { 0, 0, 0 }
	end

	p.leg = {}
end

local function hold(machine)
	local packages = Managers.package

	if packages and machine and machine ~= "" and not held[machine] then
		local ok, id = pcall(function()
			return packages:load(machine, set.name, nil, true)
		end)

		held[machine] = ok and id or nil
	end
end

local function to_machine(p, machine)
	local packages = Managers.package

	if not packages or not machine or machine == "" or networked(p.unit) then
		return false
	end

	hold(machine)

	if not packages:has_loaded(machine) then
		return false
	end

	local okm, has = pcall(Unit.has_animation_state_machine, p.unit)

	return okm and has and pcall(Unit.set_animation_state_machine, p.unit, machine) or false
end

local function ready(p, event, machine)
	local okh, has = pcall(Unit.has_animation_event, p.unit, event)

	if okh and has then
		return true
	end

	if not machine or machine == "" or networked(p.unit) then
		return false
	end

	hold(machine)

	return Managers.package and Managers.package:has_loaded(machine) and true or false
end

local function fire(p, event, machine)
	local okh, has = pcall(Unit.has_animation_event, p.unit, event)

	if not (okh and has) and machine and machine ~= "" then
		if not to_machine(p, machine) then
			return false
		end

		okh, has = pcall(Unit.has_animation_event, p.unit, event)
	end

	return okh and has and pcall(Unit.animation_event, p.unit, event) or false
end

local function clip(p, anim)
	if not ready(p, anim.event, anim.machine) then
		return
	end

	machine_on(p)
	p.frozen, p.fixed, p.anim, p.rest = nil, nil, nil, nil

	if not fire(p, anim.event, anim.machine) then
		return
	end

	for i = 1, #p.joints do
		local name = p.joints[i]

		p.dial[name] = { 0, 0, 0 }
		p.have[name] = { 0, 0, 0 }
		p.leg[name] = nil
	end

	p.anim = { fired_t = p.clock, freeze_at = anim.at }
end

local function apply(p, frame)
	if frame.anim then
		clip(p, frame.anim)
	end

	p.rest = frame.base

	if frame.sits then
		p.fixed = frame.sits
	end

	for i = 1, #p.joints do
		local name = p.joints[i]
		local d = frame.dial[name]

		p.dial[name] = d and { d[1], d[2], d[3] } or { 0, 0, 0 }
	end
end

local function extra_tick(p)
	local unit, frozen = p.unit, p.frozen

	for i = 1, #p.extra do
		local name = p.extra[i]
		local want, sits = nil, nil

		if p.play then
			want, sits = blended(p, name)
		end

		if not want then
			want = frozen and frozen[name]
			sits = p.fixed and p.fixed[name]

			if not want then
				want, sits = blended(p, name)
			end
		end

		local b = p.bone[name] or {}

		p.bone[name] = b

		if want then
			local node = Unit.node(unit, name)

			if pcall(Unit.set_animation_bone_mode, unit, "ignore", node) then
				b.held = true
			end

			if b.held then
				pcall(Unit.set_local_rotation, unit, node, want:unbox())

				if sits then
					pcall(Unit.set_local_position, unit, node, sits:unbox())
				end
			end
		elseif b.held then
			pcall(Unit.set_animation_bone_mode, unit, "position_and_rotation", Unit.node(unit, name))
			b.held = nil
		end
	end
end

local function step(p, dt)
	p.clock = p.clock + dt

	local t, unit, play = p.clock, p.unit, p.play

	if play then
		local guard = 0

		while p.play and t >= play.until_t and guard < 600 do
			guard = guard + 1

			local due = play.until_t

			if t - due > 0.25 then
				due = t
			end

			play.i = play.i + 1

			local frame = p.frames[play.i]

			if not frame and play.loop then
				play.i = 1
				frame = p.frames[1]
			end

			if frame then
				play.from_base, play.from_sits, play.t0 = p.rest, p.fixed, due
				apply(p, frame)
				play.span = frame.hold
				play.until_t = due + play.span
			else
				p.play = nil
			end
		end
	end

	local anim = p.anim

	if anim and anim.freeze_at and not p.frozen and t - anim.fired_t >= anim.freeze_at then
		freeze(p)
	end

	for i = 1, #p.joints do
		local name = p.joints[i]
		local want, have = p.dial[name], p.have[name]
		local b = p.bone[name] or {}

		p.bone[name] = b

		local leg = leg_of(p, name, have, want, play and play.span)
		local along = curve(leg.span > 0 and (t - leg.t0) / leg.span or 1)

		for a = 1, 3 do
			have[a] = leg.from[a] + (leg.to[a] - leg.from[a]) * along
		end

		local frozen = p.frozen and p.frozen[name]
		local kept = p.rest and p.rest[name]
		local idle = have[1] == 0 and have[2] == 0 and have[3] == 0
			and want[1] == 0 and want[2] == 0 and want[3] == 0

		if idle and not frozen and not kept then
			if b.held then
				pcall(Unit.set_animation_bone_mode, unit, "position_and_rotation", Unit.node(unit, name))
			end

			b.held, b.base = nil, nil
		else
			local node = Unit.node(unit, name)
			local live = not b.held and Unit.local_rotation(unit, node)
			local rest, sits = blended(p, name)

			if pcall(Unit.set_animation_bone_mode, unit, "ignore", node) and not b.held then
				b.held = true
				b.base = rest or frozen or QuaternionBox(live)
			end

			if rest then
				b.base = rest
			elseif frozen then
				b.base = frozen
			end

			if b.held then
				pcall(Unit.set_local_rotation, unit, node, turned(b.base:unbox(), have[1], have[2], have[3]))
				sits = sits or (p.fixed and p.fixed[name])

				if sits then
					pcall(Unit.set_local_position, unit, node, sits:unbox())
				end
			end
		end
	end

	extra_tick(p)

	return p.play ~= nil
end

function set.play(unit, loop)
	if not alive(unit) then
		return nil
	end

	local p = {
		unit = unit, clock = 0, rate = num(set.rate, 90), frames = frames_of(set.frames),
		joints = nodes(unit, JOINTS), extra = nodes(unit, EXTRA),
		dial = {}, have = {}, leg = {}, bone = {},
	}

	if #p.joints == 0 or #p.frames == 0 then
		return nil
	end

	for i = 1, #p.joints do
		p.dial[p.joints[i]] = { 0, 0, 0 }
		p.have[p.joints[i]] = { 0, 0, 0 }
	end

	for i = 1, #p.frames do
		if p.frames[i].anim then
			hold(p.frames[i].anim.machine)
		end
	end

	apply(p, p.frames[1])
	p.play = { i = 1, until_t = p.frames[1].hold, loop = loop and true or nil }

	return p
end

function set.update(p, dt)
	if type(p) ~= "table" or p.stopped or not alive(p.unit) then
		return false
	end

	local ok, going = pcall(step, p, num(dt, 0))

	return ok and going == true
end

function set.stop(p)
	if type(p) ~= "table" or p.stopped then
		return
	end

	p.stopped, p.play = true, nil
	machine_on(p)

	if alive(p.unit) then
		for name, b in pairs(p.bone) do
			if b.held then
				pcall(Unit.set_animation_bone_mode, p.unit, "position_and_rotation", Unit.node(p.unit, name))
			end
		end
	end

	p.bone = {}
end

return set
]=]

SK.set_export_text = function(name, rate, frames)
	local out = {
		"-- " .. name,
		"-- Made with Skeleton Key.",
		"--",
		"-- For mod makers, put this file in your mod and add:",
		"--   local set = mod:io_dofile(\"YourMod/" .. name .. "\")",
		"--   local playing = set.play(unit)",
		"--   mod.update = function(dt) set.update(playing, dt) end",
		"--   set.stop(playing)",
		"",
		"local set = {",
		string.format("\tname = %q,", name),
		string.format("\trate = %s,", tostring(rate)),
		"\tframes = {",
	}

	SK.set_rows(out, frames, false)
	out[#out + 1] = "\t},"
	out[#out + 1] = "}"

	for _, list in ipairs({ { "JOINTS", SK.JOINTS }, { "EXTRA", SK.EXTRA } }) do
		out[#out + 1] = ""
		out[#out + 1] = "local " .. list[1] .. " = {"

		for i = 1, #list[2], 6 do
			local row = {}

			for j = i, math.min(i + 5, #list[2]) do
				row[#row + 1] = string.format("%q", list[2][j])
			end

			out[#out + 1] = "\t" .. table.concat(row, ", ") .. ","
		end

		out[#out + 1] = "}"
	end

	return table.concat(out, string.char(10)) .. string.char(10) .. string.char(10) .. SK.EXPORT_PLAYER .. string.char(10)
end

SK.set_export = function(name)
	local frames, rate = SK.set_load(name)

	if not frames then
		return SK.set_unread(name, rate), true
	end

	if #frames == 0 then
		return tostring(name) .. " has no keyframes to export.", true
	end

	local ok, err = SK.anim_write(SK.EXPORTS.sets, name, SK.set_export_text(name, rate, frames))

	if not ok then
		return tostring(err), true
	end

	SK.exports_open("sets")

	return string.format("Exported %s, %s.", name, SK.count(#frames, "keyframe"))
end

-- ───────────────────── ❀ ─────────────────────
--  Set Verb
-- ───────────────────── ❀ ─────────────────────

SK.anim_rename = function(kind, old, new)
	if not SK.anim_name_ok(old) then return "That set name is not valid." end
	if not SK.anim_name_ok(new) then return SK.name_rule(new) end
	if old == new then return "That is its name already." end
	local same_file = string.lower(old) == string.lower(new)
	for _, taken in ipairs(SK.anim_index(kind)) do
		if string.lower(taken) == string.lower(new) and not same_file then
			return "There is already a set called " .. taken .. "."
		end
	end
	local frames, rate = SK.set_load(old)
	if not frames then return SK.set_unread(old, rate) end
	local text = SK.set_text(new, rate, frames)
	local ok, err = SK.anim_write(kind, new, text)
	if not ok then return tostring(err) end
	if not same_file then
		SK.anim_delete(kind, old)
	end
	return string.format("Renamed %s to %s.", old, new)
end

mod.sk_set = function(what, name, new_name)
	if what == nil or what == "" or what == "list" then
		local names = SK.anim_index("sets")
		return #names > 0 and table.concat(names, "  ") or "no sets saved"
	end
	if what == "save" then
		return SK.set_save(tostring(name or ""))
	elseif what == "load" then
		local frames, rate = SK.set_load(tostring(name or ""))
		if not frames then return SK.set_unread(name, rate), true end
		pose.frames = frames
		pose.rate = rate
		SK.frames_save()
		return string.format("Loaded %s from set %s.", SK.count(#frames, "keyframe"), name)
	elseif what == "play" then
		return mod.play_set(nil, tostring(name or ""), pose.loop)
	elseif what == "delete" then
		if not SK.anim_name_ok(name) then return "That set name is not valid." end
		SK.anim_delete("sets", name)
		return "Deleted set " .. name .. "."
	elseif what == "rename" then
		return SK.anim_rename("sets", tostring(name or ""), tostring(new_name or ""))
	elseif what == "export" then
		return SK.set_export(tostring(name or ""))
	end
	return "ERR set verbs: list save load play delete rename export"
end

mod.stop_playing = function()
	pose.play = nil

	if pose.unit and not pose.picked then
		SK.pose_release()
		pose.unit = nil
		pose.hex, pose.name = "", ""
		pose.joints, pose.dial, pose.have = {}, {}, {}
	end

	return "stopped"
end

mod.is_playing = function()
	return pose.play ~= nil
end

mod.pose_state = function()
	return pose
end

-- ───────────────────── ❀ ─────────────────────
--  Callbacks
-- ───────────────────── ❀ ─────────────────────

mod.update = function(dt)
	if mod.is_enabled and not mod:is_enabled() then
		return
	end
	pcall(SK.chat_tick)
	local t = SK.now()
	SK.peek_tick()
	if G.pose and G.pose.unit then
		pcall(SK.pose_tick, dt or 0, t)
		pcall(SK.pose_mark, t)
	else
		pcall(SK.collide_tick)

		if G.pose and G.pose.picked then
			pcall(SK.pose_refind, t)
		end
	end
	pcall(SK.frames_tick, t)
end

mod.on_unload = function()
	pcall(SK.frames_flush)
end

mod.on_disabled = function(initial_call)
	if initial_call then
		return
	end

	pcall(SK.frames_flush)
	pcall(SK.chat_tick, true)
	pcall(mod.stop_playing)
	pcall(mod.sk_pose, "clear")
	pcall(mod.sk_hide, "all")

	if SK.marks_here() then
		pcall(SK.marks_show, false)
	end

	for unit, machine in pairs(SK.moved_machine or {}) do
		local home = SK.alive(unit) and SK.home_machine(unit)

		if home and home ~= machine then
			pcall(SK.anim_machine, unit, home)
		end

		SK.moved_machine[unit] = nil
	end

	local ff = Managers.free_flight
	local okf, flying = pcall(function() return ff and ff:is_in_free_flight() end)

	if okf and flying and G.fly_want and SK.windows_open() == 0 then
		pcall(SK.free_flight, false)
	end
end

mod.on_all_mods_loaded = function()
	if not G.hooked then
		G.hooked = true
		mod:hook_safe(CLASS.PlayerUnitWeaponExtension, "fixed_update", function(self, unit, dt, t, frame)
			local player = self._player
			if not player or player.viewport_name ~= "player1" then
				return
			end
			if G.pick and G.pick.armed then
				G.pick.armed = false
				pcall(SK.pick_now, unit)
			end
		end)
	end
end

mod.sk_hello = function()
	return "Skeleton Key " .. SK.VERSION
end

-- ───────────────────── ❀ ─────────────────────
--  Registration
-- ───────────────────── ❀ ─────────────────────

if not G.hud_registered then
	G.hud_registered = true
	mod:register_hud_element({
	class_name = "HudElementSkeletonKey",
	filename = "SkeletonKey/scripts/mods/SkeletonKey/HudElementSkeletonKey",
	use_hud_scale = true,
	visibility_groups = {
		"alive",
		"dead",
		"in_view",
		"in_hub_view",
		"communication_wheel",
		"tactical_overlay",
		"player_in_danger_zone",
	},
})
end

mod:add_require_path("SkeletonKey/scripts/mods/SkeletonKey/SkeletonKey_Pose")
mod:add_require_path("SkeletonKey/scripts/mods/SkeletonKey/SkeletonKey_Pose_Definitions")

-- The Three Panels skin lives in its own two files; with either gone the
-- view registers on the panel itself, as if the skin never was.
SK.THREE = "SkeletonKey/scripts/mods/SkeletonKey/SkeletonKey_Three"

SK.has_file = function(path)
	local okf, f = pcall(function()
		return Mods.lua.io.open("./../mods/" .. path .. ".lua", "r")
	end)

	if okf and f then
		pcall(function() f:close() end)

		return true
	end

	return false
end

SK.panel_path = function()
	if SK.has_file(SK.THREE) and SK.has_file(SK.THREE .. "_Definitions") then
		mod:add_require_path(SK.THREE)
		mod:add_require_path(SK.THREE .. "_Definitions")

		return SK.THREE
	end

	return "SkeletonKey/scripts/mods/SkeletonKey/SkeletonKey_Pose"
end

local function register(view_name, class_name, path, display)
	mod:register_view({
		view_name = view_name,
		view_settings = {
			init_view_function = function(ingame_ui_context)
				return true
			end,
			class = class_name,
			disable_game_world = false,
			display_name = display,
			game_world_blur = 0,
			load_always = true,
			load_in_hub = true,
			package = "packages/ui/views/scanner_display_view/scanner_display_view",
			path = path,
			state_bound = true,
		},
		view_transitions = {},
		view_options = {
			close_all = false,
			close_previous = false,
			close_transition_time = nil,
			transition_time = nil,
		},
	})
end

register("skeletonkey_pose_view", "SkeletonKeyPoseView", SK.panel_path(), "loc_skeletonkey_pose_view_display_name")

SK.PHYS = "SkeletonKey/scripts/mods/SkeletonKey/SkeletonKey_Phys"
SK.phys = nil

do
	local okf, f = pcall(function()
		return Mods.lua.io.open("./../mods/" .. SK.PHYS .. ".lua", "r")
	end)

	if okf and f then
		pcall(function() f:close() end)
		pcall(function() mod:io_dofile(SK.PHYS) end)
	end
end

mod:io_dofile("SkeletonKey/scripts/mods/SkeletonKey/SkeletonKey_Pose")
