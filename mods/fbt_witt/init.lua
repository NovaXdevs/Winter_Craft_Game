local modname = minetest.get_current_modname()
local modpath = minetest.get_modpath(modname)
dofile(modpath .. "/types.lua")


---@type table<string, PlayerWitt>
local players_data = {}

---@type MetaDataRef
local storage = minetest.get_mod_storage()
if storage:contains("players_data") then
  players_data = minetest.deserialize(storage:get_string("players_data"))
  minetest.log("action", "fbr_witt: data loaded.")
  -- minetest.log(dump(players_data))
else
  minetest.log("action", "fbr_witt: data not found.")
end

minetest.register_on_shutdown(function()
  storage:set_string("players_data", minetest.serialize(players_data))
  minetest.log("action", "fbr_witt: data saved.")
  -- minetest.log(dump(players_data))
end)


---@param player ObjectRef
local function spawn_hud(player)
  local player_name = player:get_player_name()
  local align = {x = -1, y = 1}
  local pos = {x = 1, y = 0}
  local text_pad = -68
  local line_height = 20
  local offset_x = -8
  local offset_y = 8

  local line_cou = 0

  ---@param color integer
  ---@return integer
  local function add_paragraph(color)
    local idx = player:hud_add{
      hud_elem_type = "text",
      text = "",
      number = color,
      position = pos,
      alignment = align,
      offset = {
        x = offset_x + text_pad,
        y = offset_y + line_height * line_cou,
      },
    }
    line_cou = line_cou + 1
    return idx
  end
  
  if players_data[player_name] == nil then
    players_data[player_name] = {
      enabled = true,
      show_objects = false,
      show_liquids = true,
      node_name = "",
    }
  end

  ---@type PlayerWitt
  local data = players_data[player_name]

  data.hud_bg = player:hud_add{
    hud_elem_type = "image",
    text = "fbt_witt_bg.png",
    position = pos,
    alignment = align,
    offset = {
      x = offset_x / 2,
      y = offset_y / 2,
    },
    scale = {x = 32, y = 4.5},
  }
  data.hud_name = add_paragraph(0xebdbb2)
  data.hud_modname = add_paragraph(0x8ec07c)
  data.hud_description = add_paragraph(0x83a598)
  data.hud_image = player:hud_add{
    hud_elem_type = "image",
    text = "",
    scale = {x = 1, y = 1},
    position = pos,
    alignment = align,
    offset = {
      x = offset_x,
      y = offset_y,
    },
  }
end


---@param player ObjectRef
local function update_hud(player)
  local player_name = player:get_player_name()
  local data = players_data[player_name]
  if data.node_name == "" then
    player:hud_change(data.hud_bg, "text", "")
    player:hud_change(data.hud_name, "text", "")
    player:hud_change(data.hud_modname, "text", "")
    player:hud_change(data.hud_description, "text", "")
    player:hud_change(data.hud_image, "text", "")
  else
    ---@type NodeDef
    local node_def = minetest.registered_nodes[data.node_name]

    local name = data.node_name
    local desc = node_def.description
    local short_desc = node_def.short_description
    local no_short_desc = fbt.nil_or_empty(short_desc)

    local info = minetest.get_player_information(player_name)
    local desc_tr = minetest.get_translated_string(info.lang_code, desc)
    local length = math.max(#name, fbt.utf8_len(desc_tr))
    -- if not no_short_desc then
    --   local short_desc_tr = 
    --   length = math.max(length, utf8_len(short_desc))
    -- end
    local padding = math.min(48, 4.5 + 0.515625 * length)
    player:hud_change(data.hud_bg, "text", "fbt_witt_bg.png")
    player:hud_change(data.hud_bg, "scale", {x = padding, y = 4.5})    

    if no_short_desc or short_desc == desc then
      player:hud_change(data.hud_name, "text", desc)
      player:hud_change(data.hud_description, "text", "")
    else
      player:hud_change(data.hud_name, "text", short_desc)
      player:hud_change(data.hud_description, "text", desc)
    end

    player:hud_change(data.hud_modname, "text", name)
    player:hud_change(data.hud_image, "text", fbt.node_icon(node_def))
  end
end


minetest.register_on_joinplayer(function(player)
  spawn_hud(player)
  update_hud(player)
end)

minetest.register_globalstep(function(dtime)
  for _, player in ipairs(minetest.get_connected_players()) do
    ---@type PlayerWitt
    local data = players_data[player:get_player_name()]
    if not data.enabled then return end

    local node = fbt.get_pointed_node(player, data.show_objects, data.show_liquids)
    if node == nil then
      data.node_name = ""
    else
      data.node_name = node.name
    end

    update_hud(player)
  end
end)


---@param command string
---@param description string
---@param field string
function register_toggle(command, description, field)
  minetest.register_chatcommand(command, {
    params = "[yes | no]",
    description = description,
    ---@param name string
    ---@param param string
    ---@return boolean
    func = function(name, param)
      ---@type ObjectRef
      local player = minetest.get_player_by_name(name)
      if not player then return false end
      ---@type PlayerWitt
      local data = players_data[name]
      data[field] = minetest.is_yes(param) or param == ""
      data.node_name = ""
      update_hud(player)
      return true
    end
  })
end

register_toggle("witt", "Whether to show WITT.", "enabled")
-- register_toggle("witt_objects", "Whether WITT should show objects.", "show_objects")
register_toggle("witt_liquids", "Whether WITT should show liquids.", "show_liquids")


