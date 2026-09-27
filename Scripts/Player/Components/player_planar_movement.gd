## Left, right, crawling and being knocked about: everything that decides
## the player's horizontal speed.
##
## It also owns the [CharacterBody2D] settings that make slopes work. Those live here
## rather than in the scene because they are part of how walking behaves, and because
## having them written down next to the speed they act on is what stops the next
## person from tuning one against the other.
class_name PlayerPlanarMovement
extends PlayerComponent

@export_group("Speed")
## Tuned against the walk animation's frame rate: at anything else the feet slide.
## Change the animation before changing this.
@export var move_speed := 350.0
@export var crouch_speed_multiplier := 0.35
## Fraction of [member move_speed] shed per physics frame when nothing is held.
@export_range(0.0, 1.0, 0.01) var stop_rate := 0.1
## Fraction of [member move_speed] shed per physics frame when the player is airborne
## and travelling faster than walking pace in the direction they are holding. Lower
## carries a wall jump's push further; 1 cuts straight to walking speed.
@export_range(0.01, 1.0, 0.01) var air_momentum_decay := 0.06

@export_group("Knockback")
## How far a hit pushes the player back, in tiles.
@export var knockback_tiles := 1.0
## How high the hop at the start of a knockback goes, in tiles.
@export var knockback_apex_tiles := 0.5
## How long the knockback lasts. The player has no control until it ends. Matches the
## length of the knockback animation, so the two finish together.
@export_range(0.05, 1.0, 0.01) var knockback_seconds := 0.5

@export_group("Slopes")
## Steepest floor the player can walk up. The tilesets' slopes are 45 degrees, so
## this sits a little above that -- exactly 45 leaves them on the boundary, where a
## single pixel of rounding decides between walking up and sliding off.
@export_range(0.0, 89.0, 0.5) var max_slope_degrees := 50.0
## How far below the feet the body looks for floor to stay attached to. Without this
## a slope going down is a series of little jumps: the body leaves the ground at the
## top of each step and lands again at the bottom.
@export var slope_snap_length := 32.0
## Keeps walking speed the same up, down and along the flat. Off, a slope costs the
## player speed for being a slope.
@export var constant_speed_on_slopes := true
## Holds the player still on a slope they are not walking on, rather than letting
## them slide to the bottom.
@export var stop_on_slope := true
## Whether hitting a wall stops the body from being carried up by the collision.
##
## Godot's default, and it should stay on: the "off" setting is the one that lets a
## body climb surfaces it is only pressing against. Slopes do not need it off -- they
## are floors, decided by [member max_slope_degrees], not walls.
@export var block_on_wall := true

@export_group("Animation")
## Real horizontal speed under which the player counts as standing still, whatever
## they are holding. This is what stops the walk cycle from playing into a wall: the
## input says "moving", the actual movement says otherwise, and the actual movement
## is what the animation follows.
@export var stall_speed := 12.0

## True when the player is pushing into something that will not move. Read by the
## animator through [method is_walking].
var _stalled := false
## -1 or 1: which way the current knockback pushes.
var _knockback_direction := 1.0
var _knockback_elapsed := 0.0

func _bind() -> void:
	player.floor_max_angle = deg_to_rad(max_slope_degrees)
	player.floor_snap_length = slope_snap_length
	player.floor_constant_speed = constant_speed_on_slopes
	player.floor_stop_on_slope = stop_on_slope
	player.floor_block_on_wall = block_on_wall

func physics_update(delta: float) -> void:
	match player.move_state:
		Player.MoveState.Knockback:
			_knockback(delta)
		_:
			_walk()

func _walk() -> void:
	# A launch that owns the horizontal (a wall jump) keeps it for its hold window, so
	# steering back the way you came cannot cancel the push on the frame it happens.
	if player.horizontal_lock > 0.0:
		return

	if is_zero_approx(player.move_input):
		player.velocity.x = move_toward(player.velocity.x, 0.0, move_speed * stop_rate)
		return

	var speed := move_speed
	if player.move_state == Player.MoveState.Crouching:
		speed *= crouch_speed_multiplier

	var target := player.move_input * speed
	player.facing_right = player.move_input > 0.0

	# Airborne and already travelling that way faster than walking pace: bleed the
	# extra off rather than cutting to walking speed. Without this a wall jump's push
	# vanished the instant its hold ended, which is most of why one read as a hop
	# straight up rather than as a leap across.
	if not player.is_grounded() \
			and absf(player.velocity.x) > absf(target) \
			and signf(player.velocity.x) == signf(target):
		player.velocity.x = move_toward(player.velocity.x, target, move_speed * air_momentum_decay)
		return

	player.velocity.x = target

## Starts a knockback. Only the sign of [param force] is used: it says which way to push.
## How far, how high and how long come from this component, so every hit reads the same
## however the hitbox that landed it was set up.
##
## It used to be the hitbox's strength divided by its duration, applied as a speed. The
## default hitbox (150 over 0.01s) came out at 15000px/s, and the knockback handed that
## speed back when it ended, so on the ground it took seconds to bleed off, and holding
## away from the hit in the air kept most of it. Holding towards the hit snapped straight
## back to walking speed, which is why the distance depended on what was held.
func start_knockback(force: float) -> void:
	if is_zero_approx(force):
		_knockback_direction = -1.0 if player.facing_right else 1.0
	else:
		_knockback_direction = signf(force)
	_knockback_elapsed = 0.0
	player.knockback_timer = knockback_seconds
	# A press made just before the hit would otherwise fire on the first frame of the
	# knockback, since the jump runs before this and the arc would overwrite it anyway.
	player.reset_all_inputs()

# The arc is set by position, not by forces: each frame moves the body to where the
# curve says it should be next, and move_and_slide still gets the final say on walls.
# That keeps the distance the same at any frame rate and whatever gravity is set to, and
# the arc ends with almost no speed left over for the next state to carry on with.
func _knockback(delta: float) -> void:
	var from := _knockback_offset(_knockback_elapsed / knockback_seconds)
	_knockback_elapsed = minf(_knockback_elapsed + delta, knockback_seconds)
	var to := _knockback_offset(_knockback_elapsed / knockback_seconds)
	player.velocity = (to - from) / delta
	player.knockback_timer = knockback_seconds - _knockback_elapsed

# Pushed out fast and slowing to a stop, over a hop that lands back at the starting height.
func _knockback_offset(progress: float) -> Vector2:
	var distance := knockback_tiles * player.tile_size
	var height := knockback_apex_tiles * player.tile_size
	var eased := 1.0 - (1.0 - progress) * (1.0 - progress)
	return Vector2(_knockback_direction * distance * eased, -4.0 * height * progress * (1.0 - progress))

func post_move_update(_delta: float) -> void:
	# get_real_velocity() is what the body managed after collisions, so pushing into a
	# wall reads as nought however hard the key is held.
	_stalled = not is_zero_approx(player.move_input) \
		and absf(player.get_real_velocity().x) < stall_speed

## Whether the player is actually travelling, as opposed to merely being told to.
func is_walking() -> bool:
	return not is_zero_approx(player.move_input) and not _stalled

func on_respawn() -> void:
	_stalled = false
	_knockback_elapsed = 0.0
