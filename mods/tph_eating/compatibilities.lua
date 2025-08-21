--[[
    Input-held Eating Mod for Exile
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
-----------------------------------

--[[

/!\ THIS CODE IS INTENDED TO BE RAN VIA DOFILE() ON A REGISTER_ON_MODS_LOADED /!\

this behaviour should NOT be modified

--]]

-- add mod-specific edible and drink groups to item
local function add_to_groups(grps, liquid)
    grps = grps and table.copy(grps) or {}
    grps.tph_eating_edible = 1
    -- slurp sounds
    -- have it so `get_eating_information` checks for a specified group
    if liquid then
        grps.tph_eating_drink = 1
    end
    return grps
end
-- slurp sounds
-- have it so `get_eating_information` checks for a specified group
local function add_slurp_sounds(def)
    local grps = def.groups and table.copy(def.groups) or {}
    grps.tph_eating_drink = 1
    core.override_item(def.name, {groups = grps})
end

local supgames = { -- support games
    -- minetest game, mesecraft
    default = core.get_modpath("default"),
    -- Mantar's Exile
    exile = core.get_modpath("health") and core.get_modpath("minimal")
}
-- only Exile v4 has the mapchunkp shepherd
supgames.exilev4 = supgames.exile and core.get_modpath("mapchunk_shepherd") -- Exile v4

-- set stuff according to supported games
if supgames.exile then
    tph_eating.burping = false
    if supgames.exilev4 then
        -- v4 SETTINGS -------------------------------
        tph_eating.use_function = "_on_use_item"
        tph_eating.use_key = "aux1"
        -------------------------------------------
    end
end

-- the below is used to skip certain checks
-- games will have a unique check
-- if a part of a game
local game_mods = {}
-- while mods will have a general and more extensive check
-- if a part of a mod
local mod_mods = {}
-- can't figure it out wtf
local cantfigureitout = {}

local function get_mod_origin(def)
    local mod = def.mod_origin
    -- we know what mod you are, default :rollingeyes:
    return mod == "??" and def.name:match("default:") and "default" or mod
end

local miscsearch
miscsearch = {
    -- CUCINA VEGANA WHY!!!!!!
    ungroupedliquid = {"milk","cup","hollandaise","soup","potion","bottle_honey","beer","porridge","tea","fondue","puree",
      "sauce","jcu_","latte"},
    is_edible = function(def)
        -- the whole purpose of our existence is consumption
        if core.serialize(def.on_use):match("do_item_eat") then
            return true
        end
        -- ugh, no group organization!
        local name = def.name
        local mdo = def.mod_origin
        -- groups
        local grps = def.groups or {}
        -- edible
        if grps.edible or grps.eatable then return true end
        -- why do these HAVE `food_egg` when they're not even a food!
        if grps.food_egg and (mdo == "animalia" or mdo == "mobs_animal") then
            if name:match("fried") then return true end -- return true if fried
            return false -- false otherwise
        end
        -- these checks shouldn't be ran after this
        -- basically checks if an item has a specified group that contains "food" in its name
        for gname,_ in pairs(def.groups) do -- group name
            -- add type check in case a programmer makes a numbered group for some reason (is that possible???)
            if type(gname) == "string" and gname:match("food") then
                return true
            end
        end
        -- why no pizza slice group???
        if mdo == "jelys_pizzaria" and name:match("slice") then
            return true
        elseif mdo == "bbq" and (name:match("sugar") or not grps.vessel) then
            return true
        elseif mdo == "large_slugs" and name:match("cooked") or
          def.mod_origin == "pumpkinspice" and name:match("cake") or
          def.mod_origin == "icecream" then
            return true
        -- idk why moretrees doesn't use any groups at all
        elseif name == "moretrees:date" or
          -- OR TENPLUS'S FARMING REDO!!!
          name == "farming:flan" then
            return true
        end
    end,
    is_drink = function(def)
        local grps = def.groups or {} -- minetest doesn't fill in with an empty groups table.......
        if grps.drink or grps.food_milk or grps.food_milk_glass or grps.food_coconut_milk or grps.food_water or
          grps.food_mayonnaise or grps.food_soup or grps.food_drink or grps.food_oil
          -- Wuzzy why you no groups AAAA
          or def.mod_origin == "pep" then
            return true
        end
        -- mods don't specify groups... EVEN FOR LIQUIDS? ugh! let's take a look
        local name = def.name
        -- dad's bbq is a NIGHTMARE
        if def.mod_origin == "bbq" and (name:match("brush") or name:match("spatula") or
          name:match("sugar") or name:match("steak")) then
            return -- not a liquid
        elseif def.mod_origin == "cucina_vegana" and (grps.food_berry or
          def.name == "cucina_vegana:salad_hollandaise") then
            return -- ditto
        -- not every honey related thing is drinkable, but cucina vegana certainly makes that harder 3;<
        elseif def.mod_origin == "cucina_vegana" and (grps.honey or grps.food_honey) then
            return true
        elseif def.mod_origin == "pumpkin_pies" and name:match("mix") then
           return true
        end
        for _,ungrouped in pairs(miscsearch.ungroupedliquid) do
            -- matches predetermined list of names
            if name:match(ungrouped) then
                return true
            end
        end
    end
}

-- returns if should be liquid as well
-- true/false (edible), true/nil (liquid), number/table/nil (food value)
local function is_edible(def)
    local name = def.name
    local groups = def.groups or {}
    -- mod checking
    local mod = get_mod_origin(def)
    local is_gamemod, is_modmod = game_mods[mod] and true, mod_mods[mod] and true
    -- not added to lists yet
    if not (is_gamemod or is_modmod) and not cantfigureitout[mod] then
        -- let's deciper if we're from a game or from a mod
        local modpath = core.get_modpath(mod)
        if modpath then
            modpath = modpath:split("\\") -- split into edible parts
            for _,pathpart in ipairs(modpath) do -- index part, path part
                -- from a game
                if pathpart == "games" then
                    is_gamemod, game_mods[mod] = true, true
                    break
                -- from a mod
                elseif pathpart == "mods" then
                    is_modmod, mod_mods[mod] = true, true
                    break
                end
            end
        -- HUH how did we NOT get a modpath???
        -- must be *builtin* !
        else
            cantfigureitout[mod] = true
        end
    end
    -- now to figure out what we're doing
    -- modifying default
    if supgames.default then
        if name=="default:apple" or name=="default:blueberries" or name=="farming:bread" or
          name=="flowers:mushroom_red" then
            return true
        elseif tph_eating.silly then
            if name=="default:diamond" then return true, nil, 10 end
            if name=="default:gold_ingot" then return true, nil, 5 end -- butter
            if name=="default:mese_crystal" then return true, nil, 15 end
        end
    end
    -- exile on
    if supgames.exile then
        local lookthrough = supgames.exilev4 and HEALTH.food_table or food_table
        if groups.edible == 2 then
            return true, (groups.drink or groups.soup or name == "tech:soup"), "playermade"
        elseif lookthrough[name] or (name == "tech:tiku" or name == "tech:herbal_medicine") then
            return true, (groups.drink or def.mod_origin == "tech" and name:match("tang"))
        end
    -- other stuff ... insanity !!
    else
        local edible = miscsearch.is_edible(def)
        local liquid = miscsearch.is_drink(def)
        edible = liquid and true or edible
        if not edible then return end -- not edible, begoneth!
        return edible, liquid
    end
    
end

-- only converts if edible
local function convert_is_edible(def)
    local edible, liquid, fv = is_edible(def) -- edible, liquid, foodvalue
    if not edible then return end
    local name = def.name
    local groups = add_to_groups(def.groups, liquid)
    core.override_item(name, {groups = groups})
    if groups.tph_eating_no_edit then return end -- no editing beyond groups!
    -- me and the boys like the Exile
    if supgames.exile then
        local old_use_name = supgames.exilev4 and tph_eating.use_function or "on_use"
        local old_use = def[old_use_name]
        local modify_old_use = false
        -- used for snow lol
        if supgames.exilev4 and name == "nodes_nature" then
            modify_old_use = function(player, wielded_item, pointed_thing)
                if pointed_thing and pointed_thing.type == "node" then
                    return minimal.slabs_combine(player, wielded_item, pointed_thing,
                      "nodes_nature:snow_block")
                -- not currently eating
                elseif not tph_eating.get_player_eating_data(player) then
                    tph_eating.eating_func(player, wielded_item)
                end
            end
        end
        -- v3 will run this
        local eating_func = function(player, itemstack)
            return old_use(itemstack, player, {type="object",ref=player})
        end
        -- modify eating func if exile v4
        if supgames.exilev4 then
            if name:match("nebiyi") or name:match("marbhan") then
                eating_func = function(player, itemstack)
                    return old_use(player, itemstack)
                end
            -- does not come with a predetermined on_use function, act as one
            -- edible of 2 means playermade
            elseif groups.edible == 2 then
                eating_func = function(player, itemstack)
                    return HEALTH.eatdrink_playermade(itemstack, player)
                end
            -- regular food
            else
                eating_func = function(player, itemstack)
                    return HEALTH.eatdrink(itemstack, player)
                end
            end
        end
        local addgroups = add_to_groups(def.groups, liquid)
        -- override item
        core.override_item(name, {
            [old_use_name] = modify_old_use,
            tph_eating_success = eating_func,
            groups = addgroups
        })
        -- add finalizing hook
        return tph_eating.add_eating_hook(name, supgames.exilev4 and not modify_old_use)
    -- custom item_eat amount
    elseif type(fv) == "number" then
        groups.item_eat = fv
        core.override_item(name,{
            groups = groups, -- update groups
            on_use = false,
            tph_eating_success = function(player, itemstack)
                return core.item_eat(fv)(itemstack, player)
            end
        })
        return tph_eating.add_eating_hook(name)
    end
    -- other stuff
    tph_eating.on_use_override(def, true)
end

-- code is ran on dofile after mods loaded, so we don't need to add this to said function
-- check through game compatibilities before mod compatibilities
for _, item in pairs(core.registered_items) do
    convert_is_edible(item)
end