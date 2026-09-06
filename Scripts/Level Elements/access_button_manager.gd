extends DoorTrigger

@export var button_name: String
@onready var icon_manager := $MonitorIconManager

signal OnButtonInteract

var has_been_collected := false

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	SaveManager.register_item(self, switch_to_activated_with_icon_manager)
	has_been_collected = SaveManager.is_item_collected(self)

func OnButtonInteraction(body: Node2D) -> void:
	if has_been_collected:
		return

	if body.is_in_group("player"):
		SaveManager.save_item(self)
		icon_manager.switch_to_activated()
		has_been_collected = true
		OnButtonInteract.emit()
		open_doors()

func switch_to_activated_with_icon_manager() -> void:
	icon_manager.switch_to_activated()

func _get_object_id() -> String:
	return button_name 
