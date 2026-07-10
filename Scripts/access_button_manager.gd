extends Node2D


# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	if MetSys.register_storable_object_with_marker(self): 
		queue_free()
		return

func _process(delta: float) -> void:
	pass

func OnButtonInteraction(body: Node2D) -> void:
	print("Test")
	if body.is_in_group("player"):
		MetSys.store_object(self)
		
