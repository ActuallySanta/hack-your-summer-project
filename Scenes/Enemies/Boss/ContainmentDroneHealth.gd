class_name CDHealthComponent extends HealthComponent

signal on_death_event
signal on_destroy_event

@export var seconds_to_vaporize := 5.5

func _on_death() -> void:
	on_death_event.emit()
	hurtbox.queue_free()
	await get_tree().create_timer(seconds_to_vaporize).timeout
	on_destroy_event.emit()
	queue_free()

func _on_hit(_hurtBox: Hurtbox, hit_info: HitInfo, _source: Hitbox) -> void:
	if hit_info.damage > 0:
		take_damage(hit_info.damage)
