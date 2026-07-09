extends Node2D

@onready var InitQuad = $InitialQuadrant
@onready var BalanceQuad = $BalanceQuadrant
@onready var door = $Door
@onready var doorLockCollider = $StaticBody2D/LockedDoorCollider

var _player_started_through_here = false
var _apply_helpful_force = false
var _player_node : CharacterBody2D

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	doorLockCollider.set_deferred("disabled", true)
	await  get_tree().physics_frame
	await  get_tree().physics_frame
	await  get_tree().physics_frame
	var overlapping_bodies = InitQuad.get_overlapping_bodies()
	
	for i in overlapping_bodies:
		if i.is_in_group("player"):
			_player_started_through_here = true

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if not _apply_helpful_force or _player_started_through_here:
		return
	
	if not Input.is_action_pressed("Jump"):
		return
	
	_player_node.velocity.y -= 40

func _on_initial_quadrant_body_entered(body: Node2D) -> void:
	await get_tree().physics_frame
	if _player_started_through_here:
		return
	
	if body.is_in_group("player"):
		_apply_helpful_force = true
		_player_node = body

func _on_initial_quadrant_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		door.play("DoorOpen")
		_apply_helpful_force = false
		_player_started_through_here = false
		doorLockCollider.set_deferred("disabled", false)


func _on_balance_quadrant_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		doorLockCollider.set_deferred("disabled", true)
		var curr_frame = door.frame
		door.play("DoorClose")
		door.frame = 5-curr_frame
