## Bullet selection contain all data necessary to draw a bullet point list
##
## Bullet Selections have a current of: Array[ last_element, current_element ] 
class_name TextBulletSelections extends TextSelection

func _init(_label: String, _start_pos: Vector2i, _items: Array[ String ], default: int = -1) -> void:
	label = _label
	start_pos = _start_pos
	items = _items
	if default != -1: make_selection( default )

func make_selection(culled_input: int) -> String:
	# Remove the first element if we have at least 2
	while current.size() >= 2: current.pop_front()
	current.push_back(culled_input)
	return items[ culled_input ]

func get_element_dimensions() -> Vector2i:
	# We can get the height by the number of items
	var dims : Vector2i = Vector2i(-1, items.size())
	# We get the width from the max length of the items plus the bullet point
	for i in items:
		if dims[ 0 ] < i.length() + 1:
			dims[ 0 ] = i.length() + 1 
	return dims
