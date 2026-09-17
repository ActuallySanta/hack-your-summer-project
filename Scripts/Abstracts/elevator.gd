@abstract
class_name Elevator extends Node2D

const ELEV_START_SFX := preload("res://Sounds/EnvSFX/ElevStart.wav")

@export var height_markers : Array[ Marker2D ]
@export var floors : Array[ float ]
@export var move_speed : float = 1.0

@onready var interactable : PlayerInteractable = $Body/PlayerInteractable
@onready var extender : SpriteExtender = $Body/Platform
@onready var body_node : AnimatableBody2D = $Body

var _was_moving : bool
var _init_platform_height : float
var _target_floor : int:
	set(new_value):
		# Purify evil
		if new_value < 0 or new_value >= floors.size():
			return
		_target_platform_height = floors[ new_value ]
		_target_floor = new_value

var _target_platform_height : float
var _tile_tall : int:
	set(new_value):
		if new_value == _tile_tall:
			return
		extender.reset()
		extender.increment_for( new_value )
		_tile_tall = new_value

var _current_platform_height : float:
	set(new_value):
		if new_value > 0:
			return
		body_node.position.y = _init_platform_height + new_value
		_current_platform_height = new_value
		_tile_tall = int(-(_current_platform_height / 48)) + 1

func snap_to_floor(target_floor: int) -> void:
	var was_syncing := body_node.sync_to_physics
	body_node.sync_to_physics = false
	_target_floor = target_floor
	_current_platform_height = _target_platform_height
	body_node.force_update_transform()
	body_node.sync_to_physics = was_syncing

@abstract
func change_floor() -> void

@abstract
func reached_floor() -> void

func _in_transit() -> bool:
	return _current_platform_height != _target_platform_height

func setup() -> void:
	pass

func _ready() -> void:
	if OS.has_feature("debug"):
		__debug_checking()
	_init_platform_height = body_node.position.y
	interactable.on_player_confirm_interaction.connect( change_floor )
	for i in height_markers:
		floors.append( i.global_position.y - global_position.y)
	_target_floor = 0
	setup()

func _process(delta: float) -> void:
	if not _in_transit():
		if _was_moving:
			interactable.disable_pause()
			reached_floor()
			_was_moving = false
		return
	
	_was_moving = true
	interactable.enable_pause()
	var movement_delta = move_speed * delta
	if _target_platform_height < _current_platform_height: movement_delta *= -1
	# If the amount we're trying to move is greater than we need to, don't overshoot
	if abs(movement_delta) > abs(_current_platform_height - _target_platform_height):
		_current_platform_height = _target_platform_height
		return
	
	_current_platform_height += movement_delta

func __debug_checking() -> void:
	if body_node == null:
		printerr("Elevator: No 'Body' Node as child")
	if extender == null:
		printerr("Elevator: No 'Body/Platform' SpriteExtender as child")
	if interactable == null:
		printerr("Elevator: No 'Body/PlayerInteractable' PlayerInteractable as child")

func __debug_inputs() -> void:
	var dirty : bool = false
	if Input.is_action_pressed("Up"):
		_target_floor += 1
		dirty = true
	elif Input.is_action_pressed("Down"):
		_target_floor -= 1
		dirty = true
	
	if dirty:
		print("Height: ", int(_current_platform_height) % 48)
		print("Tiles: ", int(-_current_platform_height / 48))
