class_name RoomTransitionFade extends ColorRect

signal screen_faded_out

@export var fade_out_time : float = 0.2

var _previous_fade_amount : float
var _timer : float
var _fade_out : bool

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	GlobalSignals.room_transition.connect( on_room_transition )

func _process(delta: float) -> void:
	# If the timer is no longer counting and we're only fadeing out, switch to fade in mode and reset timer.
	if _timer > fade_out_time:
		if _fade_out:
			_start_fade(false)
			screen_faded_out.emit()
		return
	_timer += delta
	_animate()

func on_room_transition() -> void:
	_start_fade(true)
	pass

func _start_fade(fade_out: bool) -> void:
	_timer = 0
	_fade_out = fade_out
	_previous_fade_amount = 0

func _animate() -> void:
	var amount = TriangleWave.sample(_timer, fade_out_time) if _fade_out else TriangleWave.sample_complement(_timer, fade_out_time)
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
	#This method is gonna be super fuck-y since MetSys will also need to do some work transitioning
	pass
