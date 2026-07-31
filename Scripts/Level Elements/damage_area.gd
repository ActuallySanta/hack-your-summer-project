class_name DamageArea extends Hitbox

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	super._ready()
	on_hit.connect(_on_hit)

func _on_hit(_hitbox: Hitbox, hurtbox : Hurtbox) -> void:
	reset()
	if hurtbox.global_position.x > self.global_position.x:
		knockback_strength = abs(knockback_strength)
	else:
		knockback_strength = -abs(knockback_strength)
