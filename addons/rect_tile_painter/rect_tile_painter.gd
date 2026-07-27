@tool
extends EditorPlugin

## Rect Tile Painter -- editor-only click-and-drag rectangle painting for
## TileMapLayer nodes.
##
## Select any TileMapLayer, flip "Rect Paint" on in the 2D viewport toolbar,
## then drag a box. The plugin walks every cell in the box, asks
## RectTileLayout which named piece belongs there, looks that name up in the
## dictionary, and offsets it by the 4x4 region origin you configured.
##
## Toggle it off and the TileMapLayer edits exactly like it always did -- the
## plugin stops consuming viewport input entirely.

const RectPaintToolbar := preload("res://addons/rect_tile_painter/rect_paint_toolbar.gd")

## Region choice belongs to the TILESET, not the layer -- every TileMapLayer
## sharing a tileset should share the setting. Keyed by tileset resource path.
const SETTINGS_PATH := "res://addons/rect_tile_painter/tileset_regions.cfg"

var _layer: TileMapLayer = null
var _toolbar: RectPaintToolbar = null
var _settings := ConfigFile.new()

var _dragging := false
var _erasing := false
var _start_cell := Vector2i.ZERO
var _end_cell := Vector2i.ZERO
var _hover_cell := Vector2i.ZERO
var _has_hover := false


func _enter_tree() -> void:
	_settings.load(SETTINGS_PATH)

	_toolbar = RectPaintToolbar.new()
	_toolbar.enabled_changed.connect(_on_enabled_changed)
	_toolbar.region_changed.connect(_on_region_changed)
	add_control_to_container(CONTAINER_CANVAS_EDITOR_MENU, _toolbar)
	_toolbar.hide()


func _exit_tree() -> void:
	if _toolbar != null:
		remove_control_from_container(CONTAINER_CANVAS_EDITOR_MENU, _toolbar)
		_toolbar.queue_free()
		_toolbar = null


func _get_plugin_name() -> String:
	return "Rect Tile Painter"


func _handles(object: Object) -> bool:
	return object is TileMapLayer


func _edit(object: Object) -> void:
	_cancel_drag()
	_layer = object as TileMapLayer
	_load_region_for_layer()
	_refresh_status()


func _make_visible(visible: bool) -> void:
	if _toolbar != null:
		_toolbar.visible = visible
	if not visible:
		_cancel_drag()
		_has_hover = false
		_layer = null


#region Input

func _forward_canvas_gui_input(event: InputEvent) -> bool:
	if _layer == null or _toolbar == null or not _toolbar.paint_enabled:
		return false
	if _layer.tile_set == null:
		return false

	if event is InputEventMouseButton:
		return _handle_mouse_button(event as InputEventMouseButton)

	if event is InputEventMouseMotion:
		return _handle_mouse_motion(event as InputEventMouseMotion)

	if event is InputEventKey and _dragging:
		var key := event as InputEventKey
		if key.pressed and key.keycode == KEY_ESCAPE:
			_cancel_drag()
			return true

	return false


func _handle_mouse_button(event: InputEventMouseButton) -> bool:
	var is_paint := event.button_index == MOUSE_BUTTON_LEFT
	var is_erase := event.button_index == MOUSE_BUTTON_RIGHT
	if not is_paint and not is_erase:
		return false

	if event.pressed:
		if _dragging:
			# Second button pressed mid-drag: treat as a cancel.
			_cancel_drag()
			return true
		_dragging = true
		_erasing = is_erase
		_start_cell = _cell_at(event.position)
		_end_cell = _start_cell
		update_overlays()
		return true

	if not _dragging:
		return false
	# Only the button that started the drag can finish it.
	if _erasing != is_erase:
		return true

	_end_cell = _cell_at(event.position)
	var rect := _current_rect()
	var was_erasing := _erasing
	_dragging = false
	_apply_rect(rect, was_erasing)
	update_overlays()
	return true


func _handle_mouse_motion(event: InputEventMouseMotion) -> bool:
	var cell := _cell_at(event.position)

	if _dragging:
		if cell != _end_cell:
			_end_cell = cell
			update_overlays()
		return true

	# Not dragging: keep a 1x1 cursor on screen but let other tools see the
	# event, so panning and the rest of the editor still feel normal.
	if not _has_hover or cell != _hover_cell:
		_hover_cell = cell
		_has_hover = true
		update_overlays()
	return false

#endregion


#region Painting

func _apply_rect(rect: Rect2i, erase: bool) -> void:
	if _layer == null or rect.size.x <= 0 or rect.size.y <= 0:
		return

	var before := _layer.tile_map_data
	var source_id := _toolbar.source_id
	var origin := _toolbar.region_origin
	var forced := _toolbar.forced_tile_name
	var missing: Array[String] = []

	for row in rect.size.y:
		for column in rect.size.x:
			var cell := rect.position + Vector2i(column, row)

			if erase:
				_layer.erase_cell(cell)
				continue

			var tile_name := forced
			if tile_name.is_empty():
				tile_name = RectTileLayout.tile_name_at(column, row, rect.size.x, rect.size.y)

			var coords := RectTileLayout.atlas_coords(tile_name, origin)
			if not _tile_exists(source_id, coords):
				if not missing.has(tile_name):
					missing.append(tile_name)
				continue

			_layer.set_cell(cell, source_id, coords, 0)

	var after := _layer.tile_map_data
	if after == before:
		_report_missing(missing)
		return

	# Roll back, then let undo/redo re-apply it so Ctrl+Z works and the scene
	# is marked dirty properly.
	_layer.tile_map_data = before

	var undo_redo := get_undo_redo()
	undo_redo.create_action(
		"Rect Tile Erase" if erase else "Rect Tile Paint",
		UndoRedo.MERGE_DISABLE,
		_layer
	)
	undo_redo.add_do_property(_layer, "tile_map_data", after)
	undo_redo.add_undo_property(_layer, "tile_map_data", before)
	undo_redo.commit_action()

	_report_missing(missing)


func _tile_exists(source_id: int, coords: Vector2i) -> bool:
	var tile_set := _layer.tile_set
	if tile_set == null or not tile_set.has_source(source_id):
		return false
	var atlas := tile_set.get_source(source_id) as TileSetAtlasSource
	if atlas == null:
		# Scene/mesh source -- nothing to validate against, let it through.
		return true
	return atlas.has_tile(coords)


func _report_missing(missing: Array[String]) -> void:
	if missing.is_empty():
		_refresh_status()
		return
	var origin := _toolbar.region_origin
	var details: Array[String] = []
	for tile_name in missing:
		details.append("%s -> %s" % [tile_name, RectTileLayout.atlas_coords(tile_name, origin)])
	push_warning(
		"Rect Tile Painter: source %d has no tile at %s. Skipped those cells."
		% [_toolbar.source_id, ", ".join(details)]
	)
	_toolbar.set_status("%d tile(s) missing -- see Output" % missing.size(), true)

#endregion


#region Overlay

func _forward_canvas_draw_over_viewport(overlay: Control) -> void:
	if _layer == null or _toolbar == null or not _toolbar.paint_enabled:
		return
		
	if _layer.tile_set == null:
		return
	
	if not _dragging and not _has_hover:
		return

	var rect := _current_rect() if _dragging else Rect2i(_hover_cell, Vector2i.ONE)
	var points := _rect_to_viewport_polygon(rect)
	var color := (
		Color(1.0, 0.42, 0.38) if _erasing and _dragging
		else Color(0.38, 0.78, 1.0)
	)
	var fill_alpha := 0.18 if _dragging else 0.07

	overlay.draw_colored_polygon(points, Color(color, fill_alpha))

	var outline := points.duplicate()
	outline.append(points[0])
	overlay.draw_polyline(outline, color, 2.0 if _dragging else 1.0)

	if not _dragging:
		return
	
	var font := overlay.get_theme_default_font()
	var label := "%d x %d" % [rect.size.x, rect.size.y]
	var anchor: Vector2 = points[0] + Vector2(2, -6)
	overlay.draw_string(font, anchor + Vector2.ONE, label, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0, 0, 0, 0.8))
	overlay.draw_string(font, anchor, label, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, color)


func _rect_to_viewport_polygon(rect: Rect2i) -> PackedVector2Array:
	var transform := _layer.get_viewport_transform() * _layer.get_global_transform()
	var half_tile := Vector2(_layer.tile_set.tile_size) * 0.5
	var top_left := _layer.map_to_local(rect.position) - half_tile
	var bottom_right := _layer.map_to_local(rect.end - Vector2i.ONE) + half_tile
	return PackedVector2Array([
		transform * top_left,
		transform * Vector2(bottom_right.x, top_left.y),
		transform * bottom_right,
		transform * Vector2(top_left.x, bottom_right.y),
	])

#endregion


#region Helpers

func _cell_at(viewport_position: Vector2) -> Vector2i:
	var transform := _layer.get_viewport_transform() * _layer.get_global_transform()
	return _layer.local_to_map(transform.affine_inverse() * viewport_position)


func _current_rect() -> Rect2i:
	var top_left := Vector2i(mini(_start_cell.x, _end_cell.x), mini(_start_cell.y, _end_cell.y))
	var bottom_right := Vector2i(maxi(_start_cell.x, _end_cell.x), maxi(_start_cell.y, _end_cell.y))
	return Rect2i(top_left, bottom_right - top_left + Vector2i.ONE)


func _cancel_drag() -> void:
	if _dragging:
		_dragging = false
		update_overlays()

#endregion


#region Per-tileset settings

func _settings_key() -> String:
	if _layer == null or _layer.tile_set == null:
		return ""
	var path := _layer.tile_set.resource_path
	return path if not path.is_empty() else "<builtin>"


func _load_region_for_layer() -> void:
	if _toolbar == null:
		return
	var key := _settings_key()
	if key.is_empty():
		_toolbar.set_region(0, Vector2i.ZERO)
		return
	var source_id := int(_settings.get_value(key, "source_id", 0))
	var origin_x := int(_settings.get_value(key, "origin_x", 0))
	var origin_y := int(_settings.get_value(key, "origin_y", 0))
	_toolbar.set_region(source_id, Vector2i(origin_x, origin_y))


func _on_region_changed(source_id: int, region_origin: Vector2i) -> void:
	var key := _settings_key()
	if not key.is_empty():
		_settings.set_value(key, "source_id", source_id)
		_settings.set_value(key, "origin_x", region_origin.x)
		_settings.set_value(key, "origin_y", region_origin.y)
		_settings.save(SETTINGS_PATH)
	_refresh_status()
	update_overlays()


func _on_enabled_changed(enabled: bool) -> void:
	if not enabled:
		_cancel_drag()
		_has_hover = false
	_refresh_status()
	update_overlays()


func _refresh_status() -> void:
	if _toolbar == null:
		return
	if not _toolbar.paint_enabled:
		_toolbar.set_status("")
		return
	if _layer == null or _layer.tile_set == null:
		_toolbar.set_status("No TileSet on this layer", true)
		return

	var source_id := _toolbar.source_id
	if not _layer.tile_set.has_source(source_id):
		_toolbar.set_status("Source %d not in this TileSet" % source_id, true)
		return

	var origin := _toolbar.region_origin
	var fill_coords := RectTileLayout.atlas_coords("Fill", origin)
	if not _tile_exists(source_id, fill_coords):
		_toolbar.set_status("No tile at Fill %s" % fill_coords, true)
		return

	_toolbar.set_status("4x4 @ %s ... %s" % [origin, origin + RectTileLayout.REGION_SIZE - Vector2i.ONE])

#endregion
