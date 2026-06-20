extends Node

@export var nodeToSwitchTo : Control
@export var menuNode : Control
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta: float) -> void:
	pass


func _on_main_menu_button_pressed() -> void:
	nodeToSwitchTo.visible = true
	nodeToSwitchTo.process_mode = Node.PROCESS_MODE_INHERIT
	menuNode.visible = false
	menuNode.process_mode = Node.PROCESS_MODE_DISABLED
