extends CharacterBody2D

@export var MOVESPEED = 100
var initDir: Vector2
var spawnPos : Vector2
var spawnRot : float

func _ready():
	global_position = spawnPos
	global_rotation = spawnRot
	
func _physics_process(delta: float) -> void:
	velocity = initDir*MOVESPEED
	move_and_slide()
	
func _on_bullet_lifetime_timeout() -> void:
	queue_free()

func _on_area_2d_body_entered(body: Node2D) -> void:
	queue_free()

func flip_graphics() -> void:
	$AnimatedSprite2D.flip_h = !$AnimatedSprite2D.flip_h

func _on_hitbox_on_hit(hitbox: Hitbox, target: Hurtbox) -> void:
	queue_free()
