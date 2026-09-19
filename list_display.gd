extends TextDisplay

var root : TextListItem

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	var children : Array[ TextListItem ] = [
		TextListItem.new("Child 1", 15),
		TextListItem.new("Child 2", 15),
		TextListItem.new("Child 3", 15),
	]
	root = TextListItem.new("Test label that I am going to use as the root node", 15, children)
	
	root.display_list( self )
	print("drawed")
