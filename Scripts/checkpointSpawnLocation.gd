extends Node2D

@export var is_default = true
@onready var collider: Area2D = $Area2D

# Workflow:
# On start the default checkpoint is marked as the current checkpoint 
# 
# If a player collides with a checkpoint, then remove that checkpoint from the marker
#   |
#   V
# After removing the other checkpoint, add the one the player collided with

func _ready() -> void:
	if (is_default):
		CheckpointEventBus.player_needs_to_use_checkpoint.connect(respawnPlayerHere)
	
	collider.body_entered.connect(override_respawnPoint)
	
func respawnPlayerHere():
	CheckpointEventBus.move_player_position.emit(global_position)

# Clears the respawn Point from the singleton and instead makes this one the target
func override_respawnPoint(body: Node) -> void:
	# Clear connections
	var connections = CheckpointEventBus.player_needs_to_use_checkpoint.get_connections()
	
	if (connections.size() > 1):
		print(" !Warning! Too many checkpoints")
		for connection in connections:
			CheckpointEventBus.player_needs_to_use_checkpoint.disconnect(connection.callable)
	elif (connections.size() == 1):
		CheckpointEventBus.player_needs_to_use_checkpoint.disconnect(connections[0].callable)
	else:
		print(" !Warning! No checkpoint assigned")
	
	CheckpointEventBus.player_needs_to_use_checkpoint.connect(respawnPlayerHere)
