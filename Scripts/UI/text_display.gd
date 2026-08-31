## TextDisplay is used to display custom fonts that use a tilemap
## 
## Can be used on any TileMapLayer, mess with the settings if you dare, by default equiped to handle the notification pop-up
class_name TextDisplay extends TileMapLayer


## The order chars appear in the texture
const LETTER_OFFSETS : String = "ABCDEFGHIJKLMNOPQRSTUVWXYZ?!.,:;/\"()[]1234567890 "
## 'Tab' input
const INDENT : String = "   "
## A list of cordinates that have special chars in the tilemaplayer
const SPECIAL_OFFSETS : Dictionary[ String, Vector2i ] = {
	"_dot": Vector2i(8,2),
	"_circ": Vector2i(8,3),
	"_box": Vector2i(12,3),
	"_ ": Vector2i.ZERO,
}

## Debug String used for testing
const DEBUG_DEEP_OUT : String = "_dot $TAB Testing $HIGH_ON Highlight $HIGH_OFF $NEWLINE ABCDEFGHIJKLMNOPQRSTUVWXYZ?!.,:;/\"()[]1234567890"

const DATA_LOG_ENTRY : String = "_dot $HIGH_ON New Data: $HIGH_OFF $NEWLINE"

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

## Converts a char to a cordinate on the tileset
func get_tile_coords_from_char(char_id: String, is_highlight: bool) -> Vector2i:
	if char_id.begins_with("_"):
		return SPECIAL_OFFSETS[ char_id ]
	var index := LETTER_OFFSETS.findn( char_id )
	var x := index % tile_texture_width + tile_index_offset.x
	@warning_ignore("integer_division")
	var y := (index / tile_texture_width) + tile_index_offset.y
	if not is_highlight:
		x += tile_texture_width
		
	
	return Vector2i(x, y)

func _place_char_at_position(char_id: String, is_highlighted: bool, position_on_grid: Vector2i) -> void:
	set_cell(position_on_grid, 0, get_tile_coords_from_char(char_id, is_highlighted))

#region Commands
func turn_on_highlight() -> void:
	cursor_highlighted = true

func turn_off_highlight() -> void:
	cursor_highlighted = false

func set_hightlight(state: bool) -> void:
	cursor_highlighted = state

func go_to_next_line() -> void:
	cursor_pos.x = 0
	cursor_pos.y += 1
	
func _parse_command(sub_string: String) -> void:
	match sub_string:
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

#region Placing output
func place_char(char_id: String) -> void:
	if cursor_pos.y == max_height:
		printerr("WARNING: Max hight reached")
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
#endregion

func debug_test() -> void:
	place_deep( DATA_LOG_ENTRY )

func _ready() -> void:
	reset_cursor()
	debug_test()
