extends ColorRect

@export var fade_out_time : float = 0.2

var _previous_fade_amount : float
var _timer : float

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	GlobalSignals.room_transition.connect( on_room_transition )
	pass # Replace with function body.

func _process(delta: float) -> void:
	if _timer > fade_out_time:
		return
	_timer += delta
	_animate()

func on_room_transition() -> void:
	_timer = -fade_out_time
	_previous_fade_amount = 0
	pass

func _animate() -> void:
	var amount = TriangleWave.sample_complement(_timer, fade_out_time)
	_set_fade_amount( amount )
	_time_scale( amount )
	_previous_fade_amount = amount

# Assume amount is clamped to (0,1) in the method that calls this one
func _set_fade_amount(amount: float) -> void:
	if _previous_fade_amount == amount:
		return
	if amount == 0:
		visible = false
	elif _previous_fade_amount == 0:
		visible = true
	modulate.a = 255 * amount

# Assume amount is clamped to (0,1) in the method that calls this one
func _time_scale(amount: float) -> void:
	#TODO implement this function such that global deltatime for all but things like UI are multiplied by amount, this should happen at the same rate as the screen going dark
	pass
