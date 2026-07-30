extends Node2D

@export var button_names : Array[ String ]
@export var door_name : String = "SecureDoor"

var door_controls
@onready var sound_player = $SFX
var collider

func _ready() -> void:
	door_controls = get_children_with_name("Door")
	# Set collider
	var colliders = get_children_with_name("Collider")
	if not colliders.is_empty():
		collider = colliders[0]
	
	if collider == null:
		if check_all_buttons():
			set_all_open()
	
	if MetSys.register_storable_object( self, set_all_open ):
		if collider != null:
			collider.queue_free()
		return

func check_all_buttons() -> bool:
	for button_name in button_names:
		if not _is_button_pressed(button_name):
			return false
	return true

func try_open_door() -> void:
	if MetSys.save_data.stored_objects.get(door_name, false):
		return
	_open_door()

func _open_door() -> void:
	play_animation( "Opening" )
	sound_player.play()
	MetSys.store_object(self)

func play_animation(identifier: String) -> void: 
	for door in door_controls:
		door.play(identifier)

func set_all_open() -> void:
	play_animation( "IdleOpen" )

func _is_button_pressed(id: String) -> bool:
	return MetSys.save_data.stored_objects.get(id, false)

func get_children_with_name(identifier: String) -> Array[ Node ]:
	return get_children().filter(func(child: Node): return identifier in child.name)

func _get_object_id() -> String:
	return door_name
