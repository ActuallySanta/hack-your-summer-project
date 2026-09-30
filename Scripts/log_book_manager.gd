extends Node2D

@export var region_map : Dictionary[ StringName, String ]

const LOG_BOOK_ACCESS := ".../Log Book/"
const REGIONS_ACCESS := LOG_BOOK_ACCESS + "Regions"

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
	#You won't understand your sitation quite so easily.
	if region == "Limbo": region = "UNSS-Iliad"
	if not SaveManager.update_logbook(region):
		return
	MessageDisplay.add_log_pop_up("Region: %s" % region)
	_add_region_entry( region )

func _collect_lifeforms_log(creature_name: StringName) -> void:
	pass

func _add_region_entry(region: StringName) -> void:
	ListDisplay.panel.root.insert_new_list_item_at(REGIONS_ACCESS + "/" + region).on_click.connect( func(): ListDisplay.pause_panel.read_and_place( region_map[ region ] ) )

## Puts the Log Book back to what the save holds. The list lives on an autoload, so it outlives the
## save a death or a load swaps in, and would otherwise keep every entry logged since the last save
## station. A spawn follows every load and respawn, after the save is in place, so it runs here.
## Entries are taken out and put in one by one rather than the branch rebuilt, so a header the
## player left open stays open and the entry they were reading keeps its place.
func _match_list_to_save() -> void:
	var root : TextListItem = ListDisplay.panel.root
	var regions := root.parse_path( REGIONS_ACCESS )
	if regions != null:
		for entry in regions.sub_lists.duplicate():
			if not SaveManager.check_logbook( entry.item_name ):
				root.remove_label_at( REGIONS_ACCESS + "/" + entry.item_name )
		if regions.sub_lists.is_empty(): root.remove_label_at( REGIONS_ACCESS )

	# In the save's own order, which is the order they were found in
	for entry in SaveManager.get_logbook_entries():
		var region := StringName( entry )
		if region_map.has( region ) and root.parse_path( REGIONS_ACCESS + "/" + region ) == null:
			_add_region_entry( region )
