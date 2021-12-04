vines = {
	name = 'vines',
	recipes = {}
}

local enable_rope = minetest.settings:get_bool("vines_enable_rope")
local enable_roots = minetest.settings:get_bool("vines_enable_roots")
local enable_standard = minetest.settings:get_bool("vines_enable_standard")
local enable_side = minetest.settings:get_bool("vines_enable_side")
local enable_jungle = minetest.settings:get_bool("vines_enable_jungle")
local enable_willow = minetest.settings:get_bool("vines_enable_willow")

local default_rarity = 90
local rarity_roots = tonumber(minetest.settings:get("vines_rarity_roots")) or default_rarity
local rarity_standard = tonumber(minetest.settings:get("vines_rarity_standard")) or default_rarity
local rarity_side = tonumber(minetest.settings:get("vines_rarity_side")) or default_rarity
local rarity_jungle = tonumber(minetest.settings:get("vines_rarity_jungle")) or default_rarity
local rarity_willow = tonumber(minetest.settings:get("vines_rarity_willow")) or default_rarity

local growth_min = 60 * 3
local growth_max = 60 * 6

-- support for i18n
local S = minetest.get_translator("vines")

-- ITEMS

minetest.register_craftitem("vines:vines", {
	description = S("Vines"),
	inventory_image = "vines_item.png",
	groups = {vines = 1, flammable = 2}
})

-- FUNCTIONS

local function on_dig(pos, node, player)
	wielded_item = player:get_wielded_item()
	if wielded_item and wielded_item:get_name() == 'vines:shears' then
		wielded_item:add_wear(1)

		vine_name_end = node.name:gsub("_middle", "_end")
		minetest.remove_node(pos)
		minetest.handle_node_drops(pos, {vine_name_end}, player)

		below_pos = {x = pos.x, y = pos.y - 1, z = pos.z}
		while minetest.get_item_group(minetest.get_node(below_pos).name, "vines") > 0 do
			minetest.remove_node(below_pos)
			minetest.handle_node_drops(below_pos, {vine_name_end}, player)
			below_pos.y = below_pos.y - 1
		end

	else
		minetest.node_dig(pos, node, player)
	end
end

local function dig_down(pos, node, digger)

	if digger == nil then return end

	local np = {x = pos.x, y = pos.y - 1, z = pos.z}
	local nn = minetest.get_node(np)

	if minetest.get_item_group(nn.name, "vines") > 0 then
		minetest.node_dig(np, nn, digger)
	end
end

local function ensure_vine_end(pos, oldnode)
	local np = {x = pos.x, y = pos.y + 1, z = pos.z}
	local nn = minetest.get_node(np)

	vine_name_end = oldnode.name:gsub("_middle", "_end")

	if minetest.get_item_group(nn.name, "vines") > 0 then
		minetest.swap_node(np, { name = vine_name_end, param2 = oldnode.param2 })
		minetest.registered_items[vine_name_end].on_construct(np, minetest.get_node(np))
	end
end


vines.register_vine = function( name, defs, biome )

	local groups = {vines = 1, snappy = 3, flammable = 2}
	local vine_name_end = 'vines:' .. name .. '_end'
	local vine_name_middle = 'vines:' .. name .. '_middle'
	local vine_image_end = "vines_" .. name .. "_end.png"
	local vine_image_middle = "vines_" .. name .. "_middle.png"
	local drop_node = vine_name_end

	local spawn_plants = function(pos, fdir)
		local max_length = math.random(defs.average_length)
		local current_length = 0
		while minetest.get_node({ x=pos.x, y=pos.y - 1, z=pos.z }).name == 'air' and current_length < max_length do
			minetest.swap_node(pos, { name = vine_name_middle, param2 = fdir })
			pos.y = pos.y - 1
			current_length = current_length + 1
		end
		minetest.set_node(pos, { name = vine_name_end, param2 = fdir })
	end

	local vine_group = 'group:' .. name .. '_vines'

	biome.surface[#biome.surface + 1] = vine_group

	local selection_box = {type = "wallmounted",}
	local drawtype = 'signlike'

	-- different properties for bottom and side vines.
	if not biome.spawn_on_side then

		selection_box = {
			type = "fixed", fixed = { -0.4, -1/2, -0.4, 0.4, 1/2, 0.4 }
		}

		drawtype = 'plantlike'
	end

	minetest.register_node(vine_name_end, {
		description = defs.description,
		walkable = false,
		climbable = true,
		wield_image = vine_image_end,
		drop = "vines:vines",
		sunlight_propagates = true,
		paramtype = "light",
		paramtype2 = "wallmounted",
		buildable_to = false,
		tiles = {vine_image_end},
		drawtype = drawtype,
		inventory_image = vine_image_end,
		groups = groups,
		sounds = default.node_sound_leaves_defaults(),
		selection_box = selection_box,

		on_construct = function(pos)

			local timer = minetest.get_node_timer(pos)
			timer:start(math.random(growth_min, growth_max))
		end,

		on_timer = function(pos)

			local node = minetest.get_node(pos)
			local bottom = {x = pos.x, y = pos.y - 1, z = pos.z}
			local bottom_node = minetest.get_node( bottom )
			if bottom_node.name == "air" then

				if math.random(defs.average_length) ~= 1 then

					minetest.swap_node(pos, {
							name = vine_name_middle, param2 = node.param2})

					minetest.set_node(bottom, {
							name = node.name, param2 = node.param2})

					local timer = minetest.get_node_timer(bottom_node)

					timer:start(math.random(growth_min, growth_max))
				end
			end
		end,

		on_dig = on_dig,

		after_dig_node = function(pos, node, metadata, digger)
			dig_down(pos, node, digger)
		end,

		after_destruct = function(pos, oldnode)
			ensure_vine_end(pos, oldnode)
		end,
	})

	minetest.register_node( vine_name_middle, {
		description = S("Matured") .. " " .. defs.description,
		walkable = false,
		climbable = true,
		drop = "vines:vines",
		sunlight_propagates = true,
		paramtype = "light",
		paramtype2 = "wallmounted",
		buildable_to = false,
		tiles = {vine_image_middle},
		wield_image = vine_image_middle,
		drawtype = drawtype,
		inventory_image = vine_image_middle,
		groups = groups,
		sounds = default.node_sound_leaves_defaults(),
		selection_box = selection_box,

		on_dig = on_dig,

		after_dig_node = function(pos, node, metadata, digger)
			dig_down(pos, node, digger)
		end,

		after_destruct = function(pos, oldnode)
			ensure_vine_end(pos, oldnode)
		end,
	})

    biome_lib.register_on_generate(biome, spawn_plants)
end

-- ALIASES

-- used to remove the old vine nodes and give room for the new.
minetest.register_alias( 'vines:root', 'air' )
minetest.register_alias( 'vines:root_rotten', 'air' )
minetest.register_alias( 'vines:vine', 'air' )
minetest.register_alias( 'vines:vine_rotten', 'air' )
minetest.register_alias( 'vines:side', 'air' )
minetest.register_alias( 'vines:side_rotten', 'air' )
minetest.register_alias( 'vines:jungle', 'air' )
minetest.register_alias( 'vines:jungle_rotten', 'air' )
minetest.register_alias( 'vines:willow', 'air' )
minetest.register_alias( 'vines:willow_rotten', 'air' )

-- CRAFTS

minetest.register_craft({
	output = 'vines:rope_block',
	recipe = {
		{'group:vines', 'group:vines', 'group:vines'},
		{'group:vines', 'group:wood', 'group:vines'},
		{'group:vines', 'group:vines', 'group:vines'},
	}
})

if minetest.get_modpath("moreblocks") then

	minetest.register_craft({
		output = 'vines:rope_block',
		recipe = {
			{'moreblocks:rope', 'moreblocks:rope', 'moreblocks:rope'},
			{'moreblocks:rope', 'group:wood', 'moreblocks:rope'},
			{'moreblocks:rope', 'moreblocks:rope', 'moreblocks:rope'},
		}
	})
end

minetest.register_craft({
	output = 'vines:shears',
	recipe = {
		{'', 'default:steel_ingot', ''},
		{'group:stick', 'group:wood', 'default:steel_ingot'},
		{'', '', 'group:stick'}
	}
})

-- NODES

if enable_rope ~= false then
	minetest.register_node("vines:rope_block", {
		description = S("Rope"),
		sunlight_propagates = true,
		paramtype = "light",
		tiles = {
			"default_wood.png^vines_rope.png",
			"default_wood.png^vines_rope.png",
			"default_wood.png",
			"default_wood.png",
			"default_wood.png^vines_rope.png",
			"default_wood.png^vines_rope.png",
		},
		groups = {flammable = 2, choppy = 2, oddly_breakable_by_hand = 1},

		after_place_node = function(pos)

			local p = {x = pos.x, y = pos.y - 1, z = pos.z}
			local n = minetest.get_node(p)

			if n.name == "air" then
				minetest.add_node(p, {name = "vines:rope_end"})
			end
		end,

		after_dig_node = function(pos, node, digger)

			local p = {x = pos.x, y = pos.y - 1, z = pos.z}
			local n = minetest.get_node(p)

			while n.name == 'vines:rope' or n.name == 'vines:rope_end' do

				minetest.remove_node(p)

				p = {x = p.x, y = p.y - 1, z = p.z}
				n = minetest.get_node(p)
			end
		end
	})

	minetest.register_node("vines:rope", {
		description = S("Rope"),
		walkable = false,
		climbable = true,
		sunlight_propagates = true,
		paramtype = "light",
		drop = {},
		tiles = {"vines_rope.png"},
		drawtype = "plantlike",
		groups = {flammable = 2, not_in_creative_inventory = 1},
		sounds = default.node_sound_leaves_defaults(),
		selection_box = {
			type = "fixed",
			fixed = {-1/7, -1/2, -1/7, 1/7, 1/2, 1/7},
		},
	})

	minetest.register_node("vines:rope_end", {
		description = S("Rope"),
		walkable = false,
		climbable = true,
		sunlight_propagates = true,
		paramtype = "light",
		drop = {},
		tiles = {"vines_rope_end.png"},
		drawtype = "plantlike",
		groups = {flammable = 2, not_in_creative_inventory = 1},
		sounds = default.node_sound_leaves_defaults(),

		after_place_node = function(pos)

			local yesh = {x = pos.x, y = pos.y - 1, z = pos.z}

			minetest.add_node(yesh, {name = "vines:rope"})
		end,

		selection_box = {
			type = "fixed",
			fixed = {-1/7, -1/2, -1/7, 1/7, 1/2, 1/7},
		},

		on_construct = function(pos)

			local timer = minetest.get_node_timer(pos)

			timer:start(1)
		end,

		on_timer = function( pos, elapsed )

			local p = {x = pos.x, y = pos.y - 1, z = pos.z}
			local n = minetest.get_node(p)

			if	n.name == "air" then

				minetest.set_node(pos, {name = "vines:rope"})
				minetest.add_node(p, {name = "vines:rope_end"})
			else

				local timer = minetest.get_node_timer(pos)

				timer:start(1)
			end
		end
	})
end

-- SHEARS

minetest.register_tool("vines:shears", {
	description = S("Shears"),
	inventory_image = "vines_shears.png",
	wield_image = "vines_shears.png",
	stack_max = 1,
	max_drop_level = 3,
	tool_capabilities = {
		full_punch_interval = 1.0,
		max_drop_level = 1,
		groupcaps = {
			snappy = {times = {[3] = 0.2}, uses = 60, maxlevel = 3},
		}
	},
})

-- VINES
local spawn_root_surfaces = {}

if enable_roots ~= false then
	spawn_root_surfaces = {
		"default:dirt_with_grass",
		"default:dirt"
	}

	vines.register_vine('root',
		{description = S("Roots"), average_length = 9}, {
		choose_random_wall = true,
		avoid_nodes = {"vines:root_middle"},
		avoid_radius = 5,
		surface = spawn_root_surfaces,
		spawn_on_bottom = true,
		plantlife_limit = -0.6,
		rarity = rarity_roots,
	--	humidity_min = 0.4,
	})
end

if enable_standard ~= false then
	vines.register_vine('vine',
		{description = S("Vines"), average_length = 5}, {
		choose_random_wall = true,
		avoid_nodes = {"group:vines"},
		avoid_radius = 5,
		surface = {
	--		"default:leaves",
			"default:jungleleaves",
			"moretrees:jungletree_leaves_red",
			"moretrees:jungletree_leaves_yellow",
			"moretrees:jungletree_leaves_green"
		},
		spawn_on_bottom = true,
		plantlife_limit = -0.9,
		rarity = rarity_standard,
	--	humidity_min = 0.7,
	})
end

if enable_side ~= false then
	vines.register_vine('side',
		{description = S("Vines"), average_length = 6}, {
		choose_random_wall = true,
		avoid_nodes = {"group:vines", "default:apple"},
		avoid_radius = 3,
		surface = {
	--		"default:leaves",
			"default:jungleleaves",
			"moretrees:jungletree_leaves_red",
			"moretrees:jungletree_leaves_yellow",
			"moretrees:jungletree_leaves_green"
		},
		spawn_on_side = true,
		plantlife_limit = -0.9,
		rarity = rarity_side,
	--	humidity_min = 0.4,
	})
end

if enable_jungle ~= false then
	vines.register_vine("jungle",
		{description = S("Jungle Vines"), average_length = 7}, {
		choose_random_wall = true,
		neighbors = {
			"default:jungleleaves",
			"moretrees:jungletree_leaves_red",
			"moretrees:jungletree_leaves_yellow",
			"moretrees:jungletree_leaves_green"
		},
		avoid_nodes = {
			"vines:jungle_middle",
			"vines:jungle_end",
		},
		avoid_radius = 5,
		surface = {
			"default:jungletree",
			"moretrees:jungletree_trunk"
		},
		spawn_on_side = true,
		plantlife_limit = -0.9,
		rarity = rarity_jungle,
	--	humidity_min = 0.2,
	})
end

if enable_willow ~= false then
	vines.register_vine( 'willow',
		{description = S("Willow Vines"), average_length = 9}, {
		choose_random_wall = true,
		avoid_nodes = {"vines:willow_middle"},
		avoid_radius = 5,
		near_nodes = {'default:water_source'},
		near_nodes_size = 1,
		near_nodes_count = 1,
		near_nodes_vertical = 7,
		plantlife_limit = -0.8,
		spawn_on_side = true,
		surface = {"moretrees:willow_leaves"},
		rarity = rarity_willow,
	--	humidity_min = 0.5
	})
end

print("[Vines] Loaded")
