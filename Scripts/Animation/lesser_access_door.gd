extends Door

@export var button_names : Array[ String ]
@export var door_name : String = "SecureDoor"

var door_controls
@onready var sound_player = $SFX
var collider : Node2D

func setup() -> void:
	door_controls = get_children_with_name("Door")
	var colliders = get_children_with_name("Collider")
	if not colliders.is_empty():
		collider = colliders[0]

func should_be_opened_check() -> bool:
	SaveManager.register_item( self, func(): return, SaveManager.MapIcon.None )
	if SaveManager.is_item_collected(self):
		return true

	for button_name in button_names:
		if not SaveManager.is_item_id_collected(button_name):
			return false
	return true

func animate_open() -> void:
	# Check if the door is already open
	if SaveManager.is_item_id_collected(door_name):
		return
	
	# Remove the collider
	if not collider == null:
		collider.queue_free()
	else:
		printerr("collider already removed...") 
	
	# Do animation and save door as open
	for door in door_controls: door.play( "Opening" )
	sound_player.play()
	SaveManager.save_item(self, SaveManager.MapIcon.None)

func immediate_open() -> void:
	for door in door_controls: door.play( "IdleOpen" )
	if not collider == null:
		collider.queue_free()

func get_children_with_name(identifier: String) -> Array[ Node ]:
	return get_children().filter(func(child: Node): return identifier in child.name)

func _get_object_id() -> String:
	return door_name

func immediate_closed() -> void:
	pass
