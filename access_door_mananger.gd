extends Door

@export var door_opening_delta_seconds := 1.0
@export var button_names : Array[ String ]
@export var door_name : String = "SecureDoor"

@onready var door_controls = [
	[ $TopDoor1, $BottomDoor1 ],
	[ $TopDoor2, $BottomDoor2 ],
	[ $TopDoor3, $BottomDoor3 ],
]

@onready var sound_players = [ $DoorSFX, $DoorSFX2, $DoorSFX3 ]

func should_be_opened_check() -> bool:
	return MetSys.register_storable_object_with_marker(self, func(): return)

func animate_open() -> void:
	# Check if door is already open
	if MetSys.save_data.stored_objects.get(door_name, false):
		return
		
	# Get number of doors to open
	var num_to_open = 0
	for button in button_names:
		if MetSys.save_data.stored_objects.get(button, false):
			num_to_open += 1
	
	for i in num_to_open:
		play_animation( "Opening", i )
		sound_players[i].play()
		$DoorCollider.move_to_next_door()
		await get_tree().create_timer( door_opening_delta_seconds ).timeout
	
	if (num_to_open == door_controls.size()):
		MetSys.store_object(self)	

func play_animation(anim_name: String, door_index: int = 0) -> void: 
	if door_index >= door_controls.size():
		return
	
	door_controls[door_index][0].play(anim_name)
	door_controls[door_index][1].play(anim_name)

func immediate_open() -> void:
	$DoorCollider.clear_colliders()
	for i in door_controls.size():
		play_animation("IdleOpen", i)

func _get_object_id() -> String:
	return door_name
