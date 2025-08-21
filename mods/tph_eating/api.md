# API
This file contains information about the near-limitless functionality that can be sought with `tph_eating`, and how one can utilize them to the best of their ability! From custom item callbacks to changing how the mod handles things globally.



## Important to note ##
The naming of fields in items were changed from `_eating_(name)` to `tph_eating_(name)` in release 1.9



## Groups

`tph_eating` provides three different groups that can be checked for:

- * `tph_eating_edible` (introduced 1.11)

This lets you know that the item has been marked as a consumable.

:: Not to be fully trusted as the mechanisms for determining what and what isn't edible are dependent on what mods provide - and leads to me needing to make a very convoluted methodology - that could be simplified if folk just used `edible` as a group... This group of mine existing hopefully will make it easier for you despite its occasional misjudgements.

- * `tph_eating_drink` (introduced 1.11)

This lets you know that the item has been marked as a consumable drink. This is used by `tph_eating.get_eating_information` to determine whether or not to use `tph_eating.slurp_sound`.

:: Prior to the introduction of this group - slurp sounds were added directly to items under `sounds.eating_chew`.

- * `tph_eating_no_edit` (introduced 1.9)

This prevents compatibilities.lua from using `tph_eating.add_eating_hook` onto your item. For example if you've already set up support with my mod - and you don't want my mod obliterating your changes lol

:: checked in `tph_eating.on_use_override` and `tph_eating.add_eating_hook`



# API global settings (under `tph_eating`)

:## these will throw errors if you attempt to set an unsupported `type` ##

:: supported types are listed after the names, e.g: `eating_time (number)`

:: some types can have multiple supported, `eating_sound (table/function)`



* `eating_time` (number)

how many seconds it takes between each nom.

Minimum of `0.001`sec. Default is `0.36`sec


* `eating_repeats` (number)

How many times it repeats the eating() function.

Minimum of `tph_eating.min_eating_repeats` (see `API variables`). Default is `4`

Item variable equivalent: `item.tph_eating_repeats`


* `use_key` (string)

The player control key inspected per eating iteration (to check if the player is holding it down).

Default is `RMB`

:: this MUST be a detectable variable in `player:get_player_control`, otherwise throws error (checked under the `VPC (valid player controls)` table in init.lua)
:: not case sensitive - so you can provide "rmb" or "rMb" without issue


* `use_function` (string)

The name of the function that should be replaced by an eating hook in item definitions. Used to run the previous item's function in `tph_eating.add_eating_hook` if `forcereplace` is not true

Default is `on_secondary_use`


* `entity_use_function` (string)

Basically like `tph_eating.use_function`, except this is used by the eating hook to determine if it should prioritize interacting with the entity first instead of eating. Checks entity's registration and runs the function.

Default is `on_rightclick`


* `burping` (boolean)

Determines whether or not to play `tph_eating.finished_sound` or `item.sounds.eating_finished`.

Default is `true`

:: only affects sounds with "burp" in their name


* `burping_chance` (number)

A number between 0 and 100. Does a random percentage check for whether or not to play `tph_eating.finished_sound`or `item.sounds.eating_finished`.

Default is `100`

:: Like the `tph_eating.burping` boolean, only affects sound with "burp" in their name


* `silly` (boolean)

Whether or not it should add eating functions for items that should otherwise not be edible (support for MTG only in compatibilies.lua). This should be checked by mods or games using `tph_eating` if they wish to implement funny editions.

Default is `false`

:: this should be checked on `register_on_mods_loaded` with appropriate overrides applied


* `eating_item_entity` (boolean)

Whether or not to display an entity in front of the player's face. `true` shows the entity while `false` hides it.

Default is `true`

:: If your Minetest version is less than `5.4.0`, this is forced to be `false`. It won't throw a crash if you attempt to write to it - but it will throw an error message into chat



# API sounds (under `tph_eating`)

These can be string (for name, although this feature is not recommended to be used), table, or function. Expected default is table.

Permits randomization between two numbers for fields. E.g: `pitch = {0.8, 1.1}`.

Permits both `soundspec` and sound `parameters` fields.

For function argument, is provided with the definition of the item being consumed.

:## functions NEEDS to return a table with at least a `name` string and tables need a `name` string. ##:


* `eating_sound` (table/function/string)

The intermittent sound for each eating iteration except for the final one. AKA the "nomming" or "chewing" sound.

Default is a table with `name = "tph_eating_chew"`. Can be a function that returns said table `tph_eating.eating_sound(item)` - `item` being the current item being consumed, or a string for the name of the sound.

Item variable equivalent: `item.sounds.eating_chew` (string NOT supported for item variables)


* `slurp_sound` (table/function/string)

Like `tph_eating.eating_sound`, but for items with the `tph_eating_drink` group without a `item.sounds.eating_chew` specified.

Default is a table with `name = "tph_eating_slurp"`. Can be a function that returns said table `tph_eating.slurp_sound(item)` - `item` being the current item being consumed, or a string for the name of the sound.


* `finished_sound` (table/function/string)

The sound that plays on the final iteration of consumption. AKA that burp sound!

Default is a table with `name = "tph_eating_burp"`. Can be a function that returns said table `tph_eating.finished_sound(item)` - `item` being the current item being consumed, or a string for the name of the sound.

Item variable equivalent: `item.sounds.eating_finished` (string NOT supported for item variables)

:: as mentioned in `tph_eating.burping` and `tph_eating.burp_chance`, this is ONLY affected if by those settings if the name contains "burp"




# API variables (under `tph_eating`)

:## these variables can NOT be written to - and if written to - will throw a crashing error. ##


* `min_eating_repeats`

The minimum amount of eating repeats that can be derived from`tph_eating.eating_repeats` and `item.tph_eating_repeats`. Utilized in `tph_eating.get_eating_information`


* `v540`

`true` or `false` depending on if Minetest 5.4.0 is detected. Utilized to check for if `tph_eating.eating_item_entity` should be false and to adjust a `tph_eating.use_key` of `RMB` or `LMB` to `place` and `dig` respectively


* `v560`

`true` or `false` depending on if Minetest 5.6.0 is detected. Utilized to check whether or not to use legacy or 5.6.0+ particle emitter fields



# Custom Itemstack Fields

Fields that let you customize how each itemstack is consumed. Changing the speed, how the item looks, and even modifying what particles show!

* `tph_eating_image` (string/table)

What image should be used instead of an ItemStack's `inventory_image` or node's `tiles` for consumption particles

If string, should be an appropriate file type (used by Luanti engine, e.g. `.png`)

Can be a table of strings with appropriate file types (randomly chosen)

If named "tiles" (`tph_eating_image = "tiles"`), then will use the node's tiles if they exist, instead of `inventory_image`


* `tph_eating_repeats` (number)

Item equivalent of `tph_eating.eating_repeats`. What alternative amount of repeats to do instead of the current global.


* `tph_eating_itemstack_entity_override` (string)

Name of an available registered item to use as an eating model instead for the itemstack entity (what will show particles coming out of, what will be animated infront of the player)

:: requires `tph_eating.eating_item_entity` to be true, otherwise is unused

:: does not influence item field `tph_eating_image`



## Itemstack Sound Fields

To be put into an item definition's `sounds` table

* `sounds.eating_chew` (table/function)`

Item equivalent of `tph_eating.eating_sound` - maintaining nearly the same functionality.

:: does not permit `string` for name unlike the global


* `sounds.eating_finished` (table/function)`

Item equivalent of `tph_eating.finished_sound` - maintaining nearly the same functionality.

:: does not permit `string` for name unlike the global



## Custom Itemstack Callbacks

Functions that can be called by the API for specific items.

`player` parameter will be a player object and the `itemstack` parameter will be an ItemStack.

:: All item callbacks excluding `tph_eating_success` are not required to be defined for proper functionality. `tph_eating_success` is automatically defined for items if item is ran with `tph_eating.add_eating_hook` or `tph_eating.on_use_override`


* `tph_eating_condition(player, itemstack)`

If specified, expects boolean return of `true` to continue with eating, otherwise will suspect `false` and will not proceed with eating.

Use this to determine whether or not a player should begin to eat (too full, unable to consume, etc etc).

:: this will NOT run the `tph_eating_failed` item callback on failure

* `tph_eating_initiated(player, itemstack, data)`

`data` will be a table of temporary information for the player currently eating. See `tph_eating.get_player_eating_data` for its list of variables. These variables can be modified to allow for eating dynamicism.

Ran when the player begins eating.

Expects nil or ItemStack in return, otherwise will cease eating if returned something else (invalid).

Ran after `tph_eating_condition` if player can successfully begin eating.


* `tph_eating_ongoing(player, itemstack, data)`

`data` will be a table of temporary information for the player currently eating. See `tph_eating.get_player_eating_data` for its list of variables. These variables can be modified to allow for eating dynamicism.

Runs every repeated eating iteration (except for beginning and end of eating). See `tph_eating_initiated` item callback for beginning, `tph_eating_success` callback for end

Expects nil or ItemStack in return, otherwise will cease eating if returned something else (invalid).

Execute anything that should happen while the player is eating (effects, text, messages, animations, etc) with this function (and likely `tph_eating_initiated` as well).


* `tph_eating_failed(player, itemstack, data)`

`data` will be a table of temporary information for the player currently eating. See `tph_eating.get_player_eating_data` for its list of variables. These variables can be modified to allow for eating dynamicism.

Ran if the player stops eating (usually due to not holding `use_key`, no longer holding the ItemStack, or switching inventory slots).

Can be forced to occur by setting `force_finish` to true in `data` in other item callbacks or using the `tph_eating.cease_eating(player)` function.


* `tph_eating_success(player, itemstack, data)`

`data` will be a table of temporary information for the player currently eating. See `tph_eating.get_player_eating_data` for its list of variables. These variables can be modified to allow for eating dynamicism.

Ran if the player successfully finishes eating.

Use this function to determine what should happen to the player when they successfully consume their food (satiety, hydration, toxicity, etc)

:: ensure to RETURN ItemStack if you manually modify it in `tph_eating_success` (you will need to manually take 1 count away and handle `tph_eating.player_in_creative(player)` mechanics).



# Base API functions

Simple minimal functions for handling sound playing, creative privilege checking, event handling, and misc stuff that you shouldn't necessarily need to use.

`player` parameter can be a player object - or the name of an active player.


* `usekey_to_modern()`

Due to compatibility with versions as low as MT `5.0`, there is a possibility of deprecated `RMB` and `LMB` being the only options. This function assists with letting you know the modern equivalents of `RMB` or `LMB` or returning the current`use_key`.

`RMB` becomes `place`, and `LMB` becomes `dig`.


* `player_in_creative(player)`

Checks if `player` is in creative, returning `true` if in creative or `false`otherwise. Checks both world creative cache and if player has the `"creative"` privilege.

Can be replaced with a new function by setting `tph_eating.player_in_creative` to whatever function you would desire for checking a player's creative privileges.


* `play_sound(sound_def, target)`

Plays a specified `sound_def` table or any of its numbered indexes at a given `target` (entity, object, or vector/pos table). If a `target` isn't given, plays globally.

For example of "numbered indexes":
  - sound_table = {1={sound_def}, 2={sound_def}, 3={sound_def}} would be valid and would have a chance of player either of those sounds. If `name` is not provided in those indexes, the `sound_def`'s `name` if provided will be used:
  - sound_table = {name="sound", 1={sound_def}, 2={sound_def}} and so on would be valid
:: on "numbered indexes" - the primary `sound_def`'s `name` will NOT override provided names in numbered index tables

Will randomize any two number value tables (e.g. `{1,5}`) between its values
  - a pitch of `{0.9, 1.5}` would play the sound at a random pitch between both numbers (decimal included)


* `eating_func(player, itemstack)`

`ItemStack` must be a valid ItemStack.

The primary function to begin input-held consumption.

Not recommended to directly use unless you wish to specify more than one or differing functions than the `use_function` for eating. Seek the usage of this function if the overrides provided by `tph_eating.on_use_override` and `tph_eating.add_eating_hook` are unsatisfactory.

Named "eating" in base code, however presents as "eating_func" in the global table


* `clear_eating(player)`

Remove player's information from local `players_eating` table in init.lua


* `register_on_setting_changed(function)`

Runs the provided function upon a variable being changed in the `tph_eating` global.

Function is called with `func(key, value, oldvalue)`;
  - `key` is the name of the modified variable
  - `value` is the new value to be set to
  - `oldvalue` is the previous value

:: this includes anything that changes any critical functions and not simply only the mod settings



# API functions

Functions for eating mechanics - such as ending eating, getting "eating information" of an item, or setup functions for automatically setting compatibility with your item.

`player` parameter can be a player object - or the name of an active player.


* `get_eating_information(itemdef, noerror)`

`itemdef` can be an `ItemStack`, item definition table, or string correlating to an item definition table.

`noerror` if specified, is a boolean indicating whether or not to cause a crashing error due to being unable to find an item definition.

Function returns a table containing `eating_repeats` number, `eating_sound` table, and `finished_sound` table.


* `cease_eating(player)`

Stop a player from continuing to eat if they are eating.

Sets boolean `force_finish` to true for a player's eating data. Will run item callback `tph_eating_failed` if exists


* `get_player_eating_data(player)`

Returns the mod's data on the player eating or nil if there is no data (player is not eating)

Table of several variables:
 - `iteration` - how many `core.after()` iterations have passed
 - `tool_def` - ItemStack definition
 - `image_list` - table of expected strings used to determine `image`. Based off of ItemStack field `tph_eating_image` or in following of priority: `inventory_image` and then node's `tiles`
  - `image` - image used for food particles, modified on each iteration. Set and modified by `image_list` per iteration.
  - `eating_info` - return from `tph_eating.get_eating_information(item)` for currently consumable item
  - `index` - wielded_item index - index of the consumable item in the player's inventory
  - `height` - player height, used for particle position

other variables available only if `tph_eating.eating_item_entity` is true;
  - `obj` - entity created for ItemStack to show near player's mouth
  - `hud_wielditem` - hud setting, DO NOT MODIFY
  - `item_pos` - for `obj`'s relative position to player

All above variables can be modified in `tph_eating_initiated` and `tph_eating_ongoing` item callbacks.


* `add_eating_hook(itemdef, forcereplace, success_function)`

`itemdef` can be an item definition table or the name for a registered item.

`forcereplace` can be a boolean to indicate whether (true) or not (false/nil) to erase the old `use_function` detected in the item if found, default is false.

`success_function` if specified, can be a function that is ran upon item callback `tph_eating_success`

If `forcereplace` is false or nil, it will run the old `use_function` prior to eating mechanics. If the old `use_function` returns a value that isn't the same ItemStack or isn't nil, then prevents eating mechanics.

:: use item callback `tph_eating_success` in definition to determine what should be done upon success OR use the `success_function` parameter to send a function to be set instead.


* `on_use_override(def, siic, addparams)`

`def` can be an item definition table or the name for a registered item.

`siic` is 'SaveItemstackInCreative" and is to be true or false/nil. Will add 1 count to an ItemStack to prevent depletion if player is considered to be in creative by `tph_eating.player_in_creative`

Overrides a provided edible item/node's definition to work accordingly to tph_eating mechanics.

Simply automates running the old `use_function` in `tph_eating_success` item callback and erases it from definition.

If `addparams` is a table, replaces and modifies fields specified in `addparams`. For first index tables such as `def.sounds` or `def.tiles`, it will for example add the fields within your `addparams.sounds` to `def.sounds` instead of replacing. Otherwise all other data type fields are overridden.