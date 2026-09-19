## A data holder for items in a list
class_name TextListItem extends RefCounted
# Visual example:
# A textlistItem could be this:
# --------------
# V GroupHeader
# } > Here is a
# |   closed he
# |   ader.
# } Here is an
# | entry.
# \ Here is the
#    last entry 
# --------------
# Though it could also be a nested one like this:
# --------------
# V GroupHeader
# } V Here the 
# | | header is
# | | open.
# | \ Wow look 
# |   at this n
# |   ested ite
# |   m!
# } Here is an
# | entry.
# \ Here is the
#    last entry 
# --------------

const DROP_DOWN_OFFSET := Vector2i(1,0)
enum DropDownState { NOT, SHOW, HIDE }

## Gets the number of lines the text takes up
var height : int:
	get():
		var space_to_fill := list_max_width - hoizontal_offset - 1 # Minus one for list characters
		var raw_width := item_name.length()
		return (raw_width + space_to_fill - 1) / space_to_fill 	# A 22 character wide string with 4 wide space will be split across 8 lines, 
																# this is because 1 of those 4 spaces need to be used by a list char each line, limiting 
																# the width to only 3 per line. 22/3 is ~7.333, adding (space_to_fill - 1) extends this 
																# to the needed 8 lines while still letting 21/3 = 7 clean lines.

## What should be the horizontal offset what the left side of the screen
var hoizontal_offset : int
## The horizontal position of this item in the list
var vertical_offset : int

var start_pos : Vector2i:
	get():
		return Vector2i(hoizontal_offset, vertical_offset)

var super_list : TextListItem
var sub_lists : Array[ TextListItem ]
var item_name : String
var drop_down : DropDownState
var is_last_item : bool 

var list_max_width : int

#region Contrustors and linkers
func __out_constructor_error(msg: String) -> void:
	printerr("WARNING (TextListItem _make_child_of): ", msg)
	printerr("                             Data : Label: ", item_name, ", Parent: ", super_list.item_name if super_list else "NONE", " Max width: ", list_max_width)

func _init(label: String, max_width: int, child_lists: Array[ TextListItem ] = []) -> void:
	hoizontal_offset = 0
	vertical_offset = 0
	is_last_item = true
	list_max_width = max_width
	
	drop_down = DropDownState.NOT
	item_name = label
	sub_lists = [] # Must be its own array, not child_lists; make_parent_of() appends to it while we iterate child_lists.
	super_list = null
	
	for child in child_lists:
		make_parent_of( child )

func make_parent_of(child: TextListItem) -> void:
	if child == null: return
	
	if sub_lists.size() == 0: drop_down = DropDownState.HIDE
	else: sub_lists.back().is_last_item = false
	sub_lists.append( child )
	child._make_child_of( self )

func _make_child_of(parent: TextListItem) -> void:
	super_list = parent
	list_max_width -= super_list.hoizontal_offset + 1
	if list_max_width <= 0 or (drop_down != DropDownState.NOT and list_max_width <= 2): __out_constructor_error("You are making a list too nested for it's own good.")
	is_last_item = super_list.sub_lists.back() == self
	
	hoizontal_offset = super_list.hoizontal_offset + 1	# The horizontal offset is always just one more than the parents; this avoids a recursive implementation later down the line.
	vertical_offset = super_list.vertical_offset		# The vertical offset will always be at a minimum 1 more than the parents'
	vertical_offset += super_list.height				# The vertical offset needs to account for the parent's height
	for list_item in super_list.sub_lists:				# 1. Go through the parent's items
		if list_item == self: break						# 2. If I am the item we've found the offset from 0
		vertical_offset += list_item.height				# 3. Otherwise add the item's vertical offset

#endregion

#region Displayers
func display_list(display: TextDisplay) -> void:
	var display_hightlight_cache = display.cursor_highlighted
	display.set_hightlight( true )
	match drop_down:
		DropDownState.NOT: _display_plain_label( display )
		DropDownState.SHOW: _display_expanded( display )
		DropDownState.HIDE: _display_collasped( display )
	display.set_hightlight( display_hightlight_cache )

func _display_plain_label(display: TextDisplay) -> void:
	display.draw_smart_text_at(item_name, start_pos, Vector2i(list_max_width, 100))

func _display_list_connectors(display: TextDisplay, start_height: int, distance: int) -> void:
	print("Called")
	var start = start_pos + Vector2i(0,start_height)
	display.draw_char_at("_list_entry", start)
	for i in distance:
		display.draw_char_at("_list_pass", start + Vector2i(0,i+1))
		print(start_height + i+1)

func _display_expanded(display: TextDisplay) -> void:
	# Display the header
	_display_list_connectors(display, 0, height - 1)
	display.draw_char_at("_list_show", start_pos)
	display.draw_smart_text_at(item_name, start_pos + DROP_DOWN_OFFSET, Vector2i(list_max_width - 1, 100))
	# Display the children's list bar
	var total_height_travelled : int = height
	for child in sub_lists:
		_display_list_connectors(display, total_height_travelled, child.height - 1)
		total_height_travelled += child.height
	display.draw_char_at("_list_last", start_pos + Vector2i(0,total_height_travelled - 1))
	# Display the children themselves
	for child in sub_lists:
		child.display_list(display)
	
func _display_collasped(display: TextDisplay) -> void:
	display.draw_char_at("_list_hide", start_pos)
	display.draw_smart_text_at(item_name, start_pos + DROP_DOWN_OFFSET, Vector2i(list_max_width - 1, 100))
#endregion

#region Helpers
func show_children() -> void:
	if drop_down == DropDownState.HIDE: drop_down = DropDownState.SHOW
func hide_children() -> void:
	if drop_down == DropDownState.SHOW: drop_down = DropDownState.HIDE
func toggle_children() -> void:
	if drop_down == DropDownState.SHOW: drop_down = DropDownState.HIDE
	elif drop_down == DropDownState.HIDE: drop_down = DropDownState.SHOW
#endregion
