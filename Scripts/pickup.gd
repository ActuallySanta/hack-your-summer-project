class_name Pickup
extends Area2D

enum PickupType { Coin, Health, Gun, Jetpack }

@export var type : PickupType
## Does the pickup respawn when the player leaves and reenters the room?
@export var respawn_on_load := false
## MetSys automatically assigns an id to all tracked objects based on their
## parent scene + name.<br>
## Set this to true to override that id.
@export var use_custom_id := false
@export var custom_id : StringName

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	if use_custom_id:
		set_meta(&"object_id", custom_id)
	if not respawn_on_load:
		var already_collected = MetSys.register_storable_object(self)
		# MetSys automatically despawns the object if it was already collected
		if already_collected:
			return

func _on_body_entered(body: Node2D) -> void:
	var player := body as Player
	if not player:
		return
		
	var valid_pickup := player.collect(self)
	if not valid_pickup:
		return
		
	if not respawn_on_load:
		MetSys.store_object(self)
	queue_free()

func get_type_as_str() -> StringName:
	return PickupType.find_key(type)
