extends Node

#region Which tiles have an unpowered form

const DOCKING_BAY_TILESET := preload("res://Tileset/DockingBay.tres")

const DOCKING_BAY_UNPOWERED := {
	Vector2i(6, 2): Vector2i(21, 5), # wall panel with an indicator light
	Vector2i(8, 5): Vector2i(20, 5), # small light, left-hand mount
	Vector2i(8, 6): Vector2i(20, 6), # small light, right-hand mount
	Vector2i(8, 7): Vector2i(20, 7), # ceiling dome lamp
	Vector2i(4, 12): Vector2i(13, 14),
	Vector2i(5, 12): Vector2i(14, 14),
	Vector2i(4, 13): Vector2i(13, 15),
	Vector2i(5, 13): Vector2i(14, 15),
	Vector2i(16, 17): Vector2i(20, 15),
}

## Every tileset that has unpowered artwork, and the tiles in it that have it. A
## tileset absent from this table is never read and never written, which is what
## keeps the swap to the docking bay.
const UNPOWERED_TILES := {
	DOCKING_BAY_TILESET: DOCKING_BAY_UNPOWERED,
}

#endregion

#region Tuning

## How the lights come back on: each entry is how long one stage holds, starting lit
## and flipping with every entry, always settling lit. Empty for an instant swap.
const POWER_ON_FLICKER : Array[float] = [0.06, 0.05, 0.04, 0.09, 0.13, 0.06]

#endregion

## Where a layer keeps the cells this swapped and what they were, so putting them
## back is a replay of what we did rather than a guess from the table read backwards.
## Held on the layer itself, so it is freed with the room and can never outlive it or
## be applied to the wrong one.
const SWAP_RECORD := &"station_power_swapped_cells"

## The bits of a cell's alternative id that encode flipping and transposing, which
## every tile supports. What is left is an index into the tile's own alternatives,
## which the twin may not have.
const TRANSFORM_MASK := TileSetAtlasSource.TRANSFORM_FLIP_H \
	| TileSetAtlasSource.TRANSFORM_FLIP_V \
	| TileSetAtlasSource.TRANSFORM_TRANSPOSE

## True from the moment the fuse goes in. Only ever ahead of the save, never behind
## it: [signal GlobalSignals.RestoreStationPower] reaches us before [GameManager] has
## written it down, and every spawn re-reads the save as the authority (see
## [method _on_player_spawned]), so a new game or a load cannot leave this stale.
var _power_restored := false

## Bumped by everything that starts or invalidates a flicker, so a run that is no
## longer wanted stops at its next stage instead of fighting whatever replaced it.
var _flicker := 0

func _ready() -> void:
	# Rooms are streamed in and out by MetSys, and a room's tiles have to already be
	# unlit the first time it is drawn or the lights show for a frame. Catching the
	# layers as they enter the tree is the last moment before that, and it covers
	# every way a room can arrive without any of them having to tell us.
	get_tree().node_added.connect(_on_node_added)
	GlobalSignals.RestoreStationPower.connect(_on_station_power_restored)
	GlobalSignals.player_spawned.connect(_on_player_spawned)
	_validate_table()

## Whether the station has power, and so whether tiles belong in their lit form.
func is_powered() -> bool:
	return _power_restored or GameManager.is_station_powered()

## Puts every loaded tile into the form the current power state calls for. Called on
## spawn, and available to anything that changes the world under us.
func refresh() -> void:
	# A flicker still running is describing a moment that has just been overtaken.
	_flicker += 1
	_apply_to_loaded_layers(is_powered())

func _on_node_added(node: Node) -> void:
	var layer := node as TileMapLayer
	if layer == null or _variants_for(layer).is_empty():
		return
	if not is_powered():
		_darken(layer)

## A spawn is where the save becomes the authority again: it is the one moment that
## follows both a load and a new game, and it lands before the load screen lifts, so
## a room that streamed in while we thought otherwise is corrected unseen.
func _on_player_spawned() -> void:
	_power_restored = GameManager.is_station_powered()
	refresh()

## Runs the lights up when the fuse goes in.
##
## Like [Darkness], this does not re-read [method GameManager.is_station_powered]:
## being an autoload we are connected to this signal before [GameManager] is, so the
## save still says unpowered while we run. The signal is the fact.
func _on_station_power_restored() -> void:
	_power_restored = true
	_flicker_on()

## The lights come on, stutter, and settle. Abandoned the moment anything else claims
## the world, leaving the state to whatever claimed it.
func _flicker_on() -> void:
	_flicker += 1
	var run := _flicker
	var lit := true
	for hold: float in POWER_ON_FLICKER:
		_apply_to_loaded_layers(lit)
		await get_tree().create_timer(hold).timeout
		if _flicker != run:
			return
		lit = not lit
	_apply_to_loaded_layers(true)

func _apply_to_loaded_layers(lit: bool) -> void:
	for node in get_tree().root.find_children("*", "TileMapLayer", true, false):
		var layer := node as TileMapLayer
		if _variants_for(layer).is_empty():
			continue
		if lit:
			_relight(layer)
		else:
			_darken(layer)

## The powered -> unpowered table covering [param layer], or an empty one for every
## layer this system leaves alone.
func _variants_for(layer: TileMapLayer) -> Dictionary:
	if layer.tile_set == null:
		return {}
	return UNPOWERED_TILES.get(layer.tile_set, {})

## Swaps every tile in [param layer] that has an unpowered twin for it, remembering
## what each cell held.
func _darken(layer: TileMapLayer) -> void:
	if layer.has_meta(SWAP_RECORD):
		return
	var variants := _variants_for(layer)
	var record := {}
	for coords in layer.get_used_cells():
		var atlas := layer.get_cell_atlas_coords(coords)
		if not variants.has(atlas):
			continue
		var source := layer.get_cell_source_id(coords)
		var twin: Vector2i = variants[atlas]
		var twin_source := _source_with_tile(layer.tile_set, source, twin)
		if twin_source < 0:
			continue # Reported by _validate_table(), rather than once per cell.
		var alternative := layer.get_cell_alternative_tile(coords)
		record[coords] = Vector4i(source, atlas.x, atlas.y, alternative)
		layer.set_cell(coords, twin_source, twin,
			_fit_alternative(layer.tile_set, twin_source, twin, alternative))
	if not record.is_empty():
		layer.set_meta(SWAP_RECORD, record)

## Puts back exactly what [method _darken] took, cell by cell.
##
## A cell that no longer holds the twin we put there has been claimed by something
## else since — a breakable crumbling, a door opening — and is left to it.
func _relight(layer: TileMapLayer) -> void:
	if not layer.has_meta(SWAP_RECORD):
		return
	var variants := _variants_for(layer)
	var record: Dictionary = layer.get_meta(SWAP_RECORD)
	for coords: Vector2i in record:
		var cell: Vector4i = record[coords]
		var atlas := Vector2i(cell.y, cell.z)
		if layer.get_cell_atlas_coords(coords) != variants.get(atlas):
			continue
		layer.set_cell(coords, cell.x, atlas, cell.w)
	layer.remove_meta(SWAP_RECORD)

## The id of the source [param tile_set] holds [param atlas] in, preferring
## [param preferred] so a tile keeps the source it was placed from — and with it that
## source's collision — whenever the twin was drawn into the same one.
##
## Sources sharing a texture are interchangeable this way, which is what lets a twin
## be added to a single source and still apply to tiles placed from any of them. A
## source with a different texture is never a candidate: the same coordinates point
## at an entirely different picture there.
func _source_with_tile(tile_set: TileSet, preferred: int, atlas: Vector2i) -> int:
	var origin := tile_set.get_source(preferred) as TileSetAtlasSource
	if origin == null:
		return -1
	if origin.has_tile(atlas):
		return preferred
	for i in tile_set.get_source_count():
		var id := tile_set.get_source_id(i)
		var source := tile_set.get_source(id) as TileSetAtlasSource
		if source and source.texture == origin.texture and source.has_tile(atlas):
			return id
	return -1

## The alternative id to carry over to [param atlas]. Flips and transposes always
## survive; an alternative the twin does not have is dropped rather than drawn as an
## error tile.
func _fit_alternative(tile_set: TileSet, source_id: int, atlas: Vector2i, alternative: int) -> int:
	var index := alternative & ~TRANSFORM_MASK
	if index == 0:
		return alternative
	var source := tile_set.get_source(source_id) as TileSetAtlasSource
	if source and source.has_alternative_tile(atlas, index):
		return alternative
	return alternative & TRANSFORM_MASK

#region Table validation
## Checks the table against the tilesets it names, once, at startup, and reports each
## entry that cannot work — a mistyped coordinate is otherwise invisible until you
## are standing in front of the tile it names, still lit.
##
## Collision is the one that bites: a lit tile that is part of the level's geometry,
## swapped for a twin without a collision polygon, opens a hole in the wall for as
## long as the power is off.
func _validate_table() -> void:
	if not OS.is_debug_build():
		return
	for tile_set: TileSet in UNPOWERED_TILES:
		var variants: Dictionary = UNPOWERED_TILES[tile_set]
		for atlas: Vector2i in variants:
			_validate_pair(tile_set, atlas, variants[atlas])

func _validate_pair(tile_set: TileSet, atlas: Vector2i, twin: Vector2i) -> void:
	var paired := false
	for i in tile_set.get_source_count():
		var id := tile_set.get_source_id(i)
		var source := tile_set.get_source(id) as TileSetAtlasSource
		if source == null or not source.has_tile(atlas):
			continue
		var twin_source := _source_with_tile(tile_set, id, twin)
		if twin_source < 0:
			# A source drawing from another texture holds an unrelated picture at
			# these coordinates, so it is no part of this pair and no fault either.
			continue
		if not paired and not _collides_alike(tile_set, id, atlas, twin_source, twin):
			push_warning("StationPowerTiles: the unpowered tile %s (source %d) does not collide like the tile %s (source %d) it stands in for, so that tile stops being solid while the power is off. Give it the same collision in the TileSet editor." % [twin, twin_source, atlas, id])
		paired = true
	if not paired:
		push_warning("StationPowerTiles: %s pairs the tile at %s with an unpowered tile at %s, but no source in it holds both, so that entry can never match." % [tile_set.resource_path, atlas, twin])

## Whether two tiles are solid in the same way, so that swapping one for the other
## cannot change what the player can stand on or walk through.
func _collides_alike(tile_set: TileSet, source_id: int, atlas: Vector2i, twin_source_id: int, twin: Vector2i) -> bool:
	var lit := (tile_set.get_source(source_id) as TileSetAtlasSource).get_tile_data(atlas, 0)
	var unlit := (tile_set.get_source(twin_source_id) as TileSetAtlasSource).get_tile_data(twin, 0)
	for physics_layer in tile_set.get_physics_layers_count():
		if lit.get_collision_polygons_count(physics_layer) != unlit.get_collision_polygons_count(physics_layer):
			return false
	return true
#endregion
