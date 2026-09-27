extends CanvasLayer

@onready var panel : ListDisplayName = $Panel
@onready var pause_panel := $PausePanel

var enabled : bool:
	set( new_value ):
		enabled = new_value
		panel.am_i_enabled = enabled
		pause_panel.enabled = enabled

var panel_open : bool = false

func _ready() -> void:
	panel.on_fully_hidden.connect( _disable_if_fully_hidden )
	pause_panel.on_fully_hidden.connect( _disable_if_fully_hidden )
	enabled = false

# The slide and the fade finish at different times, so whichever lands second turns the menu off
func _disable_if_fully_hidden() -> void:
	if panel.fully_hidden and pause_panel.fully_hidden: enabled = false

func toggle_menu() -> void:
	panel_open = not panel_open
	if panel_open: open_menu()
	else: close_menu()

func open_menu() -> void:
	enabled = true
	panel.open_menu()
	pause_panel.display( true )

func close_menu() -> void:
	panel.close_menu()
	pause_panel.display( false )

func is_open() -> bool:
	return panel.touchable
