class_name PlayerInteractable extends Area2D

signal on_player_confirm_interaction
signal on_player_start_interaction
signal on_player_fail_interaction 

@export var interact_once : bool
@export var velocity_cutoff_point : float = 0
@export var time_to_succeed : float = 1.0

@onready var node_to_scale := $ImageScaler

var _player_reference : Player
var _player_in_interactable : bool
var _successfully_interacted : bool
var _timer : float 
var _init_y_scale : float
## Used to stop repeated firings of confirm_interaction when the criteria are met
var _hold_off : bool = false

func _ready() -> void:
	_init_y_scale = node_to_scale.scale.y

func _process(delta: float) -> void:
	# If we can't interact with this node in the future, we shouldn't waste time doing logic for it
	if not _can_interact() or _hold_off:
		return
	if _player_reference != null and (_player_reference.velocity.length() <= velocity_cutoff_point) and _can_interact() and _timer >= 1:
		confirm_interaction()
		_hold_off = true
		return
	
	# Increment the timer/weight and update accordingly
	var increment = delta / time_to_succeed
	if not _player_in_interactable:
		increment *= -1
	_timer = clamp(_timer + increment, 0, 1)
	update_visuals()

## Sends the signal that the player is interacting with this interactable
func confirm_interaction() -> void:
	on_player_confirm_interaction.emit()
	_successfully_interacted = true

## Does stuff with _timer after it's calcuated
func update_visuals() -> void:
	node_to_scale.scale.y = lerp(_init_y_scale, 0.0, _timer)

## Can this node be interacted with?
func _can_interact() -> bool:
	return not interact_once or not _successfully_interacted

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") and _can_interact():
		_player_in_interactable = true
		on_player_start_interaction.emit()

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		_player_reference = body as Player
		_player_in_interactable = false
		_hold_off = false
		if not _successfully_interacted:
			on_player_fail_interaction.emit()
