extends CanvasLayer

@onready var panel : ListDisplayName = $Panel
@onready var pause_panel := $PausePanel

var panel_open : bool = false

func toggle_menu() -> void:
	panel_open = not panel_open
	if panel_open: open_menu()
	else: close_menu()

func open_menu() -> void:
	panel.open_menu()
	pause_panel.display( true )

func close_menu() -> void:
	panel.close_menu()
	pause_panel.display( false )

func is_open() -> bool:
	return panel.touchable
