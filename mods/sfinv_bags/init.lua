--[[

Bags for Minetest

Copyright (c) 2012 cornernote, Brett O'Donnell <cornernote@gmail.com>
Original Source Code: https://github.com/cornernote/minetest-bags
License: BSD-3-Clause https://raw.github.com/cornernote/minetest-bags/master/LICENSE

Tweaked by TenPlus1 and Security improvements by Krock

]]--

-- translation and mod check

local S = core.get_translator("sfinv_bags")
local mod_def = core.get_modpath("default")

-- get bag inventory

local function get_player_bag_stack(player, i)

	return core.get_inventory({
		type = "detached",
		name = player:get_player_name() .. "_bags"
	}):get_stack("bag" .. i, 1)
end

-- hotbar helper

local function get_hotbar_bg()
	return ((mod_def and default.get_hotbar_bg(0, 5.2)) or "")
end

-- formspec

local function get_formspec(player, page)

	-- bags selection page
	if page == "bags" then

		local name = player:get_player_name()

		return "size[8,9]"
			.. "button[1,-0.4;3,3;bag1;" .. S("Bag") .. " 1]"
			.. "button[1,0.6;3,3;bag2;" .. S("Bag") .. " 2]"
			.. "button[1,1.6;3,3;bag3;" .. S("Bag") .. " 3]"
			.. "button[1,2.6;3,3;bag4;" .. S("Bag") .. " 4]"
			.. "list[detached:" .. name .. "_bags;bag1;6,0.5;1,1;]"
			.. "list[detached:" .. name .. "_bags;bag2;6,1.5;1,1;]"
			.. "list[detached:" .. name .. "_bags;bag3;6,2.5;1,1;]"
			.. "list[detached:" .. name .. "_bags;bag4;6,3.5;1,1;]"
			.. "image[4.5,0.5;1,1;sfinv_crafting_arrow.png]"
			.. "image[4.5,1.5;1,1;sfinv_crafting_arrow.png]"
			.. "image[4.5,2.5;1,1;sfinv_crafting_arrow.png]"
			.. "image[4.5,3.5;1,1;sfinv_crafting_arrow.png]"
			.. "list[current_player;main;0,5.2;8,1;]"
			.. "list[current_player;main;0,6.35;8,3;8]"
			.. get_hotbar_bg()
	end

	for i = 1, 4 do

		-- actual bag inventory
		if page == "bag" .. i then

			local image = get_player_bag_stack(player, i):get_definition().inventory_image

			return "size[8,9]"
				.. "list[current_player;bag" .. i .. "contents;0,0;8,4;]"
				.. "button[6,4.2.2;2,0.5;bags;" .. S("Main") .. "]"
				.. "image[3.5,4;1,1;" .. image .. "]"
				.. "list[current_player;main;0,5.2;8,1;]"
				.. "list[current_player;main;0,6.35;8,3;8]"
				.. get_hotbar_bg()
				.. "listring[current_player;main]"
				.. "listring[current_player;bag" .. i .. "contents]"
		end
	end
end

-- save bag inventories

local function save_bags_metadata(player, bags_inv)

	local is_empty = true
	local bags = {}
	local meta = player:get_meta()

	for i = 1, 4 do

		local bag = "bag" .. i

		if not bags_inv:is_empty(bag) then

			-- Stack limit is 1, otherwise use stack:to_string()
			bags[i] = bags_inv:get_stack(bag, 1):get_name()

			is_empty = false
		end
	end

	if is_empty then
		meta:set_string("bags:bags", nil)
	else
		meta:set_string("bags:bags", core.serialize(bags))
	end
end

-- load bag inventories

local function load_bags_metadata(player, bags_inv)

	local player_inv = player:get_inventory()
	local meta = player:get_meta()
	local bags_meta = meta:get_string("bags:bags")
	local bags = bags_meta and core.deserialize(bags_meta) or {}
	local dirty_meta = false

	if not bags_meta then

		-- Backwards compatiblity
		for i = 1, 4 do

			local bag = "bag" .. i

			if not player_inv:is_empty(bag) then

				-- Stack limit is 1, otherwise use stack:to_string()
				bags[i] = player_inv:get_stack(bag, 1):get_name()

				dirty_meta = true
			end
		end
	end

	-- Fill detached slots
	for i = 1, 4 do

		local bag = "bag" .. i

		bags_inv:set_size(bag, 1)
		bags_inv:set_stack(bag, 1, bags[i] or "")

		-- Deprecated, clean up garbage
		player_inv:set_size(bag, 0)
	end

	if dirty_meta then
		-- Requires detached inventory to be set up
		save_bags_metadata(player, bags_inv)
	end
end

-- setup bag inventory on player join

core.register_on_joinplayer(function(player)

	local player_name = player:get_player_name()
	local bags_inv = core.create_detached_inventory(player_name .. "_bags", {

		on_put = function(inv, listname, index, stack, player)

			player:get_inventory():set_size(listname .. "contents",
					stack:get_definition().groups.bagslots)

			save_bags_metadata(player, inv)
		end,

		allow_put = function(inv, listname, index, stack, player)

			if not stack:get_definition().groups.bagslots then
				return 0
			end

			if not player:get_inventory():is_empty(listname .. "contents") then
				return 0
			end

			return 1
		end,

		allow_take = function(inv, listname, index, stack, player)

			if player:get_inventory():is_empty(listname .. "contents") then
				return stack:get_count()
			end

			return 0
		end,

		on_take = function(inv, listname, index, stack, player)

			player:get_inventory():set_size(listname .. "contents", 0)

			save_bags_metadata(player, inv)
		end,

		allow_move = function(inv, from_list, from_index, to_list, to_index,
				count, player)
			return 0
		end,

	}, player_name)

	load_bags_metadata(player, bags_inv)
end)

-- register bags page

sfinv.register_page("sfinv_bags:bags", {

	title = S("Bags"),

	get = function(self, player, context)

		context.bagpage = context.bagpage or "bags"

		return sfinv.make_formspec(player, context, get_formspec(player, context.bagpage))
	end,

	on_player_receive_fields = function(self, player, context, fields)

		local name = player:get_player_name()

		if fields.bags then

			context.bagpage = "bags"

			sfinv.set_player_inventory_formspec(player, context)

			return
		end

		for i = 1, 4 do

			local page = "bag" .. i

			if fields[page] then

				local stack = get_player_bag_stack(player, i)

				if not stack:get_definition().groups.bagslots then
					page = "bags"
				end

				context.bagpage = page

				sfinv.set_player_inventory_formspec(player, context)

				return
			end
		end
	end
})

-- vegan leather and recipe

core.register_craftitem(":bags:leather", {
	description = S("Vegan Leather"),
	inventory_image = "bags_leather.png",
	groups = {leather = 8, flammable = 2},
})

core.register_craft({
	output = "bags:leather",
	recipe = {
		{"group:mushroom", "group:mushroom", "group:mushroom"},
		{"group:mushroom", "group:mushroom", "group:mushroom"},
		{"group:mushroom", "", "group:mushroom"}
	}
})

-- register bags items

core.register_craftitem(":bags:small", {
	description = S("Small Bag"),
	inventory_image = "bags_small.png",
	groups = {bagslots = 8, flammable = 2},
})

core.register_craftitem(":bags:medium", {
	description = S("Medium Bag"),
	inventory_image = "bags_medium.png",
	groups = {bagslots = 16, flammable = 2},
})

core.register_craftitem(":bags:large", {
	description = S("Large Bag"),
	inventory_image = "bags_large.png",
	groups = {bagslots = 24, flammable = 2},
})

core.register_tool(":bags:trolley", {
	description = S("Trolley"),
	inventory_image = "bags_trolley.png",
	groups = {bagslots = 32, flammable = 2},
})

-- use string if farming mod found, otherwise a stick will do
local string = core.get_modpath("farming") and "farming:string" or "group:stick"

-- register bag recipes

core.register_craft({
	output = "bags:small",
	recipe = {
		{"", string, ""},
		{"group:leather", "group:leather", "group:leather"},
		{"group:leather", "group:leather", "group:leather"}
	}
})

core.register_craft({
	output = "bags:medium",
	recipe = {
		{"", string, ""},
		{"bags:small", "bags:small", "bags:small"}
	}
})

core.register_craft({
	output = "bags:large",
	recipe = {
		{"", string, ""},
		{"bags:medium", "bags:medium", "bags:medium"}
	}
})

core.register_craft({
	output = "bags:trolley",
	recipe = {
		{"", string, ""},
		{"bags:large", "bags:large", "bags:large"}
	}
})

print ("[MOD] Sfinv Bags loaded")

-- command

core.register_chatcommand("sfinv_bag", {
	params = "<number>",
	description = "Quick Show SF Inventory Bag",
	privs = {interact = true},

	func = function(name, param)

		local player = core.get_player_by_name(name)

		if player == nil then return true end

		local num = tonumber(param)

		if not num then
			core.show_formspec(name, "", get_formspec(player, "bags"))
			return
		end

		local stack = get_player_bag_stack(player, num)

		if stack:get_definition().groups.bagslots then
			core.show_formspec(name, "", get_formspec(player, "bag" .. num))
		else
			return true, "Bag number does not exist!"
		end
	end
})
