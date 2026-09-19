extends Node2D

## The region the last entry was taken for. [SaveManager] holds the real record; this
## is only here so the many room changes inside one region do not re-ask it every time.
var _last_region: StringName = &"NONE"

func _ready() -> void:
	GlobalSignals.room_transition_complete.connect(_on_player_settled)
	GlobalSignals.player_spawned.connect(_on_player_settled)

func _on_player_settled() -> void:
	var region := MSGroups.get_current_region()
	if region == &"NONE" or region == _last_region:
		return

	_last_region = region
	_collect_region_log(region)

func _collect_region_log(region: StringName) -> void:
	#TODO Implement system to log this data
	if not SaveManager.update_logbook(region):
		return
	MessageDisplay.add_log_pop_up("Region: %s" % region)
