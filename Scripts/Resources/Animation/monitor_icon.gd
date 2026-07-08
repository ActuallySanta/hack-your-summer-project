extends Node2D

var _icons : Array[Node]
var _timer_passive = 0
var _start_pos : Vector2
var _current_icon

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	_start_pos = global_position
	_icons = get_children()
	if is_collected():
		_icons[1].visible = true
		_current_icon = _icons[1]
	else:
		_icons[0].visible = true
		_current_icon = _icons[0]


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	_timer_passive += delta
	var time = TAU * _timer_passive
	var alpha = sin(time)
	var height = sin(time/2)
	_current_icon.modulate = Color(1, 1, 1, (alpha * alpha + 6) / 7)
	_current_icon.global_position.y = _start_pos.y + height


#TODO change this to cooperate with the MetSys item collection system
func is_collected() -> bool:
	return false


#TODO integrate MetSys Item collection system to this function
func switch_to_activated() -> void:
	_icons[0].visible = false
	_icons[1].visible = true
	_current_icon = _icons[1]
