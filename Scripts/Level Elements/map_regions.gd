## The regions of the station a map station can reveal.
##
## The short codes are the identity: they are what a map station lists in the
## inspector, what its display sprite is keyed by, and what goes in the save file.
## Because they are written down here rather than in the station's own script, the
## save can replay a reveal without a station being loaded -- which is what makes a
## revealed region survive a reload without depending on MetSys' discovered-cell
## bookkeeping round-tripping through the save file exactly.
##
## To add a region: add its code and its map-editor cell group name here, and add the
## code to the [code]@export_enum[/code] on the map station and to the sectors on the
## station's [code]MapDisplay[/code].
class_name MapRegions

## Region code [b]->[/b] the name of the MetSys cell group it reveals. The names have
## to match the group names in the MetSys map editor exactly.
const GROUP_NAMES : Dictionary[String, String] = {
	"DB": "Docking Bay",
	"CQ": "Crew Quarters",
	"BS": "BRS",
	"RS": "Maintainence",
	"OP": "Operations",
	"IL": "Internals",
}

## Every region code, in the order the map station's inspector lists them.
static func codes() -> Array:
	return GROUP_NAMES.keys()

static func is_code(code: String) -> bool:
	return GROUP_NAMES.has(code)

## Marks every cell of [param code]'s region as discovered. Safe to call again for a
## region already revealed -- MetSys only ever raises a cell's discovery level.
static func reveal(code: String) -> void:
	if not GROUP_NAMES.has(code):
		printerr("MapRegions: \"%s\" is not a region code." % code)
		return

	var group := MetSys.get_group_by_name(GROUP_NAMES[code])
	if group < 0:
		# get_group_by_name has already pushed an error naming the group.
		return
	if not group in MetSys.map_data.cell_groups:
		printerr("MapRegions: region \"%s\" (group \"%s\") has no cells on the map." % [code, GROUP_NAMES[code]])
		return
	MetSys.discover_cell_group(group)
