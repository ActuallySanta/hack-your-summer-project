## TextDisplay is used to display custom fonts that use a tilemap
## 
## Can be used on any TileMapLayer, mess with the settings if you dare, by default equiped to handle the notification pop-up
class_name TextDisplay extends TileMapLayer
# It is okay for this class to be highly malluable at the expence of performance because optimally this should only do one pass through for a block of text

## The order chars appear in the texture
const LETTER_OFFSETS : String = "ABCDEFGHIJKLMNOPQRSTUVWXYZ?!.,:;/\"()[]1234567890-+%*#@`' "
## 'Tab' input
const INDENT : String = "   "
## A list of cordinates that have special chars in the tilemaplayer
const SPECIAL_OFFSETS : Dictionary[ String, Vector2i ] = {
	"_dot": Vector2i(16,4),
	"_circ": Vector2i(16,5),
	"_box": Vector2i(16,6),
	"_list_show" : Vector2i(16,7),
	"_list_hide" : Vector2i(17,7),
	"_list_entry" : Vector2i(16,8),
	"_list_pass" : Vector2i(16,9),
	"_list_last" : Vector2i(16,10),
	"_": INVALID_CHAR,
}

## Used for evil chars, or other visual assets that are pushed to the cursor
const INVALID_CHAR := Vector2i(18,7)

## Debug String used for testing
const DEBUG_DEEP_OUT : String = "_dot $TAB Testing $HIGH_ON Highlight $HIGH_OFF $NEWLINE ABCDEFGHIJKLMNOPQRSTUVWXYZ?!.,:;/\"()[]1234567890-+%*#@`' "

## The maximum rows of text that can be displayed
@export var max_height := 8
## The maximum cols of text that can be displayed
@export var max_width := 13
## The maximum cols of text that can be displayed on the title line
@export var max_width_title := 12
## The horizontal maximum of a group of tiles before the characters start going around to the next line
@export var tile_texture_width := 8
## The offset where the characters start appearing in the tilemap
@export var tile_index_offset := Vector2i(0,4)
## The position to start rendering Tiles at on the tilemap
@export var tile_map_pos_offset := Vector2i(0, 1)

var cursor_pos : Vector2i
var cursor_highlighted : bool

## Sets the cursor to a default state at the top left of the tilemap
func reset_cursor() -> void:
	cursor_pos = Vector2i.ZERO
	cursor_highlighted = false

func get_special(char_id: String) -> Vector2i:
	return SPECIAL_OFFSETS[ char_id ] if SPECIAL_OFFSETS.has( char_id ) else INVALID_CHAR

## Converts a char to a cordinate on the tileset
func get_tile_coords_from_char(char_id: String, is_highlight: bool) -> Vector2i:
	if char_id.begins_with("_"): return get_special( char_id )
	var index := LETTER_OFFSETS.findn( char_id )
	if index == -1: return INVALID_CHAR
	
	var x := index % tile_texture_width + tile_index_offset.x
	@warning_ignore("integer_division")
	var y := (index / tile_texture_width) + tile_index_offset.y
	if not is_highlight:
		x += tile_texture_width
	
	return Vector2i(x, y)

func _place_char_at_position(char_id: String, is_highlighted: bool, position_on_grid: Vector2i) -> void:
	set_cell(position_on_grid, 0, get_tile_coords_from_char(char_id, is_highlighted))

func get_cursor_height() -> int:
	return cursor_pos.y + 1

#region Commands
func turn_on_highlight() -> void:
	cursor_highlighted = true

func turn_off_highlight() -> void:
	cursor_highlighted = false

func _destylize() -> void:
	turn_off_highlight()

func set_hightlight(state: bool) -> void:
	cursor_highlighted = state

func go_to_next_line() -> void:
	cursor_pos.x = 0
	cursor_pos.y += 1
	
func _parse_command(sub_string: String) -> void:
	match sub_string:
		"$":
			_destylize()
		"$HIGH_ON":
			turn_on_highlight()
		"$HIGH_OFF":
			turn_off_highlight()
		"$NEWLINE":
			go_to_next_line()
		"$TAB":
			place_string( INDENT )
#endregion

func cursor_at_title() -> bool:
	return cursor_pos.y == 0

func is_string_too_wide(string: String) -> bool:
	return cursor_pos.x + string.length() > (max_width_title if cursor_at_title() else max_width)

# Drawing is when you put stuff directly to the screen like images, manual texts, or list items
#region Drawing output
func draw_char_at(char_id: String, position_on_grid: Vector2i) -> void:
	set_cell(position_on_grid, 0, get_tile_coords_from_char(char_id, cursor_highlighted))
	
func draw_text_at(string: String, top_left: Vector2i, dimensions: Vector2i, start_offset: Vector2i = Vector2i.ZERO) -> bool:
	# Example usage:
	#  +---+
	#  |   |
	#  +---+
	# Above is a textbox with top_left = (1,0), dimensions = (5,3)
	# The text "This is an example" would then display the following without error:
	#  This 
	#  is an
	#  examp
	# ---------
	# Alternatively, a box with these params: ("A second one wraps", (0,0),(7,4),(1,1)) does this:
	# +-----+ ->        
	# |     | ->  A Seco
	# |     | -> nd one 
	# +-----+ -> wraps   
	var old_cursor = cursor_pos
	cursor_pos = top_left + start_offset
	for character in string:
		# If we need to wrap
		if cursor_pos.x - top_left.x >= dimensions.x:
			cursor_pos.x = top_left.x
			cursor_pos.y += 1
			if cursor_pos.y - top_left.y >= dimensions.y:
				print("To many lines tall!")
				return false # We ran out of space while printing
		draw_char_at(character, cursor_pos)
		cursor_pos.x += 1
	cursor_pos = old_cursor
	return true

func draw_smart_text_at(string: String, top_left: Vector2i, dimensions: Vector2i) -> bool:
	var strings = string.split(" ")
	var cursor : Vector2i = top_left
	var end_cursor : Vector2i
	for sub_string in strings:
		if sub_string.length() >= dimensions.x:
			print("Used too big a word!")
			return false
		
		end_cursor = cursor + Vector2i(sub_string.length(),0)
		
		# Check if word is too long
		if end_cursor.x - top_left.x >= dimensions.x:
			cursor.x = top_left.x
			cursor.y += 1
			if cursor.y - top_left.y >= dimensions.y:
				print("To many lines tall! ", cursor.y - top_left.y, " is more than ", dimensions.y)
				return false # We ran out of space while printing
		
		# Draw word
		for character in sub_string:
			draw_char_at(character, cursor)
			cursor.x += 1
		
		# Add space
		cursor.x += 1
	return true
#endregion

# Placing is when you are treating the textDisplay like it is a text box, one char left to right, top to bottom
#region Placing output
func place_char(char_id: String) -> void:
	if cursor_pos.y == max_height:
		printerr("WARNING (text_display: 103): Max hight reached")
		return
	
	_place_char_at_position(char_id, cursor_highlighted, cursor_pos + tile_map_pos_offset)
	cursor_pos.x += 1
	# Go to next line
	if (cursor_at_title() and cursor_pos.x == max_width_title) or cursor_pos.x == max_width:
		go_to_next_line()

func place_string(string: String, replace_highlight: bool = false, highlight_word: bool = false) -> void:
	var old_highlight : bool = cursor_highlighted
	if replace_highlight:
		set_hightlight( highlight_word )
	# Handle strings too wide for one line
	if is_string_too_wide(string):
		go_to_next_line()
	
	# Place strings
	for chr in string:
		place_char(chr)
	
	if replace_highlight:
		set_hightlight(old_highlight)

func place_deep(string: String) -> void:
	var strings = string.split(" ")
	for sub_string in strings:
		if sub_string.begins_with("$"):
			_parse_command( sub_string )
			continue
		elif sub_string.begins_with("_"):
			place_char(sub_string)
			continue
		place_string(sub_string)
		place_char(" ")

func clear_screen() -> void:
	for y in max_height:
		for x in max_width:
			erase_cell(Vector2i(x,y) + tile_map_pos_offset)

func place_deep_fresh(string: String) -> void:
	reset_cursor()
	clear_screen()
	place_deep(string)
#endregion

func __debug_test() -> void:
	place_deep( DEBUG_DEEP_OUT )

func _ready() -> void:
	reset_cursor()
	__debug_test()
