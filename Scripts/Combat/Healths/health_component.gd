@abstract
class_name HealthComponent extends Node2D

# These two should be implemented in subclasses
signal on_hit_event
signal on_death_event
## Event called when health drops below the low health threshold
signal on_low_health_entry
## Event called when health drops rises above health threshold
signal on_low_health_exit

@export_range(0, 5, 1, "or_greater") var max_health : int = 0
@export_range(0, 5, 1, "or_greater") var start_health : int = 0
@export_range(0, 5, 1, "or_greater") var low_health_boundry : int = 0

@onready var hurtbox : Hurtbox = $Hurtbox

var ignore_effects : bool = false

var _curr_health : int:
	set(value):
		if ignore_effects:
			return
		_curr_health = min(value, max_health)
		if _curr_health <= 0:
			_on_death()
		
func _ready() -> void:
	if hurtbox == null:
		printerr("No Hurtbox for this health to detect damage")
	else:
		hurtbox.hit.connect(_on_hit)
	_curr_health = start_health

func current_health() -> float:
	return _curr_health;

func take_damage(amount: int) -> void:
	_curr_health -= amount
	if _curr_health < low_health_boundry:
		on_low_health_entry.emit()

func heal(amount: int) -> void:
	var new_health := _curr_health + amount
	if _curr_health < low_health_boundry and new_health >= low_health_boundry:
		on_low_health_exit.emit()
	_curr_health = new_health

func max_out() -> void:
	if _curr_health < low_health_boundry:
		on_low_health_exit.emit()
	_curr_health = max_health

func kill_self() -> void:
	_curr_health = 0

@abstract
func _on_death() -> void

@abstract
func _on_hit(hurtBox: Hurtbox, hit_info: HitInfo, source: Hitbox) -> void
