extends Enemy

@onready var melee_hitbox: Hitbox = $"Melee Hitbox"
@onready var attack_duration: Timer = $"Attack Duration"

func generateAttack():
	velocity = Vector2.ZERO
	melee_hitbox.monitoring = true
	attack_duration.start()
	
	await attack_duration.timeout
	
	melee_hitbox.monitoring = false
	
	pass


func _on_melee_hitbox_hit(hitbox: Hitbox, hit_info: HitInfo, source: Hurtbox) -> void:
	if(source.get_parent() is Player):
		print(name + " has hit the player!")
	pass # Replace with function body.
