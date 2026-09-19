extends Node2D

func _ready() -> void:
	GlobalSignals.room_transition_complete.connect(_on_player_settled)
	# Re-enable this if want the player to know the spawn location instantly, I say no since it can info overload :(
	#GlobalSignals.player_spawned.connect(_on_player_settled)

func _on_player_settled() -> void:
	var region := MSGroups.get_current_region()
	if region == &"NONE":
		return

	_collect_region_log(region)

func _collect_region_log(region: StringName) -> void:
	#You won't understand your sitation quite so easily.
	if region == "Limbo": region = "UNSS-Iliad"
	if not SaveManager.update_logbook(region):
		return
	MessageDisplay.add_log_pop_up("Region: %s" % region)
