class_name RepairNode extends Node2D

signal on_repair_start
signal on_repair_end

@export var repair_timer : float =  5.0

var number_of_repairers : int

func _ready() -> void:
	number_of_repairers = 0

func _process(delta: float) -> void:
	repair_timer -= delta * number_of_repairers
	if repair_timer <= 0:
		on_repair_end.emit()
		queue_free()

func start_repairs() -> void:
	number_of_repairers += 1
	if number_of_repairers == 1:
		on_repair_start.emit()

func stop_repairing() -> void:
	number_of_repairers = max(0, number_of_repairers - 1)
