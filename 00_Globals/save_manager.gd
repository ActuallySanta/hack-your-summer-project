## The one place the game asks what has been saved, and the one place that writes it
## down.
##
## [b]What it is for.[/b] Saved state lives in two places that know nothing about each
## other: MetSys keeps the map and the objects the player has taken off it, and the
## save file keeps everything else. Before this, both were reached into directly from
## wherever the question came up -- a pickup poked MetSys, a door read
## [code]stored_objects[/code] by hand, the fusebox asked [GameManager] -- so there was
## no answer to "what does a save actually hold" short of reading every script. Now
## everything goes through here, and the two halves are an implementation detail on
## this side of the wall.
##
## [b]What the game calls.[/b] Items ([method register_item], [method save_item],
## [method is_item_collected]) for anything the player can pick up or switch on that
## MetSys should remember and put a marker on the map for. The value wrappers
## ([method power_station], [method update_logbook], [method reveal_map_secret] and
## friends) for facts that are not objects. And [method save_data_to_file] to write
## the lot down.
##
## [b]The one exception.[/b] Scripts inside the MetSys addon go on calling MetSys
## directly. The addon is not ours to entangle with the game's save format.
##
## [b]How a value is stored.[/b] Every non-item fact is a string key in
## [member SaveData.values], written with [method _save_value_to_metsys] and read with
## [method _check_value_in_metsys]. Those two are deliberately dull, so that a new kind
## of fact is a pair of one-line wrappers over them with a prefix of its own rather
## than a new storage mechanism -- see [method update_logbook], which is what that is
## meant to look like.
extends Node

## The map symbols an item can leave on the world map, in the order the map theme
## lists its textures. [constant MapIcon.None] leaves the map alone entirely.
##
## [constant MapIcon.Uncollected] and [constant MapIcon.Collected] are the defaults of
## [method register_item] and [method save_item], which is what makes a pickup show as
## an open marker until it is taken and a filled one after -- the behaviour MetSys
## gives for free, kept now that we choose the symbol ourselves.
enum MapIcon { None, Uncollected, Collected, Alarm, Save, Map, Boss }

## Where save files live. One directory, so the manager can list what is in it.
const SAVE_DIR := "user://saves"
const SAVE_EXTENSION := "sav"

#region Value key prefixes
## Prefixes keep the flavours of flag apart in the one [member SaveData.values]
## dictionary: a logbook entry and a room event may share a name without becoming the
## same fact.
const LOG_ENTRY_PREFIX := "LOG_ENTRY/"
const EVENT_PREFIX := "EVENT/"
const MAP_SECRET_PREFIX := "MAP_SECRET/"
const MAP_LOCK_PREFIX := "MAP_LOCK/"
const MAP_REGION_PREFIX := "MAP_REGION/"
#endregion

#region Item ids
## The ids of the pickups the save keeps a named field for. They are the
## [code]custom_id[/code] on the pickup scenes, and MetSys knows the objects by them.
const ITEM_FUSE := "Fuse"
const ITEM_GUN := "Gun"
const ITEM_PLASMA_GUN := "PlasmaGun"
const ITEM_JETPACK := "Jetpack"
const ITEM_STRONG_WRENCH := "StrongWrench"
#endregion

## Group every [DebugSpawnPoint] joins, so a room's markers can be found once it is
## loaded without the room having to wire anything up.
const SPAWN_POINT_GROUP := &"debug_spawn_point"

## The save the game is currently running on. [code]null[/code] before anything has
## been loaded, i.e. while the main menu is up.
var _data: SaveData = null

## The [CustomSaveData] the current save was started from, if it was one. Kept because
## its spawn marker can only be resolved once the room it names has been loaded.
var _custom: CustomSaveData = null

func _ready() -> void:
	# A spawn is the one moment that follows both a load and a new game, and it lands
	# before the load screen lifts. It is where the map goes back to what the save
	# says, for the same reason [MapBorders] and [StationPowerTiles] pick that moment.
	GlobalSignals.player_spawned.connect(_restore_map_regions)
	# The fusebox announces the station coming back to life rather than writing it
	# down, so the writing down is here, next to everything else the save keeps.
	GlobalSignals.RestoreStationPower.connect(power_station)

#region Starting, loading and writing a save
## Whether a save is loaded. False on the main menu, where every read below falls back
## to its default rather than inventing state.
func is_loaded() -> bool:
	return _data != null

## Begins a new game: a save with nothing in it, which is to say the start of the game
## (see [SaveData]). MetSys is cleared to match.
func start_new_game() -> void:
	_custom = null
	_load(SaveData.new())

## Loads the save file called [param save_name], and reports whether there was one.
##
## A missing file leaves the game untouched and returns [code]false[/code], so the
## caller can start a new game instead -- which is what "Load game" does today, with
## only the one [code]demo[/code] file to go at.
func load_data_from_file(save_name: String) -> bool:
	var data := SaveData.new(get_save_path(save_name))
	if not data.loaded_from_file:
		return false

	_custom = null
	data.save_name = save_name
	_load(data)
	return true

## Loads a hand-authored starting point instead of a file. See [CustomSaveData].
func load_custom_save(custom: CustomSaveData) -> void:
	if custom == null:
		printerr("SaveManager: no custom save to load.")
		start_new_game()
		return

	_custom = custom
	_load(custom.to_save_data())

## Writes the running game to [param save_name].sav.
##
## This is the whole of saving: it takes where the player is and what MetSys has been
## told, folds them into the loaded [SaveData], and puts it on disk. A save station
## calls this and nothing else.
##
## [param use_checkpoint] is what makes a station save put the player back at the
## station rather than wherever they were standing: the room's
## [code]save_checkpoint[/code] node is preferred over the player's own position, and
## the respawn point moves there too. The starting save written at the beginning of a
## run passes [code]false[/code], having no station to speak of.
func save_data_to_file(save_name: String, use_checkpoint := true) -> void:
	if _data == null:
		printerr("SaveManager: nothing is loaded, so there is nothing to save.")
		return

	_capture_world_state(use_checkpoint)
	_data.save_name = save_name

	if not DirAccess.dir_exists_absolute(SAVE_DIR):
		var error := DirAccess.make_dir_recursive_absolute(SAVE_DIR)
		if error != OK:
			printerr("SaveManager: cannot make \"%s\". Error %d." % [SAVE_DIR, error])
			return

	var path := get_save_path(save_name)
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		printerr("SaveManager: cannot write \"%s\". Error %d." % [path, FileAccess.get_open_error()])
		return

	file.store_string(var_to_str(_data.to_dict()))

func get_save_path(save_name: String) -> String:
	return "%s/%s.%s" % [SAVE_DIR, save_name, SAVE_EXTENSION]

func has_save_file(save_name: String) -> bool:
	return FileAccess.file_exists(get_save_path(save_name))

## Every save file there is, by name. For the save picker there is not a menu for yet.
func list_save_names() -> PackedStringArray:
	var names := PackedStringArray()
	for file in DirAccess.get_files_at(SAVE_DIR):
		if file.get_extension() == SAVE_EXTENSION:
			names.append(file.get_basename())
	return names

## The room the loaded save wants, for [GameManager] to put up.
func get_spawn_room() -> String:
	return _data.current_room if _data else SaveData.START_ROOM_UID

## Where in that room the player belongs, once it is loaded.
##
## Ordinary saves wrote down a position. A [CustomSaveData] prefers a
## [DebugSpawnPoint] in the room, which can be dragged around and seen where typed
## coordinates cannot -- and which only exists once the room is up, hence the
## resolving here rather than at load.
func get_spawn_position() -> Vector2:
	if _data == null:
		return SaveData.START_POS
	if _custom:
		_data.player_pos = _custom_spawn_position()
	return _data.player_pos
#endregion

#region Items
## Tells MetSys to keep track of [param object], and puts its marker on the map.
##
## [param on_already_collected] is called instead if the save says the object has
## already been taken; leave it empty and a [Node] frees itself, which is what a
## pickup wants. [param icon] is the marker to leave, or [constant MapIcon.None] to
## leave the map alone.
##
## This deliberately reports nothing. MetSys' own version answers "was it already
## collected?" through its return value, which had half the game's scripts doing their
## already-collected work in the callback and the other half in an [code]if[/code] on
## the call, and left a reader to remember that registering also asks a question. Ask
## it afterwards, out loud, with [method is_item_collected].
func register_item(object: Object, on_already_collected := Callable(), icon := MapIcon.Uncollected) -> void:
	if MetSys.save_data == null:
		push_warning("SaveManager: no save data yet, so \"%s\" cannot be tracked." % MetSys.get_object_id(object))
		return

	MetSys.register_storable_object_with_marker(object, on_already_collected, _icon_symbol(icon))

## Records that [param object] has been collected, and swaps its map marker for the
## collected one ([constant MapIcon.None] to leave the map alone).
##
## Safe to call on something already stored, and on something never registered --
## either is a mistake MetSys asserts on, and neither is worth a crash at the moment
## the player picks something up.
func save_item(object: Object, icon := MapIcon.Collected) -> void:
	if MetSys.save_data == null:
		push_warning("SaveManager: no save data yet, so \"%s\" cannot be stored." % MetSys.get_object_id(object))
		return

	var id := MetSys.get_object_id(object)
	if id in MetSys.save_data.stored_objects:
		return
	if not id in MetSys.save_data.registered_objects:
		MetSys.save_data.registered_objects[id] = true

	MetSys.store_object(object, _icon_symbol(icon))

## Whether [param object] has been collected. Ask after [method register_item].
func is_item_collected(object: Object) -> bool:
	return is_item_id_collected(MetSys.get_object_id(object))

## Whether the object with [param id] has been collected, for asking about something
## that is not in the room -- a door about its buttons, the fusebox about the fuse.
func is_item_id_collected(id: String) -> bool:
	if MetSys.save_data == null:
		return false
	return MetSys.save_data.stored_objects.get(id, false)

func _icon_symbol(icon: MapIcon) -> int:
	match icon:
		MapIcon.None:
			return -1
		MapIcon.Uncollected:
			return MetSys.settings.theme.uncollected_item_symbol
		MapIcon.Collected:
			return MetSys.settings.theme.collected_item_symbol
	# The rest index the theme's symbol textures directly, past the two the theme
	# names itself.
	return icon - 1
#endregion

#region The map
## Whether the cell at [param coords] has been found, either walked through or
## revealed by a map station.
func is_cell_discovered(coords: Vector3i, include_mapped := true) -> bool:
	return MetSys.is_cell_discovered(coords, include_mapped)

## Records that a map station handed over [param code]'s region, and reports whether
## that was news.
##
## Kept as a flag of its own rather than left to MetSys' discovered cells, so that a
## load can replay the reveal outright (see [method _restore_map_regions]) instead of
## depending on per-cell discovery data round-tripping through the file intact.
func register_map_region_revealed(code: String) -> bool:
	return _record_once(MAP_REGION_PREFIX + code)

func is_map_region_revealed(code: String) -> bool:
	return _check_value_in_metsys(MAP_REGION_PREFIX + code)

func get_revealed_map_regions() -> Array:
	return _values_with_prefix(MAP_REGION_PREFIX)

## Records that a secret passage has been found, and reports whether that was news.
## [param id] is a border name, as [MapBorders] writes them.
func reveal_map_secret(id: String) -> bool:
	return _record_once(MAP_SECRET_PREFIX + id)

func is_map_secret_revealed(id: String) -> bool:
	return _check_value_in_metsys(MAP_SECRET_PREFIX + id)

## Records that a lock has been opened, and reports whether that was news.
func open_map_lock(lock: StringName) -> bool:
	return _record_once(MAP_LOCK_PREFIX + lock)

func is_map_lock_open(lock: StringName) -> bool:
	return _check_value_in_metsys(MAP_LOCK_PREFIX + lock)

func _restore_map_regions() -> void:
	if _data == null:
		return
	for code in get_revealed_map_regions():
		MapRegions.reveal(code)
	# Everything that draws the map redraws now, on the data that was just put back.
	MetSys.map_updated.emit()
#endregion

#region The station
## Whether the fuse has gone in and the station has power.
func is_station_powered() -> bool:
	return _data.station_powered if _data else false

## Records the station coming back to life.
func power_station() -> void:
	if _data == null:
		printerr("SaveManager: nothing is loaded, so the station's power cannot be recorded.")
		return
	_data.station_powered = true
#endregion

#region The logbook and room events
## Writes a logbook entry down, and reports whether it is one the player had not seen
## before -- which is the question every caller has, so it is one call rather than a
## check and a write.
func update_logbook(entry: String) -> bool:
	return _record_once(LOG_ENTRY_PREFIX + entry)

func check_logbook(entry: String) -> bool:
	return _check_value_in_metsys(LOG_ENTRY_PREFIX + entry)

func get_logbook_entries() -> Array:
	return _values_with_prefix(LOG_ENTRY_PREFIX)

## Records that something happened, for anything that is neither an object nor worth a
## wrapper of its own. Reports whether it had happened already.
func record_event(event: String) -> bool:
	return _record_once(EVENT_PREFIX + event)

func has_event(event: String) -> bool:
	return _check_value_in_metsys(EVENT_PREFIX + event)
#endregion

#region Health extenders
## Records that the extender with [param object_id] has been collected, and reports
## whether that was news.
##
## The ids are kept rather than a running total, which is what makes this safe to call
## twice. A pickup that reappears because the run was never saved can be taken again,
## and the second take adds nothing, because the id is already in the set.
func register_health_upgrade(object_id: String) -> bool:
	if object_id.is_empty():
		printerr("SaveManager: a health extender has no object id; it cannot be tracked.")
		return false
	if _data == null:
		printerr("SaveManager: nothing is loaded, so \"%s\" cannot be recorded." % object_id)
		return false
	if _data.health_upgrades.has(object_id):
		return false

	_data.health_upgrades.append(object_id)
	return true

## How many health extenders the save says have been collected.
func get_health_upgrade_count() -> int:
	return _data.health_upgrades.size() if _data else 0
#endregion

#region Values
## Reads a value out of the loaded save. Returns [param default] when there is no save
## yet, i.e. on the menu.
func get_value(key: String, default: Variant = null) -> Variant:
	if _data == null:
		return default
	return _data.values.get(key, default)

## Writes a value into the loaded save. It reaches disk on the next
## [method save_data_to_file], which is what keeps an upgrade and the pickup that
## granted it reverting together.
func set_value(key: String, value: Variant) -> void:
	if _data == null:
		printerr("SaveManager: nothing is loaded, so \"%s\" cannot be stored." % key)
		return
	_data.values[key] = value

## Marks a fact as true. The base every wrapper above is built on: give the fact a
## prefixed name and this is all the storage it needs.
func _save_value_to_metsys(value: String) -> void:
	set_value(value, true)

## Whether a fact marked by [method _save_value_to_metsys] is in the save.
func _check_value_in_metsys(value: String) -> bool:
	return bool(get_value(value, false))

## Marks a fact and reports whether it was news, which is what the wrappers that both
## record and answer are made of.
func _record_once(value: String) -> bool:
	if _check_value_in_metsys(value):
		return false
	_save_value_to_metsys(value)
	return true

## Every fact recorded under [param prefix], with the prefix taken back off.
func _values_with_prefix(prefix: String) -> Array:
	if _data == null:
		return []

	var found: Array = []
	for key: String in _data.values:
		if key.begins_with(prefix) and bool(_data.values[key]):
			found.append(key.trim_prefix(prefix))
	return found
#endregion

#region Putting a save into the world, and taking the world back out
## Makes [param data] the running save: MetSys is set up from it, and what the player
## is carrying is handed back to them.
func _load(data: SaveData) -> void:
	_data = data
	# set_save_data with an empty dictionary is how MetSys is initialised for a new
	# game, so this one call covers both.
	MetSys.set_save_data(_data.metsys)
	_apply_carried_items()
	_apply_to_player()

## Puts the save's named fields back into MetSys' stored objects.
##
## For a save the game wrote these agree already -- they were read out of MetSys when
## it was written. For a [CustomSaveData] they are the only thing there is, which is
## what lets a custom save hand out a kit without knowing pickup ids.
func _apply_carried_items() -> void:
	_set_item_stored(ITEM_FUSE, _data.has_fuse)
	_set_item_stored(ITEM_JETPACK, _data.has_jetpack)
	_set_item_stored(ITEM_GUN, _data.gun >= SaveData.GunState.Stun)
	_set_item_stored(ITEM_PLASMA_GUN, _data.gun == SaveData.GunState.Plasma)
	_set_item_stored(ITEM_STRONG_WRENCH, _data.wrench == SaveData.WrenchState.Allen)

func _set_item_stored(id: String, stored: bool) -> void:
	if stored:
		MetSys.save_data.stored_objects[id] = true

## Hands the player what the save says they are carrying. Their own components pick up
## the rest when they respawn (health from [method get_health_upgrade_count], the
## wrench's damage from the value store).
func _apply_to_player() -> void:
	var player := PlayerManager.player
	if player == null:
		return

	if _data.has_jetpack:
		player.enable_jetpack()
	else:
		player.disable_jetpack()

	if _data.gun >= SaveData.GunState.Stun:
		player.enable_gun()
		player.set_gun(&"plasma" if _data.gun == SaveData.GunState.Plasma else &"stun")
	else:
		player.disable_gun()

## Reads the running game back into the save, ready to be written down.
func _capture_world_state(use_checkpoint: bool) -> void:
	_data.metsys = MetSys.get_save_data()
	_data.has_fuse = is_item_id_collected(ITEM_FUSE)
	_data.has_jetpack = is_item_id_collected(ITEM_JETPACK)
	_data.wrench = SaveData.WrenchState.Allen if is_item_id_collected(ITEM_STRONG_WRENCH) else SaveData.WrenchState.Basic

	if is_item_id_collected(ITEM_PLASMA_GUN):
		_data.gun = SaveData.GunState.Plasma
	elif is_item_id_collected(ITEM_GUN):
		_data.gun = SaveData.GunState.Stun
	else:
		_data.gun = SaveData.GunState.None

	var room := MetSys.get_current_room_name()
	if not room.is_empty():
		_data.current_room = room

	var player := PlayerManager.player
	if player:
		_data.player_pos = player.global_position

	if not use_checkpoint:
		return

	# The station is what the player walked into, so it is where they come back to --
	# both on a reload and on the respawn that does not go through a file at all.
	var checkpoint := get_tree().get_first_node_in_group(&"save_checkpoint") as Node2D
	if checkpoint == null:
		printerr("SaveManager: no save checkpoint in this room. Saving the player's own position instead.")
	else:
		_data.player_pos = checkpoint.global_position
	LevelManager.set_checkpoint(_data.current_room, _data.player_pos, false)

func _custom_spawn_position() -> Vector2:
	var markers := get_tree().get_nodes_in_group(SPAWN_POINT_GROUP)
	for node in markers:
		var marker := node as DebugSpawnPoint
		if marker and marker.id == _custom.spawn_id:
			return marker.global_position

	if not markers.is_empty():
		var names := markers.map(func(m): return str(m.id))
		printerr("SaveManager: no spawn point with id \"%s\" in this room. It has: %s. Using the custom save's position." % [_custom.spawn_id, ", ".join(names)])
	return _custom.start_position
#endregion
