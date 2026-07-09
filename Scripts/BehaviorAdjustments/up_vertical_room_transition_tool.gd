extends Area2D

var _player_started_through_here = false
var _apply_helpful_force = false
var _player_node : CharacterBody2D

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	await  get_tree().physics_frame
	await  get_tree().physics_frame
	await  get_tree().physics_frame
	var overlapping_bodies = get_overlapping_bodies()
	
	for i in overlapping_bodies:
		if i.is_in_group("player"):
			_player_started_through_here = true

func _process(delta: float) -> void:
	if not _apply_helpful_force or _player_started_through_here:
		return
	
	if not Input.is_action_pressed("Jump"):
		return
	
	_player_node.velocity.y -= 40

# We should check this is a player
func _on_body_entered(body: Node2D) -> void:
	await get_tree().physics_frame
	if _player_started_through_here:
		return
	
	if body.is_in_group("player"):
		_apply_helpful_force = true
		_player_node = body

# Clear these two prereqs
func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		_apply_helpful_force = false
		_player_started_through_here = false
