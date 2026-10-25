extends AnimatedSprite2D

var _is_deploying_queued : bool = false
var _is_retract_queued : bool = false

func _ready() -> void:
	animation_finished.connect( _update )

func _update() -> void:
	if animation == "Deploying": play("Saving")
	elif animation == "Retracting": play("Idle")
	elif animation == "Idle" and _is_deploying_queued: _deploy()
	elif animation == "Saving" and _is_retract_queued: _retract()

func deploy() -> void:
	if animation == "Idle": _is_deploying_queued = true

func retract() -> void:
	if animation == "Saving": _is_retract_queued = true

func _deploy() -> void:
	play("Deploying")
	_is_deploying_queued = false
	
func _retract() -> void:
	play("Retracting")
	_is_retract_queued = false
