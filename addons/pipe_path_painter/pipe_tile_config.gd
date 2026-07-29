@tool
class_name PipeTileConfig
extends RefCounted

## Which atlas coordinate holds each of the 15 pipe shapes, for one TileSet.
##
## Unlike the rectangle painter there is no assumption that the shapes sit in
## a contiguous block, so every slot is stored individually. Saved per TileSet
## resource path, so configuring a tileset once covers every layer using it.

const UNSET := Vector2i(-1, -1)
const SETTINGS_PATH := "res://addons/pipe_path_painter/pipe_tiles.cfg"

var tileset_key := ""
var source_id := 0
var coords: Dictionary[String, Vector2i] = {}


static func load_for(key: String) -> PipeTileConfig:
	var config := PipeTileConfig.new()
	config.tileset_key = key
	if key.is_empty():
		return config

	var file := ConfigFile.new()
	if file.load(SETTINGS_PATH) != OK or not file.has_section(key):
		return config

	config.source_id = int(file.get_value(key, "source_id", 0))
	for tile_name: String in PipeTileLayout.NAME_TO_MASK:
		var stored: Variant = file.get_value(key, tile_name, UNSET)
		if stored is Vector2i:
			config.coords[tile_name] = stored
	return config


func save() -> void:
	if tileset_key.is_empty():
		return
	var file := ConfigFile.new()
	file.load(SETTINGS_PATH)
	file.set_value(tileset_key, "source_id", source_id)
	for tile_name: String in PipeTileLayout.NAME_TO_MASK:
		file.set_value(tileset_key, tile_name, get_coord(tile_name))
	file.save(SETTINGS_PATH)


func get_coord(tile_name: String) -> Vector2i:
	var coord: Vector2i = coords.get(tile_name, UNSET)
	return coord


func has_coord(tile_name: String) -> bool:
	return get_coord(tile_name) != UNSET


func set_coord(tile_name: String, coord: Vector2i) -> void:
	coords[tile_name] = coord


func clear_coord(tile_name: String) -> void:
	coords[tile_name] = UNSET


func assigned_count() -> int:
	var count := 0
	for tile_name: String in PipeTileLayout.NAME_TO_MASK:
		if has_coord(tile_name):
			count += 1
	return count


func slot_count() -> int:
	return PipeTileLayout.NAME_TO_MASK.size()


func is_complete() -> bool:
	return assigned_count() == slot_count()


## Reverse table, for reading shapes already painted on a layer. If the same
## coordinate is assigned to two slots the first one wins.
func coord_to_mask() -> Dictionary[Vector2i, int]:
	var map: Dictionary[Vector2i, int] = {}
	for tile_name: String in PipeTileLayout.NAME_TO_MASK:
		var coord := get_coord(tile_name)
		if coord != UNSET and not map.has(coord):
			map[coord] = PipeTileLayout.NAME_TO_MASK[tile_name]
	return map


## Slot name -> coord, for the atlas picker's "already taken" shading.
func coord_to_name() -> Dictionary[Vector2i, String]:
	var map: Dictionary[Vector2i, String] = {}
	for tile_name: String in PipeTileLayout.NAME_TO_MASK:
		var coord := get_coord(tile_name)
		if coord != UNSET and not map.has(coord):
			map[coord] = tile_name
	return map
