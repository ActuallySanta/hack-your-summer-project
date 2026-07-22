class_name EndMenu
extends Menu

signal go_to_main_menu()

@export var mainMenu : Control
@onready var loading_screen: ColorRect = $"../LoadingScreen"

#Return to main menu
func _on_main_menu_button_2_pressed() -> void:
	go_to_main_menu.emit()

func _quit_game() -> void:
	quit_game_pressed.emit()

#Reload from last checkpoint
func _on_main_menu_button_pressed() -> void:
	load_game_pressed.emit()
