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
## What this item is when the cursor is elsewhere: open or closed for a header, and for a label
## whether it is the one the player is standing on. The cursor's own states are not kept here - a
## header has to stay SHOW while it is hovered or the whole list would fold up under the cursor -
## so the cursor is tracked on the root instead and display_state lays the two over each other.
var state : ItemState
var is_last_item : bool
var dirty : bool = false

## The item under the cursor, the one the button went down on, and the last label to have been
## clicked. Only the root's copies are ever read; a list has one cursor and one place the player is
## standing, so the items themselves have nothing to remember.
var hovered_item : TextListItem
var pressed_item : TextListItem
var active_item : TextListItem

## The top of this list, which holds everything the whole list shares
var root_item : TextListItem:
	get():
		return super_list.root_item if super_list else self

## Whether this item heads a sub-list, and so owns a drop-down arrow rather than a plain label
var is_header : bool:
	get():
		return not sub_lists.is_empty()

## Whether a click on this item would do anything: a header opens or closes itself, and a label
## needs someone listening on on_click. Everything else is inert text that the cursor ignores.
var is_interactive : bool:
	get():
		return is_header or not on_click.get_connections().is_empty()

## What this item is doing right now, the cursor included. The cursor's states sit on top of the
## resting one rather than replacing it, so a hovered open header is still an open header and a
## hovered active label is still the active one underneath.
var display_state : ItemState:
	get():
		var root := root_item
		if root.pressed_item == self: return ItemState.CLICK
		if root.hovered_item == self: return ItemState.HOVER
		return state

## Whether this item draws lit. The highlight answers one question - what is the cursor on - and
## nothing else earns it: not the active label, which has its rule to say where the player is
## standing, and not an open header, which has its arrow. A row reads the same way wherever it is
## in the list, so a lit one is always the one a click is about to hit.
var is_highlighted : bool:
	get():
		var shown := display_state
		return shown == ItemState.HOVER or shown == ItemState.CLICK

## Whether this item draws the rule that runs out to the right edge. That is the other question -
## where in the list the player is standing - and it belongs to the active label whether or not
## the cursor happens to be resting on it. A header never takes the mark, only opens and closes.
var is_ruled : bool:
	get():
		if is_header: return false
		return state == ItemState.ACTIVE or display_state == ItemState.CLICK

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
			root_item._forget( target )
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

## The rule under an open header, closing off everything it is holding. It is drawn lit whether or
## not the header itself is: this bar and a label's are the same mark in the same shade otherwise,
## and keeping it bright is what tells the two apart at a glance.
func _display_end_line(display: TextDisplay) -> void:
	var display_hightlight_cache = display.cursor_highlighted
	display.set_hightlight( true )
	display.draw_line_at(start_pos + Vector2i(0,height - 1), list_max_width)
	display.set_hightlight( display_hightlight_cache )

## Draws a label, and on the active one the rule that ties it to the right edge of the list.
## A label has no arrow of its own, so the rule opens in that empty column and picks up again where
## the text runs out, carrying the eye across the gap. On a label that wraps, only the first line is
## ruled: the arrow column and the trailing bar sit on the same top row, and the lines below it are
## left to the text. Both ends read the display's highlight, so a lit label gets a lit rule.
func _display_plain_label(display: TextDisplay) -> void:
	display.draw_smart_text_at(item_name, start_pos + DROP_DOWN_OFFSET, Vector2i(label_width, 100))
	if not is_ruled: return

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
# Every function in here is the root's to answer: the cursor belongs to the list as a whole, and
# only the root knows which line of which branch a screen row landed on.
func mouse_over_map(mouse_position: Vector2i) -> bool:
	return not(mouse_not_over_map(mouse_position))
func mouse_not_over_map(mouse_position: Vector2i) -> bool:
	return mouse_position.y < 0 or mouse_position.y >= lines.size() or mouse_position.x < 0 or mouse_position.x >= base_max_width

## The item the cursor can act on at [param mouse_position], or null for a dead spot.
## Two things count as dead: off the list entirely, and the columns to the left of the item's own,
## which are the branch lines its parents drew and belong to no label.
func item_at(mouse_position: Vector2i) -> TextListItem:
	if mouse_not_over_map( mouse_position ): return null
	var item : TextListItem = lines[ mouse_position.y ]
	if mouse_position.x < item.hoizontal_offset: return null
	return item if item.is_interactive else null

## Moves the hover to whatever the cursor is over, which may be nothing
func on_mouse_moved(mouse_position: Vector2i) -> void:
	_set_hovered_item( item_at( mouse_position ) )

## Drops the hover, for when the cursor leaves the list. The press is left armed so the button can
## still be brought back and released on the item it went down on.
func on_mouse_exited() -> void:
	_set_hovered_item( null )

func on_mouse_pressed(click_position: Vector2i) -> void:
	var item := item_at( click_position )
	if item == null: return
	pressed_item = item
	dirty = true

## Finishes a click, and answers whether one actually landed. Press and release have to land on
## the same item, so sliding off one before letting go calls the click off the way every other
## button does - and the caller is told, because a click that never happened should not be heard.
func on_mouse_released(click_position: Vector2i) -> bool:
	var item := pressed_item
	cancel_press()
	if item == null or item != item_at( click_position ): return false

	if item.is_header: item.toggle_children()
	else: _set_active_item( item )	# Only a label brings up a screen, so only a label moves where the player is
	item.on_click.emit()		# Emitted after the move, so a listener opening its screen finds the list already agreeing with it
	dirty = true
	return true

## Forgets a press without acting on it, for when the list stops taking input mid-click
func cancel_press() -> void:
	if pressed_item == null: return
	pressed_item = null
	dirty = true

func _set_hovered_item(item: TextListItem) -> void:
	if hovered_item == item: return
	hovered_item = item
	dirty = true

## Moves where the player is standing to [param item]. Unlike the cursor, this one is written into
## the items themselves, because being the active label is something an item goes on being rather
## than something the cursor is doing to it - so the label being left has to be put back to rest.
func _set_active_item(item: TextListItem) -> void:
	if active_item == item: return
	# A label that has grown children since is a header now, and its HIDE or SHOW outranks the rest
	if active_item != null and not active_item.is_header: active_item.state = ItemState.INACTIVE
	active_item = item
	if active_item != null: active_item.state = ItemState.ACTIVE
	dirty = true

## Drops every hold the root has on [param item], so a label taken out of the list cannot stay
## hovered, held down, or standing as the place the player is
func _forget(item: TextListItem) -> void:
	if hovered_item == item: hovered_item = null
	if pressed_item == item: pressed_item = null
	if active_item == item: _set_active_item( null )

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
