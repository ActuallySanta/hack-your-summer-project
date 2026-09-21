extends TextDisplay

const hover_sfx := preload("res://Sounds/UI/menuHover.wav")
const click_sfx := preload("res://Sounds/UI/menuSelect.wav")

## Pixels the list travels per notch of the mouse wheel
@export_group("Scrolling")
@export var scroll_speed : float = 20.0
@export var scroll_update_speed : float = 400.0
@export_group("Rest Positions")
@export var hidden_pos : float = -410
@export var shown_pos : float = 0
@export var panel_move_speed : float = 1800.0

const WIDTH := 15
## How many lines of text fit on screen at once
const DISPLAY_HEIGHT := 28

enum MenuState { MENU_REST_HIDDEN, MENU_REST_SHOWN, MENU_MOVE_TO_HIDDEN, MENU_MOVE_TO_SHOWN }

@onready var audio_source : AudioStreamPlayer2D = $AudioStreamPlayer2D

var stream_playback : AudioStreamPlaybackPolyphonic

## One line of the list in screen pixels, the node's scale included
var line_height : float:
	get():
		return tile_set.tile_size.y * scale.y

## The furthest up the list may travel, which is the point where its last line rests on the bottom
## row of the screen. Never positive: a list shorter than the screen has nowhere to go.
var scroll_lower_bound : float:
	get():
		return minf(0.0, -(root.total_height - DISPLAY_HEIGHT) * line_height)

var scroll_offset : float:
	set(new_value):
		scroll_offset = clampf(new_value, scroll_lower_bound, 0.0)

var scroll_actual : float:
	get():
		return scroll_offset# - line_height * 2

var root : TextListItem
var menu_goal : MenuState:
	set(new_value):
		menu_goal = (new_value % 2) as MenuState
var goal_pos : float:
	get(): return hidden_pos if menu_goal == MenuState.MENU_REST_HIDDEN else shown_pos
var goal_dir : float:
	get(): return -1 if menu_goal == MenuState.MENU_REST_HIDDEN else 1

var menu_state : MenuState:
	set(new_value):
		menu_state = new_value
		if menu_state == MenuState.MENU_REST_HIDDEN:
			position.x = hidden_pos
		elif menu_state == MenuState.MENU_REST_SHOWN:
			position.x = shown_pos

var menu_open_percent : float:
	get(): return 1 - position.x / hidden_pos
var inverse_percent : float:
	get(): return clamp(1 - menu_open_percent, 0.01, 0.9)

var touchable : bool: 
	get(): return menu_state == MenuState.MENU_REST_SHOWN

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	menu_state = MenuState.MENU_REST_HIDDEN
	menu_goal = MenuState.MENU_REST_SHOWN
	
	var options = TextListItem.new("Options", WIDTH, [
		TextListItem.new("Visuals", WIDTH, []),
		TextListItem.new("Audio", WIDTH, []),
		TextListItem.new("Controls", WIDTH, []),
		TextListItem.new("Difficulty", WIDTH, []),
	])
	var logbook = TextListItem.new("Log Book", WIDTH, [
		TextListItem.new("Entities", WIDTH, ["a", "b", "c", "d", "e", "f", "g", "h", "i", "j", "k", "l", "m", "n", "o", "p", "q", "r", "s", "t", "u", "v", "w", "x", "y", "z"]),
		TextListItem.new("Regions", WIDTH),
		TextListItem.new("General", WIDTH),
	])
	root = TextListItem.new("C:/Users/Ash Jerock/ana7Tl", WIDTH, [ options, logbook, TextListItem.new("Shut Down", WIDTH, ["Confirm:", "Yes", "No"])])
	root.show_children()
	__debug_hook_up_labels()
	root.display_list( self )

func _process(delta: float) -> void:
	update_scroll( delta )
	update_state( delta )
	update_hover()
	if not root.dirty: return
	root.dirty = false
	root.display_clear( self )
	root.display_list( self )
	scroll_offset = scroll_offset	# The list just changed height, so re-clamp in case it shrank out from under us

func update_state(delta: float) -> void:
	$Seperater.do_update = true if touchable else false
	if menu_goal == menu_state:
		return
		
	menu_state = MenuState.MENU_MOVE_TO_HIDDEN if menu_state == MenuState.MENU_REST_HIDDEN else MenuState.MENU_MOVE_TO_SHOWN
	var d = delta * panel_move_speed
	d *= goal_dir * inverse_percent
	if abs(d) > abs(position.x - goal_pos):
		position.x = goal_pos
		menu_state = menu_goal
		return
	position.x += d

func update_scroll(delta: float) -> void:
	var p_y = position.y
	if position.y == scroll_actual:
		return
		
	var d = scroll_update_speed * delta * (-1 if p_y > scroll_actual else 1)
	if abs(d) > abs(position.y - scroll_actual):
		position.y = scroll_actual
		return
	d *= max(0.1, abs(position.y - scroll_actual)/20)
	position.y += d

## Whether the cursor is inside the list's panel on screen, which is not the same question as whether
## a list line sits under it: scrolled to the bottom the last lines still leave empty rows below them,
## and the wheel has to keep working there. Claiming the wheel by panel is also what lets the pop-up
## beside the list scroll on its own without either one counter-scrolling the other.
func mouse_over_display(tile_coords: Vector2i) -> bool:
	if tile_coords.x < 0 or tile_coords.x >= WIDTH:
		return false
	var top_row : int = floori(-position.y / line_height)	# The list line currently drawn on the top row of the screen
	return tile_coords.y >= top_row and tile_coords.y < top_row + DISPLAY_HEIGHT

## The list line the cursor is on, which is not a screen row: the node carries the scroll and the
## slide in its own position, so going through to_local() is what keeps the two in step.
func mouse_tile_coords() -> Vector2i:
	return local_to_map( to_local( get_global_mouse_position() ) )

## Keeps the hover under the cursor. This is a per frame job rather than a mouse motion one because
## the list moves as much as the cursor does: scrolling and sliding both change what a still cursor
## is pointing at.
func update_hover() -> void:
	if not touchable:
		root.on_mouse_exited()
		root.cancel_press()
		return

	var tile_coords := mouse_tile_coords()
	if mouse_over_display( tile_coords ): 
		root.on_mouse_moved( tile_coords )
		stream_playback = audio_source.get_stream_playback()
		stream_playback.play_stream( hover_sfx )
	else: root.on_mouse_exited()

func _input(event: InputEvent) -> void:
	if not touchable or not event is InputEventMouseButton:
		return

	var tile_coords := mouse_tile_coords()
	# A release is taken wherever it happens, so a press dragged off the list is called off rather
	# than left stuck down waiting for a button that already came up.
	if event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		root.on_mouse_released( tile_coords )
		return

	if not event.pressed or not mouse_over_display( tile_coords ):
		return

	if event.button_index == MOUSE_BUTTON_WHEEL_UP:
		scroll_offset += scroll_speed
	elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		scroll_offset -= scroll_speed
	elif event.button_index == MOUSE_BUTTON_LEFT:
		root.on_mouse_pressed( tile_coords )

#region Debug
const DEBUG_DEAD_LABEL := "Shut Down/Confirm:"

## Gives every label something to answer a click with, standing in for the screens that will one
## day open to the right of the list. Until a label has a listener it is inert by design, so
## without this none of them would highlight, rule or click at all.
## DEBUG_DEAD_LABEL is left unconnected on purpose: it is the case that has to stay dead.
func __debug_hook_up_labels() -> void:
	__debug_connect_labels( root, root.parse_path( DEBUG_DEAD_LABEL ) )

func __debug_connect_labels(item: TextListItem, skipped: TextListItem) -> void:
	if item == skipped: return
	if not item.is_header:
		item.on_click.connect( __debug_fire_on_click.bind( item ) )
		return
	for child in item.sub_lists:
		__debug_connect_labels( child, skipped )

func __debug_fire_on_click(item: TextListItem) -> void:
	var active : TextListItem = root.active_item
	print("[list] clicked '", item.item_name, "' | active label: '", active.item_name if active else "none",
			"' | ruled: ", item.is_ruled, " | highlighted: ", item.is_highlighted)
#endregion
