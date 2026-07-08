class_name Pickup
extends Area2D

enum PickupType { Coin, Health, Gun, Jetpack }

@export var type : PickupType
## Does the pickup respawn when the player leaves and reenters the room?
@export var respawn_on_load := false
## If true, the object will be stored in MetSys using the pickup type only.<br>
## If false, the object will be stored in MetSys using the parent scene and node name.
## Essentially, set this to false if there's only one in the map and you want it
## to be easier to track in code.
@export var is_unique := false

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	if is_unique:
		set_meta(&"object_id", PickupType.find_key(type))
	if not respawn_on_load:
		var already_collected = MetSys.register_storable_object(self)
		# MetSys automatically despawns the object if it was already collected
		if already_collected:
			print("Already Collected!")
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
