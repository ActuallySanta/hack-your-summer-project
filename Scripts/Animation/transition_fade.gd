## The black rectangle a room transition happens behind.
##
## A fade runs in three parts: it darkens to black over [member fade_out_time], holds
## there while the room is swapped, and clears again once the new room is up. The
## middle part is not timed here. How long a room takes to load is not something this
## can know, and coming back early would show the old room, so the fade only reports
## that the screen is covered ([signal screen_faded_out], mirrored on
## [signal GlobalSignals.room_transition_faded_out]) and waits to be told the swap is
## done. [i]FadedRoomTransitions[/i] is the other half of that conversation.
class_name RoomTransitionFade extends ColorRect

## Emitted when the screen is fully black, i.e. when the room may be swapped unseen.
signal screen_faded_out

enum State {
	Idle, ## Clear. Nothing is happening.
	FadingOut, ## Darkening towards black.
	Covered, ## Fully black, waiting on the room swap.
	FadingIn, ## Clearing again, on the new room.
}

## How long the screen takes to darken, and to clear again afterwards.
@export var fade_out_time : float = 0.2

var _previous_fade_amount : float
var _timer : float
var _state : State = State.Idle

func _ready() -> void:
	# Written out rather than passed through _set_fade_amount, which would see the zero
	# it already believes is showing and leave the scene's own opaque alpha in place.
	_previous_fade_amount = 0
	visible = false
	modulate.a = 0
	GlobalSignals.room_transition.connect( on_room_transition )
	GlobalSignals.room_transition_complete.connect( on_room_transition_complete )

func _process(delta: float) -> void:
	if _state == State.Idle or _state == State.Covered:
		return

	_timer += delta
	# Checked before anything samples the wave, so a fade time of zero ends the fade
	# on the next frame instead of dividing by it.
	if _timer >= fade_out_time:
		_finish_fade()
		return
	_animate()

func on_room_transition() -> void:
	_start_fade(State.FadingOut)

func on_room_transition_complete() -> void:
	_start_fade(State.FadingIn)

func _start_fade(state: State) -> void:
	_state = state
	# Measured from the darkness already on screen rather than from the end this fade
	# would have started at, so a transition that interrupts another one carries on
	# from where it caught it instead of popping. The ramp is linear, so the elapsed
	# time and the amount showing are the same fraction of the fade.
	var progress := _previous_fade_amount if state == State.FadingOut else 1.0 - _previous_fade_amount
	_timer = fade_out_time * progress

func _finish_fade() -> void:
	if _state == State.FadingOut:
		_state = State.Covered
		_set_fade_amount(1)
		_time_scale(1)
		# Deferred: the swap this sets off pulls a whole room out of the tree, which is
		# not something to do part-way through the tree's own process loop.
		_announce_faded_out.call_deferred()
	else:
		_state = State.Idle
		_set_fade_amount(0)
		_time_scale(0)

func _announce_faded_out() -> void:
	screen_faded_out.emit()
	GlobalSignals.room_transition_faded_out.emit()

func _animate() -> void:
	# The wave peaks half way along its length, so a fade that has to be complete at
	# fade_out_time rides the first half of a wave twice that long.
	var wave_length := fade_out_time * 2
	var amount = TriangleWave.sample(_timer, wave_length) if _state == State.FadingOut else TriangleWave.sample_complement(_timer, wave_length)
	_set_fade_amount( amount )
	_time_scale( amount )

# Assume amount is clamped to (0,1) in the method that calls this one
func _set_fade_amount(amount: float) -> void:
	if _previous_fade_amount == amount:
		return
	_previous_fade_amount = amount
	visible = amount > 0
	modulate.a = amount

# Assume amount is clamped to (0,1) in the method that calls this one
func _time_scale(amount: float) -> void:
	#TODO implement this function such that global deltatime for all but things like UI are multiplied by amount, this should happen at the same rate as the screen going dark
	#This method is gonna be super fuck-y since MetSys will also need to do some work transitioning
	pass
