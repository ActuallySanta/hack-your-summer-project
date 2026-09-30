class_name PausePanel extends Node2D

const SCROLL_BAR_SIZE := 26
const TILE_SIZE := 8
const CONTENT_LINE_COUNT : int = 28
const TOTAL_WIDTH : int = 32

enum HideState { HIDE_REST, SHOW_REST, HIDING, SHOWING }
## What the panel is showing: a text file from the list, or the map
enum Tab { TEXT, MAP }

## The panel has finished fading out
signal on_fully_hidden

@export var fade_speed : float

@onready var constants := $Constants
@onready var content := $Content
@onready var click_box := $ClickBox
@onready var scroll_interactable := $ScrollInteractable
@onready var scroll_wheel_detector := $ScrollWheelInteractable
@onready var map_tab := $MapTab
@onready var map : PauseMap = $MapTab/Map

var _scroll_bar_data : TextBar = TextBar.new(Vector2i(29, SCROLL_BAR_SIZE), TextElement.Axis.Vertical, SCROLL_BAR_SIZE)

var enabled : bool:
	set( new_value ):
		enabled = new_value
		set_process( enabled )	# The fade runs in _process, so enable before display( true )
		_apply_input()

var read_output : String = "$TAB $AUTO_1028"
var text_line_count : int = 0
var file_height : int = 3

var _desire_to_hide : HideState = HideState.SHOW_REST:
	set( new_value ):
		_desire_to_hide = new_value
		_apply_input()
var _tab : Tab = Tab.TEXT

var fully_hidden : bool:
	get(): return _desire_to_hide == HideState.HIDE_REST

## Whether the panel is up or on its way up, rather than fading away or gone
var _showing : bool:
	get(): return _desire_to_hide == HideState.SHOW_REST or _desire_to_hide == HideState.SHOWING

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
	#constants.draw_scroll_bar(_scroll_bar_data, 1000)
	scroll_interactable.on_mouse_pressed.connect( func(): click_box.was_pressed = true )
	scroll_wheel_detector.on_scroll.connect( on_scroll )
	_apply_tab()
	force_set_display( false )

func _process(_delta: float) -> void:
	update_display_state( RealDelta.get_capped() )

func read_and_place(file_name: String) -> void:
	if not FileAccess.file_exists(file_name):
		printerr("Warning (pause_panel, 27): File does not exist")
		return
	
	_show_text()
	var file = FileAccess.open(file_name, FileAccess.READ)
	read_output = file.get_as_text()
	file.close()
	content.place_deep_fresh( read_output )
	text_line_count = content.get_lines_placed()
	@warning_ignore("integer_division")
	var new_file_height : int = max(text_line_count + 3 - CONTENT_LINE_COUNT / 2, 0)
	if new_file_height == file_height: return
	pos_y = 0
	_draw_scroll_bar( 0 )
	file_height = new_file_height

func on_scroll(delta: int) -> void:
	pos_y -= delta
	_draw_scroll_bar( get_pos_percent )

func on_mouse_hold() -> void:
	_draw_scroll_bar( click_box.get_mouse_percent().y )
	var offset: int = int( file_height * click_box.get_mouse_percent().y )
	pos_y = offset

func _draw_scroll_bar(percent: float) -> void:
	if text_line_count < CONTENT_LINE_COUNT: 
		constants.erase_scroll_bar( _scroll_bar_data )
		return
	constants.draw_scroll_bar(_scroll_bar_data, constants._get_scroll_bar_quarters_from_percent(SCROLL_BAR_SIZE, 1 - percent))

#region Tabs
## Switches to the map, which plays its turn-on. Already on the map this does nothing, so
## clicking the tab again, or closing and reopening the menu, never replays it.
func show_map() -> void:
	if _tab == Tab.MAP: return
	_tab = Tab.MAP
	_apply_tab()
	map.open()

func _show_text() -> void:
	if _tab == Tab.TEXT: return
	_tab = Tab.TEXT
	map.snap_closed()
	_apply_tab()

func _apply_tab() -> void:
	var on_map := _tab == Tab.MAP
	map_tab.visible = on_map
	content.visible = not on_map
	constants.visible = not on_map
	_apply_input()

# The text's click and scroll boxes sit over the map, so only the tab showing takes input
func _apply_input() -> void:
	var reading := enabled and _tab == Tab.TEXT
	click_box.enabled = reading
	scroll_interactable.enabled = reading
	scroll_wheel_detector.enabled = reading
	map.active = enabled and _tab == Tab.MAP
	# Resuming puts the player straight back on the movement keys while the map is still fading
	# out, so it stops panning the moment the panel starts to go rather than once it has gone
	map.takes_input = _showing
#endregion

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
	# Coming back from fully away, the player has moved on since the map last looked
	if should_show and fully_hidden and _tab == Tab.MAP: map.refresh()
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
		# Reopening shows the map as it was left, so a turn-on the fade cut short finishes unseen
		map.finish_animation()
		on_fully_hidden.emit()

#endregion
