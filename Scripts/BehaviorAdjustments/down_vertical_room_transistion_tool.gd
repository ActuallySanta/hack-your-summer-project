class_name DownDoorTool extends Node2D

@onready var InitQuad = $InitialQuadrant
@onready var BalanceQuad = $BalanceQuadrant
@onready var door = $Door
@onready var doorLockCollider = $StaticBody2D/LockedDoorCollider

var _player_started_through_here = false
var _player_exited = false
var _apply_helpful_force = false
var _door_closed = false
var _player_node : CharacterBody2D

@export var lockOnEnter : bool = false

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	doorLockCollider.set_deferred("disabled", true)
	await get_tree().physics_frame
	await get_tree().physics_frame
	await get_tree().physics_frame
	_player_started_through_here = verify_player_location( InitQuad )

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if not _apply_helpful_force or _player_started_through_here:
		return
	
	if not Input.is_action_pressed("Jump"):
		return
	
	_player_node.velocity.y -= 40

func verify_player_location(quad: Area2D) -> bool:
	var overlapping_bodies = quad.get_overlapping_bodies()
	
	for i in overlapping_bodies:
		if i.is_in_group("player"):
			return true
	return false

func _on_initial_quadrant_body_entered(body: Node2D) -> void:
	await get_tree().physics_frame
	if not _player_started_through_here:
		return
	
	if body.is_in_group("player"):
		_apply_helpful_force = true
		_player_node = body

func _on_initial_quadrant_body_exited(body: Node2D) -> void:
	await get_tree().physics_frame
	if verify_player_location( InitQuad ) or not _player_started_through_here or _player_exited:
		return
	if body.is_in_group("player") and not _door_closed:
		door.play("DoorOpen")
		_apply_helpful_force = false
		_door_closed = true
		doorLockCollider.set_deferred("disabled", false)


func _on_balance_quadrant_body_exited(body: Node2D) -> void:
	await get_tree().physics_frame
	if verify_player_location( BalanceQuad ) or not _player_started_through_here or _player_exited:
		return
	if body.is_in_group("player") and _door_closed and !lockOnEnter:
		doorLockCollider.set_deferred("disabled", true)
		var curr_frame = door.frame
		door.play("DoorClose")
		_door_closed = false
		door.frame = 5-curr_frame
		_player_exited = true
			
			
