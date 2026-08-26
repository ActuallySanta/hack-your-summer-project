## The ground jump, and the gravity that shapes it.
##
## [b]How the height is set.[/b] The launch speed is left alone -- that is the part
## of the jump that felt right -- and the [i]gravity[/i] does the work instead. While
## the player is rising with the button held they get [member max_jump_tiles] worth
## of gravity; the moment they let go, gravity swaps to whatever brings the arc to a
## stop at [member min_jump_tiles]. Letting go partway lands somewhere between the
## two on its own, and because nothing is ever snapped to zero, the cut reads as the
## jump running out of push rather than as the player hitting an invisible lid.
##
## Heights are given in tiles, apex measured from the ground, because that is the
## question that actually gets asked of a jump: what can it clear.
##
## Set [member model] to [constant Model.LEGACY] to get the old jump back verbatim,
## constant-nudge gravity and all -- see [member legacy_hold_relief].
class_name PlayerFloorJump
extends PlayerComponent

## How the arc is shaped.
enum Model {
	## Rising gravity is picked from the two heights; releasing swaps between them.
	VARIABLE_GRAVITY,
	## What the jump did before: full gravity, minus a fixed nudge while held.
	LEGACY,
}

@export_group("Jump")
@export var model: Model = Model.VARIABLE_GRAVITY
## Launch speed, in pixels per second. This is the bit of the old jump worth keeping;
## the arc is shaped by the gravity below rather than by changing this.
@export var jump_force := 800.0
## How long a jump press is remembered when it lands before the player does.
@export var jump_buffer_time := 0.25
## How long after walking off a ledge a jump still counts as a ground jump.
@export var coyote_time := 0.1

@export_group("Height")
## Apex, in tiles, of a jump held all the way up. Tuned so five tiles clear tightly.
@export var max_jump_tiles := 5.2
## Apex, in tiles, of a jump released immediately. One tile has to be comfortable, so
## this sits half a tile above it.
@export var min_jump_tiles := 1.5
@export var tile_size := 48.0

@export_group("Falling")
## How heavy the fall feels. This is the knob for it.
##
## Multiplies the project's gravity (Project Settings > Physics > 2D > Default
## Gravity, currently 2000) once the player is on the way down, so 1 is 2000 and 0.75
## is 1500. It has no effect on jump heights: those are set by [member max_jump_tiles]
## and [member min_jump_tiles] and the rising gravity is worked out from them, so this
## can be tuned on its own without the jump changing shape.
@export_range(0.1, 3.0, 0.05, "or_greater") var fall_gravity_scale := 1.0

## Fastest the player may ever fall, in pixels per second -- terminal velocity.
##
## Lower it to cap long drops without making short ones floaty; at the default fall
## gravity the player reaches 1000 after a five-tile drop, so anything above that only
## affects falls longer than the tallest jump.
@export_range(200.0, 3000.0, 10.0, "or_greater") var max_fall_speed := 1500.0

## Fastest the player may ever rise. A ceiling on launches rather than a feel knob.
@export_range(200.0, 3000.0, 10.0, "or_greater") var max_rise_speed := 1000.0

@export_group("Legacy model")
## What [constant Model.LEGACY] subtracted from gravity each frame while the jump was
## held. Frame-rate dependent by nature -- it is a per-frame number, not a per-second
## one -- which is one of the reasons the default model no longer works this way.
@export var legacy_hold_relief := 10.0

var _jump_buffer := 0.0
var _coyote := 0.0
## False from the moment a jump launches until the player is genuinely back on the
## ground. This is what stops a crawl-height gap from being a trampoline: pinned
## against a ceiling the body can still report floor contact, and without this each
## report was a fresh jump, so holding the key floated the player across gaps that
## were meant to drop them.
var _grounded_since_jump := true

func _bind() -> void:
	player.jumped.connect(_on_external_jump)

#region Queries
## Whether a ground jump would be allowed right now.
func can_jump() -> bool:
	return component_enabled \
		and _grounded_since_jump \
		and (player.is_on_floor() or _coyote > 0.0)

func is_rising() -> bool:
	return player.velocity.y < 0.0

func has_buffered_jump() -> bool:
	return _jump_buffer > 0.0

func consume_jump_buffer() -> void:
	_jump_buffer = 0.0
#endregion

func on_jump_pressed() -> void:
	_jump_buffer = jump_buffer_time

func physics_update(delta: float) -> void:
	_apply_gravity(delta)
	_track_ground(delta)

	if _jump_buffer <= 0.0:
		return
	if can_jump():
		jump()
	else:
		_jump_buffer -= delta

## Launches. Public so the mantle can decline a vault and hand the press straight
## back, and so a scripted moment can make the player jump.
func jump() -> void:
	_jump_buffer = 0.0
	_coyote = 0.0
	_grounded_since_jump = false
	player.jump_sfx.play()
	player.velocity.y = -jump_force
	player.jumped.emit()

func post_move_update(_delta: float) -> void:
	# Rising into a ceiling is over: kill the climb rather than letting the body hold
	# itself up there while the key is down.
	if player.is_on_ceiling() and player.velocity.y < 0.0:
		player.velocity.y = 0.0

	if player.is_on_floor() and player.velocity.y >= 0.0:
		_grounded_since_jump = true

func on_respawn() -> void:
	_jump_buffer = 0.0
	_coyote = 0.0
	_grounded_since_jump = true

func _on_external_jump() -> void:
	# A wall jump is still a jump: it has to spend the ground the same way, or the
	# two together give a free extra launch.
	_grounded_since_jump = false
	_jump_buffer = 0.0

#region Gravity
func _apply_gravity(delta: float) -> void:
	if player.is_on_floor():
		_coyote = coyote_time
		return

	player.velocity.y += _gravity() * delta
	player.velocity.y = clampf(player.velocity.y, -max_rise_speed, max_fall_speed)

func _gravity() -> float:
	# A launch that owns the arc (a wall jump) sets its own gravity, so its height is
	# the same every time instead of being shaped by rules tuned for this jump.
	if player.gravity_override >= 0.0:
		return player.gravity_override

	var base: float = player.get_gravity().y
	if model == Model.LEGACY:
		# The original: full gravity, less a flat per-frame amount while held. Kept
		# as-is, frame-rate dependence and all, so switching back is a true revert.
		var relief := legacy_hold_relief / maxf(get_physics_process_delta_time(), 0.0001)
		return base - relief if player.jump_held else base

	if not is_rising():
		return base * fall_gravity_scale
	return _gravity_for_apex(max_jump_tiles) if player.jump_held else _gravity_for_apex(min_jump_tiles)

## The gravity that brings a launch at [member jump_force] to rest exactly
## [param tiles] above the ground.
##
## The textbook answer is v^2 = 2*g*h solved for g, but the physics step does not
## integrate a curve -- it moves the body at its current speed for a whole frame and
## only then takes the frame's gravity off. That hands the jump half a frame of free
## travel, a fixed v*dt/2 on top of every apex (about 7px at 800 and 60Hz), so a jump
## asked for 5.2 tiles arrives at 5.34. Taking that overshoot out of the height first
## is what makes the numbers in the inspector the heights actually reached.
func _gravity_for_apex(tiles: float) -> float:
	var height := maxf(tiles * tile_size, 1.0)
	var step_overshoot := jump_force * 0.5 / maxf(Engine.physics_ticks_per_second, 1)
	return (jump_force * jump_force) / (2.0 * maxf(height - step_overshoot, 1.0))

func _track_ground(delta: float) -> void:
	if not player.is_on_floor():
		_coyote -= delta
#endregion
