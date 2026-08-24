class_name RoboHealth extends HealthComponent

const EXPLOSION := preload("res://Scenes/Enemies/enemy_death_boom.tscn")

func _on_death() -> void:
	var effects : Node2D = EXPLOSION.instantiate()
	effects.global_position = global_position
	get_tree().root.add_child(effects)
	var parent = get_parent()
	if parent.has_method("_die"):
		parent._die()
	

func _on_hit(_hurtBox: Hurtbox, hit_info: HitInfo, source: Hitbox) -> void:
	take_damage(hit_info.damage)
	var parent = get_parent()
	if parent.has_method("_on_hit"):
		parent._on_hit(hit_info, source)
