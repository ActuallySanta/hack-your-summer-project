class_name CDHealthComponent extends HealthComponent

signal on_death_event

func _on_death() -> void:
	on_death_event.emit()

func _on_hit(hurtBox: Hurtbox, hit_info: HitInfo, source: Hitbox) -> void:
	if hit_info.damage > 0:
		take_damage(hit_info.damage)
