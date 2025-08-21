-- SPDX-FileCopyrightText: 2024 DS
--
-- SPDX-License-Identifier: Apache-2.0

beds.register_bed("bed_rock:bed_rock", {
	description = "Bed-Rock", -- TODO: translate
	-- FIXME: bed_rock_invimg.png is ugly (looks flat)
	inventory_image = "bed_rock_invimg.png",
	wield_image = "bed_rock_invimg.png",
	sounds = default.node_sound_stone_defaults(),
	tiles = {
		bottom = {
			"default_stone.png",
			"default_stone.png",
			"default_stone.png",
			"default_stone.png",
			"blank.png",
			"default_stone.png"
		},
		top = {
			"default_stone.png^(beds_bed_top_top.png^[mask:bed_rock_pillowmask_top.png^[transformR90)",
			"default_stone.png",
			"default_stone.png^(beds_bed_side_top_r.png^[mask:bed_rock_pillowmask_side_r.png)",
			"default_stone.png^(beds_bed_side_top_r.png^[mask:bed_rock_pillowmask_side_r.png^[transformFX)",
			"default_stone.png^(beds_bed_side_top.png^[mask:bed_rock_pillowmask_side_top.png)",
			"beds_bed_side_top.png^[mask:bed_rock_pillowmask_side_top.png^[transformFX",
		},
	},
	nodebox = {
		bottom = {-0.5, -0.5, -0.5, 0.5, -3/16, 0.5},
		top = {
			{-0.5, -0.5, -0.5, 0.5, -3/16, 0.5},
			{-7/16, -3/16, 0, 7/16, 1/16, 7/16},
		},
	},
	selectionbox = {
			{-0.5, -0.5, -0.5, 0.5, -3/16, 1.5},
			{-7/16, -3/16, 1, 7/16, 1/16, 7/16+1},
	},
	recipe = {
		{"group:wool", "", ""},
		{"default:stone", "default:stone", "default:stone"}
	}
})

core.override_item("bed_rock:bed_rock_bottom", {
	groups = {cracky = 3, bed = 1},

	-- player lies lower than in normal bed
	on_rightclick = function(pos, _node, clicker, itemstack, _pointed_thing)
		beds.on_rightclick(pos, clicker)
		if not clicker or not clicker:is_player() then
			return itemstack
		end
		local bed_pos = beds.bed_position[clicker:get_player_name()]
		if not bed_pos then
			return itemstack
		end

		local node = core.get_node(bed_pos)
		if node.name ~= "bed_rock:bed_rock_bottom" then
			return itemstack
		end
		local param2 = node.param2 % 4 -- because of color param2 stuff
		local dir = core.facedir_to_dir(param2)
		local p = vector.offset(bed_pos, dir.x / 2, -0.2, dir.z / 2)
		clicker:set_pos(p)

		return itemstack
	end
})

-- FIXME: make it flammable, but only burn away the pillow
core.override_item("bed_rock:bed_rock_top", {
	groups = {cracky = 3, bed = 2, not_in_creative_inventory = 1},
})

-- hurt players that are lying in a bed rock on night skip
local old_skip_night = beds.skip_night
beds.skip_night = function(...)
	if not core.settings:get_bool("bed_rock.enable_sleep_damage", true) then
		return old_skip_night(...)
	end

	for _, player in ipairs(core.get_connected_players()) do
		local player_name = player:get_player_name()
		-- (hacky, beds.bed_position is not documented)
		local bed_pos = beds.bed_position[player_name]
		if bed_pos and core.get_node(bed_pos).name == "bed_rock:bed_rock_bottom" then
			-- player slept in bed rock. it hurts
			local hp = player:get_hp()
			hp = hp - math.random(2, 4)
			player:set_hp(hp, {from = "mod", type = "set_hp",
					set_hp_type = "bed_rock:bad_sleep", bed_pos = bed_pos})
		end
	end

	return old_skip_night(...)
end
