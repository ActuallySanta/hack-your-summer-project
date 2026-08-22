class_name Bullet extends CharacterBody2D

@export var MOVESPEED = 100
@export var sprite_texture_map : Dictionary[ StringName, int ] = {
	"U" : 194,
	"UR": 194,
	"R" : 194,
	"DR": 194,
	"D" : 195,
	"DL": 195,
	"L" : 195,
	"UL": 195,
}
var direction_to_vector : Dictionary[ StringName, Vector2 ] = {
	"U" : Vector2(0, -1),
	"UR": Vector2(1, -1).normalized(),
	"R" : Vector2(1, 0),
	"DR": Vector2(1, 1).normalized(),
	"D" : Vector2(0, 1),
	"DL": Vector2(-1, 1).normalized(),
	"L" : Vector2(-1, 0),
	"UL": Vector2(-1, -1).normalized(),
}
var initDir : StringName
var spawnPos : Vector2
var start_offset : float

func _ready() -> void:
	pass

func _on_bullet_lifetime_timeout() -> void:
	queue_free()

func _physics_process(delta: float) -> void:
	move_and_slide()

func initial_operations(spawn_pos: Vector2, spawn_direction: StringName, spawn_offset: float) -> void:
	initDir = spawn_direction
	spawnPos = spawn_pos
	start_offset = spawn_offset
	var dir : = direction_to_vector[ initDir ]
	position = spawnPos + dir * start_offset
	velocity = dir * MOVESPEED
	$Sprite2D.frame = sprite_texture_map[ initDir ]


func _on_hitbox_on_hit(_hitbox: Hitbox, _target: Hurtbox) -> void:
	queue_free()
