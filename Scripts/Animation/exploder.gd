@tool
class_name Exploder extends Node2D

signal when_no_explosions_left

const EXPLOSTION := preload("res://Scenes/Enemies/enemy_death_boom.tscn")

@export var max_explosions := 5
@export var time_between_explosions := 0.5
@export var num_spawn := 2

@export var range_rect : Rect2:
	set(value):
		range_rect = value
		queue_redraw()

var explosions: Array[ Node2D ] = []
var timer := 0.0
var do_explosions : bool = false
var queue_destruction : bool = false

func start_explosions() -> void:
	do_explosions = true

func end_explosions() -> void:
	do_explosions = false
	queue_destruction = true

func _process(delta: float) -> void:
	if Engine.is_editor_hint():
		return
	
	if queue_destruction and explosions.size() == 0:
		when_no_explosions_left.emit()
		queue_free()
		return
	
	explosions = explosions.filter(func(item): return is_instance_valid(item))
	
	if not do_explosions:
		return
	
	timer -= delta
	while timer <= 0:
		timer += time_between_explosions
		for i in num_spawn:
			try_create_explosion()

func try_create_explosion() -> bool:
	if explosions.size() > max_explosions:
		return false
	
	var new_explosion : Node2D = EXPLOSTION.instantiate()
	new_explosion.position = Vector2(range_rect.position.x + randf() * range_rect.size.x,
		range_rect.position.y + randf() * range_rect.size.y)
	new_explosion.scale = Vector2(1,1)
	explosions.append(new_explosion)
	add_child(new_explosion)
	return true

func _draw() -> void:
	if not Engine.is_editor_hint():
		return
	draw_rect(range_rect, Color(1,1,1,0.1), false, 3)
