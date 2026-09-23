class_name PausePanel extends Node2D

const SCROLL_BAR_SIZE := 26
const TILE_SIZE := 8
const CONTENT_LINE_COUNT : int = 28

@onready var constants := $Constants
@onready var content := $Content
@onready var click_box := $ClickBox
@onready var scroll_interactable := $ScrollInteractable

var read_output : String = "$TAB $AUTO_1028"
var text_line_count : int = 0
var file_height : int = 3

func _ready() -> void:
	click_box.on_mouse_held.connect( on_mouse_hold )
	constants.draw_scroll_bar(Vector2i(29, SCROLL_BAR_SIZE), TextElement.Axis.Vertical, SCROLL_BAR_SIZE, 1000)
	scroll_interactable.on_mouse_pressed.connect( func(): click_box.was_pressed = true )
	read_and_place( "res://Logs/Docking-Bay.txt" )

func _process(_delta: float) -> void:
	pass

func read_and_place(file_name: String) -> void:
	if not FileAccess.file_exists(file_name):
		printerr("Warning (pause_panel, 27): File does not exist")
		return
	var file = FileAccess.open(file_name, FileAccess.READ)
	read_output = file.get_as_text()
	file.close()
	content.place_deep( read_output )
	text_line_count = content.get_lines_placed()		
	@warning_ignore("integer_division")
	file_height = max(text_line_count + 3 - CONTENT_LINE_COUNT / 2, 0)

func print_screen_percent_line() -> void:
	print( int( file_height * click_box.get_mouse_percent().y ) )

func on_mouse_hold() -> void:
	constants.draw_scroll_bar(Vector2i(29, SCROLL_BAR_SIZE), TextElement.Axis.Vertical, SCROLL_BAR_SIZE, constants._get_scroll_bar_quarters_from_percent(SCROLL_BAR_SIZE, 1 - click_box.get_mouse_percent().y))
	var offset: int = int( file_height * click_box.get_mouse_percent().y )
	content.position.y = -TILE_SIZE * clamp(offset, 0, file_height)
