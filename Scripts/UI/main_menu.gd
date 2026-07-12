extends Control


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func _start_game() -> void:
	SceneLoader.LoadScene("uid://5uhi1nn3ykxt")
	pass

func _load_game() -> void:
	pass

func _quit_game() -> void:
	get_tree().quit()
	pass
