class_name PausePanel extends Node2D

const SCROLL_BAR_SIZE := 26
const TILE_SIZE := 8
const CONTENT_LINE_COUNT : int = 28
const TOTAL_WIDTH : int = 32

enum HideState { HIDE_REST, SHOW_REST, HIDING, SHOWING }

@export var fade_speed : float

@onready var constants := $Constants
@onready var content := $Content
@onready var click_box := $ClickBox
@onready var scroll_interactable := $ScrollInteractable
@onready var scroll_wheel_detector := $ScrollWheelInteractable

var read_output : String = "$TAB $AUTO_1028"
var text_line_count : int = 0
var file_height : int = 3

var _desire_to_hide : HideState = HideState.SHOW_REST

var _pos_raw : int = 0 
var pos_y : int:
	get(): return _pos_raw
	set( new_value ):
		_pos_raw = clamp(new_value, 0, file_height)
		content.position.y = -TILE_SIZE * _pos_raw

var get_pos_percent : float:
	get():
		return _pos_raw / float(file_height)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	click_box.on_mouse_held.connect( on_mouse_hold )
	constants.draw_scroll_bar(Vector2i(29, SCROLL_BAR_SIZE), TextElement.Axis.Vertical, SCROLL_BAR_SIZE, 1000)
	scroll_interactable.on_mouse_pressed.connect( func(): click_box.was_pressed = true )
	#read_and_place( "res://Logs/Docking-Bay.txt" )
	scroll_wheel_detector.on_scroll.connect( on_scroll )
	force_set_display( false )

func _process(delta: float) -> void:
	update_display_state( delta )

func read_and_place(file_name: String) -> void:
	if not FileAccess.file_exists(file_name):
		printerr("Warning (pause_panel, 27): File does not exist")
		return
	
	var file = FileAccess.open(file_name, FileAccess.READ)
	read_output = file.get_as_text()
	file.close()
	content.place_deep_fresh( read_output )
	text_line_count = content.get_lines_placed()
	@warning_ignore("integer_division")
	file_height = max(text_line_count + 3 - CONTENT_LINE_COUNT / 2, 0)

func print_screen_percent_line() -> void: print( int( file_height * click_box.get_mouse_percent().y ) )

func on_scroll(delta: int) -> void:
	pos_y -= delta
	constants.draw_scroll_bar(Vector2i(29, SCROLL_BAR_SIZE), TextElement.Axis.Vertical, SCROLL_BAR_SIZE, constants._get_scroll_bar_quarters_from_percent(SCROLL_BAR_SIZE, 1 - get_pos_percent))

func on_mouse_hold() -> void:
	constants.draw_scroll_bar(Vector2i(29, SCROLL_BAR_SIZE), TextElement.Axis.Vertical, SCROLL_BAR_SIZE, constants._get_scroll_bar_quarters_from_percent(SCROLL_BAR_SIZE, 1 - click_box.get_mouse_percent().y))
	var offset: int = int( file_height * click_box.get_mouse_percent().y )
	pos_y = offset

#region animation stuffs
# shw | dth | ocm
#  0  |  0  |  0
#  0  |  1  |  2
#  0  |  2  |  2
#  0  |  3  |  2
#  1  |  0  |  3
#  1  |  1  |  1
#  1  |  2  |  3
#  1  |  3  |  3
# When equal -> no change
# else: outcome (ocm) = 2 + show
func display(should_show: bool) -> void:
	if int(should_show) == _desire_to_hide: pass
	else: _desire_to_hide = (2 + int(should_show)) as HideState

func update_display_state(delta: float) -> void:
	if _desire_to_hide < 2: return
	
	var scaled_fade_speed : float = delta * fade_speed
	modulate.a += scaled_fade_speed if _desire_to_hide == HideState.SHOWING else -scaled_fade_speed
	if _desire_to_hide == HideState.SHOWING and modulate.a >= 1: force_set_display( true )
	elif _desire_to_hide == HideState.HIDING and modulate.a <= 0: force_set_display( false )

func force_set_display(should_show: bool) -> void:
	if should_show:
		modulate.a = 1
		_desire_to_hide = HideState.SHOW_REST
	else:
		modulate.a = 0
		_desire_to_hide = HideState.HIDE_REST

#endregion
