extends Node2D

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	MetSys.room_changed.connect( _on_room_change )
	print("connected safely")

func _collect_region_log(region: StringName) -> void:
	#TODO Implement system to log this data
	MessageDisplay.add_log_pop_up("Region: {region}")
	SaveManager.update_logbook( region )
	print("Updated")

func _on_room_change() -> void:
	print("Room changed")
	var region := MSGroups.get_current_region()
	if not SaveManager.check_logbook( region ):
		_collect_region_log( region )
