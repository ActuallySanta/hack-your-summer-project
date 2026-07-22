extends Control
class_name Menu

signal start_game_pressed()
signal load_game_pressed()
signal quit_game_pressed()

func _start_game() -> void:
	start_game_pressed.emit()

func _load_game() -> void:
	load_game_pressed.emit()

func _quit_game() -> void:
	quit_game_pressed.emit()
