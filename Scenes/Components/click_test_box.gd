@tool
class_name ClickBox extends Node2D

signal on_mouse_pressed
signal on_mouse_held
signal on_mouse_released

signal on_scroll

@export var scroll_speed : float = 100.0
@export var show_boundries : bool = true

var was_pressed : bool
var init_click : Vector2
var _last_mouse_pos : Vector2
var _curr_mouse_pos : Vector2
var delta_mouse_pos : Vector2:
	get(): return _curr_mouse_pos - _last_mouse_pos
var delta_from_start : Vector2:
	get(): return _curr_mouse_pos - init_click

@export var dimensions : Vector2:
	set(new_value):
		dimensions = abs(new_value)
		queue_redraw()

func _process(_delta: float) -> void:
	if not was_pressed:
		return
	_last_mouse_pos = _curr_mouse_pos
	_curr_mouse_pos = get_mouse_percent()
	on_mouse_held.emit()

func get_mouse_percent() -> Vector2:
	return get_local_mouse_position() / dimensions

func _is_mouse_in_bounds() -> bool:
	return Rect2(Vector2.ZERO, dimensions).has_point(get_local_mouse_position())

func _input(event: InputEvent) -> void:
	if not event is InputEventMouseButton:
		return
		
	_left_click_handling( event )
	_scroll_handling( event )

func _left_click_handling(event: InputEvent) -> void:
	if not event.button_index == MOUSE_BUTTON_LEFT:
		return 
	if event.is_pressed() and _is_mouse_in_bounds():
		was_pressed = true
		init_click = get_mouse_percent()
		on_mouse_pressed.emit()
	elif event.is_released():
		was_pressed = false
		on_mouse_released.emit()
	
func _scroll_handling(event: InputEvent) -> void:
	if event.button_index != MOUSE_BUTTON_WHEEL_UP and event.button_index != MOUSE_BUTTON_WHEEL_DOWN or not _is_mouse_in_bounds(): return
	var scroll_offset := scroll_speed if event.button_index == MOUSE_BUTTON_WHEEL_UP else -scroll_speed
	on_scroll.emit( scroll_offset )

func _draw() -> void:
	if not show_boundries: return
	draw_rect(Rect2(Vector2.ZERO, dimensions), Color(1.0,1.0,1.0,0.5), false, 0.5)
