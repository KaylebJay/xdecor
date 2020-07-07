-- Thanks to sofar for helping with that code.

minetest.setting_set("nodetimer_interval", 0.1)

local plate = {}
screwdriver = screwdriver or {}


function plate_closing_after(door,player_name,actuator,pos_actuator) 
	minetest.after(1, function()
		-- Re-get player object (or nil) because 'player' could
		-- be an invalid object at this time (player left)
		local player = minetest.get_player_by_name(player_name)

		-- calculate player distance from the pressure plate
		local dist_square = 9 --  player not online  == far of the pplate 
		if player then
			local ppos = player:get_pos()
			local dx = ppos.x - pos_actuator.x
			local dy = ppos.y - pos_actuator.y
			local dz = ppos.z - pos_actuator.z
			dist_square = dx*dx + dy*dy + dz*dz
		end

		-- prevent the door to close if player still on the pressure plate
		if dist_square > 0.64 then -- = 0.8²
			if minetest.get_node(pos_actuator).name:sub(-3) == "_on" then
				minetest.set_node(pos_actuator,
					{name = actuator.name, param2 = actuator.param2})
			end

			door:close(player)
		else
			-- if player still here whe check again after 
			plate_closing_after(door,player_name,actuator,pos_actuator) 
		end
	end)
end


local function door_toggle(pos_actuator, pos_door, player)
	local player_name = player:get_player_name()
	local actuator = minetest.get_node(pos_actuator)
	local door = doors.get(pos_door)

	if actuator.name:sub(-4) == "_off" then
		minetest.set_node(pos_actuator,
			{name = actuator.name:gsub("_off", "_on"), param2 = actuator.param2})
	end
	door:open(player)
	plate_closing_after(door,player_name,actuator,pos_actuator)
end




function plate.construct(pos)
	local timer = minetest.get_node_timer(pos)
	timer:start(0.1)
end



function plate.timer(pos)
	local objs = minetest.get_objects_inside_radius(pos, 0.8)
	if not next(objs) or not doors.get then return true end

	local minp = {x = pos.x - 2, y = pos.y, z = pos.z - 2}
	local maxp = {x = pos.x + 2, y = pos.y, z = pos.z + 2}
	local doors_pos = minetest.find_nodes_in_area(minp, maxp, "group:door")

	for _, player in pairs(objs) do
		if player:is_player() then
			for i = 1, #doors_pos do
				-- only keep in front of ppalte side (not diagonal ones)
				if doors_pos[i].x == pos.x or doors_pos[i].z == pos.z then
					local is_to_toggle = true
					local node = nil
					if  math.abs(doors_pos[i].x - pos.x) == 2   or math.abs(doors_pos[i].z - pos.z) == 2  then
						local node = minetest.get_node(doors_pos[i])
						local door = doors.get(doors_pos[i])
						is_to_toggle = false 

						-- only toogle door facing (when closed) the pplate when they are 2 node far.
						if door:state() then
							if (node.param2 == 2 and doors_pos[i].x - pos.x > 0)  
							or (node.param2 == 0 and doors_pos[i].x - pos.x < 0)  
							or (node.param2 == 1 and doors_pos[i].z - pos.z > 0)  
							or (node.param2 == 3 and doors_pos[i].z - pos.z < 0)  
							then 
								is_to_toggle = true 
							end
						else
							if (node.param2 == 1 and doors_pos[i].x - pos.x > 0)  
							or (node.param2 == 3 and doors_pos[i].x - pos.x < 0)  
							or (node.param2 == 0 and doors_pos[i].z - pos.z > 0)  
							or (node.param2 == 2 and doors_pos[i].z - pos.z < 0)  
							then 
								is_to_toggle = true 
							end
						end
					end
					if is_to_toggle then door_toggle(pos, doors_pos[i], player) end
				end
			end
			break
		end
	end

	return true
end

function plate.register(material, desc, def)
	xdecor.register("pressure_" .. material .. "_off", {
		-- xdecor.register("pressure_wood_off", {
		-- xdecor.register("pressure_stone_on", {
		description = desc .. " Pressure Plate",
		tiles = {"xdecor_pressure_" .. material .. ".png"},
		drawtype = "nodebox",
		node_box = xdecor.pixelbox(16, {{1, 0, 1, 14, 1, 14}}),
		groups = def.groups,
		sounds = def.sounds,
		sunlight_propagates = true,
		on_rotate = screwdriver.rotate_simple,
		on_construct = plate.construct,
		on_timer = plate.timer
	})
	xdecor.register("pressure_" .. material .. "_on", {
		tiles = {"xdecor_pressure_" .. material .. ".png"},
		drawtype = "nodebox",
		node_box = xdecor.pixelbox(16, {{1, 0, 1, 14, 0.4, 14}}),
		groups = def.groups,
		sounds = def.sounds,
		drop = "xdecor:pressure_" .. material .. "_off",
		sunlight_propagates = true,
		on_rotate = screwdriver.rotate_simple
	})
end

plate.register("bronze", "Bronze", {
	sounds = default.node_sound_wood_defaults(),
	groups = {choppy = 3, oddly_breakable_by_hand = 2, flammable = 2}
})

plate.register("steel", "Steel", {
	sounds = default.node_sound_stone_defaults(),
	groups = {cracky = 3, oddly_breakable_by_hand = 2}
})

xdecor.register("lever_off", {
	description = "Lever",
	tiles = {"xdecor_lever_off.png"},
	drawtype = "nodebox",
	node_box = xdecor.pixelbox(16, {{2, 1, 15, 12, 14, 1}}),
	groups = {cracky = 3, oddly_breakable_by_hand = 2},
	sounds = default.node_sound_stone_defaults(),
	sunlight_propagates = true,
	on_rotate = screwdriver.rotate_simple,

	on_rightclick = function(pos, node, clicker, itemstack)
		if not doors.get then return itemstack end
		local minp = {x = pos.x - 2, y = pos.y - 1, z = pos.z - 2}
		local maxp = {x = pos.x + 2, y = pos.y + 1, z = pos.z + 2}
		local doors = minetest.find_nodes_in_area(minp, maxp, "group:door")

		for i = 1, #doors do
			door_toggle(pos, doors[i], clicker)
		end

		return itemstack
	end
})

xdecor.register("lever_on", {
	tiles = {"xdecor_lever_on.png"},
	drawtype = "nodebox",
	node_box = xdecor.pixelbox(16, {{2, 1, 15, 12, 14, 1}}),
	groups = {cracky = 3, oddly_breakable_by_hand = 2, not_in_creative_inventory = 1},
	sounds = default.node_sound_stone_defaults(),
	sunlight_propagates = true,
	on_rotate = screwdriver.rotate_simple,
	drop = "xdecor:lever_off"
})

-- back compatibility
minetest.register_alias("xdecor:pressure_stone_off", "xdecor:pressure_steel_off")
minetest.register_alias("xdecor:pressure_stone_on", "xdecor:pressure_steel_on")
minetest.register_alias("xdecor:pressure_wood_off", "xdecor:pressure_bronze_off")
minetest.register_alias("xdecor:pressure_wood_on", "xdecor:pressure_bronze_on")

-- Recipes
if core.get_modpath("technic") then
	minetest.register_craft({
		output = "xdecor:pressure_steel_off",
		type = "shapeless",
		recipe = {"technic:stainless_steel_ingot", "default:technic:stainless_steel_ingot"}
	})
else
	minetest.register_craft({
		output = "xdecor:pressure_steel_off",
		type = "shapeless",
		recipe = {"default:steel_ingot", "default:steel_ingot"}
	})
end

minetest.register_craft({
	output = "xdecor:pressure_bronze_off",
	type = "shapeless",
	recipe = {"default:bronze_ingot", "default:bronze_ingot"}
})

minetest.register_craft({
	output = "xdecor:lever_off",
	recipe = {
		{"group:stick"},
		{"group:stone"}
	}
})