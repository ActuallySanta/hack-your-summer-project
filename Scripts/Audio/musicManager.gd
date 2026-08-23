extends AudioStreamPlayer2D

const DEBUG = preload("res://Sounds/DebugAndTemp/ChargeFire.wav")

const DOCKING_BAY_UNPOWERED = preload("res://Sounds/Music/Docking Bay Ruined.ogg")
const DOCKING_BAY = preload("res://Sounds/Music/Docking Bay Powered.ogg")
const CREW_QUARTERS = preload("res://Sounds/Music/A surprise infusion.ogg")
const INTERNALS = DEBUG
const LABS = preload("res://Sounds/Music/Jetpack Joyride DEMO.ogg")
const BRS = preload("res://Sounds/Music/BRS.ogg")
const LOWER_BRS = preload("res://Sounds/Music/Lower Biological Zone.ogg")

const MAIN_MENU = DEBUG

const BOSS_AMBIANCE = preload("res://Sounds/Music/Tension before a… big scary robot.ogg")
const ANDROID = DEBUG
const MATRIX = preload("uid://dlo7hhcd6w44g")
const CONTAINMENT_DRONE = preload("res://Sounds/Music/Containment Drone.ogg")

const MAP = preload("res://Sounds/Music/Uncertainty.ogg")
const SAVE = preload("res://Sounds/Music/Uncertainty.ogg")
const PICKUP = preload("res://Sounds/Music/Uncertainty.ogg")

const NONE = preload("res://Sounds/Music/issue.wav")

@onready var ui_ost := {
	"Main Menu": DEBUG,
}

@onready var location_ost := {
	"Docking Bay": DOCKING_BAY,
	"Docking Bay Hidden": DOCKING_BAY,
	"Crew Quarters": CREW_QUARTERS,
	"Crew Quarters Hidden": CREW_QUARTERS,
	"Internals": INTERNALS,
	"Internals Hidden": INTERNALS,
	"Maintainence": LABS,
	"Maintainence Hidden": LABS,
	"BRS": LOWER_BRS,
	"BRS Hidden": BRS,
}

@onready var boss_ost := {
	"Ambiance": BOSS_AMBIANCE,
	"Awoken Android": ANDROID,
	"Matrix": MATRIX,
	"Containment Drone": CONTAINMENT_DRONE,
}

@onready var special_ost := {
	"Map": MAP,
	"Save": SAVE,
	"Pickup": PICKUP,
}

@onready var osts := {
	"UI": ui_ost,
	"LOCATION": location_ost,
	"BOSS": boss_ost,
	"SPECIAL": special_ost,
}

var default := DEBUG
var music_volume : float
var list_of_pausers : Array[ String ]

var ignore_cell_groups_flag : bool
var allow_auto_swap : bool

func _ready() -> void:
	MetSys.room_changed.connect(update_ignore)
	music_volume = volume_db
	await get_tree().process_frame
	set_background_track_from_room_instance()

#region Playing Audio
## Switches the background track
func play_background_track(track: AudioStream) -> void:
	if track == null:
		playing = false
		return
	
	if stream == track and playing:
		return
	
	stream = track
	play()

func get_current_room_instance_groups() -> PackedInt32Array:
	if MetSys.current_room == null:
		return []
	var current_cells := MetSys.current_room.cells
	if current_cells.is_empty():
		return []
	var groups := MetSys.get_cell_groups(current_cells[0])
	if groups.is_empty():
		return []
	else:
		return groups 

## DO NOT USE OUTSIDE OF DEBUG; takes a string and attempts to play it, overwriting the
## current song in use. Super slow and ineffiecient
func _DEBUG_set_background_track_ost_name(ost_name: String) -> void:
	var track : AudioStream
	for dict in osts:
		track = dict.get( ost_name )
		if not track == null:
			play_background_track( track )
			return
	printerr("No track in game with name: ", ost_name)
	play_background_track( DEBUG )

func set_background_track_from_name(type: String, ost_name: String) -> void:
	if type == "NONE":
		play_background_track( NONE )
		return
	
	var dictionary = osts[ type ]
	if dictionary == null:
		return
	
	var track = dictionary[ ost_name ]
	if track == null:
		return
	
	play_background_track( track )

## Takes a MetSys cell groups and determines what song should play
func set_background_track(location: PackedInt32Array) -> void:
	if ignore_cell_groups_flag:
		return
	play_background_track( _get_current_cell_group_music( location ) )

## Determines the music to play VIA the current active MetSys RoomInstance.
## Only works on rooms that have uniform groupings between cells.
func set_background_track_from_room_instance() -> void:
	if ignore_cell_groups_flag:
		return
	
	var groups := get_current_room_instance_groups()
	if groups.is_empty():
		return
	
	var track = _get_current_cell_group_music( groups )
	play_background_track( track )

func _get_current_cell_group_music(groups: PackedInt32Array) -> AudioStream:
	if ignore_cell_groups_flag:
		return NONE
		
	var best_guess: AudioStream
	for group in groups:
		var group_name = MetSys.get_group_name(group)
		if group_name.begins_with( "_" ):
			var type = group_name.split("_", false, 1)
			if type[ 0 ] == "NONE":
				return NONE
			return _parse_special_room(type[ 0 ], type[ 1 ])
		else:
			best_guess = location_ost.get(group_name)
			if best_guess == null:
				printerr("Music Manager (_get_current_cell_group_music) cannot find an ost for this zone, there is probably no entry in the regions dictionary.")
	
	return best_guess

func _parse_music_effect(condition: String) -> AudioStream:
	if condition == "DockPower":
		return DOCKING_BAY if GameManager.is_station_powered() else DOCKING_BAY_UNPOWERED
	return NONE

func _parse_special_room(type: String, special_name: String) -> AudioStream:
	if type == "MUSEFFECT":
		return _parse_music_effect(special_name)
		
	var dictionary = osts[type]
	return dictionary.get(special_name)

func override_automatic_assignment(restore_when_leaving_room) -> void:
	ignore_cell_groups_flag = true
	allow_auto_swap = restore_when_leaving_room
	
func restore_automatic_assignment() -> void:
	ignore_cell_groups_flag = false

func update_ignore(_new_room: String) -> void:
	if not ignore_cell_groups_flag or not allow_auto_swap:
		return
	
	ignore_cell_groups_flag = false
#endregion

#region Pause Audio

func try_mute_volume(requester: String) -> bool:
	if list_of_pausers.has(requester):
		return false
	
	list_of_pausers.append(requester)
	volume_db = -80
	return true

func try_unmute_volume(requester: String) -> bool:
	if not list_of_pausers.has(requester):
		return false
	list_of_pausers.erase(requester)
	
	if list_of_pausers.size() <= 0:
		volume_db = music_volume
	return true
#endregion
