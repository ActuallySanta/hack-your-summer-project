extends Node2D

@export var height_markers : Array[ Marker2D ]
@export var floors : Array[ float ]
@export var move_speed : float = 1.0

@onready var interactable : PlayerInteractable = $Body/PlayerInteractable
@onready var extender : SpriteExtender = $Body/Platform
@onready var body_node := $Body

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

func change_floor() -> void:
	if _in_transit():
		return
	_target_floor = 1 if _target_floor == 0 else 0

func _in_transit() -> bool:
	return _current_platform_height != _target_platform_height

func _ready() -> void:
	_init_platform_height = body_node.position.y
	interactable.on_player_confirm_interaction.connect( change_floor )
	for i in height_markers:
		floors.append( i.global_position.y - global_position.y)
	_target_floor = 0

func _process(delta: float) -> void:
	if not _in_transit():
		interactable.disable_pause()
		return
	
	interactable.enable_pause()
	var movement_delta = move_speed * delta
	if _target_platform_height < _current_platform_height: movement_delta *= -1
	# If the amount we're trying to move is greater than we need to, don't overshoot
	if abs(movement_delta) > abs(_current_platform_height - _target_platform_height):
		_current_platform_height = _target_platform_height
		return
	
	_current_platform_height += movement_delta

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
