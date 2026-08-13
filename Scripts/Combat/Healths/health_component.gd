@abstract
class_name HealthComponent extends Node2D

@export_range(0, 5, 1, "or_greater") var max_health : int = 0
@export_range(0, 5, 1, "or_greater") var start_health : int = 0

@onready var hurtbox : Hurtbox = $Hurtbox

var curr_health : int:
	set(value):
		curr_health = min(value, max_health)
		if curr_health <= 0:
			_on_death()
		
func _ready() -> void:
	if hurtbox == null:
		printerr("No Hurtbox for this health to detect damage")
	else:
		hurtbox.hit.connect(_on_hit)
	curr_health = start_health

func take_damage(amount: int) -> void:
	curr_health -= amount

func heal(amount: int) -> void:
	curr_health += amount

func max_out() -> void:
	curr_health = max_health

func kill_self() -> void:
	curr_health = 0

@abstract
func _on_death() -> void

@abstract
func _on_hit(hurtBox: Hurtbox, hit_info: HitInfo, source: Hitbox) -> void
