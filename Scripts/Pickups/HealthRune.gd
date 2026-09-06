extends Pickup

@export var do_float : bool = true

func _ready_after_setup() -> void:
	if not do_float:
		$HealthRuneImage.stop_anim = true

## Records this particular extender in the save before announcing it.
##
## The announcement used to be unconditional, and maximum health was a counter that
## went up every time one arrived. A pickup that reappeared -- because MetSys had only
## been told about it in memory and the run was never saved -- could then be taken
## again for another permanent point. Registering the id first makes the second take
## a no-op, and it is the same set the health component measures itself from, so the
## two can no longer drift apart.
func _on_collect() -> void:
	if SaveManager.register_health_upgrade(MetSys.get_object_id(self)):
		GlobalSignals.health_extended_by_one.emit()
