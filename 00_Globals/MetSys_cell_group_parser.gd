class_name CellGroupParser extends Node

const REGION_IDENTIFIERS : Array[ StringName ] = [ "Crew Quarters", "Maintainence", "Internals", "BRS", "Docking Bay", "Operations", "Limbo" ]

func parse_special(group_name: StringName) -> PackedStringArray:
		if not group_name.begins_with( "_" ): return []
		var type : PackedStringArray = group_name.split("_", false, 1)
		return type

## Figure out what root region we are in; ignore suffix / descriptors
func parse_region(group_name: StringName) -> StringName:
	if group_name.begins_with("_"): return "NONE"
	for identifier in REGION_IDENTIFIERS:
		if group_name.begins_with(identifier):
			return identifier
	return "NONE"

## Given an array of group id's, find the cell's region
func get_region_from_groups(groups: PackedInt32Array) -> StringName:
	for group in groups:
		var group_name = MetSys.get_group_name(group)
		if group_name.begins_with("_"): continue
		return parse_region( group_name )
	return "NONE"

## Gets the groups of the current cell
func get_current_room_groups() -> PackedInt32Array:
	# Error checking
	if MetSys.current_room == null: return []
	var current_cells := MetSys.current_room.cells
	if current_cells.is_empty(): return []
	var groups := MetSys.get_cell_groups(current_cells[0])
	if groups.is_empty(): return []
	
	return groups 

## Gets the current region with no data input
func get_current_region() -> StringName:
	return get_region_from_groups( get_current_room_groups() )
