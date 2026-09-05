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

## Whether health was under [member low_health_boundry] last time it changed, so the
## two low-health signals fire on the crossing rather than on every hit that happens
## to land while already low.
var _was_low : bool = false

var _curr_health : int:
	set(value):
		if ignore_effects:
			return
		_curr_health = clampi(value, 0, max_health)
		if _curr_health <= 0:
			_on_death()

func _ready() -> void:
	if hurtbox == null:
		printerr("No Hurtbox for this health to detect damage")
	else:
		hurtbox.hit.connect(_on_hit)
	_curr_health = start_health
	# Seeded rather than checked, so a body that starts below the line does not fire
	# an "entry" it never crossed into.
	_was_low = _curr_health < low_health_boundry

func current_health() -> float:
	return _curr_health;

func take_damage(amount: int) -> void:
	_curr_health -= amount
	_check_low_health()

func heal(amount: int) -> void:
	_curr_health += amount
	_check_low_health()

func max_out() -> void:
	_curr_health = max_health
	_check_low_health()

func _check_low_health() -> void:
	var low := _curr_health < low_health_boundry
	if low == _was_low:
		return
	_was_low = low
	if low:
		on_low_health_entry.emit()
	else:
		on_low_health_exit.emit()

func kill_self() -> void:
	_curr_health = 0

@abstract
func _on_death() -> void

@abstract
func _on_hit(hurtBox: Hurtbox, hit_info: HitInfo, source: Hitbox) -> void
