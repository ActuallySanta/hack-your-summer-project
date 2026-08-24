class_name Navigator extends Node2D

@export var node_to_go_to : Node2D
#TODO Fix this: does not appear to try and intercept at all, just does same logioc for some reason
## Do I move to intercept or be stupid
@export var move_to_intercept : bool
## Values less than 0.0 will place no limit on the steering_force; will make navigator track perfectly
@export var steering_max_force : float
## Values less than 0.0 will be treated as infinite; the navigator will "snap" to it's target
@export var max_speed : float
@export var stop_friction := 0.9
@export var stop_velocity := 0.1
@export var node_to_move_instead_of_me : Node2D = null
@export var ignore_target : bool

func _ready() -> void:
	if is_instance_valid(node_to_move_instead_of_me):
			_nav_position = node_to_move_instead_of_me.global_position
	else:
		_nav_position = global_position

func set_nav_position(new_pos: Vector2) -> void:
	_nav_position = new_pos

var x : float:
	get(): return _nav_position.x
	set(value): _nav_position.x = value

var y : float:
	get(): return _nav_position.y
	set(value): _nav_position.y = value

var _nav_position : Vector2:
	set(value):
		if is_instance_valid(node_to_move_instead_of_me):
			node_to_move_instead_of_me.global_position = value
			_nav_position = node_to_move_instead_of_me.global_position
		else:
			global_position = value
			_nav_position = global_position

var _velocity_mag : float:
	get():
		return _velocity.length()
	set(value):
		_velocity = _velocity_dir * value

var _velocity_dir : Vector2:
	get():
		return _velocity.normalized()
	set(value):
		_velocity = _velocity_mag * value

var _velocity : Vector2
var _steering : Vector2
var _desired_velocity : Vector2
var _target_distance_to_me : Vector2
var _target_previous_pos : Vector2
var _target_velocity : Vector2
var _target_future_pos : Vector2
## This should be the main way variables are updated
var _target_current_pos : Vector2:
	set(value):
		if max_speed < 0.0: # Leave earily and only track the current pos; all movement should be handled outside of this setter
			_target_current_pos = value
			return
		
		_target_previous_pos = _target_current_pos
		_target_current_pos = value
		_target_distance_to_me = abs(_target_current_pos - _nav_position)
		_target_velocity = _target_current_pos - _target_previous_pos
		
		if move_to_intercept: # Are we predicting where to go, or just charing blindly
			var t :float = _target_distance_to_me.length() / (max_speed + abs(_target_velocity.length()))
			_target_future_pos = _target_current_pos + (_target_velocity * t)
			_desired_velocity = (_target_future_pos - _nav_position).normalized() * max_speed
		else:
			_desired_velocity = (_target_current_pos - _nav_position).normalized() * max_speed
		
		_steering = _desired_velocity - _velocity
		if steering_max_force < 0.0: # Leave early since infinite correction needs no limit in this case
			return
		if _steering.length() <= steering_max_force: # No correction needed
			return
		
		_steering = _steering.normalized() * steering_max_force

func start_moving_manually() -> void:
	ignore_target = true

func start_following_target() -> void:
	ignore_target = false

func manual_movement() -> void:
	pass

func sudden_stop() -> void:
	_velocity_mag = 0
	_velocity = Vector2.ZERO
	ignore_target = true

func slow_down_and_stop() -> void:
	if _velocity_mag == 0:
		return
	
	_velocity_mag *= stop_friction
	var new_mag := _velocity_mag - stop_velocity
	if new_mag > 0:
		_velocity_mag = new_mag
		return
	
	_velocity_mag = 0

# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	if ignore_target:
		manual_movement()
		return
		
	if not is_instance_valid(node_to_go_to):
		slow_down_and_stop()
	else:
		_target_current_pos = node_to_go_to.global_position
		if max_speed < 0.0:
			_nav_position = _target_current_pos
			return
		_velocity += _steering
	_nav_position += _velocity * delta
