extends Menu

@export var mainMenu : Control
@onready var loading_screen: ColorRect = $"../LoadingScreen"

#Return to main menu
func _on_main_menu_button_2_pressed() -> void:
	self.visible = false
	mainMenu.visible = true
	mainMenu.process_mode = Node.PROCESS_MODE_INHERIT
	self.process_mode = Node.PROCESS_MODE_DISABLED


func _quit_game() -> void:
	get_tree().quit()
	pass

#Reload from last checkpoint
func _on_main_menu_button_pressed() -> void:
	loading_screen.visible = true
	
	for item in mainGameObjects:
		item.process_mode = Node.PROCESS_MODE_INHERIT
		item.visible = true
		
	
	self.visible = false
	Game._init_metsys_and_objects()
	await Game._load_game()
	loading_screen.visible = false
	Game.isInGame = true
