extends Enemy

@onready var melee_hitbox : Hitbox= $"Melee Hitbox"

@onready var attack_duration: Timer = $"Attack Duration"

func generateAttack():
	velocity = Vector2.ZERO
	melee_hitbox.process_mode = Node.PROCESS_MODE_INHERIT
	melee_hitbox.reset()
	if isFlipped != (melee_hitbox.knockback_strength < 0):
		melee_hitbox.knockback_strength *= -1
	attack_duration.start()
	
	await attack_duration.timeout
	melee_hitbox.process_mode = Node.PROCESS_MODE_DISABLED
	
	pass

func _on_melee_hitbox_on_hit(hitbox: Hitbox, target: Hurtbox) -> void:
	pass
