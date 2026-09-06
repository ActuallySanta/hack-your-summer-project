class_name Pickup
extends Area2D

enum PickupType { Coin, HealthRune, PlasmaGun, Jetpack, Fuse, StunGun, AllenWrench }

@export var type : PickupType
@export var destroy_on_pickup := false
## Does the pickup respawn when the player leaves and reenters the room?
@export var respawn_on_load := false
## MetSys automatically assigns an id to all tracked objects based on their
## parent scene + name.<br>
## Set this to true to override that id.
@export var use_custom_id := false
@export var custom_id : StringName

## The marker this leaves on the world map while it is still here. It becomes the
## collected marker once taken; "None" keeps the pickup off the map altogether.
## [br][br]The list mirrors [enum SaveManager.MapIcon] and has to stay in its order.
@export_enum("None", "Uncollected", "Collected", "Alarm", "Save", "Map", "Boss")
var map_icon: int = SaveManager.MapIcon.Uncollected

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	if use_custom_id:
		set_meta(&"object_id", custom_id)

	if respawn_on_load:
		_ready_after_setup()
		return

	SaveManager.register_item(self, _on_load_if_collected, map_icon)
	# Asked out loud, rather than read off the call above. Registering records the
	# pickup; whether it had already been taken is a separate question, and the
	# answer arrives here rather than hidden in a return value.
	if SaveManager.is_item_collected(self):
		return

	_ready_after_setup()

func _on_load_if_collected() -> void:
	queue_free()

func _ready_after_setup() -> void:
	pass

func _on_collect() -> void:
	pass

func _on_body_entered(body: Node2D) -> void:
	var player := body as Player
	if not player:
		return
		
	var valid_pickup := player.collect(self)
	if not valid_pickup:
		return
		
	_on_collect()
	
	if not respawn_on_load:
		SaveManager.save_item(self)

	queue_free()

func get_type_as_str() -> StringName:
	return PickupType.find_key(type)
