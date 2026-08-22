class_name CDMinigun extends Node2D

@export var bullet_scene : PackedScene
@export var spawn_delta : Vector2

@onready var animator := $MiniGun/MinigunAnimator

var timer := 0.0
var is_flipped : bool = false

func _process(delta: float) -> void:
	timer += delta

func shoot() -> bool:
	if animator.is_playing():
		return false
	
	animator.play("Shoot")
	return true

func spawn_bullet() -> void:
	var bullet : Bullet = bullet_scene.instantiate()
	bullet.initial_operations(position + Vector2(-spawn_delta.x if is_flipped else spawn_delta.x, spawn_delta.y), "L" if is_flipped else "R", 0.0)
	get_parent().add_child(bullet)
