extends AudioStreamPlayer2D

const DEBUG = preload("res://Sounds/DebugAndTemp/ChargeFire.wav")

const DOCKING_BAY = DEBUG
const CREW_QUARTERS = preload("res://Sounds/Music/A surprise infusion.ogg")
const INTERNALS = DEBUG
const LABS = preload("res://Sounds/Music/Jetpack Joyride DEMO.ogg")
const BRS = preload("res://Sounds/Music/BRS.ogg")
const LOWER_BRS = preload("res://Sounds/Music/BRS.ogg")

const MAIN_MENU = DEBUG

const ANDROID = DEBUG
const MATRIX = DEBUG

const MAP = DEBUG
const SAVE = DEBUG
const PICKUP = DEBUG

@onready var ui_ost := {
	"Main Menu": DEBUG,
}

@onready var location_ost := {
	"Crew Quarters": CREW_QUARTERS,
	"Crew Quarters Hidden": CREW_QUARTERS,
	"Internals": INTERNALS,
	"Internals Hidden": INTERNALS,
	"Maintainence": LABS,
	"Maintainence Hidden": LABS,
	"BRS": BRS,
	"BRS Hidden": LOWER_BRS,
}

@onready var boss_ost := {
	"Awoken Android": ANDROID,
	"Matrix": MATRIX,
}

@onready var special_ost := {
	"Map": MAP,
	"Save": SAVE,
	"Item Pickup": PICKUP,
}

@onready var osts := {
	"UI": ui_ost,
	"LOCATION": location_ost,
	"BOSS": boss_ost,
	"SPECIAL": special_ost,
}

var default := DEBUG

func _ready() -> void:
	await get_tree().process_frame
	set_background_track_from_room_instance()

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
	var groups := MetSys.get_cell_groups(MetSys.current_room.cells[0])
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
	print("No track in game with name: ", ost_name)
	play_background_track( DEBUG )

func set_background_track_from_name(type: String, ost_name: String) -> void:
	var dictionary = osts[ type ]
	if dictionary == null:
		return
	
	var track = dictionary[ ost_name ]
	if track == null:
		return
	
	play_background_track( track )

## Takes a MetSys cell groups and determines what song should play
func set_background_track(location: PackedInt32Array) -> void:
	play_background_track( _get_current_cell_group_music( location ) )

## Determines the music to play VIA the current active MetSys RoomInstance.
## Only works on rooms that have uniform groupings between cells.
func set_background_track_from_room_instance() -> void:
	var groups := get_current_room_instance_groups()
	if groups.is_empty():
		return
	
	play_background_track( _get_current_cell_group_music( groups ) )

func _get_current_cell_group_music(groups: PackedInt32Array) -> AudioStream:
	var best_guess: AudioStream
	for group in groups:
		var group_name = MetSys.get_group_name(group)
		if group_name.begins_with( "_" ):
			var type = group_name.split("_", false, 1)
			print("Playing Music for: [ ", type[0], ": ", type[1], " ]")
			return _parse_special_room(type[ 0 ], type[ 1 ])
		else:
			best_guess = location_ost.get(group_name)
	
	return best_guess

func _parse_special_room(type: String, special_name: String) -> AudioStream:
	var dictionary = osts[type]
	return dictionary.get(special_name)
