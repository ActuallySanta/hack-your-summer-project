extends Node2D

@export var button_name: String
@onready var icon_manager := $MonitorIconManager

var has_been_collected := false

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	if MetSys.register_storable_object_with_marker(self, switch_to_activated_with_icon_manager):
		has_been_collected = true
		return

func OnButtonInteraction(body: Node2D) -> void:
	if has_been_collected: 
		return
		
	if body.is_in_group("player"):
		MetSys.store_object(self)
		icon_manager.switch_to_activated()
		has_been_collected = true

func switch_to_activated_with_icon_manager() -> void:
	icon_manager.switch_to_activated()

func _get_object_id() -> String:
	return button_name 
