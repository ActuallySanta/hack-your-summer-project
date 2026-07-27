@tool
extends EditorPlugin

## Pipe Path Painter -- editor-only click-and-drag path painting for
## TileMapLayer nodes.
##
## Drag freehand and the trail is snapped to 90-degree turns; hold Shift and
## it becomes a straight A-to-B run instead (Alt swaps which axis it travels
## first). Every cell the path touches is resolved to a connection mask, ORed
## with whatever is already on the layer, and looked up in the 15-shape table.
## That single OR is what turns a horizontal run crossing a vertical pipe into
## a four-way instead of overwriting it.
##
## Toggle it off and the TileMapLayer edits exactly like it always did.

const PipePathToolbar := preload("res://addons/pipe_path_painter/pipe_path_toolbar.gd")
const PipeTileConfigDialog := preload("res://addons/pipe_path_painter/pipe_tile_config_dialog.gd")

## Shared latch so the rectangle painter and this one can't both swallow the
## same drag. Whichever tool is switched on last owns the viewport.
const ACTIVE_TOOL_META := "tile_paint_active_tool"
const TOOL_ID := "pipe_path"

const PAINT_COLOR := Color(0.42, 0.85, 1.0)
const ERASE_COLOR := Color(1.0, 0.42, 0.38)
const MISSING_COLOR := Color(1.0, 0.78, 0.25)

var _layer: TileMapLayer = null
var _toolbar: PipePathToolbar = null
var _dialog: PipeTileConfigDialog = null
var _config := PipeTileConfig.new()

var _dragging := false
var _erasing := false
## Committed freehand trail. In line mode the previewed leg is not folded in
## here until Shift is released or the drag ends.
var _path: Array[Vector2i] = []
var _cursor_cell := Vector2i.ZERO
var _has_hover := false
var _line_mode := false
var _vertical_first := false


func _enter_tree() -> void:
	_toolbar = PipePathToolbar.new()
	_toolbar.enabled_changed.connect(_on_enabled_changed)
	_toolbar.configure_requested.connect(_open_config_dialog)
	add_control_to_container(CONTAINER_CANVAS_EDITOR_MENU, _toolbar)
	_toolbar.hide()


func _exit_tree() -> void:
	if _dialog != null:
		_dialog.queue_free()
		_dialog = null
	if _toolbar != null:
		remove_control_from_container(CONTAINER_CANVAS_EDITOR_MENU, _toolbar)
		_toolbar.queue_free()
		_toolbar = null


func _get_plugin_name() -> String:
	return "Pipe Path Painter"


func _handles(object: Object) -> bool:
	return object is TileMapLayer


func _edit(object: Object) -> void:
	_cancel_drag()
	_layer = object as TileMapLayer
	_reload_config()


func _make_visible(visible: bool) -> void:
	if _toolbar != null:
		_toolbar.visible = visible
	if not visible:
		_cancel_drag()
		_has_hover = false
		_layer = null


#region Activation

func _is_active() -> bool:
	if _layer == null or _toolbar == null or not _toolbar.paint_enabled:
		return false
	if Engine.has_meta(ACTIVE_TOOL_META) and str(Engine.get_meta(ACTIVE_TOOL_META)) != TOOL_ID:
		# Another tile tool took the viewport -- stand down rather than fight.
		_toolbar.force_disable()
		_cancel_drag()
		return false
	return _layer.tile_set != null


func _on_enabled_changed(enabled: bool) -> void:
	if enabled:
		Engine.set_meta(ACTIVE_TOOL_META, TOOL_ID)
	else:
		_cancel_drag()
		_has_hover = false
		if Engine.has_meta(ACTIVE_TOOL_META) and str(Engine.get_meta(ACTIVE_TOOL_META)) == TOOL_ID:
			Engine.set_meta(ACTIVE_TOOL_META, "")
	_refresh_status()
	update_overlays()

#endregion


#region Input

func _forward_canvas_gui_input(event: InputEvent) -> bool:
	if not _is_active():
		return false

	if event is InputEventKey:
		return _handle_key(event as InputEventKey)
	if event is InputEventMouseButton:
		return _handle_mouse_button(event as InputEventMouseButton)
	if event is InputEventMouseMotion:
		return _handle_mouse_motion(event as InputEventMouseMotion)
	return false


func _handle_key(event: InputEventKey) -> bool:
	if _dragging and event.pressed and event.keycode == KEY_ESCAPE:
		_cancel_drag()
		return true

	if event.keycode == KEY_SHIFT or event.keycode == KEY_ALT:
		# Modifier flags on the event itself already reflect press vs release,
		# so the preview can react without the mouse moving.
		_set_modifiers(event.shift_pressed, event.alt_pressed)
		return _dragging

	return false


func _handle_mouse_button(event: InputEventMouseButton) -> bool:
	var is_paint := event.button_index == MOUSE_BUTTON_LEFT
	var is_erase := event.button_index == MOUSE_BUTTON_RIGHT
	if not is_paint and not is_erase:
		return false

	if event.pressed:
		if _dragging:
			_cancel_drag()
			return true
		_set_modifiers(event.shift_pressed, event.alt_pressed)
		_dragging = true
		_erasing = is_erase
		_cursor_cell = _cell_at(event.position)
		_path.clear()
		_path.append(_cursor_cell)
		update_overlays()
		return true

	if not _dragging:
		return false
	if _erasing != is_erase:
		return true

	var final_path := _effective_path()
	var was_erasing := _erasing
	_dragging = false
	_path.clear()
	_apply(final_path, was_erasing)
	update_overlays()
	return true


func _handle_mouse_motion(event: InputEventMouseMotion) -> bool:
	_set_modifiers(event.shift_pressed, event.alt_pressed)

	var cell := _cell_at(event.position)
	if cell != _cursor_cell or not _has_hover:
		_cursor_cell = cell
		_has_hover = true
		if _dragging and not _line_mode:
			_extend_path(cell)
		update_overlays()

	return _dragging


func _set_modifiers(shift: bool, alt: bool) -> void:
	var changed := false

	if alt != _vertical_first:
		_vertical_first = alt
		changed = true

	if shift != _line_mode:
		if not shift and _dragging:
			# Leaving line mode mid-drag: bake the previewed leg into the
			# trail so freehand carries on from where the line ended.
			_path = _effective_path()
		_line_mode = shift
		changed = true

	if changed and _dragging:
		update_overlays()

#endregion


#region Path construction

## Freehand: bridge any cells the mouse skipped, and treat a step straight
## back onto the previous cell as an undo of the last step.
func _extend_path(to: Vector2i) -> void:
	if _path.is_empty():
		_path.append(to)
		return
	for cell in PipeTileLayout.bridge_cells(_path[_path.size() - 1], to, true):
		if _path.size() >= 2 and _path[_path.size() - 2] == cell:
			_path.remove_at(_path.size() - 1)
		else:
			_path.append(cell)


## Always a fresh array -- callers finish a drag by clearing `_path`, so
## handing out the live one would empty the stroke before it gets painted.
func _effective_path() -> Array[Vector2i]:
	if _path.is_empty():
		return []

	var full: Array[Vector2i] = _path.duplicate()
	if _line_mode:
		full.append_array(
			PipeTileLayout.bridge_cells(_path[_path.size() - 1], _cursor_cell, not _vertical_first)
		)
	return full

#endregion


#region Mask resolution

## Reads the layer as connection masks, so the shape rules in PipeTileLayout
## never have to know what a TileMapLayer is.
func _existing_mask_reader() -> Callable:
	var reverse := _config.coord_to_mask()
	var source_id := _config.source_id
	var layer := _layer
	return func(cell: Vector2i) -> int:
		if layer.get_cell_source_id(cell) != source_id:
			return 0
		var mask: int = reverse.get(layer.get_cell_atlas_coords(cell), 0)
		return mask


func _compute_final_masks(path: Array[Vector2i]) -> Dictionary[Vector2i, int]:
	return PipeTileLayout.resolve_paint(path, _existing_mask_reader(), _toolbar.join_ends)

#endregion


#region Applying

func _apply(path: Array[Vector2i], erase: bool) -> void:
	if _layer == null or path.is_empty():
		return

	var before := _layer.tile_map_data
	var missing: Array[String] = []

	if erase:
		_erase_path(path, missing)
	else:
		# Resolved up front: every cell is decided against the layer as it was
		# before this stroke, not against cells the same stroke just wrote.
		var final := _compute_final_masks(path)
		for cell: Vector2i in final:
			_write_mask(cell, final[cell], missing)

	var after := _layer.tile_map_data
	if after == before:
		_report_missing(missing)
		return

	_layer.tile_map_data = before

	var undo_redo := get_undo_redo()
	undo_redo.create_action(
		"Pipe Path Erase" if erase else "Pipe Path Paint",
		UndoRedo.MERGE_DISABLE,
		_layer
	)
	undo_redo.add_do_property(_layer, "tile_map_data", after)
	undo_redo.add_undo_property(_layer, "tile_map_data", before)
	undo_redo.commit_action()

	_report_missing(missing)


func _write_mask(cell: Vector2i, mask: int, missing: Array[String]) -> void:
	if mask == 0:
		_layer.erase_cell(cell)
		return

	var tile_name := PipeTileLayout.mask_to_name(mask)
	var coord := _config.get_coord(tile_name)
	if coord == PipeTileConfig.UNSET or not _tile_exists(coord):
		if not missing.has(tile_name):
			missing.append(tile_name)
		return

	_layer.set_cell(cell, _config.source_id, coord, 0)


func _erase_path(path: Array[Vector2i], missing: Array[String]) -> void:
	var resolved := PipeTileLayout.resolve_erase(path, _existing_mask_reader())
	for cell: Vector2i in resolved:
		_write_mask(cell, resolved[cell], missing)


func _tile_exists(coord: Vector2i) -> bool:
	var tile_set := _layer.tile_set
	if tile_set == null or not tile_set.has_source(_config.source_id):
		return false
	var atlas := tile_set.get_source(_config.source_id) as TileSetAtlasSource
	if atlas == null:
		return true
	return atlas.has_tile(coord)


func _report_missing(missing: Array[String]) -> void:
	if missing.is_empty():
		_refresh_status()
		return
	push_warning(
		"Pipe Path Painter: no tile assigned for %s. Those cells were skipped."
		% ", ".join(missing)
	)
	_toolbar.set_status("Unassigned: %s" % ", ".join(missing), true)

#endregion


#region Overlay

func _forward_canvas_draw_over_viewport(overlay: Control) -> void:
	if not _is_active():
		return

	var transform := _layer.get_viewport_transform() * _layer.get_global_transform()

	if not _dragging:
		if _has_hover:
			_draw_cell(overlay, transform, _cursor_cell, PAINT_COLOR, 0.06, 1.0)
		return

	var path := _effective_path()
	if path.is_empty():
		return

	if _erasing:
		for cell in path:
			_draw_cell(overlay, transform, cell, ERASE_COLOR, 0.22, 1.0)
		_draw_mode_hint(overlay, transform, ERASE_COLOR, path.size())
		return

	var final := _compute_final_masks(path)
	for cell: Vector2i in final:
		var mask: int = final[cell]
		var color := PAINT_COLOR if _config.has_coord(PipeTileLayout.mask_to_name(mask)) else MISSING_COLOR
		_draw_cell(overlay, transform, cell, color, 0.14, 1.0)
		_draw_connections(overlay, transform, cell, mask, color)

	_draw_mode_hint(overlay, transform, PAINT_COLOR, path.size())


func _draw_cell(
	overlay: Control,
	transform: Transform2D,
	cell: Vector2i,
	color: Color,
	fill_alpha: float,
	width: float
) -> void:
	var half := Vector2(_layer.tile_set.tile_size) * 0.5
	var center := _layer.map_to_local(cell)
	var points := PackedVector2Array([
		transform * (center - half),
		transform * (center + Vector2(half.x, -half.y)),
		transform * (center + half),
		transform * (center + Vector2(-half.x, half.y)),
	])
	overlay.draw_colored_polygon(points, Color(color, fill_alpha))
	var outline := points.duplicate()
	outline.append(points[0])
	overlay.draw_polyline(outline, Color(color, 0.85), width)


func _draw_connections(
	overlay: Control,
	transform: Transform2D,
	cell: Vector2i,
	mask: int,
	color: Color
) -> void:
	var half := Vector2(_layer.tile_set.tile_size) * 0.5
	var center := _layer.map_to_local(cell)
	for direction in PipeTileLayout.mask_directions(mask):
		overlay.draw_line(
			transform * center,
			transform * (center + Vector2(direction) * half),
			color,
			2.0
		)


func _draw_mode_hint(overlay: Control, transform: Transform2D, color: Color, cell_count: int) -> void:
	var label := "%d" % cell_count
	if _line_mode:
		label += "  line, " + ("vertical first" if _vertical_first else "horizontal first")
	var anchor := transform * _layer.map_to_local(_cursor_cell) + Vector2(14, -10)
	var font := overlay.get_theme_default_font()
	overlay.draw_string(font, anchor + Vector2.ONE, label, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color(0, 0, 0, 0.8))
	overlay.draw_string(font, anchor, label, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, color)

#endregion


#region Config

func _tileset_key() -> String:
	if _layer == null or _layer.tile_set == null:
		return ""
	var path := _layer.tile_set.resource_path
	return path if not path.is_empty() else "<builtin>"


func _reload_config() -> void:
	_config = PipeTileConfig.load_for(_tileset_key())
	_refresh_status()


func _open_config_dialog() -> void:
	if _layer == null or _layer.tile_set == null:
		push_warning("Pipe Path Painter: select a TileMapLayer that has a TileSet first.")
		return

	if _dialog == null:
		_dialog = PipeTileConfigDialog.new()
		_dialog.config_changed.connect(_on_config_changed)
		EditorInterface.get_base_control().add_child(_dialog)

	_dialog.setup(_config, _layer.tile_set)
	_dialog.popup_centered(Vector2i(1000, 640))


func _on_config_changed() -> void:
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

	var assigned := _config.assigned_count()
	var total := _config.slot_count()
	if assigned < total:
		_toolbar.set_status("%d / %d shapes set" % [assigned, total], true)
	else:
		_toolbar.set_status("%d shapes set" % total)

#endregion


#region Helpers

func _cell_at(viewport_position: Vector2) -> Vector2i:
	var transform := _layer.get_viewport_transform() * _layer.get_global_transform()
	return _layer.local_to_map(transform.affine_inverse() * viewport_position)


func _cancel_drag() -> void:
	if _dragging:
		_dragging = false
		_path.clear()
		update_overlays()

#endregion
