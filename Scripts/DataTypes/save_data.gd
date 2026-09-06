## The contents of one save file.
##
## This holds values and nothing else. [SaveManager] is what puts them into the
## running game and takes them back out again; the only behaviour here is reading a
## file and becoming one.
##
## The headline state -- what the player is carrying, how much health they have
## earned, whether the station has power -- gets a named field, so a save file can be
## read at a glance and a [CustomSaveData] can be authored by hand. Everything else
## the game records along the way lives in [member values] under a string key, so
## recording a new kind of thing means adding a wrapper to [SaveManager] and nothing
## here. [member metsys] is MetSys' own bookkeeping (discovered cells, stored
## objects, map markers, cell overrides), carried through the file untouched.
class_name SaveData
extends RefCounted

## Where a save that has never been written puts the player: the start of the game.
## A [code]SaveData.new()[/code] is a new game, which is why these live here rather
## than in [GameManager].
const START_ROOM_UID := "uid://djrq87v0sx3lq" # Docking Station
const START_POS := Vector2(158, 834)

## Which gun the player owns. Ordered, so [code]>= Stun[/code] reads as "owns a gun".
enum GunState { None, Stun, Plasma }

## Which wrench the player swings. Ordered, so [code]>= Basic[/code] reads as "has a
## wrench at all" -- the player starts the game with nothing and is handed one in the
## tutorial, the same shape as [enum GunState].
enum WrenchState { None, Basic, Allen }

#region The file's keys
const KEY_SAVE_NAME := "save_name"
const KEY_CURRENT_ROOM := "current_room"
const KEY_PLAYER_POS := "player_pos"
const KEY_HEALTH_UPGRADES := "health_upgrades"
const KEY_STATION_POWERED := "station_powered"
const KEY_HAS_FUSE := "has_fuse"
const KEY_HAS_JETPACK := "has_jetpack"
const KEY_GUN := "gun"
const KEY_WRENCH := "wrench"
const KEY_VALUES := "values"
const KEY_METSYS := "metsys"
#endregion

## The file this was written as, without the directory or the extension.
var save_name := ""

## The room to load and the position to put the player at when this save is loaded.
var current_room := START_ROOM_UID
var player_pos := START_POS

## The ids of every health extender collected, rather than a count of them --
## see [method SaveManager.register_health_upgrade] for why.
var health_upgrades: Array[String] = []

## Whether the fuse has been put in the fusebox and the station brought back to life.
var station_powered := false

#region What the player is carrying
## These mirror MetSys' stored objects, which is where collection is actually
## recorded while the game runs. They are filled in when a save is written and read
## back out when one is loaded, so that a file says what the player has in plain
## words and a [CustomSaveData] can hand out a kit without naming pickup ids.
var has_fuse := false
var has_jetpack := false
var gun := GunState.None
var wrench := WrenchState.None
#endregion

## Everything recorded through [SaveManager]'s value wrappers: logbook entries, room
## events, revealed map secrets, opened locks, and any other flag a wrapper invents.
var values: Dictionary = {}

## MetSys' own save data, exactly as [method MetroidvaniaSystem.get_save_data]
## returns it.
var metsys: Dictionary = {}

## Whether this came off disk. False for a new game and for a [CustomSaveData], which
## is what lets [SaveManager] tell "no save yet" from "a save that happens to look
## like the beginning of the game".
var loaded_from_file := false

## Reads the save at [param path]. Leave [param path] empty for a new game: the
## defaults above are the start of the game.
##
## A file that is missing or unreadable leaves the defaults in place and
## [member loaded_from_file] false, so a failed load is a new game rather than a
## half-loaded one.
func _init(path := "") -> void:
	if path.is_empty():
		return

	if not FileAccess.file_exists(path):
		return

	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("SaveData: cannot read \"%s\". Error %d." % [path, FileAccess.get_open_error()])
		return

	var parsed = str_to_var(file.get_as_text())
	if not parsed is Dictionary:
		push_error("SaveData: \"%s\" does not hold save data." % path)
		return

	_apply_dict(parsed)
	loaded_from_file = true

## The whole save as a [Dictionary], ready for [method @GlobalScope.var_to_str].
func to_dict() -> Dictionary:
	return {
		KEY_SAVE_NAME: save_name,
		KEY_CURRENT_ROOM: current_room,
		KEY_PLAYER_POS: player_pos,
		KEY_HEALTH_UPGRADES: health_upgrades,
		KEY_STATION_POWERED: station_powered,
		KEY_HAS_FUSE: has_fuse,
		KEY_HAS_JETPACK: has_jetpack,
		KEY_GUN: gun,
		KEY_WRENCH: wrench,
		KEY_VALUES: values,
		KEY_METSYS: metsys,
	}

func _apply_dict(dict: Dictionary) -> void:
	save_name = str(dict.get(KEY_SAVE_NAME, save_name))
	current_room = str(dict.get(KEY_CURRENT_ROOM, current_room))
	player_pos = dict.get(KEY_PLAYER_POS, player_pos)
	station_powered = bool(dict.get(KEY_STATION_POWERED, station_powered))
	has_fuse = bool(dict.get(KEY_HAS_FUSE, has_fuse))
	has_jetpack = bool(dict.get(KEY_HAS_JETPACK, has_jetpack))
	gun = int(dict.get(KEY_GUN, gun)) as GunState
	wrench = int(dict.get(KEY_WRENCH, wrench)) as WrenchState

	# assign() rather than assignment: what comes back out of the file is an untyped
	# Array, and a typed one will not take it whole.
	var upgrades = dict.get(KEY_HEALTH_UPGRADES, [])
	if upgrades is Array:
		health_upgrades.assign(upgrades)

	var stored_values = dict.get(KEY_VALUES, {})
	if stored_values is Dictionary:
		values = stored_values

	var metsys_data = dict.get(KEY_METSYS, {})
	if metsys_data is Dictionary:
		metsys = metsys_data
