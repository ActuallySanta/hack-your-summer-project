extends Control

@export var tile_height : int = 24
@export var time_up : float = 0.5
@export var time_held : float = 3.5
@onready var text : TextDisplay = $Guide/Text
@onready var guide : Node2D = $Guide

var _state : int = 0
var _goal_height : float = 0
var _timer : float = 0
var _last_msg : String = "Gay little gay boy, gay gay gay. Got I hope this game doesn't end up getting datamined... Do you think tkn heard you? No I doubt it, niether of us would be here if that were the case."

func _ready() -> void:
	_state = 0
	_goal_height = 0

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	match _state:
		0: setup_pop_up()
		1: shift_up( delta )
		2: idle( delta )
		3: shift_down( delta )

func setup_pop_up() -> void:
	if not MessageDisplay.has_message() or not _state == 0:
		return
	text.place_deep_fresh( MessageDisplay.peak_next() )
	_goal_height = (text.get_cursor_height() + 1.5)* -tile_height
	_timer = time_up
	_state = 1

func shift_up(delta: float) -> void: 
	_timer -= delta
	guide.position.y = maxf(lerpf(_goal_height, 0, _timer/time_up), _goal_height)
	if _timer > 0 :
		return
	_timer = time_held
	_state = 2

func idle(delta: float) -> void:
	_timer -= delta
	if _timer > 0 :
		return
	_timer = time_up
	_state = 3

func shift_down(delta: float) -> void:
	_timer -= delta
	guide.position.y = minf(lerpf(0, _goal_height, _timer/time_up), 0)
	if _timer > 0 :
		return
	
	_last_msg = MessageDisplay.pop_next()
	guide.position.y = 0
	_goal_height = 0
	_state = 0
