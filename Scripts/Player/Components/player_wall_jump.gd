## Pushing off a wall in mid-air.
##
## The wall is on the side [i]opposite[/i] the held direction: you hold away from it
## to launch off it. Two short windows make that forgiving in both directions -- one
## remembers the press for a moment after it happens, the other remembers the wall
## for a moment after leaving it -- so reaching the wall a frame late and leaving it
## a frame early both still work.
##
## [b]The arc is fixed.[/b] A wall jump is one launch, the same every time: the same
## push away from the wall and the same height, whether the button is tapped or held.
## It is emphatically not the floor jump -- that one is shaped by how long you hold,
## and letting a wall jump inherit those rules sent a held wall jump eight tiles up,
## because the floor jump's held gravity is tuned for a much slower launch. The wall
## jump takes gravity over for the length of its rise (see [member Player.gravity_override])
## so nothing else can shape it.
##
## [b]It is mostly sideways.[/b] The push is spent on getting away from the wall
## rather than on height, and the player cannot steer against it for
## [member launch_hold_seconds] -- otherwise holding back into the wall on the launch
## frame cancelled the whole thing and left only the vertical, which is what made wall
## jumps read as vertical.
##
## [b]One-way platforms.[/b] A point query cannot tell a wall from a one-way
## platform: both answer "there is a collider here". Inside a platform more than one
## tile wide, the probes to either side land in its own tiles, so the player used to
## be able to launch off a floor they were standing in the middle of. The probes go
## through [method PlayerGeometry.is_blocking_wall], which discards anything whose
## collision is entirely one-way -- so it covers one-way [StaticBody2D]s and any
## future one-way tile as well, not just the platforms that showed the bug.
class_name PlayerWallJump
extends PlayerComponent

@export_group("Launch")
## Apex of every wall jump, in tiles. Uniform: holding the button does not add to it.
@export var apex_tiles := 2.0
## Speed away from the wall, in pixels per second. This is the part that should
## dominate -- a wall jump is a way across a gap, not a way up.
@export var launch_speed := 520.0
## How long the launch owns the player's horizontal movement. Steering is ignored for
## this long so the push cannot be cancelled on the frame it happens.
@export_range(0.0, 0.5, 0.01, "or_greater") var launch_hold_seconds := 0.16
## Multiplies the project's gravity for the length of the rise. The arc's height comes
## from [member apex_tiles]; this decides how snappy getting there feels.
@export var arc_gravity_scale := 1.0

@export_group("Windows")
## How long a jump press stays live while looking for a wall, and how long a wall
## stays live after the player leaves it.
@export var contact_buffer_seconds := 0.05
## How far in from the top and bottom of the active collider the outermost probes sit.
##
## The rows used to be measured from the player's origin, which is not inside the
## collider at all while crouching -- the crouch shape hangs 25px below it. In a
## one-tile crawl space that put every probe inside the ceiling tile, so mashing jump
## while crawling wall-jumped off the ceiling, over and over, and pinned the player up
## against it. Rows now come from the collider, so they are always somewhere the
## player actually is.
@export var vertical_inset := 4.0
## How far past the collider's edge the outer probes reach.
@export var horizontal_buffer := 10.0
@export_flags_2d_physics var geometry_layers := 1

## Whether a wall is in reach right now. The animator watches this for the wall-slide
## pose.
var _available := false
var _contact_buffer := 0.0
var _input_buffer := 0.0
## Seconds of the launch's horizontal hold still to run.
var _hold_timer := 0.0
## Seconds since the last launch, for the push-off frame. See
## [method launched_recently].
var _since_launch := 999.0

func on_jump_pressed() -> void:
	_input_buffer = contact_buffer_seconds

func physics_update(delta: float) -> void:
	_since_launch += delta
	var available := _wall_in_reach()
	if not available:
		_contact_buffer = maxf(_contact_buffer - delta, 0.0)
	_input_buffer = maxf(_input_buffer - delta, 0.0)
	_available = available

	if _hold_timer > 0.0:
		_hold_timer = maxf(_hold_timer - delta, 0.0)
		if _hold_timer <= 0.0:
			player.horizontal_lock = 0.0
	player.horizontal_lock = _hold_timer

	if player.is_on_floor():
		return
	if _input_buffer > 0.0 and _contact_buffer > 0.0:
		wall_jump()

func wall_jump() -> void:
	_contact_buffer = 0.0
	_input_buffer = 0.0

	# Away from the wall is the way the player is holding, which is what put them
	# against it in the first place.
	var away := signf(player.move_input)
	if is_zero_approx(away):
		away = 1.0 if player.facing_right else -1.0

	var gravity := _arc_gravity()
	player.velocity = Vector2(away * launch_speed, -_launch_speed_for_apex(gravity))
	player.facing_right = away > 0.0

	# Ours until the rise is over: the floor jump's hold-variable gravity is tuned for
	# its own launch speed and would make this one enormous.
	player.gravity_override = gravity
	_hold_timer = launch_hold_seconds
	_since_launch = 0.0
	player.horizontal_lock = _hold_timer

	player.jump_sfx.play()
	player.jumped.emit()

func post_move_update(_delta: float) -> void:
	if player.gravity_override < 0.0:
		return
	# The rise is what needed protecting. Once it is over -- apex reached, or cut short
	# by a ceiling or a landing -- gravity goes back to whoever normally owns it.
	if player.velocity.y >= 0.0 or player.is_on_floor() or player.is_on_ceiling():
		player.gravity_override = -1.0

## The launch speed that brings the arc to rest exactly [member apex_tiles] above
## where it started.
##
## Two corrections, both of them about how the physics step actually integrates rather
## than about how a parabola works:
##
## The step moves the body at its current speed for a whole frame and only then takes
## that frame's gravity off, so every launch is handed half a frame of free travel.
## That is the [code]v*dt/2[/code] term, and solving the quadratic for it is what makes
## the number in the inspector the height actually reached.
##
## Then the launch is set here, and [PlayerFloorJump] -- which runs later in the same
## frame -- applies this frame's gravity to it. So the speed handed over is one
## frame's gravity more than the arc needs, to be spent immediately.
func _launch_speed_for_apex(gravity: float) -> float:
	var height := maxf(apex_tiles * player.tile_size, 1.0)
	var step := 1.0 / maxf(Engine.physics_ticks_per_second, 1)
	var gravity_step := gravity * step
	# h = v^2 / 2g + v*dt/2, solved for v.
	var free_flight := (-gravity_step + sqrt(gravity_step * gravity_step + 8.0 * gravity * height)) * 0.5
	return free_flight + gravity_step

func _arc_gravity() -> float:
	return player.get_gravity().y * arc_gravity_scale

## Whether a wall is close enough to launch from, and refreshes the contact window
## while one is.
func _wall_in_reach() -> bool:
	if not component_enabled or player.is_on_floor() or is_zero_approx(player.move_input):
		return false

	for point in probe_points():
		if PlayerGeometry.is_blocking_wall(player.get_world_2d(), point, geometry_layers, [player.get_rid()]):
			_contact_buffer = contact_buffer_seconds
			return true
	return false

## The points checked for wall: a band down the leading side of the active collider.
##
## Everything here is measured from the collider rather than from the player's origin,
## so the probes are inside the player's own height whichever shape is switched on.
func probe_points() -> PackedVector2Array:
	var direction := -1.0 if player.move_input > 0.0 else 1.0

	var bounds := player.collision_manager.get_bounds()
	var right_edge := maxf(bounds[0].x, bounds[1].x)
	var left_edge := minf(bounds[0].x, bounds[1].x)
	var top := minf(bounds[0].y, bounds[1].y)
	var bottom := maxf(bounds[0].y, bounds[1].y)
	var lead_edge := right_edge if direction > 0.0 else left_edge

	# Inset so a probe cannot reach into the tile above or below the player, which is
	# what let a crouching player find "wall" in the ceiling.
	var inset := minf(vertical_inset, (bottom - top) * 0.5)
	var rows : Array[ float ] = [ top + inset, (top + bottom) * 0.5, bottom - inset ]

	var points := PackedVector2Array()
	for depth in [ 1.0, horizontal_buffer ]:
		for row in rows:
			points.append(Vector2(lead_edge + direction * depth, row))
	return points

## Whether the player can push off a wall this instant.
##
## The contact window counts, because a wall jump fired inside it is a real wall jump;
## the input buffer does not, because that only remembers a press for a moment and
## being early is not the same as being able. So the wall-slide frame comes up exactly
## when the jump would work, and a press queued before then simply runs the slide and
## the push-off back to back.
func is_wall_available() -> bool:
	return _available or _contact_buffer > 0.0

## Whether a launch happened within the last frame or two, so the state machine can
## tell a push off a wall from an ordinary jump when it sees the player go airborne.
func launched_recently() -> bool:
	return _since_launch <= contact_buffer_seconds

func on_respawn() -> void:
	_available = false
	_contact_buffer = 0.0
	_input_buffer = 0.0
	_hold_timer = 0.0
	_since_launch = 999.0
	player.horizontal_lock = 0.0
	player.gravity_override = -1.0
