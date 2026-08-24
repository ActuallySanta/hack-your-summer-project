class_name CDMinigun extends Node2D

@export var bullet_scenes : Dictionary[ PackedScene, float ]
@export var spawn_delta : Vector2

@onready var animator := $MiniGun/MinigunAnimator

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

## Bullets this gun has put into the world. They are deliberately parented
## outside the drone, so they outlive it -- the drone has to clear them itself
## when it dies or a stray round can still kill the player after the fight.
var _live_bullets : Array[Bullet] = []

func make_paused(value: bool) -> void:
	$MiniGun.make_paused(value)

func _process(delta: float) -> void:
	timer += delta

## Clears every bullet still in flight and cancels any shot mid-animation.
func despawn_bullets() -> void:
	# A shot already underway would otherwise still reach the spawn_bullet()
	# method track partway through Shoot and fire posthumously.
	animator.stop()
	$MiniGun.visible = false  # where the animation would have left it at rest
	
	for bullet in _live_bullets:
		if is_instance_valid(bullet):
			bullet.queue_free()
	_live_bullets.clear()

func is_shooting() -> bool:
	return animator.is_playing()

func shoot() -> bool:
	if animator.is_playing():
		return false
	
	animator.play("Shoot")
	return true

func spawn_bullet() -> void:
	var parent : Node2D = bullet_parent if is_instance_valid(bullet_parent) else get_parent()
	var bullet_scene : PackedScene = PieRand.Roll(bullet_scenes)
	var bullet : Bullet = bullet_scene.instantiate()
	var spawn_global := to_global(spawn_delta)
	
	parent.add_child(bullet)
	bullet.initial_operations(parent.to_local(spawn_global), "L" if is_flipped else "R", 0.0)

	var drone_scale := global_scale
	bullet.global_scale = Vector2(absf(drone_scale.x), absf(drone_scale.y))
	
	# Forget bullets that already expired on their own, so a long fight does not
	# pile up dead references.
	for i in range(_live_bullets.size() - 1, -1, -1):
		if not is_instance_valid(_live_bullets[i]):
			_live_bullets.remove_at(i)
	_live_bullets.append(bullet)
