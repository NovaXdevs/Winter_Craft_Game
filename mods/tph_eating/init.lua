--[[
    Input-held Eating Mod for Minetest
    Copyright (C) 2025 TPH/TubberPupperHusker

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <https://www.gnu.org/licenses/>.
--]]
-- use new particle spawner features (5.6.0) or legacy
local v560 = core.features and (core.features.particlespawner_tweenable or core.features.get_sky_as_table or core.get_tool_wear_after_use) or
  false
-- eating_item_entity possible or false
local v540 = core.features and (core.features.direct_velocity_on_players and core.features.use_texture_alpha_string_modes) or
  false
-- numbers should be numbers
-- booleans should be booleans
-- strings should be strings
-- else you'll get an error!
tph_eating = {
    eating_time = 0.36,
    eating_repeats = 4,
    use_key = "RMB", -- SHOULD BE STRING TO INDEX PLAYER CONTROLS
    use_function = "on_secondary_use", -- SHOULD BE STRING TO INDEX ITEMS
    entity_use_function = "on_rightclick", -- SHOULD BE STRING TO INDEX ON REGISTERED ENTITES
    burping = true,
    burp_chance = 100,
    silly = false,
    eating_item_entity = v540, -- do not modify if v540 is not true
    -- DO NOT MODIFY (you'll get an error)
    min_eating_repeats = 2, -- minimum of 2
    v540 = v540, -- if 5.4.0+
    v560 = v560 -- if 5.6.0+
}
tph_eating.eating_sound = {
    name = "tph_eating_chew",
    gain = {0.25,0.32},
    pitch = {0.8,1.02}
}
tph_eating.slurp_sound = {
    name = "tph_eating_slurp",
    gain = {0.25,0.3},
    pitch = {0.95,1.1}
}
tph_eating.finished_sound = {
    name = "tph_eating_burp",
    gain = 0.35,
    pitch = {0.93,1.03}
}

-- for error handling
-- get current modname, but with handling for nil
local function get_cmn()
    return core.get_current_modname() or "unknown mod"
end

-- determine if place or dig
-- converts RMB to place, LMB to dig
-- otherwsie returns usual use_key
local function usekey_to_modern()
    return (tph_eating.use_key == "RMB" and "place" or
      tph_eating.use_key == "LMB" and "dig") or tph_eating.use_key
end
tph_eating.usekey_to_modern = usekey_to_modern

-- MISC API \/
tph_eating.creative_mode = core.settings:get_bool("creative_mode")
-- custom function for detecting if player is in creative
tph_eating.player_in_creative = function(player)
  -- get the player by name if string
  player = type(player) == "string" and core.get_player_by_name(player) or player
  if not core.is_player(player) then return false end -- not a player
  -- returns false if both incorrect, true if one is correct
  return core.check_player_privs(player, "creative") or tph_eating.creative_mode
end

-- for getting an edible item's definition
-- uses get_definition() for itemstacks
local function get_def(item)
  -- ensure getting a proper table lol
    item = type(item) == "table" and item.name or item
    -- return itemstack's get_definition
    if type(item) == "userdata" and type(item.get_definition) == "function" then
        return item:get_definition()
    end
    -- couldn't get a string to check
    if type(item) ~= "string" then return end
    return core.registered_items[item]
end

-- utilize singular number or randomized value
local function get_range(value)
    -- if value is a table and its index 1 and 2 are numbers then return a randomized value between them, otherwise return value
    return type(value) == 'table' and (tonumber(value[1]) and tonumber(value[2])) and
      (value[1]+math.random()*(value[2]-value[1]) ) or value
end

-- sound definition, target (pos or object)
local function play_sound(sdef,target)
    -- you gave me something that doesn't work
    if type(sdef) ~= "table" then
        error("tph_eating.play_sound: provided sound definition is not a table. Got type "..type(sdef)..
          ". Error caused by "..get_cmn())
    end
    local sname = sdef.name -- # permits using a table as so: sound_table = {name = "sound", 1 = {stuff}, 2 = {stuff} }
    -- if more than 1 playable sound
    if #sdef > 1 then
        local plysounds = {} -- playable sounds
        for _,sound in ipairs(sdef) do
            if type(sound) == "table" and (sound.name or sname) then
                plysounds[#plysounds + 1] = sound
            end
        end
        -- did not get proper sound defs
        if #plysounds < 1 then
            error("tph_eating.sound_play: numbered indexes detected in sound definition (other sounds to play?) "..
              "- however none of them are proper sound definitions! No name provided in sound definition or other numbered"..
              " indexes. Error caused by mod: "..get_cmn())
        end
        sdef = plysounds[math.random(1, #plysounds)]
        sname = sdef.name or sname
    end
    -- no name
    if type(sname) ~= "string" then
        error("tph_eating.sound_play: improper name provided for sound! Error caused by mod: "..get_cmn())
    end
    sname = sname:gsub(" ","") -- remove spaces
    if sname == "" then return end -- you didn't want to play this sound, ok..?
    -- prevent overwriting tables and apply modified name to prevent issues
    sdef = table.copy(sdef)
    sdef.name = sname
    -- verify or eliminate pos
    if type(target) == "table" then
        -- you want us to play to an entity table? aight...
        if type(target.object) == "userdata" then
            target = target.object
        else
            target = {x=tonumber(target.x), y=tonumber(target.y), z=tonumber(target.z)}
            target = (target.x and target.y and target.z) and target or nil
        end
    end
    if type(target) == "table" then
        sdef.pos = target
    elseif type(target) == "userdata" then
        sdef.object = target
    end
    -- automatically set each number table value (in case of future new values)
    for valuename,value in pairs(sdef) do
        if type(value) == "table" and tonumber(value[1]) and tonumber(value[2]) then
            sdef[valuename] = get_range(value)
        end
    end

    return core.sound_play(sname, sdef)
end
tph_eating.sound_play = play_sound

-- gets tph_eating-based information of an ItemStack
-- randomizes sound data according to provided ItemStack parameters and tph_eating settings
-- returns 4 values utilize by the eating function
local function get_eating_information(item, noerror)
    item = get_def(item)
    if not item and not noerror then
        error("tph_eating: Could not get eating information for "..tostring(item))
    end
    local eating_repeats = tonumber(item.tph_eating_repeats) or tph_eating.eating_repeats
    eating_repeats = math.max(eating_repeats,tph_eating.min_eating_repeats) -- keep above minimum
    local sounds = item.sounds
    -- eating sound (can be slurp if group specified)
    local esound = (item.groups and item.groups.tph_eating_drink) and tph_eating.slurp_sound or
      tph_eating.eating_sound
    local fsound = tph_eating.finished_sound -- finished sound
    -- permit functions for making sounds
    if type(sounds) == "table" then
        esound = (type(sounds.eating_chew) == "function" or type(sounds.eating_chew) == "table")
          and sounds.eating_chew or esound
        fsound = (type(sounds.eating_finished) == "function" or type(sounds.eating_finished) == "table")
          and sounds.eating_finished or fsound
    end
    -- # accepts getting a sound table from a function or table
    -- send item definition as argument
    esound = type(esound) == "function" and esound(item) or esound
    fsound = type(fsound) == "function" and fsound(item) or fsound
    -- default to table in times of no table
    esound = type(esound) == "table" and esound or {name = "tph_eating_chew"}
    fsound = type(fsound) == "table" and fsound or {name = "tph_eating_burp"}
    -- burping mechanics
    -- will be true if burping is false but the finished sound is not a burp sound
    local is_burping = tph_eating.burping == false and not fsound.name:match("burp") or tph_eating.burping
    -- possible for random chance :D (suggested by j0j0n4th4n on minetest forums)
    if is_burping and tph_eating.burp_chance ~= 100 then
        is_burping = tph_eating.burp_chance/100 -- burp chance mechanics (only ran if `burp_chance` is not equal to 100)
        is_burping = is_burping > math.random() -- if percetange is greater than random result
    end
    -- you don't like my burping lol, let's modify `esound` for a `fsound` if you didn't specify one
    if not is_burping then
        fsound = {
            name = esound.name,
            gain = esound.gain,
            -- table, number, or nil - depends on eating_sound
            pitch = type(esound.pitch) == "table" and {esound.pitch[1]*0.8, esound.pitch[1]*0.95} or
              type(esound.pitch) == "number" and esound.pitch * 0.85 or esound.pitch
        }
    end

    return {
        eating_repeats = eating_repeats,
        eating_sound = esound,
        finished_sound = fsound,
    }
end
tph_eating.get_eating_information = get_eating_information

-- local table to determine which players are eating
local players_eating = {}

-- get player eating data
local function get_eating_data(player)
    -- get player name if player
    player = type(player) == "string" and player or core.is_player(player) and player:get_player_name()
    return type(player) == "string" and players_eating[player]
end
tph_eating.get_player_eating_data = get_eating_data

local eating -- declare 'eating' so that 'clear_eating' can use it

-- remove player from table global of concurrent players indulging in food
-- player name (though can be actual player), hold `boolean`
local function clear_eating(pname, hold)
    -- get string
    pname = type(pname) == "string" and pname or core.is_player(pname) and pname:get_player_name()
    -- get player's eating data
    local data = get_eating_data(pname)
    if not data then return end
    if type(data.obj) == "userdata" then -- eating_item_entity is or was enabled and the player has an eating object, get rid of
        -- ensure player object for hud edit
        local plr = core.get_player_by_name(pname)
        if plr then
          -- return to prior wielditem hud state
            plr:hud_set_flags({wielditem = data.hud_wielditem or data.hud_wielditem ~= false and true})
        end
        data.obj:remove()
    end
    -- permit custom "hold" boolean to hold for a bit instead of deleting information
    -- only runs if iteration is over the eating repeats - and if both exist
    -- permits holding down use_key to eat again
    if hold and data.iteration and data.eating_info and data.eating_info.eating_repeats and
      data.iteration >= data.eating_info.eating_repeats then
        core.after(tph_eating.eating_time*2, function()
            local plr = core.get_player_by_name(pname)
            local data = get_eating_data(pname)
            -- ensure we have plr AND data
            if plr and data then
                -- refresh some stats
                data.iteration = 1
                data.hud_wielditem = nil
                data.item_pos = nil
                data.image_list = nil
                -- run eating again, use plr and get their wielded_item
                eating(plr, plr:get_wielded_item())
          end
      end)
    -- remove eating information
    else
        players_eating[pname] = nil
    end
end
-- allow mods to clear player eating
tph_eating.clear_eating = clear_eating

-- stop a player's nutritional indulgence
local function cease_eating(player)
    local data = get_eating_data(player)
    if data then
        data.force_finish = true
    end
end
-- allow mods to stop a player from eating
tph_eating.cease_eating = cease_eating

-- better automate compatibility supports
-- assumes eating function is on_use and that mod does not have any support of tph_eating
-- siic = "SaveItemStackInCreative" -- adds to the ItemStack prior to on_use function
-- addparams = table of params to add
local function automated_on_use_override(def,siic,addparams)
    -- will only accept valid definitions or their names (registered items)
    -- if a table;
    -- will only have an option to override sounds, tph_eating_image, and tph_eating_repeats - will not accept any other values
    def = get_def(def)
    if not def then return end
    -- explicitly said no editing lol
    if def.groups and def.groups.tph_eating_no_edit then return end
    -- only override if on_use is specified
    if type(def.on_use) == "function" then
        local old_use = def.on_use
        local newdef = {}
        newdef.on_use = false -- prevent usage of on_use
        -- adding to itemstack before consumption
        if siic then
            newdef.tph_eating_success = function(player, itemstack)
                if tph_eating.player_in_creative(player) then
                    itemstack:set_count(itemstack:get_count()+1)
                end
                return old_use(itemstack, player, {type="nothing"})
            end
        -- no modifications needed
        else
            newdef.tph_eating_success = function(player, itemstack)
                return old_use(itemstack, player, {type="nothing"}) end
        end
        -- addparams
        -- be sure to specify custom sounds, `tph_eating_image`, and `tph_eating_repeats` here!
        -- if a table, adds the contents of said table to the newdef's equivalent
        if type(addparams) == "table" then
            for name, data in pairs(addparams) do -- variable name, variable data
                -- find equivalent in old def
                -- only try to merge if a table
                if type(data) == "table" and type(def[name]) == "table" then
                    local olddata = table.copy(def[name])
                    -- mass replace or set
                    for index, value in pairs(data) do
                        olddata[index] = value
                    end
                    -- add to newdef
                    newdef[name] = olddata
                -- otherwise overwrite
                else
                    newdef[name] = data
                end
            end
        end
        -- now to override
        core.override_item(def.name, newdef)
        tph_eating.add_eating_hook(def.name)
    end
end
tph_eating.on_use_override = automated_on_use_override
-- MISC API /\

-- PRIMARY FUNCTIONS \/

-- MAIN EATING FUNCTION
eating = function(player, itemstack)
    -- you're no fun, you gave me a bad itemstack or player
    if type(itemstack) ~= "userdata" or not core.is_player(player) then
        return clear_eating(player)
    end
    -- initialization
    local pname = player:get_player_name()
    local data = players_eating[pname] or {}
    data.iteration = tonumber(data.iteration) or 1
    data.tool_def = data.tool_def or get_def(itemstack)
    -- can't be eating with no tooldef
    if not data.tool_def then return clear_eating(player) end
  -- tool def interactions
    -- images (set as table for more randomization/options)
    data.image_list = data.image_list or data.tool_def.tph_eating_image or data.tool_def.inventory_image
    -- try to get node tiles if no inventory_image
    -- if no tiles, then become UNKNOWN!
    data.image_list = data.image_list == "" and (data.tool_def.tiles or "unknown_item.png")
      or data.image_list
    -- allow getting node tiles if gotten string (likely tph_eating_image) equals "tiles"
    data.image_list = type(data.image_list) == "table" and data.image_list or
      type(data.image_list) == "string" and (data.image_list == "tiles" and data.tool_def.tiles or
      {data.image_list}) or nil
    -- get a new image every iteration
    data.image = data.image_list and data.image_list[math.random(1,#data.image_list)] or nil
    data.image = type(data.image) == "table" and data.image.name or data.image -- get any provided texture
    -- eating_info for getting stable _eating values
    data.eating_info = data.eating_info or tph_eating.get_eating_information(data.tool_def)
    local eating_time = tph_eating.eating_time
    local eating_repeats = data.eating_info.eating_repeats
    -- first time?
    if data.iteration == 1 then
        -- # clear_eating not necessary for returns since player has not yet been added to eating global
        -- custom function for specifying whether or not the eating should commence
        if type(data.tool_def.tph_eating_condition) == "function" and
          data.tool_def.tph_eating_condition(player, itemstack) ~= true then
            return
        end
        data.index = tonumber(data.index) or player:get_wield_index()
        -- allow for custom "eating_initiated" function to be defined upon eating start
        itemstack = type(data.tool_def.tph_eating_initiated) == "function" and
          data.tool_def.tph_eating_initiated(player, itemstack, data) or itemstack
        if type(itemstack) ~= "userdata" then
          -- no breaking allowed
            return
        end
    end
    -- wielded item and player's controls
    local w_item = player:get_wielded_item()
    local control = player:get_player_control()
    -- ate item fully (no item!), no longer eating or selecting food item, or dropped item
    if (itemstack:get_name() == "" or itemstack:is_empty()) or not control[tph_eating.use_key] or
      not (data.index or data.index ~= player:get_wield_index()) or
      data.tool_def.name ~= w_item:get_name() or data.force_finish then
        -- custom failed eat function
        if type(data.tool_def.tph_eating_failed) == "function" then
            data.tool_def.tph_eating_failed(player, itemstack, data)
        end
        return clear_eating(player)
    else
        -- update itemstack to wielded item
        itemstack = w_item
    end
    local itr_pos = player:get_pos() -- interaction pos
    if type(data.height) ~= "number" then
        local collbox = player:get_properties().collisionbox
        data.height = (collbox[2] + collbox[5])*0.67 -- height for where particles should be (67% of total player height)
    end
    -- # height can be set in tph_eating_ongoing if player's true height changes (such as in a chair or bed)
    -- spawn an entity infront of the player when they're eating (don't run code if someone unregistered the entity 3:<)
    -- only works 5.4.0+ (entity doesn't get registered on older versions)
    if tph_eating.eating_item_entity == true and core.registered_entities["tph_eating:eating_item"] then
        local function create_obj()
            -- allow players to specify an entity override for what will be shown as the item during consumption instead
            local usingstack = data.tool_def.tph_eating_itemstack_entity_override -- using itemstack
            if usingstack then -- verify if it's atleast an item, if not, revert
                usingstack = core.registered_items[usingstack] and usingstack or nil
            end
            return core.add_entity( {x=0,y=0,z=0},"tph_eating:eating_item",usingstack or itemstack:get_name() )
        end
        local function attach_obj()
            if data.obj then
                -- attach to player's "Head" bone, at item_pos, no rotation, allow being seen in first person
                data.obj:set_attach(player,"Head",data.item_pos,nil,true)
            end
        end
        -- add entity
        data.obj = data.obj or create_obj()
        data.item_pos = data.item_pos or {x=0,y=1,z=-3} -- modify this to create custom itemstack positions
        -- got an object now
        if data.obj then
            attach_obj()
            -- only run hud edit once
            if not data.hud_wielditem then
                data.hud_wielditem = data.hud_wielditem ~= false and player:hud_get_flags().wielditem
                player:hud_set_flags({wielditem = false}) -- make itemstack in hand disappear
            end
            -- chance of weird invisible item entity bug if this isn't done
            -- try 10 times to connect
            for i=1, 10 do
                if not data.obj:get_pos() then
                    data.obj:remove()
                    data.obj = create_obj()
                    attach_obj()
                end
            end
        end
    end
    -- code for eating particles
    if type(data.image) == "string" then
        local prtc_pos = {x=0,y=data.height*0.96,z=0.5} -- particle position
        if data.obj then
            -- prioritize setting particles to item entity
            prtc_pos = {x=0,y=0,z=0}
        end
        local bounds = 4 -- crop image bounds (X,Y), should not be lower than 1
        local prtc_amt = 2
        if (data.iteration + 1) >= eating_repeats then
            -- create more particles upon finishing
            prtc_amt = 6
        end

        local prtc_def = {
            pos = prtc_pos,
            attached = data.obj or player,
            time = (eating_time), -- last as long as it takes for a player to eat again
            amount = prtc_amt,
            collisiondetection = true,
            collision_removal = true,
            -- negative Z goes forwards from player
            vel = {min={x = -1.5, y = 1, z = -2},max={x = 1.5, y = 3.5, z = 0}  },
            acc = {x = 0, y = -11, z = 0},
            size = {min=0.5, max=1},
            vertical = true -- face player
            --glow = 5 -- makes particles not so dark at night lol
        }
        if not v560 then
            -- compatibility for v5.0.1 to before v5.6
            prtc_def.minpos = prtc_pos
            prtc_def.maxpos = prtc_pos
            prtc_def.minvel = prtc_def.vel.min
            prtc_def.maxvel = prtc_def.vel.max
            prtc_def.minacc = prtc_def.acc
            prtc_def.maxacc = prtc_def.acc
            prtc_def.minsize = prtc_def.size.min
            prtc_def.maxsize = prtc_def.size.max
        end

        for i = 1, 6, 1 do
            -- random bounds
            -- subtract 1 to prevent error on MT 5.9
            local rbounds = {math.random(0,bounds-1),math.random(0,bounds-1)}
            prtc_def.texture = data.image.."^[sheet:"..tostring(bounds).."x"..tostring(bounds)..":"..rbounds[1]..","..rbounds[2]
            core.add_particlespawner(prtc_def)
        end
    end
    -- finished eating
    if data.iteration >= eating_repeats then
        -- custom eating success function, sounds will have to be played in function
        local tempstack = type(data.tool_def.tph_eating_success) == "function" and
          data.tool_def.tph_eating_success(player, itemstack, data) or nil
        itemstack = type(tempstack) == "userdata" and tempstack or itemstack -- ensure we get a proper itemstack in return
        play_sound(data.eating_info.finished_sound, player)
        player:set_wielded_item(itemstack)
        return clear_eating(player, true)
    -- not done eating yet
    else
        -- do not run custom `tph_eating_ongoing` function if began eating
        if data.iteraton ~= 1 then
          -- custom function "tph_eating_ongoing" to run each time it iterates over eating, expects itemstack in return or nil
          itemstack = type(data.tool_def.tph_eating_ongoing) == "function" and
            data.tool_def.tph_eating_ongoing(player, itemstack, data) or itemstack
          -- # could add a custom eating animation, get time with tph_eating.eating_time
        end
        play_sound(data.eating_info.eating_sound, player)
    end
    -- ending iteration
    data.iteration = data.iteration + 1
    players_eating[pname] = data
    core.after(eating_time, eating, player, itemstack)
end
-- permits mods to use the eating function instead of using an eating hook
tph_eating.eating_func = eating

-- primary function for determining whether or not to eat food
-- expects on_secondary_use arguments
local function on_main_use(itemstack, user, pointed_thing, oldfunc)
    if type(itemstack) ~= "userdata" or type(user) ~= "userdata" then
        -- you did something bad
        return itemstack
    end
    -- run old function if applicable
    local use_result = type(oldfunc) == "function" and oldfunc(itemstack, user, pointed_thing) or nil
    if core.is_player(itemstack) then -- itemstack arg is player
        local temp = user
        user = itemstack
        itemstack = temp
    end
    -- if old function returns something that exists but doesn't equal itemstack then return
    if use_result ~= nil and use_result ~= itemstack then
        return itemstack
    end
    -- pointing at an entity with an on_rightclick function
    if type(pointed_thing) == "table" and pointed_thing.ref then
        local entity = pointed_thing.ref:get_luaentity()
        if entity then
            local entity_use_function = entity[tph_eating.entity_use_function]
            -- entity has a function according to entity_use_function, send stuff to it! (self, player, itemstack, pointed_thing)
            if type(entity_use_function) == "function" then
                local stored_stack = ItemStack(itemstack:to_string())
                use_result = entity[tph_eating.entity_use_function](entity, user, itemstack, pointed_thing)
                -- we got an itemstack return, compare!
                if type(use_result) == "userdata" and use_result["get_name"] and use_result["get_count"] then
                    if use_result:get_name() ~= stored_stack:get_name() or use_result:get_count() ~= stored_stack:get_count() then
                        return use_result
                    end
                elseif use_result ~= false then
                    return itemstack
                end
            end
        end
    end
    -- check if we're not eating currently
    local data = get_eating_data(user)
    if not data then
        eating(user, itemstack)
    -- noted a weird issue happening in Ex-E (Exiled From Other Servers, Mantar's Exile v4)
    -- where players were simply unable to eat...
    -- wonder if this fixes it?
    elseif data and not data.obj then
        clear_eating(user)
        eating(user, itemstack)
    end
    return itemstack
end
tph_eating.on_main_use = on_main_use

-- this will automatically add proper usage of the eating_func function
-- will not touch tph_eating_no_edit items
function tph_eating.add_eating_hook(item,forcereplace,success_function)
    item = get_def(item)
    -- can't modify
    if not item then return end
    -- told not to modify
    if item.groups and item.groups.tph_eating_no_edit then return end
    -- get old functions to run
    local oldfunc = item[tph_eating.use_function]
    local node_oldfunc = item["on_place"]
    -- touch(screen) interaction
    local ti = item.touch_interaction
    ti = type(ti) == "table" and table.copy(ti) or {}
    -- convert into a table for our purposes
    if type(ti) == "string" then
        ti = {
            pointed_node = ti,
            pointed_object = ti,
            pointed_nothing = ti
        }
    end
    -- for mobile support with RMB
    ti.pointed_nothing = usekey_to_modern() == "place" and
      "short_dig_long_place" or ti.pointed_nothing -- default to anything that was there before
    if not next(ti) then ti = nil end -- clear out touch_interaction value if it doesn't contain anything
    -- override time
    core.override_item(item.name,{
        [tph_eating.use_function] = function(itemstack, player, pointed_thing)
            -- 4th parameter being previous old function, if forcereplace then do not use
            return on_main_use(itemstack, player, pointed_thing, (not forcereplace) and oldfunc)
        end,
        tph_eating_success = type(success_function) == "function" and success_function or
          item.tph_eating_success, -- should be nil, but just in case you did specify it
        -- touch(screen) interaction
        touch_interaction = ti
    })
end
-- PRIMARY FUNCTIONS /\

-- METATABLE \/

local registered_callbacks
registered_callbacks = {
    setting_changed = {}, -- table of functions
    -- ran whenever a value inside `tph_eating` is modified
    setting_changed_func = function(key, value, oldvalue)
        for _,func in ipairs(registered_callbacks.setting_changed) do
            func(key, value, oldvalue)
        end
    end
}

-- API function that lets functions detect when something's been changed
function tph_eating.register_on_setting_changed(func)
    if type(func) == "function" then
        local setchange = registered_callbacks.setting_changed
        setchange[#setchange + 1] = func
    else
        error("tph_eating: attempt to register_on_setting_changed non-function type "
          ..type(func).." from mod: "..get_cmn())
    end
end

local VPC = { -- valid player controls
    up = true, down = true, left = true, right = true, jump = true, aux1 = true, sneak = true,
    dig = true, place = true, LMB = true, RMB = true, zoom = true
}
-- custom functions for when an index is modified
local writingchecks = {
    eating_time = function(value)
        value = tonumber(value)
        if type(value) ~= "number" then
            error("tph_eating: attempt to modify eating_time with a non-number type "..type(value)..
              ". Blocked write from mod: "..get_cmn())
        end
        return math.max(value, 0.001) -- ensure above 0.001
    end,
    -- ensure we got a proper use_key for usage
    use_key = function(value)
        if type(value) ~= "string" then
            error("tph_eating: attempt to write to 'use_key' with non-string type "..type(value)..
              ". Blocked write from mod: "..get_cmn())
        end
        value = value:lower() -- sanitize to lowercase for easier debugging
        -- uppercase LMB and RMB, but if v540+, convert to dig and place respectively
        value = value == "lmb" and (v540 and "dig" or "LMB") or
          value == "rmb" and (v540 and "place" or "RMB") or value
        if not VPC[value] then
            error("tph_eating: "..value.." is not a proper player control value. Blocked write from mod: "..
              get_cmn())
        end
    end,
    use_function = function(value)
        if type(value) ~= "string" then
            error("tph_eating: attempt to write to 'use_function' with non-string type "..type(value)..
              ". Blocked write from mod: "..get_cmn())
        end
        -- autoset RMB or LMB depending on the function name
        if value == "on_use" then
            tph_eating.use_key = "LMB"
        elseif value == "on_secondary_use" then
            tph_eating.use_key = "RMB"
        end
    end,
    -- 0 to 100 only
    burp_chance = function(value)
        value = tonumber(value)
        if type(value) ~= "number" then
            error("tph_eating: attempt to modify burp_chance with a non-number type "..type(value)..
              ". Blocked write from mod: "..get_cmn())
        end
        -- clamp between 0 and 100
        return math.min(math.max(value, 0), 100)
    end,
    -- only if lower than v540
    eating_item_entity = not (v540 or v560) and function(value)
        if value == false then return end -- already false, no point to modifying or causing error
        core.log("error",
          "tph_eating: cannot write to 'eating_item_entity' due to incompatibile version. Blocked attempt from mod: "..
          get_cmn())
        return false
    end or nil,
}

-- requirement of originals or preventing write
do
    -- no overriding these
    local unwritables = {min_eating_repeats = true, v540 = true, v560 = true}
    -- have it so rewriting variables to anything but their original type causes error
    local function writeerror(var, oftype)
        -- make an error message
        return function(value)
            if type(value) ~= oftype then
                -- e.g:
                -- tph_eating: attempted write of `type` `variablename` to non- `type`. Blocked write from mod: `modname`
                error("tph_eating: attempted write of "..oftype.." '"..var.."' to non-"..
                  oftype.." type "..type(value)..". Blocked write from mod: "..get_cmn())
            end
        end
    end
    for name,var in pairs(tph_eating) do
        -- and if not in writingchecks already
        if not writingchecks[name] then
            -- needs to prevent overwriting
            if unwritables[name] then
                writingchecks[name] = function(value)
                    error("tph_eating: blocked attempt from mod '"..get_cmn()..
                      "' to write to "..name..". Not permitted to overwrite.")
                end
            -- can be overwritten, but must be the same type
            else
                local gottype = type(var)
                -- not for any of our tables lol
                if var ~= "table" then
                    writingchecks[name] = writeerror(var, gottype)
                -- soundspecs: tables or functions with a string exception
                elseif name:match("_sound") then
                    writingchecks[name] = function(value)
                        value = type(value) == "string" and {name=value} or value
                        if not (type(value) == "table" or type(value) == "function") then
                            error("tph_eating: '"..name.."' must be a table, function, or string. Got incompatible type "..
                              type(value)..". Blocked write from mod: "..get_cmn())
                        end
                        return value
                    end
                end
            end -- not an unwritable
        end -- writing checks
    end
end

-- save a copy of all variables locally
local moddata = table.copy(tph_eating)
-- metatable it!!!
tph_eating = setmetatable({}, {
    __index = function(data, key)
        return moddata[key]
    end,
    __newindex = function(data, key, value)
        local oldvalue = moddata[key]
        if type(oldvalue) == "nil" then -- no writing to this mod with unique values
            return core.log("warning", "tph_eating: attempted to add "..type(value).." type '"..tostring(key)..
              "' to tph_eating global. Blocked write from mod: "..get_cmn())
        end
        if type(value) == "nil" then return end -- can't set to nil
        local checkfunc = writingchecks[key]
        if checkfunc then
            value = checkfunc(value) or value -- return nil to not modify
        end
        if oldvalue == value then return end -- don't modify something that's already been modified
        moddata[key] = value
        registered_callbacks.setting_changed_func(key, value, oldvalue)
    end,
    -- requires https://content.luanti.org/packages/TPH/metatable_metamethods/
    __pairs = function(t)
        return pairs(moddata)
    end,
    -- no ipairs needed
    -- prevent metatable overwrite
    __setmetatable = function(t, met)
        return false
    end
})

-- METATABLE /\

-- setting settings
local function set_settings()
    tph_eating.burping = core.settings:get_bool("tph_eating.burping",tph_eating.burping)
    tph_eating.silly = core.settings:get_bool("tph_eating.silly",tph_eating.silly)
    tph_eating.burp_chance = tonumber(core.settings:get("tph_eating.burp_chance")) or tph_eating.burp_chance
    -- only set if compatible
    if v540 then
        tph_eating.eating_item_entity = core.settings:get_bool("tph_eating.eating_item_entity",tph_eating.eating_item_entity)
    end
end
set_settings() -- set initially (prior to mod load)


-- run mod support code on register_on_mods_loaded
core.register_on_mods_loaded(function()
    -- MOD SUPPORT
    dofile(core.get_modpath("tph_eating").."/compatibilities.lua") -- run compatibility
    -- set again after mod load - players deserve what they want!
    set_settings()
end)

-- do not register entity if version is older than 5.4.0
if v540 then
    -- check tph_eating.eating_item_entity for whether or not this gets used. Gets defined regardless of false or true
    core.register_entity("tph_eating:eating_item",{
        initial_properties = {
            pointable = false,
            physical = false,
            static_save = false, -- I erase upon chunk unloading
            makes_footstep_sound = false,
            visual = "wielditem",
            visual_size = {x = 0.17, y = 0.17},
        },
        on_activate = function(self, staticdata, dtime_s)
            -- I have no texture and so I don't want to spawn
            if staticdata == "" then
                return self.object:remove()
            end
            local props = self.object:get_properties()
            props.wield_item = staticdata
            self.object:set_properties(props)
        end,
    })
    -- for v540+
    -- set RMB to place
    if tph_eating.use_key == "RMB" then tph_eating.use_key = "place" end
    -- LMB to dig
    if tph_eating.use_key == "LMB" then tph_eating.use_key = "dig" end
end