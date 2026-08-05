@tool
extends EditorPlugin

## Drag handles for [Path], so a route can be laid out with the mouse instead of
## by typing coordinates into the inspector.
##
## Selecting a path puts a numbered handle on each entry of [member Path.points],
## and dragging one moves that point. Points land on whole pixels by default,
## since a moving platform sitting on a half pixel only ever looks blurry; hold
## Ctrl while dragging to place one freely. Escape abandons a drag, and every
## finished drag is one undo step.
##
## A point added from the inspector starts at the path's origin, so a fresh batch
## of them lands in a single stack. Grabbing that stack takes the last point in it
## — the one just added — so they can be pulled out one at a time in order.


const HANDLE_RADIUS := 5.0
const GRAB_RADIUS := 12.0

const POINT_COLOR := Color(0.39, 0.58, 0.93)
const HOVER_COLOR := Color(1.0, 1.0, 1.0)
const OUTLINE_COLOR := Color(0.05, 0.06, 0.09, 0.9)
const LABEL_COLOR := Color(1.0, 1.0, 1.0, 0.7)

var _path: Path

var _hover_point := -1

var _drag_point := -1
## The whole list as it stood when the drag began, so Escape can put it back and
## undo has something to restore.
var _drag_from_points: Array[Vector2]
## Gap between the handle and the cursor when the drag began, so grabbing a
## handle off-centre doesn't snap it under the pointer.
var _drag_offset := Vector2.ZERO


func _exit_tree() -> void:
	_release_path()


func _get_plugin_name() -> String:
	return "Path Point Editor"


func _handles(object: Object) -> bool:
	return object is Path


func _edit(object: Object) -> void:
	_cancel_drag()
	_release_path()
	_path = object as Path
	if _path != null:
		# The path draws its own markers when nothing else is; ours replace them.
		_path.editor_handles_active = true
	_hover_point = -1
	update_overlays()


func _make_visible(visible: bool) -> void:
	if visible:
		return
	_cancel_drag()
	_release_path()
	_hover_point = -1
	update_overlays()


#region Input

func _forward_canvas_gui_input(event: InputEvent) -> bool:
	if not _is_editable():
		return false
	if event is InputEventMouseButton:
		return _handle_mouse_button(event)
	if event is InputEventMouseMotion:
		return _handle_mouse_motion(event)
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		if _drag_point != -1:
			_cancel_drag()
			return true
	return false


func _handle_mouse_button(event: InputEventMouseButton) -> bool:
	if event.button_index != MOUSE_BUTTON_LEFT:
		return false

	if event.pressed:
		var hit := _pick(event.position)
		if hit == -1:
			# Nothing of ours under the cursor, so let the editor get on with
			# selecting and moving nodes as usual.
			return false
		_drag_point = hit
		_drag_from_points = _path.points.duplicate()
		_drag_offset = _path.points[hit] - _to_local(event.position)
		return true

	if _drag_point == -1:
		return false
	_commit_drag()
	return true


func _handle_mouse_motion(event: InputEventMouseMotion) -> bool:
	if _drag_point == -1:
		var hit := _pick(event.position)
		if hit != _hover_point:
			_hover_point = hit
			update_overlays()
		return false

	# Ctrl is the 2D editor's own snap override, so it means the same here.
	_apply_drag(_to_local(event.position) + _drag_offset, not event.ctrl_pressed)
	update_overlays()
	return true


func _apply_drag(local_point: Vector2, snap: bool) -> void:
	if snap:
		local_point = local_point.round()
	_path.points[_drag_point] = local_point
	_path.queue_redraw()


func _commit_drag() -> void:
	var moved := _path.points.duplicate()
	if not moved[_drag_point].is_equal_approx(_drag_from_points[_drag_point]):
		var undo_redo := get_undo_redo()
		undo_redo.create_action("Move Path Point", UndoRedo.MERGE_DISABLE, _path)
		# Whole-array properties, because assigning one element of an exported
		# Array doesn't tell the inspector or the scene anything changed.
		undo_redo.add_do_property(_path, "points", moved)
		undo_redo.add_undo_property(_path, "points", _drag_from_points)
		undo_redo.add_do_method(_path, "queue_redraw")
		undo_redo.add_undo_method(_path, "queue_redraw")
		# The value is already on the path, so committing must not re-run it.
		undo_redo.commit_action(false)

	_drag_point = -1
	_drag_from_points = []
	update_overlays()


func _cancel_drag() -> void:
	if _drag_point == -1:
		return
	if _is_editable() and _drag_point < _drag_from_points.size():
		_path.points[_drag_point] = _drag_from_points[_drag_point]
		_path.queue_redraw()
	_drag_point = -1
	_drag_from_points = []
	update_overlays()

#endregion


#region Handles

## Index of the point under [param screen_point], or -1. Ties go to the highest
## index, so the newest of a stack of points at the origin is the one that comes
## off first.
func _pick(screen_point: Vector2) -> int:
	var best := -1
	var best_distance := INF
	for i in _path.points.size():
		var distance := screen_point.distance_to(_to_screen(_path.points[i]))
		if distance > GRAB_RADIUS or distance > best_distance:
			continue
		best_distance = distance
		best = i
	return best


func _to_screen(local_point: Vector2) -> Vector2:
	return _canvas_transform() * local_point


func _to_local(screen_point: Vector2) -> Vector2:
	return _canvas_transform().affine_inverse() * screen_point


## Path-local coordinates to the ones the viewport overlay draws in.
##
## Deliberately not [method CanvasItem.get_global_transform_with_canvas], which
## reads the viewport's [i]canvas layer[/i] transform — identity for an ordinary
## 2D scene. The editor keeps its pan and zoom in the viewport's
## [code]global_canvas_transform[/code] instead, which only
## [method CanvasItem.get_viewport_transform] picks up. Using the wrong one draws
## the handles at raw local coordinates, so they sit in a fixed spot on screen and
## ignore the camera.
func _canvas_transform() -> Transform2D:
	return _path.get_viewport_transform() * _path.get_global_transform()


func _is_editable() -> bool:
	return is_instance_valid(_path) and _path.is_inside_tree()


func _release_path() -> void:
	if is_instance_valid(_path):
		_path.editor_handles_active = false
	_path = null

#endregion


#region Overlay

func _forward_canvas_draw_over_viewport(overlay: Control) -> void:
	if not _is_editable():
		return
	var font := overlay.get_theme_default_font()
	for i in _path.points.size():
		var at := _to_screen(_path.points[i])
		var lit := i == (_drag_point if _drag_point != -1 else _hover_point)
		overlay.draw_circle(at, HANDLE_RADIUS + 1.5, OUTLINE_COLOR)
		overlay.draw_circle(at, HANDLE_RADIUS, HOVER_COLOR if lit else POINT_COLOR)
		if font != null:
			# Which point is which, so the travel order stays readable.
			overlay.draw_string(font, at + Vector2(8, -8), str(i),
					HORIZONTAL_ALIGNMENT_LEFT, -1, 12, LABEL_COLOR)

#endregion
