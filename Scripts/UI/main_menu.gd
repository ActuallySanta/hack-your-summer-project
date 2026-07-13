extends Control
class_name Menu

@export var mainGameObjects : Array[Node] 
@export var loadingScreen : ColorRect
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	for item in mainGameObjects:
		item.process_mode = Node.PROCESS_MODE_DISABLED
		item.visible = false
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass

func _start_game() -> void:
	Game.use_custom_save = false
	_transfer_to_game(true)
	pass

func _load_game() -> void:
	Game.use_custom_save = true
	_transfer_to_game(false)
	pass

func _quit_game() -> void:
	get_tree().quit()
	pass

func _transfer_to_game(_isNewGame: bool):
	loadingScreen.visible = true
	
	for item in mainGameObjects:
		item.process_mode = Node.PROCESS_MODE_INHERIT
		item.visible = true
		
	
	self.visible = false
	Game._init_metsys_and_objects()
	if(_isNewGame):
		await Game._new_game()
	else:
		await Game._load_game()
	loadingScreen.visible = false
	Game.isInGame = true
