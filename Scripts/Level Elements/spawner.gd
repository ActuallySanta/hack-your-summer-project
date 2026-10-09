class_name Spawner extends Node2D

@export var scene_to_spawn : PackedScene
@export var max_spawns : int
@export var keep_as_child : bool

var nodes_I_spawned : Array[ Node2D ] = []

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	if keep_as_child:
		tree_exited.connect( clear_spawned_objects )

func _process(_delta: float) -> void:
	nodes_I_spawned = nodes_I_spawned.filter( func(node): return is_instance_valid(node) )

func spawn_object(num_to_spawn: int, spawn_offset: Vector2 = Vector2.ZERO) -> Array[ Node2D ]:
	var spawned_objects_this_call : Array[ Node2D ] = []
	while num_to_spawn > 0 and nodes_I_spawned.size() < max_spawns:
		var instance : Node2D = scene_to_spawn.instantiate()
		instance.global_position = global_position + spawn_offset
		nodes_I_spawned.push_back( instance )
		spawned_objects_this_call.push_back( instance )
		
		# Add to the correct node
		var parent : Node = self if keep_as_child else MetSys.current_room
		parent.add_child.call_deferred( instance )
		num_to_spawn -= 1
	return spawned_objects_this_call

func spawn_array(num_to_spawn: Vector2i, end_pos: Vector2, start_pos: Vector2 = Vector2.ZERO) -> Array[ Node2D]:
	var spawned_this_call : Array[ Node2D ] = []
	# Offset between individual nodes
	var offsets : Vector2 = (end_pos - start_pos) / Vector2(num_to_spawn.x, num_to_spawn.y)
	num_to_spawn = num_to_spawn.max(Vector2i.ONE)
	for x in num_to_spawn.x:
		for y in num_to_spawn.y:
			spawned_this_call.append_array( spawn_object(1, offsets * Vector2(x, y) + start_pos) )
	return spawned_this_call

## Clears all objects spawned by this spawner
func clear_spawned_objects() -> void:
	for i in nodes_I_spawned:
		i.queue_free()
	nodes_I_spawned = []
