@tool
extends Sprite2D

## Whether or not these Teeth animate themselves, or are triggered by a third party
@export var loop : bool = true:
	set(value):
		loop = value
		notify_property_list_changed()

## The time between when "grab()" is called and when the teeth actually try to grab
@export var queueTimeSeconds : float
## The time between each "grab()" in a loop
@export var loopTimeSeconds : float
## Should the teeth start by waiting or grabing
@export var startWaiting : bool
## Initial offset time
@export var offsetTime : float:
	set(value):
		offsetTime = min(value, loopTimeSeconds)

var _is_queued : bool
var _timer : float

@onready var animator : AnimationPlayer = $AnimationPlayer

func _validate_property(property: Dictionary) -> void:
	if property.name == "queueTimeSeconds" and loop == true:
		property["usage"] = PROPERTY_USAGE_NO_EDITOR
	elif property.name == "loopTimeSeconds" and loop == false:
		property["usage"] = PROPERTY_USAGE_NO_EDITOR
	elif property.name == "startWaiting" and loop == false:
		property["usage"] = PROPERTY_USAGE_NO_EDITOR

func _ready() -> void:
	_timer = offsetTime if startWaiting else 0.0

func _process(delta: float) -> void:
	if Engine.is_editor_hint() or loop == false or cannot_play():
		return
	
	_timer -= delta
	if _timer > 0:
		return
	
	_timer = loopTimeSeconds
	grab()

func cannot_play() -> bool:
	return animator.is_playing() or _is_queued

## Called when a loop needs to occur OR when another script wants the teeth to grab
func grab() -> void:
	if cannot_play():
		return
	
	if loop == true:
		animator.play("Bite")
	else:
		_is_queued = true
		await get_tree().create_timer(queueTimeSeconds).timeout
		_is_queued = false
		animator.play("Bite")
