class_name HitInfo

var damage : int
var knockback_strength : float
var knockback_duration : float

func _init(damage: int,
		knockback_strength: float = 0,
		knockback_duration: float = 0,):
	self.damage = damage
	self.knockback_strength = knockback_strength
	self.knockback_duration = knockback_duration
