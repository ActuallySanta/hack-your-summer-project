class_name RoboHealth extends HealthComponent

@export var destroy_on_death : bool = false

const EXPLOSION := preload("res://Scenes/Enemies/enemy_death_boom.tscn")

func _on_death() -> void:
	var effects : Node2D = EXPLOSION.instantiate()
	effects.global_position = global_position
	get_tree().root.add_child(effects)
	on_death_event.emit()
	if destroy_on_death:
		get_parent().queue_free()

func _on_hit(_hurtBox: Hurtbox, hit_info: HitInfo, source: Hitbox) -> void:
	take_damage(hit_info.damage)
	var parent = get_parent()
	if parent.has_method("_on_hit"):
		parent._on_hit(hit_info, source)
	on_hit_event.emit()
