## Open/close state machine for an animated map panel.
##
## The panel owns the animation; this object only decides [i]when[/i] it runs. Once
## [method open] or [method close] is called the matching step callable is invoked
## once per frame with the frame delta, and the panel stays in the OPENING/CLOSING
## state until that callable returns [code]true[/code].
##
## Used by [FullMap] and [HudMinimap] so both follow the same contract.
class_name MapPanelAnimator
extends RefCounted

enum State {
	CLOSED,
	OPENING,
	OPEN,
	CLOSING,
}

## Emitted when [method open] starts an opening animation. Reset your animation
## state here: the panel may be anywhere, including mid-close.
signal open_started
## Emitted the frame the opening step callable returns [code]true[/code].
signal opened
## Emitted when [method close] starts a closing animation.
signal close_started
## Emitted the frame the closing step callable returns [code]true[/code].
signal closed

var state: State

var _open_step: Callable
var _close_step: Callable

## [param open_step] and [param close_step] both take the frame delta and return
## [code]true[/code] once their animation has finished.
func _init(open_step: Callable, close_step: Callable, initial_state := State.CLOSED) -> void:
	_open_step = open_step
	_close_step = close_step
	state = initial_state

func is_open() -> bool:
	return state == State.OPEN

## True while an opening or closing animation is still running.
func is_animating() -> bool:
	return state == State.OPENING or state == State.CLOSING

## Starts opening. Does nothing if already open or opening; reverses an in-progress
## close, in which case the opening animation starts from wherever the panel is.
func open() -> void:
	if state == State.OPEN or state == State.OPENING:
		return
	state = State.OPENING
	open_started.emit()

## Starts closing. Mirror of [method open].
func close() -> void:
	if state == State.CLOSED or state == State.CLOSING:
		return
	state = State.CLOSING
	close_started.emit()

func toggle() -> void:
	if state == State.OPEN or state == State.OPENING:
		close()
	else:
		open()

## Closes with no animation, in one call.
##
## For the moments the panel has to be off screen now rather than shortly: pausing,
## where the tree stops and a half-played close animation would freeze mid-slide with
## the panel still covering the screen. The step callable is run once with a delta
## long enough that any duration-based animation reports itself finished.
func snap_closed() -> void:
	if state == State.CLOSED:
		return
	close()
	# Large enough that any sane animation_duration is over; run twice so an animation
	# that resets its own elapsed time on close_started still lands.
	_close_step.call(3600.0)
	if not _close_step.call(3600.0):
		push_warning("MapPanelAnimator: the close animation did not finish when snapped. It may not be duration-based.")
	state = State.CLOSED
	closed.emit()

## Drives the current animation. Call once per frame from the panel's [code]_process[/code].
func step(delta: float) -> void:
	match state:
		State.OPENING:
			if _open_step.call(delta):
				state = State.OPEN
				opened.emit()
		State.CLOSING:
			if _close_step.call(delta):
				state = State.CLOSED
				closed.emit()
