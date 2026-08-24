class_name CDMinigun extends Node2D

@export var bullet_scene : PackedScene
@export var spawn_delta : Vector2

@onready var animator := $MiniGun/MinigunAnimator

## Where spawned bullets get parented. The drone sets this to its own parent in
## _ready(). It must be somewhere outside the drone's FaderNode: bullets left
## under the drone inherit its fade and its mirrored scale, so they wink out and
## teleport with it whenever it ducks into a tunnel.
var bullet_parent : Node2D

var anim_speed_adjust : float:
	set(value):
		anim_speed_adjust = value
		$MiniGun.anim_speed_adjust = value

var timer := 0.0
var is_flipped : bool = false

func make_paused(value: bool) -> void:
	$MiniGun.make_paused(value)

func _process(delta: float) -> void:
	timer += delta

## True while a shot is still playing out, i.e. its bullet may not have spawned
## yet -- the Shoot animation spawns on a method track partway through.
func is_shooting() -> bool:
	return animator.is_playing()

func shoot() -> bool:
	if animator.is_playing():
		return false
	
	animator.play("Shoot")
	return true

func spawn_bullet() -> void:
	var parent : Node2D = bullet_parent if is_instance_valid(bullet_parent) else get_parent()
	var bullet : Bullet = bullet_scene.instantiate()
	# to_global() already mirrors the offset when the drone faces right (the
	# root's scale.x goes negative), so spawn_delta.x must NOT be negated here
	# as well -- doing both cancels out and the muzzle offset never flips.
	var spawn_global := to_global(spawn_delta)
	
	parent.add_child(bullet)
	bullet.initial_operations(parent.to_local(spawn_global), "L" if is_flipped else "R", 0.0)
	# Bullets no longer live under the drone, so carry its art size across by
	# hand -- unsigned, so the sprite is not mirrored on top of its direction.
	var drone_scale := global_scale
	bullet.global_scale = Vector2(absf(drone_scale.x), absf(drone_scale.y))
