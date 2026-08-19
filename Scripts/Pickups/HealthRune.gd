extends Pickup

@export var do_float : bool = true

func _ready_after_setup() -> void:
	if not do_float:
		$HealthRuneImage.stop_anim = true

func _on_collect() -> void:
	GlobalSignals.health_extended_by_one.emit()
