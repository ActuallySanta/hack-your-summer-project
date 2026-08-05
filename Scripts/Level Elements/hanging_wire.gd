@tool
class_name HangingWire
extends Resource

## One sagging wire: two anchor points, a rope length, and how it moves.
##
## A wire describes a [i]shape[/i] and nothing else. Colour, thickness, shadow and
## how hard the player shoves it all live on the [HangingWireRig] that draws it,
## because those are what a bundle of cables in one place has in common — and
## wires that should look different belong on different rigs anyway. That keeps a
## wire down to its geometry, so a rig can hold a lot of them cheaply.
##
## The rig owns all the scene state too, so a wire holds none and the same
## [code].tres[/code] can safely be shared between rigs.
##
## [b]Shape.[/b] [member length] is the length of the [i]rope[/i], not the distance
## between the anchors, and that is what makes the wire hang: the further
## [member length] runs past the straight-line gap, the deeper the sag. The curve
## is a real catenary (the shape a chain actually takes), solved for the anchors
## and the length given, so a wire between anchors at different heights leans the
## way it should instead of drooping symmetrically. A length shorter than the gap
## between the anchors just draws taut.
##
## Points are in the rig's local space, so a rig sitting at the top-left corner of
## a room can hold every wire in that room with its anchors written as plain
## offsets.

## Shape being drawn, decided by the anchors and [member length].
enum Shape {
	TAUT, ## [member length] doesn't reach past the anchors, so it draws straight.
	CATENARY, ## The normal hanging curve.
	PLUMB, ## Anchors are vertically stacked: the rope drops and doubles back.
}

#region Geometry
## Anchor the wire starts at, in the rig's local space.
@export var point_a := Vector2(-48, -48):
	set(value):
		point_a = value
		_dirty = true
		emit_changed()

## Anchor the wire ends at, in the rig's local space.
@export var point_b := Vector2(48, -48):
	set(value):
		point_b = value
		_dirty = true
		emit_changed()

## Length of the rope. Everything past the straight-line distance between the
## anchors becomes sag, so this is the dial for how much the wire hangs. Below
## that distance the wire draws taut.
@export_range(0.0, 512.0, 1.0, "or_greater") var length := 160.0:
	set(value):
		length = maxf(value, 0.0)
		_dirty = true
		emit_changed()
#endregion

#region Motion
@export_group("Wind", "wind_")
## How far the valley drifts on the wind, in pixels. X is the sideways sway, Y is
## the bob. Zero on both leaves the wire still until something disturbs it.
@export var wind_strength := Vector2(3.0, 1.5):
	set(value):
		wind_strength = value
		emit_changed()

## Drift cycles per second. Slow values (well under 1) read as air movement;
## fast ones read as a rattle.
@export_range(0.0, 4.0, 0.01, "or_greater") var wind_speed := 0.12:
	set(value):
		wind_speed = maxf(value, 0.0)
		emit_changed()

## Offsets this wire's place in the wind cycle, in radians. Give neighbouring
## wires different phases so a bank of them doesn't move as one slab.
@export_range(0.0, 6.283, 0.01) var wind_phase := 0.0:
	set(value):
		wind_phase = value
		emit_changed()

@export_group("Swing", "swing_")
## Derive [member swing_frequency] from the sag, the way a longer pendulum swings
## slower. Deeper wires then settle at their own pace with nothing to tune.
@export var swing_auto_frequency := true:
	set(value):
		swing_auto_frequency = value
		_dirty = true
		emit_changed()

## How fast a disturbed wire swings, in cycles per second. Only used when
## [member swing_auto_frequency] is off.
@export_range(0.05, 4.0, 0.01) var swing_frequency := 0.8:
	set(value):
		swing_frequency = maxf(value, 0.05)
		_dirty = true
		emit_changed()

## How quickly a swing dies down, as a fraction of critical damping. Around 0.1
## rocks for a few seconds; 1.0 returns to rest without overshooting at all.
@export_range(0.0, 1.5, 0.01) var swing_damping := 0.18:
	set(value):
		swing_damping = maxf(value, 0.0)
		emit_changed()

## Ceiling on how far the valley can be pushed from its resting place, in world
## units. Stops a fast player from flinging the wire across the room.
@export_range(0.0, 128.0, 1.0, "or_greater") var swing_max := 24.0:
	set(value):
		swing_max = maxf(value, 0.0)
		emit_changed()
#endregion

## Cached curve constants. [method _rebuild] refreshes these whenever a geometry
## property changes; everything else is read straight off the exports.
var _dirty := true
var _shape := Shape.TAUT
var _curve_a := 1.0
var _curve_x0 := 0.0
var _curve_c := 0.0
var _plumb_low := Vector2.ZERO
var _plumb_split := 0.5
var _frequency := 1.0

## The wire's shape as a polyline in the rig's local space, [param samples] points
## long, running from [member point_a] to [member point_b].
##
## [param sway] displaces the valley: it is applied through the mode shape a real
## string swings in, so it peaks in the middle and falls to nothing at both
## anchors, and the wire stays pinned however hard it is pushed.
func sample_points(sway: Vector2, samples: int) -> PackedVector2Array:
	_rebuild()
	samples = maxi(samples, 2)
	var points := PackedVector2Array()
	points.resize(samples)
	var last := float(samples - 1)
	for i in samples:
		var t := float(i) / last
		points[i] = point_at(t) + sway * sin(PI * t)
	return points

## Point at [param t] along the wire, 0 at [member point_a] and 1 at
## [member point_b], with no sway applied.
func point_at(t: float) -> Vector2:
	_rebuild()
	t = clampf(t, 0.0, 1.0)
	match _shape:
		Shape.CATENARY:
			var x := lerpf(point_a.x, point_b.x, t)
			# Solved in a Y-up frame, so flip back to Godot's Y-down screen space.
			return Vector2(x, -(_curve_c + _curve_a * cosh((x - _curve_x0) / _curve_a)))
		Shape.PLUMB:
			if t <= _plumb_split:
				return point_a.lerp(_plumb_low, t / maxf(_plumb_split, 0.0001))
			return _plumb_low.lerp(point_b, (t - _plumb_split) / maxf(1.0 - _plumb_split, 0.0001))
		_:
			return point_a.lerp(point_b, t)

## Lowest point of the resting curve, in the rig's local space. This is the
## "valley" the sway moves.
func get_low_point() -> Vector2:
	_rebuild()
	match _shape:
		Shape.CATENARY:
			# The catenary bottoms out at its own centre when that falls between
			# the anchors, and at the lower anchor when the wire is barely slack.
			var x := clampf(_curve_x0, minf(point_a.x, point_b.x), maxf(point_a.x, point_b.x))
			return Vector2(x, -(_curve_c + _curve_a * cosh((x - _curve_x0) / _curve_a)))
		Shape.PLUMB:
			return _plumb_low
		_:
			return point_a.lerp(point_b, 0.5)

## How far the wire hangs below its lower anchor, in world units.
func get_sag() -> float:
	return maxf(get_low_point().y - maxf(point_a.y, point_b.y), 0.0)

## Sets [member length] to whatever makes the wire hang [param target] world
## units below its lower anchor.
##
## Inverted by search rather than algebra: the length a given sag needs has no
## closed form, but sag only ever climbs with length, so bisection walks straight
## onto it. This is what lets the valley be dragged to a depth directly.
func set_sag(target: float) -> void:
	var chord := point_a.distance_to(point_b)
	target = maxf(target, 0.0)
	if target <= 0.0:
		length = chord
		return
	var probe := duplicate() as HangingWire
	var low := chord
	# A rope hanging `target` deep is never much past twice that plus its span,
	# but grow the bracket rather than assume it.
	var high := chord + target * 2.5 + 1.0
	probe.length = high
	for _i in 16:
		if probe.get_sag() >= target:
			break
		high *= 1.5
		probe.length = high
	for _i in 32:
		var mid := (low + high) * 0.5
		probe.length = mid
		if probe.get_sag() < target:
			low = mid
		else:
			high = mid
	length = (low + high) * 0.5

## Cycles per second this wire swings at once disturbed, honouring
## [member swing_auto_frequency].
func get_swing_frequency() -> float:
	_rebuild()
	return _frequency

## Whether [member length] is too short to sag between the anchors.
func is_taut() -> bool:
	_rebuild()
	return _shape == Shape.TAUT

#region Curve solve
func _rebuild() -> void:
	if not _dirty:
		return
	_dirty = false
	_solve_shape()
	_frequency = _solve_frequency()

func _solve_shape() -> void:
	var chord := point_a.distance_to(point_b)
	if length <= chord + 0.001:
		_shape = Shape.TAUT
		return

	# Work in a Y-up frame with the left-hand anchor first, so the span is
	# positive and the curve opens upwards the way the maths assumes.
	var p1 := point_a
	var p2 := point_b
	if p1.x > p2.x:
		var swap := p1
		p1 = p2
		p2 = swap
	var span := p2.x - p1.x
	var y1 := -p1.y
	var rise := -p2.y - y1

	if span < 0.001:
		# Vertically stacked anchors: the rope drops straight down and doubles
		# back, so there is no curve to solve. Split the parameter by leg length.
		var drop := (length - absf(rise)) * 0.5
		_plumb_low = Vector2(point_a.x, maxf(point_a.y, point_b.y) + drop)
		var leg_a := point_a.distance_to(_plumb_low)
		_plumb_split = clampf(leg_a / maxf(length, 0.0001), 0.001, 0.999)
		_shape = Shape.PLUMB
		return

	# y = a * cosh((x - x0) / a) + c, with a from sqrt(L^2 - v^2) = 2a*sinh(span/2a)
	# and the centre from tanh((s1 + s2) / 2) = v / L. Both fall out of writing the
	# arc length and the height difference as sinh/cosh sums; see any catenary
	# derivation. `length > chord >= |rise|` here, so neither is degenerate.
	var horizontal := sqrt(maxf(length * length - rise * rise, 0.0001))
	var u := _solve_span_ratio(horizontal / span)
	if u < 1e-3:
		# Barely any slack at all. The curve is straight to the eye and `a` blows
		# up as `u` goes to zero, so drop to the straight line rather than lose
		# every digit of precision to a cosh of an enormous radius.
		_shape = Shape.TAUT
		return
	_curve_a = span / (2.0 * u)
	_curve_x0 = p1.x + span * 0.5 - _curve_a * _atanh(rise / length)
	_curve_c = y1 - _curve_a * cosh((p1.x - _curve_x0) / _curve_a)
	_shape = Shape.CATENARY

## Solves [code]sinh(u) / u = ratio[/code] for the positive [code]u[/code].
## [code]sinh(u) / u[/code] climbs from 1 without turning back, so bracket it by
## doubling and then bisect.
static func _solve_span_ratio(ratio: float) -> float:
	if ratio <= 1.0 + 1e-9:
		return 1e-4
	var low := 0.0
	var high := 1.0
	# sinh() overflows a double somewhere past 700, and a ratio that needs a `u`
	# anywhere near the cap is a rope hundreds of times its own span.
	while high < 350.0 and sinh(high) / high < ratio:
		high *= 2.0
	for _i in 48:
		var mid := (low + high) * 0.5
		if sinh(mid) / mid < ratio:
			low = mid
		else:
			high = mid
	return maxf((low + high) * 0.5, 1e-4)

static func _atanh(value: float) -> float:
	var z := clampf(value, -0.999999, 0.999999)
	return 0.5 * log((1.0 + z) / (1.0 - z))

func _solve_frequency() -> float:
	if not swing_auto_frequency:
		return swing_frequency
	# A hanging wire swings roughly like a pendulum as long as its sag, so deeper
	# wires come out slower on their own.
	var sag := maxf(get_low_point().y - maxf(point_a.y, point_b.y), 1.0)
	var gravity: float = ProjectSettings.get_setting("physics/2d/default_gravity", 980.0)
	return clampf(sqrt(maxf(gravity, 1.0) / sag) / TAU, 0.05, 4.0)
#endregion
