extends Node2D

@export var region_map : Dictionary[ StringName, String ]
@export var event_map : Dictionary[ StringName, String ]

const LOG_BOOK_ACCESS := ".../Log Book/"
const REGIONS_ACCESS := LOG_BOOK_ACCESS + "Regions"
const EVENTS_ACCESS := LOG_BOOK_ACCESS + "Environment"

func _ready() -> void:
	GlobalSignals.room_transition_complete.connect(_on_player_settled)
	# Re-enable this if want the player to know the spawn location instantly, I say no since it can info overload :(
	#GlobalSignals.player_spawned.connect(_on_player_settled)
	GlobalSignals.player_spawned.connect(_match_list_to_save)

func _on_player_settled() -> void:
	var current_region := MSGroups.get_current_region()
	if current_region == &"NONE":
		return

	_collect_region_log( current_region )

func _collect_region_log(region: StringName) -> void:
	if region == "Limbo": region = "UNSS-Iliad"
	if not SaveManager.update_logbook(region): return
	MessageDisplay.add_log_pop_up("Region: %s" % region)
	_add_region_entry( region )

func _collect_lifeforms_log(creature_name: StringName) -> void:
	pass

func _add_region_entry(region: StringName) -> void:
	_add_entry(REGIONS_ACCESS, region, func(): ListDisplay.pause_panel.read_and_place( region_map[ region ] ))

func collect_event_log(log_name: StringName, event_display: String) -> void:
	if not SaveManager.update_logbook( log_name ): return
	MessageDisplay.add_log_pop_up( event_display )
	_add_event_entry( log_name )

func _add_event_entry(log_name: StringName) -> void:
	_add_entry(EVENTS_ACCESS, log_name, func(): ListDisplay.pause_panel.read_and_place( event_map[ log_name ] ))

func _add_entry(access: StringName, entry_name: StringName, callable: Callable) -> void:
	var item : TextListItem = ListDisplay.panel.root.insert_new_list_item_at(access + "/" + entry_name)
	item.is_unread = not SaveManager.is_logbook_entry_read( entry_name )
	item.on_click.connect( callable )
	# The item takes its own star off when clicked, so only the save has to be told
	item.on_click.connect( func(): SaveManager.read_logbook_entry( entry_name ) )

func _match_list_to_save() -> void:
	_match_group_to_save( REGIONS_ACCESS, region_map, _add_region_entry )
	_match_group_to_save( EVENTS_ACCESS, event_map, _add_event_entry )

## Makes one group of the log book hold exactly what the save has of its kind, no more and no less.
## The save keeps regions and events under the one logbook prefix, so which group an entry belongs
## in is answered by whose table names it.
func _match_group_to_save(access: String, logs: Dictionary[ StringName, String ], add_entry: Callable) -> void:
	var root : TextListItem = ListDisplay.panel.root
	var group := root.parse_path( access )
	if group != null:
		for entry in group.sub_lists.duplicate():
			if not SaveManager.check_logbook( entry.item_name ):
				root.remove_label_at( access + "/" + entry.item_name )
		if group.sub_lists.is_empty(): root.remove_label_at( access )

	# In the save's own order, which is the order they were found in
	for entry in SaveManager.get_logbook_entries():
		var log_name := StringName( entry )
		if logs.has( log_name ) and root.parse_path( access + "/" + log_name ) == null:
			add_entry.call( log_name )

	# An entry read since the last save goes back to unread with everything else a death undoes
	group = root.parse_path( access )
	if group == null: return
	for entry in group.sub_lists:
		entry.is_unread = not SaveManager.is_logbook_entry_read( entry.item_name )
