extends Node2D

@export_range(0.4,5,0.1,"or_greater") var save_time : float = 2.5

@onready var animator : AnimationPlayer = $Animator
@onready var interact : PlayerInteractable = $PlayerInteractable

var _save_queued : bool = false
var _idle_queued : bool = false

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	if not Difficulty.get_setting().can_save: interact.queue_free()
	interact.on_player_confirm_interaction.connect( try_start )

## Attempts to run the save protocal
## Assumes that this function will never be called twice in a row; no stale interact calls
func try_start() -> void:
	if animator.current_animation == "Idle":
		_save_queued = true
		PlayerManager.canMove = false
		PlayerManager.player.global_position.x = interact.global_position.x
		print("Saving...")
		await get_tree().create_timer( save_time ).timeout
		if animator.current_animation == "Saving":
			_idle_queued = true
			print("Finishing...")

## Attempts to run the exit protocal
func try_stop() -> void:
	pass

func _anim_update() -> void:
	if _idle_queued: 
		_idle_queued = false
		animator.play("Retract")
	elif _save_queued: 
		_save_queued = false
		animator.play("Deploy")

func on_save_anim_exit() -> void:
	PlayerManager.canMove = true

func _save() -> void:
	SaveManager.save_data_to_file(GameManager.current_save_name)
	MessageDisplay.add_saving_data()
	GlobalSignals.max_player_health.emit()
