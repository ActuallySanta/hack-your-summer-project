## The gun on the shoot button.
##
## One shot every [member cooldown] seconds, whether the trigger is held or tapped
## again. Holding it down keeps the fire buffer topped up, so a held trigger and a
## mashed one come to the same thing.
##
## [b]On the rate.[/b] This was briefly driven by the shoot animation instead -- a shot
## rewound a couple of frames and went off again as it came back round, giving roughly
## one every 0.2s. Playtesters preferred the slower gun, so the rate is a plain
## cooldown again; only the auto-fire survives from that version.
class_name PlayerShooting
extends PlayerComponent

signal fired(mode: StringName)

## Gun modes the player can carry.
const GUN_MODES: Array[StringName] = [&"stun", &"plasma"]

## How the gun is being held, which is not quite the player's move state.
##
## Crouching and crawling are one [enum Player.MoveState] -- they are told apart by
## whether the player is actually travelling -- but the gun sits somewhere different in
## each, and each has its own frames. This is the distinction both of those need, worked
## out once in [method _stance] rather than twice.
enum Stance { STANDING, CROUCHING, CRAWLING, AIRBORNE, KNOCKBACK }

@export_group("Gun")
@export var bullet_scene: PackedScene
## Seconds between shots, and the rate a held trigger fires at.
@export var cooldown := 0.6
## How long a press keeps counting after it lands, so a shot fired a hair early still
## goes off rather than being dropped.
@export var buffer_time := 0.15
## Whether holding the button keeps firing. Off, each shot needs its own press.
@export var auto_fire_on_hold := true

@export_group("Muzzle")
## Where the muzzle sits for each stance, relative to the player's origin.
##
## [b]X is how far in front[/b], mirrored with the player, so a positive number always
## reaches the way they are facing whichever way that is. [b]Y is height[/b], negative
## being up. Both are per stance because the gun is not in the same place in the
## crouched frames as in the standing ones -- it used to be one shared reach for every
## stance, with only the height tunable, so a crouched shot came out of the player's
## middle however the frames were drawn.
##
## Measured from the origin rather than from the sprite, and the height picks up
## [member Player.visual_offset] so it follows the sprite down while the shorter air
## collider is in.
@export var muzzle_offset: Dictionary[int, Vector2] = {
	Player.MoveState.Standing: Vector2(10.0, -20.0),
	Player.MoveState.Crouching: Vector2(10.0, 4.0),
	Player.MoveState.Jumping: Vector2(10.0, 0.0),
	Player.MoveState.Knockback: Vector2(10.0, 0.0),
}

@export_group("Animation")
@export var stand_animation: StringName = &"stand_shoot"
@export var crouch_animation: StringName = &"crouch_shoot"
@export var air_animation: StringName = &"jump_shoot"
## Shooting while crawling. The crouched shot is drawn standing still, so a player
## moving along the floor needs its own.
@export var crawl_animation: StringName = &"crawl_shoot"

var _has_gun := false
var _mode: StringName = &"stun"
var _cooldown_timer := 0.0
var _buffer_timer := 0.0

#region Gun state
func has_gun() -> bool:
	return _has_gun

func enable_gun() -> void:
	_has_gun = true

func disable_gun() -> void:
	_has_gun = false

func set_gun(mode: StringName) -> void:
	if not mode in GUN_MODES:
		printerr("PlayerShooting: \"%s\" is not a gun mode." % mode)
		return
	_mode = mode

func gun_mode() -> StringName:
	return _mode
#endregion

func on_shoot_pressed() -> void:
	if not _has_gun:
		return
	_buffer_timer = buffer_time

func physics_update(delta: float) -> void:
	if _cooldown_timer > 0.0:
		_cooldown_timer -= delta

	# A held trigger keeps the buffer topped up, which is what makes holding the button
	# fire at the same rate as tapping it as fast as the cooldown allows.
	if auto_fire_on_hold and _has_gun and player.shoot_held and _buffer_timer <= 0.0:
		_buffer_timer = buffer_time

	if _buffer_timer <= 0.0:
		return
	if _cooldown_timer <= 0.0:
		shoot()
	else:
		_buffer_timer -= delta

func shoot() -> void:
	if bullet_scene == null or not _has_gun:
		return

	var bullet := bullet_scene.instantiate() as PlayerBullet
	var offset: Vector2 = muzzle_offset.get(player.move_state, Vector2.ZERO)
	if not player.facing_right:
		offset.x *= -1.0
		bullet.scale.x = -1.0
	# The tuned heights are relative to the sprite, so they follow it while airborne.
	offset.y += player.visual_offset
	var muzzle := player.global_position + offset
	bullet.direction = Vector2.RIGHT if player.facing_right else Vector2.LEFT
	bullet.set_mode(_mode)

	# Into the room, so the shot is cleaned up with it. Placed after it is in the tree
	# and in global terms, so it lands in the same spot whatever it ends up under.
	var home := ProjectileHome.current_room()
	(home if home != null else get_tree().root).add_child(bullet)
	bullet.global_position = muzzle

	player.shoot_sfx.play()
	_cooldown_timer = cooldown
	_buffer_timer = 0.0
	# Firing keeps the wrench out of action for the same stretch, so a shot cannot be
	# cancelled straight into a swing.
	player.wrench.block_for(cooldown)

	player.animator.request_action(_animation_for_state())
	fired.emit(_mode)

func _animation_for_state() -> StringName:
	match player.move_state:
		Player.MoveState.Crouching:
			var moving: bool = player.planar_movement != null and player.planar_movement.is_walking()
			return crawl_animation if moving else crouch_animation
		Player.MoveState.Jumping:
			return air_animation
		_:
			return stand_animation

func on_respawn() -> void:
	_cooldown_timer = 0.0
	_buffer_timer = 0.0

## Puts the gun on cooldown from outside, so swinging the wrench still blocks a shot.
func block_for(seconds: float) -> void:
	_cooldown_timer = maxf(_cooldown_timer, seconds)
