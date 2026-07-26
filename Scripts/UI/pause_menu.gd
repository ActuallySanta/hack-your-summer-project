class_name PauseMenu extends Control

signal resume_pressed
signal restart_pressed
signal quit_pressed
signal main_menu_pressed

func _ready() -> void:
	hide()

func _on_resume_button_pressed() -> void:
	resume_pressed.emit()

func _on_restart_button_pressed() -> void:
	restart_pressed.emit()

func _on_quit_game_button_pressed() -> void:
	quit_pressed.emit()

func _on_return_to_main_menu_button_pressed() -> void:
	main_menu_pressed.emit()
