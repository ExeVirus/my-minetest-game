--
-- Player as a Rocket
--
-- This file defines functions for turning the player into a rocket, applying decent rocket
-- physics, and allowing them to turn back into a player
--

local players_data = {}

-- Default player appearance
player_api.register_model("rocket_player.obj", {
	animation_speed = 0,
	textures = {"rocket.png"},
	animations = {},
	collisionbox = {-0.5, -0.5, -0.5, 0.5, 2.5, 0.5},
	stepheight = 0.6,
	eye_height = 1.47,
})

rocket.update_hud = function (player)
	local name = player:get_player_name()
	if players_data[name] == nil then
		return
	end
	-- Update thrust icons
	local old_thrust = players_data[name].visible_thrust
	local new_thrust = players_data[name].thrust
	if new_thrust ~= old_thrust then
		-- Delete old HUD
		local old_hud = players_data[name].thrust_hud
		if old_hud ~= nil then
			player:hud_remove(old_hud)
			players_data[name].thrust_hud = nil
		end
		-- Add new HUD
		if new_thrust == nil then
			players_data[name].thrust_hud = nil
		elseif new_thrust == "full" then
			players_data[name].thrust_hud = player:hud_add {
				hud_elem_type = "image",
				position = {x=0.1, y=0.1},
				scale = {x=4, y=4},
				text = "icon_full_thrust.png"
			}
		elseif new_thrust == "low" then
			players_data[name].thrust_hud = player:hud_add {
				hud_elem_type = "image",
				position = {x=0.1, y=0.1},
				scale = {x=4, y=4},
				text = "icon_low_thrust.png"
			}
		end
		players_data[name].visible_thrust = new_thrust
	end
	-- Update crash danger icon
	local vel = player:get_velocity()
	local new_danger = nil
	-- Empirical, only slightly (-0.5) conservative value for fall damage
	if vel.y < -14 then
		new_danger = "crash"
	end
	local old_danger = players_data[name].visible_danger
	if new_danger ~= old_danger then
		-- Delete old HUD
		local old_hud = players_data[name].danger_hud
		if old_hud ~= nil then
			player:hud_remove(old_hud)
			players_data[name].danger_hud = nil
		end
		-- Add new HUD
		if new_danger == nil then
			players_data[name].danger_hud = nil
		elseif new_danger == "crash" then
			players_data[name].danger_hud = player:hud_add {
				hud_elem_type = "image",
				position = {x=0.1, y=0.1},
				scale = {x=4, y=4},
				text = "icon_crash_danger.png",
				offset = {x=80, y=0}
			}
		end
		players_data[name].visible_danger = new_danger
	end
end

-- Turn a player into a rocket
rocket.player_to_rocket = function (player, pos)
    player:set_physics_override {
        speed = 0,
        gravity = 1,
    }
	player:set_pos(pos)
    player_api.set_model(player, "rocket_player.obj")
    local name = player:get_player_name()
    players_data[name].is_rocket = true
    players_data[name].is_lifted_off = false
	players_data[name].thrust = nil
end

--Turn a rocket player back into a player
rocket.rocket_to_player = function(player, pos)
	local name = player:get_player_name()
    player_api.player_attached[name] = false
    player_api.set_model(player, "character.b3d")
    player:set_local_animation(
        {x = 0,   y = 79},
        {x = 168, y = 187},
        {x = 189, y = 198},
        {x = 200, y = 219},
        30
    )
    player:set_physics_override {
        speed = 1,
        gravity = 1,
    }

    --Move to rocket landing position
    if pos ~= nil then
        player:set_pos {x=pos.x, y=pos.y, z=pos.z}
    end

	local inventory = player:get_inventory()
	if not inventory:contains_item("main", "rocket:rocket 1") then
		inventory:add_item("main", "rocket:rocket 1")
	end

	players_data[name].is_rocket = false
	players_data[name].is_lifted_off = false
	players_data[name].thrust = nil
end

rocket.particles = function(pos, vel, dtime)
	local maxtime = dtime
	local offset = 0
	if vel.y < 0 then
		maxtime = math.min(dtime, -1/vel.y)
		offset = -vel.y*dtime*2
	end
    minetest.add_particlespawner {
        amount = 50 * dtime,
        time   = maxtime,
        minpos = {x=pos.x-0.5, y=pos.y-offset, z=pos.z-0.5},
        maxpos = {x=pos.x+0.5, y=pos.y-offset, z=pos.z+0.5},
        minvel = {x=-0.7,y=math.min(-1, vel.y-8),z=-0.7},
        maxvel = {x=0.7,y=math.min(-1, vel.y-6),z=0.7},
        minacc = 0,
        maxacc = 0,
        minexptime = 3,
        maxexptime = 4,
        minsize = 0.8,
        maxsize = 10,
        collisiondetection = false,
        collision_removal  = false,
        vertical = false,
        texture = 'thrust.png',
    }
end

-- Rocket globalstep
local function rocket_physics(dtime, player, name)
	-- Handle the rocket flying up
	local controls = player:get_player_control()
	local pos = player:get_pos()
	local vel = player:get_velocity()
	local physics = player:get_physics_override()
	if controls.jump then
		physics.speed = 5
	    physics.gravity = -1
		players_data[name].thrust = "full"
	    rocket.particles(pos, vel, dtime)
	elseif controls.sneak then
		physics.speed = 2
		physics.gravity = 0
		players_data[name].thrust = "low"
	    rocket.particles(pos, vel, dtime)
	else
		if players_data[name].is_lifted_off then
			physics.speed = 1
		else
			physics.speed = 0
		end
		physics.gravity = 1
		players_data[name].thrust = nil
	end
	player:set_physics_override(physics)

	local vel = player:get_velocity()

	if(players_data[name].is_lifted_off) then
	    -- Handle the player landing on ground
	    pos.y = pos.y - 1
	    local node = minetest.get_node(pos)
	    pos.y = pos.y + 1
	    if minetest.registered_nodes[node.name].walkable
		and math.abs(vel.y) < 1.5 then
	        rocket.rocket_to_player(player, pos)
	    end
	else
	    if vel.y > 1 then
	        players_data[name].is_lifted_off = true
	    end
	end
	rocket.update_hud(player)
end

local function globalstep_callback(dtime)
    local player_list = minetest.get_connected_players()
    for _, player in pairs(player_list) do
        -- Check if player is rocket
        local name = player:get_player_name()
        if players_data[name] ~= nil then
			if players_data[name].is_rocket then
				rocket_physics(dtime, player, name)
			end
        end
    end
end

minetest.register_globalstep(globalstep_callback)

-- Rocket on_join_player
local function rocket_join_player(player, last_login)
	local name = player:get_player_name()
	players_data[name] = {
		is_rocket = false,
		is_lifted_off = false,
	}
	rocket.rocket_to_player(player)
end

minetest.register_on_joinplayer(rocket_join_player)
