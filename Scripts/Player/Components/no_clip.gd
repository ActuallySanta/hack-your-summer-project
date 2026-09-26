extends Node2D

@export var move_speed := 1000.0

var _cheats_enabled : bool
var _parent : Player
var _collision_mask_and_layer : PackedInt32Array

var _no_clip_on : bool:
	set( new_value ):
		if new_value == _no_clip_on:
			return
		if new_value == true: _turn_on_noclip()
		else: _turn_off_noclip()
		_no_clip_on = new_value

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	_parent = get_parent()
	_collision_mask_and_layer = PackedInt32Array([ _parent.collision_mask, _parent.collision_layer ])
	_cheats_enabled = false
	_no_clip_on = false

func _turn_on_noclip() -> void:
	_parent.collision_layer = 0
	_parent.collision_mask = 0
	_parent.gravity_override = 0
	
func _turn_off_noclip() -> void:
	_parent.collision_layer = _collision_mask_and_layer[ 1 ]
	_parent.collision_mask = _collision_mask_and_layer[ 0 ]
	_parent.gravity_override = -1.0

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if Input.is_action_just_pressed("Cheats"): 
		_cheats_enabled = not _cheats_enabled
		print("Cheats: ", _cheats_enabled)
	if not _cheats_enabled: return
	
	if Input.is_action_just_pressed("Climb"): _no_clip_on = not _no_clip_on
	if not _no_clip_on: return
	
	var move_input_x := Input.get_axis("Left", "Right")
	var move_input_y := Input.get_axis("Up", "Down")
	_parent.global_position += Vector2(move_input_x, move_input_y) * move_speed * delta
