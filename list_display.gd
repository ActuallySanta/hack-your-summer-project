extends TextDisplay

## Pixels the list travels per notch of the mouse wheel
@export var scroll_speed : float = 20.0
@export var scroll_update_speed : float = 400.0
const WIDTH := 15
## How many lines of text fit on screen at once
const DISPLAY_HEIGHT := 28

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

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
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
	root.display_list( self )

func _process(delta: float) -> void:
	update_scroll(delta)
	if not root.dirty: return
	root.dirty = false
	root.display_clear( self )
	root.display_list( self )
	scroll_offset = scroll_offset	# The list just changed height, so re-clamp in case it shrank out from under us

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

func _input(event: InputEvent) -> void:
	if not event is InputEventMouseButton or not event.pressed:
		return
	
	var local_pos = to_local(get_global_mouse_position())
	var tile_coords = local_to_map( local_pos )
	if not mouse_over_display( tile_coords ):
		return
	
	if event.button_index == MOUSE_BUTTON_WHEEL_UP:
		scroll_offset += scroll_speed
	elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		scroll_offset -= scroll_speed
	elif event.button_index == MOUSE_BUTTON_LEFT and root.mouse_over_map( tile_coords ):
		root.on_mouse_click( tile_coords )
