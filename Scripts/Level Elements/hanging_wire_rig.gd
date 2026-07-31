@tool
class_name HangingWireRig
extends Node2D

## Draws any number of hanging wires as chunky pixels that line up with the
## room's tile art.
##
## Add one of these to a room, then fill [member wires] with a [HangingWire] per
## cable. One rig can carry a whole room's worth, so a wall of cabling is a single
## node rather than a node each. Anchor points are in the rig's local space, so
## the rig is best dropped somewhere memorable (a corner, a junction box) and left
## alone while the wires are laid out as offsets from it.
##
## [b]What lives where.[/b] A [HangingWire] carries only its own shape and
## movement. Colour, thickness, shadow and how hard the player shoves the cables
## are settings on the rig, shared by everything it draws — a bundle running
## through one room is the same cable, and wires that should look different want
## their own rig anyway. It also keeps each wire small, which is what lets a rig
## hold a lot of them.
##
## [b]Matching the tiles.[/b] The wire is rasterised onto a grid rather than drawn
## as a smooth line, so it has the same blocky edges as the tile art around it. The
## grid comes from a [TileMapLayer]: one art pixel of a 16x16 tile drawn at scale 3
## covers 3 world units, so that is the size of block the wire is drawn in, snapped
## to the same origin as the layer. Leave [member pixel_source] alone and the rig
## finds a layer by itself; point [member tile_map_layer] at one to be explicit, or
## switch to [constant PixelSource.MANUAL] to set the size by hand.
##
## [b]Movement.[/b] Each wire's valley drifts on [member HangingWire.wind_strength]
## and gets shoved around by the player walking through it, on a spring that rocks
## and settles. Nothing moves the anchors, so a wire always stays connected. Other
## systems can knock a wire about through [method disturb].
##
## Redraws only happen when a wire's sway crosses a pixel boundary, so a slow drift
## costs a handful of redraws a second rather than one per frame.

## Where the size of one drawn pixel comes from.
enum PixelSource {
	TILE_MAP_LAYER, ## Read it off a [TileMapLayer], so the wire matches the tiles.
	MANUAL, ## Use [member pixel_size] as given.
}

## The wires this rig draws. Add an element and expand it to place a new cable.
@export var wires: Array[HangingWire] = []:
	set(value):
		_unbind_wires()
		wires = value
		_bind_wires()
		_invalidate()

@export_group("Appearance")
## Colour of the wires.
@export var color := Color("3d4a5c"):
	set(value):
		color = value
		queue_redraw()

## How thick the wires are, in pixels. Extra thickness is added downwards.
@export_range(1, 8, 1) var thickness := 1:
	set(value):
		thickness = maxi(value, 1)
		_invalidate()

## Where the shadow sits relative to the wires, in pixels. Positive Y is below.
@export var shadow_offset := Vector2i(0, 1):
	set(value):
		shadow_offset = value
		queue_redraw()

## Darkens [member color] to get the shadow colour. Ignored when
## [member use_shadow_color] is on.
@export_range(0.0, 1.0, 0.01) var shadow_darkening := 0.5:
	set(value):
		shadow_darkening = value
		queue_redraw()

## Pick the shadow's colour by hand instead of darkening [member color]. Worth
## turning on over a coloured background, where a straight darkening reads as
## grey rather than as shade.
@export var use_shadow_color := false:
	set(value):
		use_shadow_color = value
		queue_redraw()

## Shadow colour used when [member use_shadow_color] is on.
@export var shadow_color := Color("1e2530"):
	set(value):
		shadow_color = value
		queue_redraw()

@export_group("Pixel Grid")
## Where the size of one drawn pixel comes from.
@export var pixel_source := PixelSource.TILE_MAP_LAYER:
	set(value):
		pixel_source = value
		_invalidate()

## The layer to take the pixel grid from. Leave empty to search the room for one,
## which is enough whenever a room's layers all share a scale.
@export_node_path("TileMapLayer") var tile_map_layer := NodePath():
	set(value):
		tile_map_layer = value
		_layer_cache = null
		_invalidate()

## Size of one drawn pixel in world units, used when [member pixel_source] is
## [constant PixelSource.MANUAL] and as the fallback when no layer can be found.
@export_range(1.0, 16.0, 0.5, "or_greater") var pixel_size := 3.0:
	set(value):
		pixel_size = maxf(value, 0.01)
		_invalidate()

@export_group("Motion")
## Whether the wires move at all. Off draws them at rest, which is what a wire
## behind glass or in a sealed room wants.
@export var animate := true

## Run the motion in the editor too. Handy for dialling in wind, but it keeps the
## editor redrawing, so it defaults to off.
@export var animate_in_editor := false:
	set(value):
		animate_in_editor = value
		_invalidate()

@export_group("Player Reaction", "player_")
## Whether the player pushes the wires aside when walking through them.
@export var player_reacts := true

## How hard the player pushes a wire when passing through it. Zero means the
## player walks through without moving anything.
@export_range(0.0, 4.0, 0.01, "or_greater") var player_push := 0.6

## How close the player has to get to a wire to shove it, in world units.
@export_range(0.0, 128.0, 1.0, "or_greater") var player_reach := 24.0

@export_group("Editor")
## Draw anchor markers over the wires in the editor. Turned off automatically
## while the Hanging Wire Editor plugin has this rig selected, since its drag
## handles mark the same points.
@export var show_anchors := true:
	set(value):
		show_anchors = value
		_invalidate()

## Set by the Hanging Wire Editor plugin while it is drawing drag handles for
## this rig, so the two don't mark the same points twice. Not exported, so it
## never ends up saved in a scene.
var editor_handles_active := false:
	set(value):
		editor_handles_active = value
		queue_redraw()

## Grid the wire is rasterised onto, in this rig's local space.
var _cell_size := Vector2.ONE
var _grid_origin := Vector2.ZERO

## Per-wire state, all indexed alongside [member wires].
var _swing := PackedVector2Array() ## Current push away from rest.
var _swing_velocity := PackedVector2Array()
var _sway_cell := PackedVector2Array() ## Last sway, in whole pixels, to spot redraws.
var _points: Array[PackedVector2Array] = [] ## Sampled curve, reused for player hits.
var _cells: Array[Dictionary] = [] ## Lit pixels, keyed by grid coordinate.
var _bounds: Array[Rect2] = [] ## Curve extents, to skip player tests cheaply.

var _time := 0.0
var _dirty := true
var _layer_cache: TileMapLayer

func _ready() -> void:
	# The grid is anchored in global space, so dragging the rig re-snaps the wires.
	set_notify_transform(true)
	_bind_wires()
	_resolve_grid()
	_invalidate()

func _process(delta: float) -> void:
	if not animate:
		return
	if Engine.is_editor_hint() and not animate_in_editor:
		return
	_resize_state()
	_time += delta

	var moved := false
	for i in wires.size():
		var wire := wires[i]
		if wire == null:
			continue
		# A damped spring about the resting curve: the wind rides on top of it
		# rather than driving it, so a gust can't feed a swing into resonance.
		var omega := TAU * wire.get_swing_frequency()
		var velocity := _swing_velocity[i]
		velocity += (-omega * omega * _swing[i] - 2.0 * wire.swing_damping * omega * velocity) * delta
		_swing_velocity[i] = velocity
		_swing[i] = (_swing[i] + velocity * delta).limit_length(wire.swing_max)

		# Only a sway that crossed a pixel boundary can change what is drawn.
		var cell := ((_swing[i] + _wind_offset(wire)) / _cell_size).floor()
		if cell != _sway_cell[i]:
			_sway_cell[i] = cell
			moved = true

	if moved:
		_invalidate()

func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint() or not player_reacts or not animate:
		return
	if player_push <= 0.0 or player_reach <= 0.0:
		return
	var player := PlayerManager.player
	if not is_instance_valid(player) or not player.is_inside_tree():
		return
	# Only a moving player disturbs anything, so one standing in a wire lets it
	# settle instead of holding it aside.
	var velocity: Vector2 = player.velocity
	if velocity.length_squared() < 1.0:
		return

	if _dirty:
		_rebuild()
	var inverse := global_transform.affine_inverse()
	var local_player := inverse * player.global_position
	var local_velocity := inverse.basis_xform(velocity)

	for i in mini(wires.size(), _points.size()):
		var wire := wires[i]
		if wire == null:
			continue
		if not _bounds[i].grow(player_reach).has_point(local_player):
			continue
		var points := _points[i]
		if points.is_empty():
			continue
		var nearest := 0
		var nearest_distance := INF
		for j in points.size():
			var distance := local_player.distance_squared_to(points[j])
			if distance < nearest_distance:
				nearest_distance = distance
				nearest = j
		nearest_distance = sqrt(nearest_distance)
		if nearest_distance > player_reach:
			continue
		# Push hardest through the middle of the wire and when passing closest to
		# it, matching the mode shape the sway is applied through.
		var along := float(nearest) / float(maxi(points.size() - 1, 1))
		var weight := sin(PI * along) * (1.0 - nearest_distance / player_reach)
		_swing_velocity[i] += local_velocity * player_push * weight * delta

func _notification(what: int) -> void:
	if what == NOTIFICATION_TRANSFORM_CHANGED:
		_invalidate()

func _draw() -> void:
	if _dirty:
		_rebuild()
	# Every wire on a rig shares one colour, so they are drawn as a single set
	# rather than one at a time. That way a wire crossing behind another can't
	# cast its shadow onto the front one's body - together they read as one
	# bundle of cable instead of a stack of separate sprites.
	var body := {}
	for i in mini(wires.size(), _cells.size()):
		if wires[i] != null:
			body.merge(_cells[i])
	if not body.is_empty():
		if shadow_offset != Vector2i.ZERO:
			var shadow := {}
			for cell: Vector2i in body:
				shadow[cell + shadow_offset] = true
			# Skipping the wires' own pixels keeps a translucent shadow from
			# doubling up underneath them.
			_draw_cells(shadow, get_shadow_color(), body)
		_draw_cells(body, color, {})
	if Engine.is_editor_hint() and show_anchors and not editor_handles_active:
		_draw_anchors()

func _get_configuration_warnings() -> PackedStringArray:
	var warnings := PackedStringArray()
	if wires.is_empty():
		warnings.append("No wires to draw. Add an element to Wires and expand it to place one.")
	for i in wires.size():
		var wire := wires[i]
		if wire == null:
			warnings.append("Wire %d is empty. Set its type to HangingWire." % i)
		elif wire.is_taut():
			warnings.append("Wire %d has a Length shorter than the gap between its anchors, so it draws straight. Raise Length past %d to make it hang."
					% [i, ceili(wire.point_a.distance_to(wire.point_b))])
	if pixel_source == PixelSource.TILE_MAP_LAYER and _find_layer() == null:
		warnings.append("No TileMapLayer found to take the pixel grid from, so Pixel Size is being used as-is. Point Tile Map Layer at one, or switch Pixel Source to Manual.")
	if not is_equal_approx(rotation, 0.0):
		warnings.append("A rotated rig can't snap its wires to the tile grid. Rotate the wires' anchor points instead of the rig.")
	return warnings

## Knocks the wire at [param index] sideways, as if something had swept through
## it. [param impulse] is a velocity in world units per second; the wire rocks and
## settles from there under its own damping.
func disturb(index: int, impulse: Vector2) -> void:
	_resize_state()
	if index < 0 or index >= wires.size() or wires[index] == null:
		return
	_swing_velocity[index] += global_transform.affine_inverse().basis_xform(impulse)

## Knocks every wire, as [method disturb] does. Useful for a shockwave.
func disturb_all(impulse: Vector2) -> void:
	for i in wires.size():
		disturb(i, impulse)

## Picks up wires added or edited by code. Assigning [member wires] does this
## already; call it after changing the array in place, or after moving the
## [TileMapLayer] the grid is read from.
func refresh() -> void:
	_layer_cache = null
	_bind_wires()
	_resolve_grid()
	_invalidate()

## Rounds [param local_point] onto the pixel grid the wires are drawn on, so an
## anchor placed through it lands on a whole art pixel rather than between two.
func snap_to_pixel_grid(local_point: Vector2) -> Vector2:
	_resolve_grid()
	return _grid_origin + ((local_point - _grid_origin) / _cell_size).round() * _cell_size

## Size of one drawn pixel, in this rig's local space.
func get_pixel_cell_size() -> Vector2:
	_resolve_grid()
	return _cell_size

## The colour drawn under the wires.
func get_shadow_color() -> Color:
	return shadow_color if use_shadow_color else color.darkened(shadow_darkening)

#region Geometry
func _invalidate() -> void:
	_dirty = true
	queue_redraw()
	if Engine.is_editor_hint():
		update_configuration_warnings()

## Resamples every wire and works out which pixels it lights up.
func _rebuild() -> void:
	_dirty = false
	_resolve_grid()
	_resize_state()
	for i in wires.size():
		var wire := wires[i]
		if wire == null:
			_points[i] = PackedVector2Array()
			_cells[i] = {}
			_bounds[i] = Rect2()
			continue
		var sway := _swing[i] + _wind_offset(wire)
		var points := wire.sample_points(sway, _sample_count(wire))
		_points[i] = points
		_bounds[i] = _bounds_of(points)
		var cells := {}
		_rasterize(points, thickness, cells)
		_cells[i] = cells

## Turns a polyline into the set of grid pixels it covers, joining consecutive
## samples so the wire stays unbroken wherever it runs steeply.
func _rasterize(points: PackedVector2Array, thickness: int, cells: Dictionary) -> void:
	var previous := Vector2i.ZERO
	var has_previous := false
	for point in points:
		var cell := _cell_of(point)
		if has_previous:
			if cell != previous:
				_trace_line(previous, cell, cells)
		else:
			cells[cell] = true
		previous = cell
		has_previous = true
	if thickness > 1:
		var extra := {}
		for cell: Vector2i in cells:
			for offset in range(1, thickness):
				extra[cell + Vector2i(0, offset)] = true
		cells.merge(extra)

## Bresenham, inclusive of both ends.
func _trace_line(from: Vector2i, to: Vector2i, cells: Dictionary) -> void:
	var dx := absi(to.x - from.x)
	var dy := -absi(to.y - from.y)
	var step_x := 1 if from.x < to.x else -1
	var step_y := 1 if from.y < to.y else -1
	var error := dx + dy
	var x := from.x
	var y := from.y
	while true:
		cells[Vector2i(x, y)] = true
		if x == to.x and y == to.y:
			return
		var doubled := error * 2
		if doubled >= dy:
			error += dy
			x += step_x
		if doubled <= dx:
			error += dx
			y += step_y

func _cell_of(point: Vector2) -> Vector2i:
	return Vector2i(((point - _grid_origin) / _cell_size).floor())

## Enough samples that consecutive ones land within about a pixel of each other,
## which keeps the traced line from having to guess at the curve between them.
func _sample_count(wire: HangingWire) -> int:
	var step := maxf(minf(_cell_size.x, _cell_size.y), 0.001)
	var span := maxf(wire.length, wire.point_a.distance_to(wire.point_b))
	return clampi(int(span / step * 1.5) + 2, 8, 4096)

func _bounds_of(points: PackedVector2Array) -> Rect2:
	if points.is_empty():
		return Rect2()
	var bounds := Rect2(points[0], Vector2.ZERO)
	for point in points:
		bounds = bounds.expand(point)
	return bounds

func _wind_offset(wire: HangingWire) -> Vector2:
	if wire.wind_strength == Vector2.ZERO or wire.wind_speed <= 0.0:
		return Vector2.ZERO
	# Two sines at unrelated rates, so the sway and the bob drift apart instead of
	# tracing the same diagonal over and over.
	var phase := TAU * wire.wind_speed * _time + wire.wind_phase
	return Vector2(sin(phase), sin(phase * 0.7 + 1.3)) * wire.wind_strength
#endregion

#region Pixel grid
## Works out the size and origin of the pixel grid, converted into this rig's
## local space so the drawing below can stay axis-aligned.
func _resolve_grid() -> void:
	var world_size := pixel_size
	var world_origin := Vector2.ZERO
	if pixel_source == PixelSource.TILE_MAP_LAYER:
		var layer := _find_layer()
		if layer != null:
			# A tile's art is drawn one texture pixel per unscaled unit, so the
			# layer's scale is exactly how big one art pixel ends up on screen.
			world_size = maxf(absf(layer.global_scale.x), 0.01)
			world_origin = layer.global_position
	var rig_scale := global_scale
	_cell_size = Vector2(
		world_size / maxf(absf(rig_scale.x), 0.0001),
		world_size / maxf(absf(rig_scale.y), 0.0001))
	_grid_origin = to_local(world_origin)

## The layer the grid is taken from: the one named in [member tile_map_layer] if
## there is one, otherwise the nearest layer found by walking up the tree and
## looking through each ancestor's children.
func _find_layer() -> TileMapLayer:
	if not tile_map_layer.is_empty():
		return get_node_or_null(tile_map_layer) as TileMapLayer
	# Searching costs a walk over the whole room, and the answer only changes when
	# the room does, so hold onto it between rebuilds.
	if is_instance_valid(_layer_cache) and _layer_cache.is_inside_tree():
		return _layer_cache
	var node: Node = self
	while node != null:
		var found := _first_layer_in(node)
		if found != null:
			_layer_cache = found
			return found
		node = node.get_parent()
	return null

func _first_layer_in(node: Node) -> TileMapLayer:
	for child in node.get_children():
		if child is TileMapLayer:
			return child
		var found := _first_layer_in(child)
		if found != null:
			return found
	return null
#endregion

#region Drawing
## Fills [param cells], skipping anything in [param skip]. Runs of pixels along a
## row are drawn as one rectangle, so a long wire costs a few dozen draws rather
## than one per pixel.
func _draw_cells(cells: Dictionary, color: Color, skip: Dictionary) -> void:
	var rows := {}
	for cell: Vector2i in cells:
		if skip.has(cell):
			continue
		if not rows.has(cell.y):
			rows[cell.y] = []
		rows[cell.y].append(cell.x)
	for y: int in rows:
		var columns: Array = rows[y]
		columns.sort()
		var run_start: int = columns[0]
		var run_end: int = columns[0]
		for i in range(1, columns.size()):
			var x: int = columns[i]
			if x == run_end + 1:
				run_end = x
				continue
			_draw_run(run_start, run_end, y, color)
			run_start = x
			run_end = x
		_draw_run(run_start, run_end, y, color)

func _draw_run(from_x: int, to_x: int, y: int, color: Color) -> void:
	var corner := _grid_origin + Vector2(from_x, y) * _cell_size
	var extent := Vector2(float(to_x - from_x + 1) * _cell_size.x, _cell_size.y)
	draw_rect(Rect2(corner, extent), color, true)

## Editor-only markers, so the anchors and the valley are findable while the
## wires are being laid out.
func _draw_anchors() -> void:
	var anchor_color := Color(0.4, 0.9, 1.0, 0.9)
	var valley_color := Color(1.0, 0.8, 0.3, 0.9)
	var arm := maxf(_cell_size.x, 2.0) * 2.0
	for wire in wires:
		if wire == null:
			continue
		for point in [wire.point_a, wire.point_b]:
			draw_line(point - Vector2(arm, 0), point + Vector2(arm, 0), anchor_color, 1.0)
			draw_line(point - Vector2(0, arm), point + Vector2(0, arm), anchor_color, 1.0)
		var valley := wire.get_low_point()
		draw_line(valley - Vector2(arm, 0) * 0.6, valley + Vector2(arm, 0) * 0.6, valley_color, 1.0)
#endregion

#region Wire bookkeeping
func _resize_state() -> void:
	var count := wires.size()
	if _points.size() == count:
		return
	var previous := _points.size()
	_swing.resize(count)
	_swing_velocity.resize(count)
	_sway_cell.resize(count)
	_points.resize(count)
	_cells.resize(count)
	_bounds.resize(count)
	# Give the new slots their own containers rather than trusting resize() to
	# hand out unshared ones, so two wires can never end up writing to one
	# dictionary of pixels.
	for i in range(previous, count):
		_cells[i] = {}
		_points[i] = PackedVector2Array()
		_bounds[i] = Rect2()

## Editing a wire in the inspector changes a resource, not a property of this
## node, so the redraw has to come off the resource's own signal.
func _bind_wires() -> void:
	for wire in wires:
		if wire != null and not wire.changed.is_connected(_invalidate):
			wire.changed.connect(_invalidate)

func _unbind_wires() -> void:
	for wire in wires:
		if wire != null and wire.changed.is_connected(_invalidate):
			wire.changed.disconnect(_invalidate)
#endregion
