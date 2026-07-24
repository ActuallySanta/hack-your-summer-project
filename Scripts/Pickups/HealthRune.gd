extends Pickup

func _ready_after_setup() -> void:
	pass

func _on_collect() -> void:
	GlobalSignals.health_extended_by_one.emit()
