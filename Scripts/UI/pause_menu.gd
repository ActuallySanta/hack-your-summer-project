extends Control

signal doneResuming

func _ready() -> void:
	hide()

func Resume()->void:
	get_tree().paused = false
	hide()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	doneResuming.emit()
	GlobalSignals.OnGameResume.emit()

func Pause() ->void:
	get_tree().paused = true
	show()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	GlobalSignals.OnGamePause.emit()

func _input(event: InputEvent) -> void:
	if(event.is_action_pressed("pause")):
		if(get_tree().paused):
			Resume()
		else :
			Pause()


func _on_resume_button_pressed() -> void:
	Resume()

func _on_restart_button_pressed() -> void:
	Resume()
	
	await doneResuming
	get_tree().reload_current_scene()


func _on_quit_game_button_pressed() -> void:
	get_tree().quit()


func _on_return_to_main_menu_button_pressed() -> void:
	Resume()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	Game._hud.load_menu("uid://dbr2sfm8y3rni")
