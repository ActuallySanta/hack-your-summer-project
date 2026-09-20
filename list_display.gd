extends TextDisplay

var root : TextListItem

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	var double_nested_children : Array[ TextListItem ] = [
		TextListItem.new("Chp 1", 15),
		TextListItem.new("Chp 2", 15),
		TextListItem.new("Chp 3", 15),
		TextListItem.new("Chp 4", 15),
		TextListItem.new("Chp 5", 15),
		TextListItem.new("Chp 6", 15),
	]
	var monsters_children : Array[ TextListItem ] = [
		TextListItem.new("The", 15),
		TextListItem.new("Quick", 15),
		TextListItem.new("Brown", 15),
		TextListItem.new("Fox", 15),
		TextListItem.new("_dot error Test?", 15),
		TextListItem.new("Jumped over the lazy dog", 15),
	]
	var children : Array[ TextListItem ] = [
		TextListItem.new("Monsters", 15, monsters_children),
		TextListItem.new("Book", 15, double_nested_children),
		TextListItem.new("Regions", 15),
	]

	root = TextListItem.new("Log Book", 15, children)
	root.show_children()
	children[1].show_children()
	root.display_list( self )

func _process(_delta: float) -> void:
	if root.dirty:
		root.dirty = false
		root.display_clear( self )
		root.display_list( self )

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var local_pos = to_local(get_global_mouse_position())
		var tile_coords = local_to_map( local_pos )
		root.on_mouse_click( tile_coords )
