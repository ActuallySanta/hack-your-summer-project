extends Control

#Return to main menu
func _on_main_menu_button_2_pressed() -> void:
	SceneLoader.LoadScene("uid://dbr2sfm8y3rni")


func _quit_game() -> void:
	get_tree().quit()
	pass

#Reload from last checkpoint
func _on_main_menu_button_pressed() -> void:
	SceneLoader.LoadScene("uid://5uhi1nn3ykxt")
	pass # Replace with function body.
