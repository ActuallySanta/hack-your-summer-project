extends CanvasLayer

@onready var panel : ListDisplayName = $Panel
@onready var pause_panel := $PausePanel

var enabled : bool:
	set( new_value ):
		enabled = new_value
		panel.am_i_enabled = enabled
		pause_panel.enabled = enabled

var panel_open : bool = false

## A pause pressed while a room transition still had the world clock, just through a door. The list
## refuses to open then, and the pause panel has to wait with it or it comes up on its own, so the
## whole menu waits and opens the moment the fade hands time back.
var _open_waiting : bool = false:
	set( new_value ):
		_open_waiting = new_value
		set_process( new_value )

func _ready() -> void:
	panel.on_fully_hidden.connect( _disable_if_fully_hidden )
	pause_panel.on_fully_hidden.connect( _disable_if_fully_hidden )
	panel.root.parse_path(".../Map").on_click.connect( pause_panel.show_map )
	enabled = false
	set_process( false )

func _process(_delta: float) -> void:
	open_menu()

# The slide and the fade finish at different times, so whichever lands second turns the menu off
func _disable_if_fully_hidden() -> void:
	if panel.fully_hidden and pause_panel.fully_hidden: enabled = false

func toggle_menu() -> void:
	panel_open = not panel_open
	if panel_open: open_menu()
	else: close_menu()

func open_menu() -> void:
	_open_waiting = not panel.open_menu()
	if _open_waiting: return
	enabled = true
	pause_panel.display( true )

func close_menu() -> void:
	_open_waiting = false
	panel.close_menu()
	pause_panel.display( false )

func is_open() -> bool:
	return panel.touchable
