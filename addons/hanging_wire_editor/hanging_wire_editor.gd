@tool
extends EditorPlugin

## Drag handles for [HangingWireRig], so wires can be laid out with the mouse
## instead of by typing coordinates into the inspector.
##
## Selecting a rig puts a round handle on each of its wires' anchors and a
## diamond at the wire's valley. Dragging an anchor moves it; dragging the valley
## sets how far the wire hangs, which is [member HangingWire.length] under the
## hood. Anchors land on whole art pixels by default, since the wire is drawn on
## that grid anyway and an anchor between two pixels only ever rounds; hold Ctrl
## while dragging to place one freely. Escape abandons a drag, and every finished
## drag is one undo step.


const HANDLE_RADIUS := 5.0
const GRAB_RADIUS := 12.0

const ANCHOR_COLOR := Color(0.42, 0.85, 1.0)
const VALLEY_COLOR := Color(1.0, 0.78, 0.25)
const HOVER_COLOR := Color(1.0, 1.0, 1.0)
const OUTLINE_COLOR := Color(0.05, 0.06, 0.09, 0.9)
const LABEL_COLOR := Color(1.0, 1.0, 1.0, 0.7)

enum Handle {
	NONE,
	POINT_A,
	POINT_B,
	VALLEY,
}

var _rig: HangingWireRig

var _hover_wire := -1
var _hover_handle := Handle.NONE

var _drag_wire := -1
var _drag_handle := Handle.NONE
## Value the drag started from, so Escape can put it back and undo has something
## to restore.
var _drag_from_point := Vector2.ZERO
var _drag_from_length := 0.0
## Gap between the handle and the cursor when the drag began, so grabbing a
## handle off-centre doesn't snap it under the pointer.
var _drag_offset := Vector2.ZERO


func _exit_tree() -> void:
	_release_rig()


func _get_plugin_name() -> String:
	return "Hanging Wire Editor"


func _handles(object: Object) -> bool:
	return object is HangingWireRig


func _edit(object: Object) -> void:
	_cancel_drag()
	_release_rig()
	_rig = object as HangingWireRig
	if _rig != null:
		# The rig draws its own markers when nothing else is; ours replace them.
		_rig.editor_handles_active = true
	_hover_wire = -1
	_hover_handle = Handle.NONE
	update_overlays()


func _make_visible(visible: bool) -> void:
	if visible:
		return
	_cancel_drag()
	_release_rig()
	_hover_wire = -1
	_hover_handle = Handle.NONE
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
		if _drag_handle != Handle.NONE:
			_cancel_drag()
			return true
	return false


func _handle_mouse_button(event: InputEventMouseButton) -> bool:
	if event.button_index != MOUSE_BUTTON_LEFT:
		return false

	if event.pressed:
		var hit := _pick(event.position)
		var handle: Handle = hit["handle"]
		if handle == Handle.NONE:
			# Nothing of ours under the cursor, so let the editor get on with
			# selecting and moving nodes as usual.
			return false
		_drag_wire = int(hit["wire"])
		_drag_handle = handle
		var wire := _rig.wires[_drag_wire]
		_drag_from_point = wire.point_a if handle == Handle.POINT_A else wire.point_b
		_drag_from_length = wire.length
		_drag_offset = _handle_point(wire, handle) - _to_local(event.position)
		return true

	if _drag_handle == Handle.NONE:
		return false
	_commit_drag()
	return true


func _handle_mouse_motion(event: InputEventMouseMotion) -> bool:
	if _drag_handle == Handle.NONE:
		var hit := _pick(event.position)
		if hit["wire"] != _hover_wire or hit["handle"] != _hover_handle:
			_hover_wire = hit["wire"]
			_hover_handle = hit["handle"]
			update_overlays()
		return false

	# Ctrl is the 2D editor's own snap override, so it means the same here.
	_apply_drag(_to_local(event.position) + _drag_offset, not event.ctrl_pressed)
	update_overlays()
	return true


func _apply_drag(local_point: Vector2, snap: bool) -> void:
	var wire := _rig.wires[_drag_wire]
	if snap:
		local_point = _rig.snap_to_pixel_grid(local_point)
	match _drag_handle:
		Handle.POINT_A:
			wire.point_a = local_point
		Handle.POINT_B:
			wire.point_b = local_point
		Handle.VALLEY:
			# The valley is dragged to a depth, which is a length once inverted.
			wire.set_sag(local_point.y - maxf(wire.point_a.y, wire.point_b.y))


func _commit_drag() -> void:
	var wire := _rig.wires[_drag_wire]
	var undo_redo := get_undo_redo()

	if _drag_handle == Handle.VALLEY:
		if not is_equal_approx(wire.length, _drag_from_length):
			undo_redo.create_action("Set Wire Hang", UndoRedo.MERGE_DISABLE, _rig)
			undo_redo.add_do_property(wire, "length", wire.length)
			undo_redo.add_undo_property(wire, "length", _drag_from_length)
			# The value is already on the wire, so committing must not re-run it.
			undo_redo.commit_action(false)
	else:
		var property := "point_a" if _drag_handle == Handle.POINT_A else "point_b"
		var moved: Vector2 = wire.get(property)
		if not moved.is_equal_approx(_drag_from_point):
			undo_redo.create_action("Move Wire Anchor", UndoRedo.MERGE_DISABLE, _rig)
			undo_redo.add_do_property(wire, property, moved)
			undo_redo.add_undo_property(wire, property, _drag_from_point)
			undo_redo.commit_action(false)

	_drag_wire = -1
	_drag_handle = Handle.NONE
	update_overlays()


func _cancel_drag() -> void:
	if _drag_handle == Handle.NONE:
		return
	if _is_editable() and _drag_wire < _rig.wires.size():
		var wire := _rig.wires[_drag_wire]
		if wire != null:
			match _drag_handle:
				Handle.POINT_A:
					wire.point_a = _drag_from_point
				Handle.POINT_B:
					wire.point_b = _drag_from_point
				Handle.VALLEY:
					wire.length = _drag_from_length
	_drag_wire = -1
	_drag_handle = Handle.NONE
	update_overlays()

#endregion


#region Handles

## The handle under [param screen_point], as
## [code]{wire = int, handle = Handle}[/code]. Anchors win ties with a valley,
## which matters on a barely-slack wire where all three sit on top of each other.
func _pick(screen_point: Vector2) -> Dictionary:
	var best := {"wire": -1, "handle": Handle.NONE}
	var best_distance := INF
	for i in _rig.wires.size():
		var wire: HangingWire = _rig.wires[i]
		if wire == null:
			continue
		# Anchors are tested first and ties go to whoever got there, so an anchor
		# keeps the grab when a valley is sitting right on top of it.
		for handle: Handle in [Handle.POINT_A, Handle.POINT_B, Handle.VALLEY]:
			var distance := screen_point.distance_to(_to_screen(_handle_point(wire, handle)))
			if distance > GRAB_RADIUS or distance >= best_distance:
				continue
			best_distance = distance
			best = {"wire": i, "handle": handle}
	return best


func _handle_point(wire: HangingWire, handle: Handle) -> Vector2:
	match handle:
		Handle.POINT_A:
			return wire.point_a
		Handle.POINT_B:
			return wire.point_b
		_:
			return wire.get_low_point()


func _to_screen(local_point: Vector2) -> Vector2:
	return _canvas_transform() * local_point


func _to_local(screen_point: Vector2) -> Vector2:
	return _canvas_transform().affine_inverse() * screen_point


## Rig-local coordinates to the ones the viewport overlay draws in.
##
## Deliberately not [method CanvasItem.get_global_transform_with_canvas], which
## reads the viewport's [i]canvas layer[/i] transform — identity for an ordinary
## 2D scene. The editor keeps its pan and zoom in the viewport's
## [code]global_canvas_transform[/code] instead, which only
## [method CanvasItem.get_viewport_transform] picks up. Using the wrong one draws
## the handles at raw local coordinates, so they sit in a fixed spot on screen and
## ignore the camera.
func _canvas_transform() -> Transform2D:
	return _rig.get_viewport_transform() * _rig.get_global_transform()


func _is_editable() -> bool:
	return is_instance_valid(_rig) and _rig.is_inside_tree()


func _release_rig() -> void:
	if is_instance_valid(_rig):
		_rig.editor_handles_active = false
	_rig = null

#endregion


#region Overlay

func _forward_canvas_draw_over_viewport(overlay: Control) -> void:
	if not _is_editable():
		return
	var font := overlay.get_theme_default_font()
	var label_wires := _rig.wires.size() > 1
	for i in _rig.wires.size():
		var wire: HangingWire = _rig.wires[i]
		if wire == null:
			continue
		var point_a := _to_screen(wire.point_a)
		var point_b := _to_screen(wire.point_b)
		_draw_anchor(overlay, point_a, _is_lit(i, Handle.POINT_A))
		_draw_anchor(overlay, point_b, _is_lit(i, Handle.POINT_B))
		_draw_valley(overlay, _to_screen(wire.get_low_point()), _is_lit(i, Handle.VALLEY))
		if label_wires and font != null:
			# Which wire is which, so a bundle of them stays sortable.
			overlay.draw_string(font, point_a + Vector2(8, -8), str(i),
					HORIZONTAL_ALIGNMENT_LEFT, -1, 12, LABEL_COLOR)


func _is_lit(wire_index: int, handle: Handle) -> bool:
	if _drag_handle != Handle.NONE:
		return _drag_wire == wire_index and _drag_handle == handle
	return _hover_wire == wire_index and _hover_handle == handle


func _draw_anchor(overlay: Control, at: Vector2, lit: bool) -> void:
	overlay.draw_circle(at, HANDLE_RADIUS + 1.5, OUTLINE_COLOR)
	overlay.draw_circle(at, HANDLE_RADIUS, HOVER_COLOR if lit else ANCHOR_COLOR)


func _draw_valley(overlay: Control, at: Vector2, lit: bool) -> void:
	overlay.draw_colored_polygon(_diamond(at, HANDLE_RADIUS + 1.5), OUTLINE_COLOR)
	overlay.draw_colored_polygon(_diamond(at, HANDLE_RADIUS), HOVER_COLOR if lit else VALLEY_COLOR)


func _diamond(at: Vector2, radius: float) -> PackedVector2Array:
	return PackedVector2Array([
		at + Vector2(0, -radius),
		at + Vector2(radius, 0),
		at + Vector2(0, radius),
		at + Vector2(-radius, 0),
	])

#endregion
