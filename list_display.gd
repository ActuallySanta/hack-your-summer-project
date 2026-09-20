extends TextDisplay

@export var scroll_speed : float = 5.0

const WIDTH := 15
const DISPLAY_HEIGHT := 28

var scroll_offset : float:
	set(new_value):
		new_value = clamp(new_value, -(root.total_height - DISPLAY_HEIGHT) * 48, 0)
		position.y = new_value
		scroll_offset = new_value
		print(scroll_offset)

var root : TextListItem

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	var garbage : Array[ TextListItem ] = [ 
		TextListItem.new("a", WIDTH),
		TextListItem.new("b", WIDTH),
		TextListItem.new("c", WIDTH),
		TextListItem.new("d", WIDTH),
		TextListItem.new("e", WIDTH),
		TextListItem.new("f", WIDTH),
		TextListItem.new("g", WIDTH),
		TextListItem.new("h", WIDTH),
		TextListItem.new("i", WIDTH),
		TextListItem.new("j", WIDTH),
		TextListItem.new("k", WIDTH),
		TextListItem.new("l", WIDTH),
		TextListItem.new("m", WIDTH),
		TextListItem.new("n", WIDTH),
		TextListItem.new("o", WIDTH),
		TextListItem.new("p", WIDTH),
		TextListItem.new("q", WIDTH),
		TextListItem.new("r", WIDTH),
		TextListItem.new("s", WIDTH),
		TextListItem.new("t", WIDTH),
		TextListItem.new("u", WIDTH),
		TextListItem.new("v", WIDTH),
		TextListItem.new("w", WIDTH),
		TextListItem.new("x", WIDTH),
		TextListItem.new("y", WIDTH),
		TextListItem.new("z", WIDTH),
	]
	var groups : Array[ TextListItem ] = [
		TextListItem.new("Entities", WIDTH, garbage),
		TextListItem.new("Regions", WIDTH),
		TextListItem.new("General", WIDTH),
	]
	root = TextListItem.new("Log Book", WIDTH, groups)
	root.show_children()
	root.display_list( self )

func _process(_delta: float) -> void:
	if root.dirty:
		root.dirty = false
		root.display_clear( self )
		root.display_list( self )

func _input(event: InputEvent) -> void:
	if not event is InputEventMouseButton or not event.pressed:
		return
	var local_pos = to_local(get_global_mouse_position())
	var tile_coords = local_to_map( local_pos )
	if root.mouse_not_over_map( tile_coords ):
		return
	
	if event.button_index == MOUSE_BUTTON_LEFT:
		root.on_mouse_click( tile_coords )
	elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
		scroll_offset += scroll_speed
	elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		scroll_offset -= scroll_speed
