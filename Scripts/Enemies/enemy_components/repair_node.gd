class_name RepairNode extends Node2D

signal on_repair_start
signal on_repair_end
signal on_repair_failure

@export var repair_timer : float =  5.0
@export var can_be_accel : bool = true
@export var start_repair_state : bool = true
@export var destroy_on_completion : bool = true

var can_repair : bool = true
var number_of_repairers : int

func _ready() -> void:
	number_of_repairers = 0
	can_repair = start_repair_state

func _process(delta: float) -> void:
	repair_timer -= delta * number_of_repairers
	if repair_timer > 0: return
	
	number_of_repairers += 2
	on_repair_end.emit()
	if destroy_on_completion:
		queue_free()
	else:
		can_repair = false
		number_of_repairers -= 2

func start_repairs() -> void:
	number_of_repairers += 1
	if number_of_repairers == 1:
		on_repair_start.emit()
	elif number_of_repairers > 1 and not can_be_accel:
		number_of_repairers -= 1

func stop_repairing() -> void:
	number_of_repairers = max(0, number_of_repairers - 1)
	if number_of_repairers == 0:
		on_repair_failure.emit()
