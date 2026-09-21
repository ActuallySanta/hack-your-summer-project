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
	"_line_start_high" : Vector2i(17,8),
	"_line_continue_high" : Vector2i(18,8),
	"_line_end_high" : Vector2i(19,8),
	"_line_start" : Vector2i(17,9),
	"_line_continue" : Vector2i(18,9),
	"_line_end" : Vector2i(19,9),
	"_": INVALID_CHAR,
}

## Used for evil chars, or other visual assets that are pushed to the cursor
const INVALID_CHAR := Vector2i(18,7)

const EMPTY_CHAR = Vector2i(19,7)

## The left end, middle and right end pieces of a horizontal rule
const LINE_PIECES : Array[ String ] = [ "_line_start", "_line_continue", "_line_end" ]
const LINE_PIECES_HIGH : Array[ String ] = [ "_line_start_high", "_line_continue_high", "_line_end_high" ]

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

## The [start, middle, end] pieces of a horizontal rule in the shade the cursor is currently set to.
## Anything hand placing a single rule piece has to go through here, because the special chars skip
## the highlight lookup get_tile_coords_from_char() does for letters.
func get_line_pieces() -> Array[ String ]:
	return LINE_PIECES_HIGH if cursor_highlighted else LINE_PIECES

func go_to_next_line() -> void:
	cursor_pos.x = 0
	cursor_pos.y += 1

func place_line(size: int) -> void:
	var order := get_line_pieces()
	if size <= 0: return
	if size == 1:									# Too short for a start and an end, so just the middle piece
		place_char(order[ 1 ])
		return
	place_char(order[ 0 ])
	for i in size - 2: place_char(order[ 1 ])
	place_char(order[ 2 ])

func __out_command_error(command: String, expected: String) -> void:
	printerr("WARNING (text_display _parse_command): '", command, "' is missing a parameter, ", expected)

func _parse_command(sub_string: String) -> void:
	var split = sub_string.split("_")
	var cmd_name = split[ 0 ]
	split.remove_at( 0 )
	var cmd_prmt = split
	match cmd_name:
		"$":
			_destylize()
		"$HIGH":
			if cmd_prmt.is_empty():
				__out_command_error(sub_string, "expected $HIGH_ON or $HIGH_OFF")
				return
			set_hightlight(cmd_prmt[ 0 ] == "ON")
		"$NEWLINE":
			go_to_next_line()
		"$TAB":
			place_string( INDENT )
		"$HORIZONTALLINE":
			if cmd_prmt.is_empty():
				__out_command_error(sub_string, "expected a width, like $HORIZONTALLINE_12")
				return
			place_line( cmd_prmt[ 0 ].to_int())
#endregion

func cursor_at_title() -> bool:
	return cursor_pos.y == 0

func is_string_too_wide(string: String) -> bool:
	return cursor_pos.x + string.length() > (max_width_title if cursor_at_title() else max_width)

# Drawing is when you put stuff directly to the screen like images, manual texts, or list items
#region Drawing output
func draw_char_at(char_id: String, position_on_grid: Vector2i) -> void:
	set_cell(position_on_grid, 0, get_tile_coords_from_char(char_id, cursor_highlighted))
	
## Draws a horizontal rule [param size] cells wide with its left end at [param start].
## The drawing twin of place_line(): straight to the grid, so the text box rules the placing cursor
## obeys - the narrower title row, wrapping at max_width, max_height and tile_map_pos_offset - do not
## apply. Anything positioning itself absolutely wants this one.
## Pass [param capped_start] as false when the rule picks up a line that already started further
## left on the row, so it opens on the middle piece instead of a second left end.
func draw_line_at(start: Vector2i, size: int, capped_start: bool = true) -> void:
	var order := get_line_pieces()
	if size <= 0: return
	if size == 1:									# Too short for a start and an end, so just one piece
		draw_char_at(order[ 1 ] if capped_start else order[ 2 ], start)
		return
	draw_char_at(order[ 0 ] if capped_start else order[ 1 ], start)
	for i in size - 2:
		draw_char_at(order[ 1 ], start + Vector2i(i + 1, 0))
	draw_char_at(order[ 2 ], start + Vector2i(size - 1, 0))

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
		if cursor_pos.x - top_left.x > dimensions.x:
			cursor_pos.x = top_left.x
			cursor_pos.y += 1
			if cursor_pos.y - top_left.y >= dimensions.y:
				print("To many lines tall!")
				return false # We ran out of space while printing
		draw_char_at(character, cursor_pos)
		cursor_pos.x += 1
	cursor_pos = old_cursor
	return true

## How many lines draw_smart_text_at() will take to write [param string] into a box [param width] wide.
## Word wrapping means the raw length of the string no longer predicts this, so anything that needs to
## reserve vertical space has to ask here. Must be kept in step with draw_smart_text_at() below.
static func count_smart_text_lines(string: String, width: int) -> int:
	if width <= 0: return 0

	var lines := 1
	var line_x := 0
	for sub_string in string.split(" "):
		if line_x + sub_string.length() >= width:
			line_x = 0
			lines += 1
		line_x += sub_string.length() + 1
	return lines

## How many cells wide the first line of [param string] comes out when draw_smart_text_at() writes
## it into a box [param width] wide. Word wrapping decides where that line stops, so anything that
## wants to draw alongside the text has to ask here instead of measuring the string itself.
## Must be kept in step with draw_smart_text_at() below.
static func measure_smart_text_first_line(string: String, width: int) -> int:
	if width <= 0: return 0

	var line_x := 0
	for sub_string in string.split(" "):
		if line_x + sub_string.length() >= width: break	# This word wraps, so line one ended with the last one
		line_x += sub_string.length() + 1
	return maxi(line_x - 1, 0)							# Drop the trailing space the loop left room for

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
