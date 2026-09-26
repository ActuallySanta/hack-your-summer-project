extends Node2D

@export var region_map : Dictionary[ StringName, String ]

const LOG_BOOK_ACCESS := ".../Log Book/"

func _ready() -> void:
	GlobalSignals.room_transition_complete.connect(_on_player_settled)
	# Re-enable this if want the player to know the spawn location instantly, I say no since it can info overload :(
	#GlobalSignals.player_spawned.connect(_on_player_settled)

func _on_player_settled() -> void:
	var current_region := MSGroups.get_current_region()
	if current_region == &"NONE":
		return

	_collect_region_log( current_region )

func _collect_region_log(region: StringName) -> void:
	#You won't understand your sitation quite so easily.
	if region == "Limbo": region = "UNSS-Iliad"
	if not SaveManager.update_logbook(region):
		return
	MessageDisplay.add_log_pop_up("Region: %s" % region)
	ListDisplay.panel.root.insert_new_list_item_at(LOG_BOOK_ACCESS + "Regions/" + region).on_click.connect( func(): ListDisplay.pause_panel.read_and_place( region_map[ region ] ) )

func _collect_lifeforms_log(creature_name: StringName) -> void:
	pass
