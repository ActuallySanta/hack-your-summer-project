## A data holder for items in a list
class_name TextListItem extends RefCounted
# Visual example:
# A textlistItem could be this:
# --------------
# V GroupHeader
# } > Here is a
# |   closed   
# |   header.  
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
# |   at this 
# |   nested 
# |   item!
# } Here is an
# | entry.
# \ Here is the
#    last entry 
# --------------

signal on_click
const DROP_DOWN_OFFSET := Vector2i(1,0)
## Every state a list item can rest in. An item that heads a sub-list uses HIDE and SHOW for whether
## that list is open; every other item uses the four interaction states. The two sets never meet
## because whether an item is a header is answered by is_header, not by the state it is sitting in.
enum ItemState { INACTIVE, HOVER, CLICK, ACTIVE, HIDE, SHOW }

var super_list : TextListItem
var sub_lists : Array[ TextListItem ]
var item_name : String
var state : ItemState
var is_last_item : bool
var dirty : bool = false

## Whether this item heads a sub-list, and so owns a drop-down arrow rather than a plain label
var is_header : bool:
	get():
		return not sub_lists.is_empty()

## Whether this item draws lit: an open header, or a label the mouse is on or has picked
var is_highlighted : bool:
	get():
		return state != ItemState.INACTIVE and state != ItemState.HIDE

## The width the whole list has to fit in. Only the root's copy is ever read; children walk up to it.
var base_max_width : int

## The space this item has to work with, from its own column across to the right edge
var list_max_width : int:
	get():
		return super_list.list_max_width - 1 if super_list else base_max_width

## The width the label itself gets, once the list character in the item's own column is taken out
var label_width : int:
	get():
		return list_max_width - 1

## Gets the number of lines the text takes up
var height : int:
	get():
		return TextDisplay.count_smart_text_lines( item_name, label_width ) + 1

## The lines this item claims on screen in total, including any children it is currently showing
var total_height : int:
	get():
		if state != ItemState.SHOW: return height
		var total := height
		for child in sub_lists:
			total += child.total_height
		return total

## What should be the horizontal offset what the left side of the screen
var hoizontal_offset : int:
	get():
		return super_list.hoizontal_offset + 1 if super_list else 0	# Always just one more than the parent's; this avoids a recursive implementation later down the line.

## The vertical position of this item in the list
var vertical_offset : int:
	get():
		if super_list == null: return 0
		var offset : int = super_list.vertical_offset + super_list.height	# Start below every line of the parent's own label
		for list_item in super_list.sub_lists:								# 1. Go through the parent's items
			if list_item == self: break										# 2. If I am the item we've found the offset from 0
			offset += list_item.total_height								# 3. Otherwise clear the whole sibling, expanded children and all
		return offset

var lines : Array[ TextListItem ]:
	get():
		var items : Array[ TextListItem ]
		for i in height: items.append( self )						# Append entry for line I take up
		if state != ItemState.SHOW: return items					# If I'm closed return myself
		for child in sub_lists: items.append_array( child.lines )	# Otherwise add the items of my children
		return items

var start_pos : Vector2i:
	get():
		return Vector2i(hoizontal_offset, vertical_offset)

#region Contrustors and linkers
func __out_constructor_error(msg: String) -> void:
	printerr("WARNING (TextListItem _make_child_of): ", msg)
	printerr("                                Data : Label: ", item_name, ", Parent: ", super_list.item_name if super_list else "NONE", " Max width: ", list_max_width)

func _init(label: String, max_width: int, child_lists: Array = []) -> void:
	is_last_item = true
	base_max_width = max_width

	state = ItemState.INACTIVE
	item_name = label
	sub_lists = [] # Must be its own array, not child_lists; make_parent_of() appends to it while we iterate child_lists.
	super_list = null
	
	for child in child_lists:
		if child is TextListItem:
			make_parent_of( child )
		elif child is String:
			insert_new_list_item_at( child )

func make_parent_of(child: TextListItem) -> void:
	if child == null: return
	
	if sub_lists.size() == 0: state = ItemState.HIDE	# This first child turns a plain label into a closed header
	else: sub_lists.back().is_last_item = false
	sub_lists.append( child )
	child._make_child_of( self )

func _make_child_of(parent: TextListItem) -> void:
	super_list = parent
	is_last_item = super_list.sub_lists.back() == self
	if label_width <= 0: __out_constructor_error("You are making a list too nested for it's own good.")

func remove_label_at(label: String) -> TextListItem:
	var last_path_marker = label.rfind("/")
	var path = label.substr(0, last_path_marker)
	var label_name = label.substr(last_path_marker + 1)
	var holder := parse_path(path) if last_path_marker != -1 else self
	var nodes := holder.sub_lists

	for i in nodes.size():
		if nodes[ i ].item_name == label_name:
			var target = nodes[ i ]
			target.super_list = null
			nodes.remove_at( i )
			if nodes.is_empty(): holder.state = ItemState.INACTIVE	# Nothing left to head, so it is a plain label again
			return target
	return null

func insert_new_list_item_at(label: String) -> TextListItem:
	var last_path_marker = label.rfind("/")
	if last_path_marker == -1:
		return insert_new_list_item(label)
	var path = label.substr(0, last_path_marker)
	var label_name = label.substr(last_path_marker + 1)
	return parse_path( path ).insert_new_list_item( label_name )

func insert_new_list_item(label: String) -> TextListItem:
	var child := new(label, base_max_width)
	make_parent_of( child )
	dirty = true
	return child

func insert_list_item(child: TextListItem) -> TextListItem:
	make_parent_of(child)
	dirty = true
	return child

#endregion

#region Displayers
func display_clear(display: TextDisplay) -> void:
	if super_list != null:
		super_list.display_clear(display)
		return
	
	for y in 200:
		for x in base_max_width:
			display.set_cell(Vector2i(x,y), 0, display.EMPTY_CHAR)
	
func display_list(display: TextDisplay) -> void:
	var display_hightlight_cache = display.cursor_highlighted
	display.set_hightlight( is_highlighted )
	if not is_header: _display_plain_label( display )
	elif state == ItemState.SHOW: _display_expanded( display )
	else: _display_collasped( display )
	display.set_hightlight( display_hightlight_cache )

func _display_end_line(display: TextDisplay) -> void:
	display.draw_line_at(start_pos + Vector2i(0,height - 1), list_max_width)

## Draws a label and the rule that ties it to the right edge of the list.
## A label has no arrow of its own, so the rule opens in that empty column and picks up again where
## the text runs out, carrying the eye across the gap. On a label that wraps, only the first line is
## ruled: the arrow column and the trailing bar sit on the same top row, and the lines below it are
## left to the text. Both ends read the display's highlight, so a lit label gets a lit rule.
func _display_plain_label(display: TextDisplay) -> void:
	display.draw_smart_text_at(item_name, start_pos + DROP_DOWN_OFFSET, Vector2i(label_width, 100))

	var first_line_width := TextDisplay.measure_smart_text_first_line(item_name, label_width)
	display.draw_char_at(display.get_line_pieces()[ 0 ], start_pos)
	display.draw_line_at(start_pos + DROP_DOWN_OFFSET + Vector2i(first_line_width, 0), label_width - first_line_width, false)	# Uncapped: the piece before the label already opened this rule

func _display_list_connectors(display: TextDisplay, start_height: int, distance: int) -> void:
	var start = start_pos + Vector2i(0,start_height)
	display.draw_char_at("_list_entry", start)
	for i in distance:
		display.draw_char_at("_list_pass", start + Vector2i(0,i+1))

func _display_expanded(display: TextDisplay) -> void:
	# Display the header
	_display_list_connectors(display, 0, height - 1)
	display.draw_char_at("_list_show", start_pos)
	display.draw_smart_text_at(item_name, start_pos + DROP_DOWN_OFFSET, Vector2i(label_width, 100))

	# Display the children
	var total_height_travelled : int = height
	for child in sub_lists:
		if child.is_last_item:
			display.draw_char_at("_list_last", start_pos + Vector2i(0,total_height_travelled))
		else:
			_display_list_connectors(display, total_height_travelled, child.total_height - 1)
		child.display_list(display)
		total_height_travelled += child.total_height
	_display_end_line(display)

func _display_collasped(display: TextDisplay) -> void:
	display.draw_char_at("_list_hide", start_pos)
	display.draw_smart_text_at(item_name, start_pos + DROP_DOWN_OFFSET, Vector2i(label_width, 100))
#endregion

#region Mouse Click Handling
func mouse_over_map(mouse_position: Vector2i) -> bool:
	return not(mouse_not_over_map(mouse_position))
func mouse_not_over_map(mouse_position: Vector2i) -> bool:
	return mouse_position.y < 0 or mouse_position.y >= lines.size() or mouse_position.x < 0 or mouse_position.x >= base_max_width

func on_mouse_click(click_position: Vector2i) -> void:
	var item_clicked = lines[ click_position.y ]
	if item_clicked.is_header:
		item_clicked.toggle_children()
	item_clicked.on_click.emit()
	dirty = true

#endregion

#region Helpers
func parse_path(path: String) -> TextListItem:
	#Example:
	# Input: (../../Something/Else/Here) called on "Is here*" node, given:
	#
	# Root
	#  Something
	#   Else
	#    Here*
	#  A thing
	#   Is here*
	#
	# would return "Here*" node
	var nodes := path.split("/", false)
	var current_node := self
	for node in nodes:
		current_node = current_node.super_list if node == ".." else current_node.find_child( node )
		if current_node == null:
			return null
	return current_node

func find_child(label: String) -> TextListItem:
	for child in sub_lists:
		if child.item_name == label:
			return child
	return null

func show_children() -> void:
	if state == ItemState.HIDE: state = ItemState.SHOW
func hide_children() -> void:
	if state == ItemState.SHOW: state = ItemState.HIDE
func toggle_children() -> void:
	if state == ItemState.SHOW: state = ItemState.HIDE
	elif state == ItemState.HIDE: state = ItemState.SHOW
#endregion
