## A starting point written by hand, for testing a part of the game without playing
## up to it.
##
## Drop one of these on [member GameManager.custom_save_data] and tick
## [member GameManager.use_custom_save], and the game skips the menu and starts from
## what this describes instead of from the [code]demo[/code] file. It is a
## [Resource] rather than a [SaveData] so that it can be edited in the inspector and
## kept as a [code].tres[/code] per thing you are testing.
##
## It only describes a beginning. [method to_save_data] turns it into the [SaveData]
## the game actually runs on, and from then on it is an ordinary save: the first
## thing [SaveManager] does with it is write it to the save file, so dying reverts to
## this start exactly as it would revert to a save station.
class_name CustomSaveData
extends Resource

## How far the fuse has got: found, or found and put in the box.
enum FuseState { Uncollected, Collected, Powered }

@export_group("Where to start")
## The room to load. Defaults to the start of the game.
@export_file var start_room := SaveData.START_ROOM_UID
## Which [DebugSpawnPoint] in [member start_room] to stand on. Drop one in the room
## and drag it where you want it; [member start_position] is only used when the room
## has no marker with this id.
@export var spawn_id: StringName = &"default"
## Fallback spawn coordinate, used when [member start_room] holds no
## [DebugSpawnPoint] matching [member spawn_id].
@export var start_position := Vector2(3000, 483)

@export_group("What the player has")
@export var fuse := FuseState.Uncollected
@export var gun := SaveData.GunState.None
@export var wrench := SaveData.WrenchState.None
@export var has_jetpack := false
## How many health extenders to count as already collected.
@export_range(0, 32) var health_upgrades := 0

@export_group("Anything else")
## Extra entries for [member SaveData.values], for a flag with no field of its own:
## a logbook entry, a room event, an opened lock. Keys are the same ones
## [SaveManager]'s wrappers use.
@export var extra_values: Dictionary = {}

## Builds the save this describes. The ids given to the health extenders are made up
## -- nothing reads them back, only how many there are (see
## [method SaveManager.get_health_upgrade_count]) -- so collecting a real extender
## afterwards still counts.
func to_save_data() -> SaveData:
	var data := SaveData.new()
	data.current_room = start_room
	data.player_pos = start_position
	data.has_fuse = fuse > FuseState.Uncollected
	data.station_powered = fuse == FuseState.Powered
	data.gun = gun
	data.wrench = wrench
	data.has_jetpack = has_jetpack
	data.values = extra_values.duplicate(true)

	for i in health_upgrades:
		data.health_upgrades.append("custom_save/health_%d" % i)

	return data
