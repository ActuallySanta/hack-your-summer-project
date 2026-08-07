extends RigidBody2D
class_name BossBullet


func _on_hitbox_on_hit(hitbox: Hitbox, target: Hurtbox) -> void:
	queue_free()


func _on_bullet_life_time_timeout() -> void:
	queue_free()


func _on_hurtbox_hit(hurtBox: Hurtbox, hit_info: HitInfo, source: Hitbox) -> void:
	if(source.owner != BossBullet):
		queue_free()
