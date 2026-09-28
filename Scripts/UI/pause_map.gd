@tool
## The world map on the pause panel's Map tab.
##
## Draws a slice of the MetSys world map with a [MapView], so every texture and colour
## comes from the theme on [code]MetSys.settings.theme[/code]. The slice always fills
## this node's rect completely: place and size the node in the scene to decide where the
## map goes, and use the Map Area exports to decide how big the cells are inside it.
## Cells cut by the edges are clipped, not left out.
##
## The view starts centred on the player's cell whenever it is brought up, and pans with
## the movement keys (a whole cell per step) or by dragging with the mouse, as far as the
## four pan limits allow. [PausePanel] decides when it is [member active].
##
## [b]Animation contract.[/b] While opening, [method _animate_open] is called once per
## frame with the real frame delta (the pause menu slows [code]Engine.time_scale[/code]
## to zero, so the scaled one would freeze it), and the map counts as open on the first
## frame it returns [code]true[/code]. Extend this script and override it to write your
## own; the default is an old CRT television switching on. Closing is instant.
class_name PauseMap
extends Control

enum SizeMode {
	## Set [member cell_scale]. However many cells fit are drawn.
	SCALE,
	## Set [member cells_tall]. The scale is whatever fits that many down the area, and the
	## width fills with however many fit across.
	CELLS_TALL,
	## Set [member cells_wide]. The mirror of [constant CELLS_TALL].
	CELLS_WIDE,
	## Set both counts. The scale is the largest that still shows at least that many cells
	## each way, and the looser direction fills with extra.
	CELLS_BOTH,
}

## Emitted when [method _animate_open] reports it has finished.
signal opened
## Emitted when the map is put away.
signal closed

# A zero scale leaves no inverse transform, and the GUI's mouse picking inverts every
# Control's transform each frame, visible or not.
const MIN_SCALE := 0.001
# A hitch (the first opening builds the whole view) would otherwise skip most of the
# turn-on in one frame, so it slows down through one instead.
const MAX_TURN_ON_STEP := 1.0 / 30.0

@export_group("Map Area")
## Which of the settings below decides how big a cell is. The others are ignored.
@export var size_mode := SizeMode.SCALE:
	set(value):
		size_mode = value
		_layout()

## [constant SizeMode.SCALE] only. Screen pixels per map texture pixel, so a cell is
## [code]MetSys.CELL_SIZE * cell_scale[/code] pixels on screen. Whole numbers keep the
## pixel art crisp.
@export var cell_scale := 2.0:
	set(value):
		cell_scale = maxf(value, 0.01)
		_layout()

## [constant SizeMode.CELLS_TALL] and [constant SizeMode.CELLS_BOTH] only. Cells shown
## down the area.
@export var cells_tall := 8:
	set(value):
		cells_tall = maxi(value, 1)
		_layout()

## [constant SizeMode.CELLS_WIDE] and [constant SizeMode.CELLS_BOTH] only. Cells shown
## across the area.
@export var cells_wide := 11:
	set(value):
		cells_wide = maxi(value, 1)
		_layout()

## Shows the theme's player location scene on the map.
@export var display_player_location := true:
	set(value):
		display_player_location = value
		_refresh_player_location()

@export_group("Turn On Animation")
## Seconds the line takes to stretch across the full width.
@export var horizontal_duration := 0.2
@export var horizontal_transition := Tween.TRANS_CUBIC
@export var horizontal_ease := Tween.EASE_OUT
## Seconds the finished line holds before it opens up.
@export var line_hold := 0.05
## Seconds the line takes to open out to the full height.
@export var vertical_duration := 0.25
@export var vertical_transition := Tween.TRANS_CUBIC
@export var vertical_ease := Tween.EASE_OUT
## Height of the line in screen pixels while it stretches across.
@export var line_thickness := 3.0
## Laid over the map while it turns on, as the bright beam of the tube, and faded out as
## the picture opens up. Without it the first half would be invisible: squashed to a few
## pixels high, the map is just a sliver of dark cells. Alpha 0 turns it off.
@export var beam_color := Color(1, 1, 1, 0.9)

@export_group("Panning")
## Cells stepped per second while a direction key is held. The first frame of a press
## always steps at once, so a tap moves exactly one cell.
@export var key_pan_speed := 8.0

## How far the view can be panned off the player's cell, in cells. Each direction is
## separate, so the reachable area does not have to be centred on the player.
@export var pan_limit_up := 8
@export var pan_limit_down := 8
@export var pan_limit_left := 12
@export var pan_limit_right := 12

@export_subgroup("Actions")
## Reveals cells above: the view moves up, so the map appears to slide down.
@export var pan_action_up := &"Up"
@export var pan_action_down := &"Down"
@export var pan_action_left := &"Left"
@export var pan_action_right := &"Right"

## Whether the map is up and taking input. Set by [PausePanel] while its Map tab is the
## one showing and the panel is open; while false the map neither pans nor follows the
## player.
var active := false:
	set(value):
		# Keys already down when the map comes up were meant for the player (a pause
		# pressed mid-run), so each axis waits for its key to be let go first.
		if value and not active:
			_key_ignored = _held_direction()
		active = value
		if not active:
			_dragging = false
			_key_input = Vector2i.ZERO
		_update_processing()

@onready var _drawer: Node2D = $Drawer

var _animator: MapPanelAnimator
var _map_view: MapView
var _player_location: Node2D
var _beam: ColorRect
## Size of the map view, in cells.
var _view_cells: Vector2i
## One map cell, in this node's local units.
var _cell_size: Vector2
## Where the view is looking, in cells off the centre of the player's cell.
var _pan: Vector2
var _key_input: Vector2i
var _key_ignored: Vector2i
## Fractional cells built up towards the next key step, per axis.
var _key_accum: Vector2
var _dragging := false
var _drag_last: Vector2
var _turn_on_elapsed: float

func _ready() -> void:
	_animator = MapPanelAnimator.new(_animate_open, _animate_close)
	_animator.open_started.connect(_on_open_started)
	_animator.opened.connect(opened.emit)
	_animator.closed.connect(closed.emit)
	set_process(false)

	_beam = ColorRect.new()
	_beam.set_anchors_preset(Control.PRESET_FULL_RECT)
	_beam.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Over the MetSys borders (z 1-2), custom elements (3) and player location (5).
	_beam.z_index = 8
	_beam.visible = false
	# Internal, so the editor neither lists it in the scene nor saves it.
	add_child(_beam, false, Node.INTERNAL_MODE_BACK)

	resized.connect(_layout)
	_layout()

	if Engine.is_editor_hint():
		# A preview, so the Map Area settings can be tuned against the panel.
		_build_view()
		return

	MetSys.map_updated.connect(_on_map_updated)
	MetSys.cell_changed.connect(_on_cell_changed)

func _process(_delta: float) -> void:
	var delta := RealDelta.get_capped()
	if active and _animator.is_open():
		_handle_key_pan(delta)
	_animator.step(delta)
	_update_processing()

func _update_processing() -> void:
	if not _animator:
		return
	set_process(not Engine.is_editor_hint() and (_animator.is_animating() or (active and _animator.is_open())))

#region Open / close
## Brings the map up with its turn-on animation, centred on the player. Safe to call
## when already open.
func open() -> void:
	_animator.open()
	_update_processing()

## Puts the map away at once.
func snap_closed() -> void:
	_animator.snap_closed()
	_update_processing()

## Skips the rest of a turn-on still playing, for when it would play out where nobody
## can see it. Does nothing otherwise.
func finish_animation() -> void:
	if _animator.state == MapPanelAnimator.State.OPENING:
		_animator.snap_open()
	_update_processing()

## Catches the map up with everything that happened while it was out of sight: redraws
## every cell and puts the view back on the player.
func refresh() -> void:
	if _map_view:
		_map_view.update_all()
	recenter()

## Called once per frame while the map is opening, with the real frame delta. Return
## [code]true[/code] when the animation has finished. Override to supply your own;
## [member scale] pivots on the centre of the map.
func _animate_open(delta: float) -> bool:
	_turn_on_elapsed += minf(delta, MAX_TURN_ON_STEP)
	return _pose_turn_on(_turn_on_elapsed)

func _animate_close(_delta: float) -> bool:
	scale = Vector2.ONE
	_set_beam(0.0)
	return true

func _on_open_started() -> void:
	if _map_view:
		_map_view.update_all()
	else:
		_build_view()
	recenter()
	_turn_on_elapsed = 0.0
	_pose_turn_on(0.0)

## Poses the turn-on [param t] seconds in, and returns whether it is over by then.
func _pose_turn_on(t: float) -> bool:
	var line := minf(line_thickness / (size.y * _canvas_scale()), 1.0) if size.y > 0.0 else 1.0
	var vertical_start := horizontal_duration + line_hold
	var width := 1.0
	var height := 1.0
	var beam := 0.0
	if t < horizontal_duration:
		width = _eased(t, horizontal_duration, horizontal_transition, horizontal_ease)
		height = line
		beam = 1.0
	elif t < vertical_start:
		height = line
		beam = 1.0
	elif t < vertical_start + vertical_duration:
		var opened_by := _eased(t - vertical_start, vertical_duration, vertical_transition, vertical_ease)
		height = lerpf(line, 1.0, opened_by)
		beam = 1.0 - opened_by

	scale = Vector2(maxf(width, MIN_SCALE), maxf(height, MIN_SCALE))
	_set_beam(beam)
	return t >= vertical_start + vertical_duration

func _eased(t: float, duration: float, transition: Tween.TransitionType, easing: Tween.EaseType) -> float:
	return Tween.interpolate_value(0.0, 1.0, t, duration, transition, easing)

func _set_beam(strength: float) -> void:
	_beam.color = Color(beam_color, beam_color.a * strength)
	_beam.visible = _beam.color.a > 0.0
#endregion

#region Panning
## Pans the view by [param cells], clamped to the four pan limits.
func pan_by(cells: Vector2) -> void:
	var wanted := _pan + cells
	wanted.x = clampf(wanted.x, -pan_limit_left, pan_limit_right)
	wanted.y = clampf(wanted.y, -pan_limit_up, pan_limit_down)
	if wanted == _pan:
		return
	_pan = wanted
	_apply_focus()

## Puts the view back on the player's cell.
func recenter() -> void:
	_pan = Vector2.ZERO
	_key_accum = Vector2.ZERO
	_apply_focus()

func _held_direction() -> Vector2i:
	return Vector2i(
		int(Input.is_action_pressed(pan_action_right)) - int(Input.is_action_pressed(pan_action_left)),
		int(Input.is_action_pressed(pan_action_down)) - int(Input.is_action_pressed(pan_action_up)))

func _handle_key_pan(delta: float) -> void:
	var direction := _held_direction()
	for axis in 2:
		if _key_ignored[axis] == 0:
			continue
		if direction[axis] == _key_ignored[axis]:
			direction[axis] = 0
		else:
			_key_ignored[axis] = 0

	# A newly pressed direction steps once right away, so a tap always moves a cell and
	# holding doesn't feel like it starts late.
	if direction.x != _key_input.x:
		_key_accum.x = 0.0
		if direction.x != 0:
			_step(Vector2i(direction.x, 0))
	if direction.y != _key_input.y:
		_key_accum.y = 0.0
		if direction.y != 0:
			_step(Vector2i(0, direction.y))
	_key_input = direction

	if direction == Vector2i.ZERO or key_pan_speed <= 0.0:
		return

	_key_accum += Vector2(direction) * key_pan_speed * delta
	var steps := Vector2i(int(_key_accum.x), int(_key_accum.y))
	if steps != Vector2i.ZERO:
		_key_accum -= Vector2(steps)
		_step(steps)

# A drag can leave the view between cells. Key steps land back on the grid, on the next
# whole cell in their direction, so the first one after a drag may be a partial move.
func _step(cells: Vector2i) -> void:
	var target := _pan
	if cells.x != 0:
		target.x = (floorf(_pan.x) if cells.x > 0 else ceilf(_pan.x)) + cells.x
	if cells.y != 0:
		target.y = (floorf(_pan.y) if cells.y > 0 else ceilf(_pan.y)) + cells.y
	pan_by(target - _pan)

func _input(event: InputEvent) -> void:
	if not active or not _animator.is_open():
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var mouse := (make_input_local(event) as InputEventMouse).position
		if event.pressed and Rect2(Vector2.ZERO, size).has_point(mouse):
			_dragging = true
			_drag_last = mouse
		elif not event.pressed:
			_dragging = false
	elif event is InputEventMouseMotion and _dragging:
		var mouse := (make_input_local(event) as InputEventMouse).position
		# Dragging right moves the map right, which looks further left.
		pan_by((_drag_last - mouse) / _cell_size)
		_drag_last = mouse
#endregion

#region Map view
## Local units per map texture pixel.
func _map_pixel_scale() -> float:
	var cell := MetSys.CELL_SIZE
	var fit: float
	match size_mode:
		SizeMode.CELLS_TALL:
			fit = size.y / (cells_tall * cell.y)
		SizeMode.CELLS_WIDE:
			fit = size.x / (cells_wide * cell.x)
		SizeMode.CELLS_BOTH:
			fit = minf(size.x / (cells_wide * cell.x), size.y / (cells_tall * cell.y))
		_:
			fit = cell_scale / _canvas_scale()
	return maxf(fit, 0.001)

# cell_scale is in screen pixels but this node's units are the panel's, which the
# pause panel scales up. Read off the parent, since this node's own scale is the
# turn-on animation's.
func _canvas_scale() -> float:
	var parent := get_parent() as CanvasItem
	var parent_scale := parent.get_global_transform().get_scale().y if parent else 1.0
	return maxf(absf(parent_scale), 0.001)

func _layout() -> void:
	if not is_node_ready() or MetSys.CELL_SIZE == Vector2.ZERO:
		return

	pivot_offset = size * 0.5
	var pixel_scale := _map_pixel_scale()
	_drawer.scale = Vector2.ONE * pixel_scale
	_cell_size = MetSys.CELL_SIZE * pixel_scale

	# One more than fit, so the area stays covered wherever the focus lands in a cell.
	var cells := Vector2i((size / _cell_size).ceil()) + Vector2i.ONE
	if cells != _view_cells:
		_view_cells = cells
		# The view's size is fixed when it is made.
		if _map_view:
			_build_view()
			return
	_apply_focus()

func _build_view() -> void:
	# Assigning drops the previous view, which frees its canvas items with it.
	_map_view = MetSys.make_map_view(_drawer, _view_begin(), _view_cells, MetSys.current_layer)
	_refresh_player_location()
	_apply_focus()

## The point the middle of the area looks at, in cells.
func _focus() -> Vector2:
	# Vector3i.MAX until the player's first position report (and always, in the editor).
	# Centring on that would build the view around integer overflow.
	var player_cell := Vector2.ZERO
	if MetSys.last_player_position != Vector3i.MAX:
		player_cell = Vector2(MetSys.get_current_flat_coords())
	return player_cell + Vector2(0.5, 0.5) + _pan

func _view_top_left() -> Vector2:
	return _focus() - size / _cell_size * 0.5

func _view_begin() -> Vector2i:
	return Vector2i(_view_top_left().floor())

# The view only moves in whole cells, so the drawer is offset by the fraction left over.
func _apply_focus() -> void:
	if _cell_size == Vector2.ZERO:
		return

	var top_left := _view_top_left()
	var begin := Vector2i(top_left.floor())
	_drawer.position = (Vector2(begin) - top_left) * _cell_size
	if _map_view:
		_map_view.move_to(Vector3i(begin.x, begin.y, MetSys.current_layer))
	# The location scene positions itself in absolute world-map pixels.
	if is_instance_valid(_player_location):
		_player_location.offset = -Vector2(begin) * MetSys.CELL_SIZE

func _refresh_player_location() -> void:
	if not is_node_ready():
		return

	var wanted := display_player_location and _map_view != null and not Engine.is_editor_hint()
	if wanted and not is_instance_valid(_player_location):
		_player_location = MetSys.add_player_location(_drawer)
	elif not wanted and is_instance_valid(_player_location):
		_player_location.queue_free()
		_player_location = null
	_apply_focus()

func _on_cell_changed(_new_cell: Vector3i) -> void:
	if active:
		_apply_focus()

# While the map is away, refresh() catches it up when it comes back instead.
func _on_map_updated() -> void:
	if active and _map_view:
		_map_view.update_all()
#endregion
