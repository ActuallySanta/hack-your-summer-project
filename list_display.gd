extends TextDisplay

var root : TextListItem

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	var double_nested_children : Array[ TextListItem ] = [
		TextListItem.new("A", 15),
		TextListItem.new("B", 15),
		TextListItem.new("A", 15),
	]
	var children : Array[ TextListItem ] = [
		TextListItem.new("Child 1 that is long", 15),
		TextListItem.new("Child 2", 15, double_nested_children),
		TextListItem.new("Child 3", 15),
	]

	root = TextListItem.new("Test node that is long and is root node what is going on here", 15, children)
	root.show_children()
	root.display_list( self )
