extends Node2D

@export var door_opening_delta_seconds := 1.0
@export var button_names : Array[ String ]
@export var door_name : String = "SecureDoor"

@onready var door_controls = [
	[ $TopDoor1, $BottomDoor1 ],
	[ $TopDoor2, $BottomDoor2 ],
	[ $TopDoor3, $BottomDoor3 ]
]

@onready var sound_players = [ $DoorSFX, $DoorSFX2, $DoorSFX3 ]

func _ready() -> void:
	if MetSys.register_storable_object_with_marker(self, set_doors_open):
		$DoorCollider.clear_colliders()
		return

func try_open_door() -> void:
	dramatic_door_open_very_cool( get_open_door_count() )

func dramatic_door_open_very_cool(num_to_open: int) -> void:
	if MetSys.save_data.stored_objects.get(door_name, false):
		return
	
	for i in num_to_open:
		play_animation( "Opening", i )
		sound_players[i].play()
		$DoorCollider.move_to_next_door()
		await get_tree().create_timer( door_opening_delta_seconds ).timeout
	
	if ( num_to_open == door_controls.size() ):
		MetSys.store_object(self)

func get_open_door_count() -> int:
	var num_open = 0
	for id in button_names:
		if is_button_pressed( id ):
			num_open += 1
			
	return num_open

func is_button_pressed(id: String) -> bool:
	return MetSys.save_data.stored_objects.get(id, false)

func play_animation(name: String, door_index: int = 0) -> void: 
	if door_index >= door_controls.size():
		return
	
	door_controls[door_index][0].play(name)
	door_controls[door_index][1].play(name)

func set_doors_open() -> void:
	play_anim_all("IdleOpen")

func _get_object_id() -> String:
	return door_name

func play_anim_all(name: String) -> void:
	for i in door_controls.size():
		play_animation(name, i)
