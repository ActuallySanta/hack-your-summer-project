@tool
## The full-screen map panel.
##
## Draws a slice of the MetSys world map centred on the player, using a [MapView] so
## every texture and colour comes from the theme on [code]MetSys.settings.theme[/code].
## The panel is never removed from the tree: closed simply means parked offscreen.
## While open it takes over the movement keys to scroll the view a whole cell at a
## time, within the four scroll limits; [PlayerHUD] stops the player reading them.
##
## [b]Animation contract.[/b] While the panel is opening, [method _animate_open] is
## called once per frame with the frame delta; the panel is considered open on the
## first frame it returns [code]true[/code]. [method _animate_close] is the same for
## closing. Extend this script and override those two to write your own animation —
## the defaults just slide the panel in from [member closed_side]. [HudMinimap]
## follows the same contract.
class_name FullMap
extends Control

enum ClosedSide {
	BOTTOM,
	TOP,
	LEFT,
	RIGHT,
}

## Emitted when an opening animation starts.
signal open_started
## Emitted when [method _animate_open] reports it has finished.
signal opened
## Emitted when a closing animation starts.
signal close_started
## Emitted when [method _animate_close] reports it has finished.
signal closed

@export_group("Map Area")
## Number of map cells shown across the panel.
@export var cells_horizontal := 15:
	set(value):
		value = maxi(value, 1)
		if value == cells_horizontal:
			return
		cells_horizontal = value
		_rebuild_view()

## Number of map cells shown down the panel.
@export var cells_vertical := 9:
	set(value):
		value = maxi(value, 1)
		if value == cells_vertical:
			return
		cells_vertical = value
		_rebuild_view()

## Multiplier on the theme's cell size. The panel ends up
## [code]cells_horizontal * MetSys.CELL_SIZE.x * cell_scale[/code] pixels wide.
@export var cell_scale := 2.0:
	set(value):
		value = maxf(value, 0.01)
		if is_equal_approx(value, cell_scale):
			return
		cell_scale = value
		_rebuild_view()

## Shows the theme's player location scene on the map.
@export var display_player_location := true:
	set(value):
		if value == display_player_location:
			return
		display_player_location = value
		_refresh_player_location()

@export_group("Animation")
## Which edge of the screen the panel is parked behind while closed.
@export var closed_side := ClosedSide.BOTTOM:
	set(value):
		closed_side = value
		_update_positions()

## Extra pixels past the screen edge, so a panel with a shadow or border is fully hidden.
@export var offscreen_margin := 32.0:
	set(value):
		offscreen_margin = value
		_update_positions()

## Length of the built-in slide, in seconds. Ignored once you override
## [method _animate_open] / [method _animate_close].
@export var animation_duration := 0.25

@export_group("Scrolling")
## Cells scrolled per second while a direction is held down. The view only ever
## lands on whole cells, so this is really "one cell every 1 / scroll_speed seconds".
## The first frame of a press always steps immediately.
@export var scroll_speed := 8.0

## How far the view can be scrolled off the player's cell, in cells. Each direction
## is separate, so the reachable area does not have to be centred on the player.
@export var scroll_limit_up := 8
@export var scroll_limit_down := 8
@export var scroll_limit_left := 12
@export var scroll_limit_right := 12

@export_subgroup("Actions")
## Reveals cells above: the view moves up, so the map appears to slide down.
@export var scroll_action_up := &"Up"
@export var scroll_action_down := &"Down"
@export var scroll_action_left := &"Left"
@export var scroll_action_right := &"Right"

@onready var _drawer: Node2D = $Drawer

var _animator: MapPanelAnimator
var _map_view: MapView
var _player_location: Node2D
## Map coordinates of the cell drawn in the panel's top-left corner.
var _begin: Vector2i
var _open_position: Vector2
var _closed_position: Vector2
var _slide_from: Vector2
var _slide_elapsed: float
## Cells the view has been scrolled away from the player, reset every time the map opens.
var _scroll_offset: Vector2i
## Fractional cells built up towards the next whole-cell step, per axis.
var _scroll_accum: Vector2
var _scroll_input: Vector2i

func _ready() -> void:
	_animator = MapPanelAnimator.new(_animate_open, _animate_close)
	_animator.open_started.connect(_on_open_started)
	_animator.close_started.connect(_on_close_started)
	_animator.opened.connect(opened.emit)
	_animator.closed.connect(closed.emit)
	set_process(false)

	_rebuild_view()

	if Engine.is_editor_hint():
		# Leave the panel wherever it was placed so it stays visible in the editor.
		return

	_update_positions()
	position = _closed_position

	MetSys.map_updated.connect(_on_map_updated)
	MetSys.cell_changed.connect(_on_cell_changed)
	var parent := get_parent() as Control
	if parent:
		parent.resized.connect(_update_positions)
	else:
		get_viewport().size_changed.connect(_update_positions)

func _process(delta: float) -> void:
	if _animator.is_open():
		_handle_scroll_input(delta)
	_animator.step(delta)
	set_process(_needs_process())

## Processing is needed while an animation runs and for as long as the map is open,
## since an open map reads the scroll keys every frame.
func _needs_process() -> bool:
	return _animator.is_animating() or _animator.is_open()

#region Open / close
## Starts opening. Safe to call when already open.
func open() -> void:
	_animator.open()
	set_process(_needs_process())

## Starts closing. Safe to call when already closed.
func close() -> void:
	_animator.close()
	set_process(_needs_process())

func toggle() -> void:
	_animator.toggle()
	set_process(_needs_process())

## Takes the panel off screen immediately, with no animation. Used when the game
## pauses: the tree stops, so a close animation started there would freeze part-way
## and leave the map sitting over the pause menu.
func snap_closed() -> void:
	_animator.snap_closed()
	set_process(_needs_process())

## True once the opening animation has finished, false from the moment a close starts.
func is_open() -> bool:
	return _animator.is_open()

## True while either animation is still running.
func is_animating() -> bool:
	return _animator.is_animating()

## Called once per frame while the map is opening. Return [code]true[/code] when the
## animation has finished and the map counts as open.
##
## Override to supply your own opening animation. [member position] starts wherever
## the panel was when [method open] was called (see [method get_open_position] and
## [method get_closed_position]).
func _animate_open(delta: float) -> bool:
	return _slide_towards(_open_position, delta)

## Called once per frame while the map is closing. Return [code]true[/code] when the
## animation has finished. See [method _animate_open].
func _animate_close(delta: float) -> bool:
	return _slide_towards(_closed_position, delta)

## Onscreen position of the panel, centred in its parent.
func get_open_position() -> Vector2:
	return _open_position

## Offscreen parking position of the panel, past the [member closed_side] edge.
func get_closed_position() -> Vector2:
	return _closed_position

func _slide_towards(target: Vector2, delta: float) -> bool:
	if animation_duration <= 0.0:
		position = target
		return true

	_slide_elapsed = minf(_slide_elapsed + delta, animation_duration)
	position = _slide_from.lerp(target, smoothstep(0.0, 1.0, _slide_elapsed / animation_duration))
	return _slide_elapsed >= animation_duration

func _on_open_started() -> void:
	# Every opening starts centred on the player, wherever the last one was left.
	_scroll_offset = Vector2i.ZERO
	_scroll_accum = Vector2.ZERO
	_scroll_input = Vector2i.ZERO
	# The player has been moving behind the closed panel, so catch the view up before
	# the first frame of it is visible.
	_recenter(true)
	_slide_from = position
	_slide_elapsed = 0.0
	open_started.emit()

func _on_close_started() -> void:
	_slide_from = position
	_slide_elapsed = 0.0
	close_started.emit()
#endregion

#region Scrolling
## How far the view is currently scrolled off the player's cell, in cells.
func get_scroll_offset() -> Vector2i:
	return _scroll_offset

## Scrolls the view by whole cells, clamped to the four scroll limits. Returns the
## number of cells actually moved, which is short of [param step] at a limit.
func scroll_by(step: Vector2i) -> Vector2i:
	var wanted := _scroll_offset + step
	wanted.x = clampi(wanted.x, -scroll_limit_left, scroll_limit_right)
	wanted.y = clampi(wanted.y, -scroll_limit_up, scroll_limit_down)

	var moved := wanted - _scroll_offset
	if moved != Vector2i.ZERO:
		_scroll_offset = wanted
		_apply_begin(_centered_begin() + _scroll_offset)
	return moved

## Puts the view back on the player's cell.
func reset_scroll() -> void:
	scroll_by(-_scroll_offset)

func _handle_scroll_input(delta: float) -> void:
	# Up reveals the cells above, which means the view climbs and the map appears to
	# slide down; left/right work the same way.
	var direction := Vector2i(
		int(Input.is_action_pressed(scroll_action_right)) - int(Input.is_action_pressed(scroll_action_left)),
		int(Input.is_action_pressed(scroll_action_down)) - int(Input.is_action_pressed(scroll_action_up)))

	# A newly pressed direction steps once right away, so a tap always moves a cell
	# and holding doesn't feel like it starts late.
	if direction.x != _scroll_input.x:
		_scroll_accum.x = 0.0
		if direction.x != 0:
			scroll_by(Vector2i(direction.x, 0))
	if direction.y != _scroll_input.y:
		_scroll_accum.y = 0.0
		if direction.y != 0:
			scroll_by(Vector2i(0, direction.y))
	_scroll_input = direction

	if direction == Vector2i.ZERO or scroll_speed <= 0.0:
		return

	# Whole cells only: the leftover fraction is carried into the next frame rather
	# than moving the view a partial tile.
	_scroll_accum += Vector2(direction) * scroll_speed * delta
	var step := Vector2i(int(_scroll_accum.x), int(_scroll_accum.y))
	if step != Vector2i.ZERO:
		_scroll_accum -= Vector2(step)
		scroll_by(step)
#endregion

#region Map view
func _map_pixel_size() -> Vector2:
	return Vector2(cells_horizontal, cells_vertical) * MetSys.CELL_SIZE * cell_scale

## Top-left cell that puts the player's cell in the middle of the panel.
func _centered_begin() -> Vector2i:
	# Vector3i.MAX until the player's first position report (and always, in the
	# editor). Centring on that would build the view around integer overflow.
	var center := Vector2i.ZERO
	if MetSys.last_player_position != Vector3i.MAX:
		center = MetSys.get_current_flat_coords()
	return center - Vector2i(cells_horizontal / 2, cells_vertical / 2)

func _rebuild_view() -> void:
	if not is_node_ready():
		return

	custom_minimum_size = _map_pixel_size()
	size = _map_pixel_size()
	_drawer.scale = Vector2.ONE * cell_scale

	_begin = _centered_begin() + _scroll_offset
	# Assigning drops the previous view, which frees its canvas items with it.
	_map_view = MetSys.make_map_view(_drawer, _begin, Vector2i(cells_horizontal, cells_vertical), MetSys.current_layer)

	_refresh_player_location()
	_update_positions()

func _refresh_player_location() -> void:
	if not is_node_ready():
		return

	var wanted := display_player_location and not Engine.is_editor_hint()
	if wanted and not is_instance_valid(_player_location):
		_player_location = MetSys.add_player_location(_drawer)
	elif not wanted and is_instance_valid(_player_location):
		_player_location.queue_free()
		_player_location = null

	_align_player_location()

## The location scene positions itself in absolute world-map pixels, so it needs the
## panel's top-left cell subtracted back out.
func _align_player_location() -> void:
	if is_instance_valid(_player_location):
		_player_location.offset = -Vector2(_begin) * MetSys.CELL_SIZE

## Follows the player, keeping whatever the view has been scrolled by. Skipped while
## the panel is offscreen unless [param force] is set, since nothing would see it.
func _recenter(force := false) -> void:
	if not _map_view:
		return
	if not force and not (_animator.is_open() or _animator.is_animating()):
		return
	_apply_begin(_centered_begin() + _scroll_offset)

## Moves the view so [param new_begin] is the cell in the panel's top-left corner.
func _apply_begin(new_begin: Vector2i) -> void:
	if not _map_view:
		return
	if new_begin == _begin and MetSys.current_layer == _map_view.layer:
		return

	_begin = new_begin
	_map_view.move_to(Vector3i(_begin.x, _begin.y, MetSys.current_layer))
	_align_player_location()

func _on_cell_changed(_new_cell: Vector3i) -> void:
	_recenter()

func _on_map_updated() -> void:
	if _map_view:
		_map_view.update_all()
#endregion

func _update_positions() -> void:
	if not is_node_ready() or Engine.is_editor_hint():
		return

	var area := get_parent_area_size()
	var panel := _map_pixel_size()
	_open_position = ((area - panel) * 0.5).round()

	match closed_side:
		ClosedSide.BOTTOM:
			_closed_position = Vector2(_open_position.x, area.y + offscreen_margin)
		ClosedSide.TOP:
			_closed_position = Vector2(_open_position.x, -panel.y - offscreen_margin)
		ClosedSide.LEFT:
			_closed_position = Vector2(-panel.x - offscreen_margin, _open_position.y)
		ClosedSide.RIGHT:
			_closed_position = Vector2(area.x + offscreen_margin, _open_position.y)

	# A resize mid-animation is left to the animation; only settled states re-park.
	if _animator and not _animator.is_animating():
		position = _open_position if _animator.is_open() else _closed_position
