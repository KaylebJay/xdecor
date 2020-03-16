-- Thanks to sofar for helping with that code.
screwdriver = screwdriver or {}

local function door_toggle(pos_actuator, pos_door, player)
	local player_name = player:get_player_name()
	local actuator = minetest.get_node(pos_actuator)
	local door = doors.get(pos_door)

	if actuator.name:sub(-4) == "_off" then
		minetest.set_node(pos_actuator,
			{name = actuator.name:gsub("_off", "_on"), param2 = actuator.param2})
	end
	door:open(player)

	minetest.after(2, function()
		if minetest.get_node(pos_actuator).name:sub(-3) == "_on" then
			minetest.set_node(pos_actuator,
				{name = actuator.name, param2 = actuator.param2})
		end
		-- Re-get player object (or nil) because 'player' could
		-- be an invalid object at this time (player left)
		door:close(minetest.get_player_by_name(player_name))
	end)
end
