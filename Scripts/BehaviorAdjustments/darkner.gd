extends Node

const SCREEN_WIDTH := 1152.0

func _ready() -> void:
	if SaveManager.is_station_powered():
		queue_free()
		return
	Darkness.globle_darkness.hold_manual()


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	var x_percent : float = (Player.active_player.global_position / SCREEN_WIDTH).x
	Darkness.globle_darkness.fade_manual(x_percent)

func _exit_tree() -> void:
	Darkness.globle_darkness.release(false)
