@tool
## The HUD minimap, with the same open/close animation contract as [FullMap].
##
## Everything about what the minimap draws is inherited from MetSys' Minimap.gd; this
## only adds the ability to animate it out of the way while the full map is open.
##
## [b]Animation contract.[/b] While closing, [method _animate_close] is called once per
## frame with the frame delta and the minimap counts as closed on the first frame it
## returns [code]true[/code]; [method _animate_open] is the same for opening. Extend
## this script and override those two for your own animation — the defaults fade.
class_name HudMinimap
extends "res://addons/MetroidvaniaSystem/Template/Nodes/Minimap.gd"

## Emitted when an opening animation starts.
signal open_started
## Emitted when [method _animate_open] reports it has finished.
signal opened
## Emitted when a closing animation starts.
signal close_started
## Emitted when [method _animate_close] reports it has finished.
signal closed

@export_group("Animation")
## Length of the built-in fade, in seconds. Ignored once you override
## [method _animate_open] / [method _animate_close].
@export var animation_duration := 0.2

## Hides the node outright once the closing animation finishes, so a minimap that
## animated to something still visible (a corner, a sliver) disappears anyway.
@export var hide_when_closed := true

var _animator: MapPanelAnimator
var _fade_from := 1.0
var _fade_elapsed: float

func _ready() -> void:
	super()
	# The minimap starts on screen, so it starts open.
	_animator = MapPanelAnimator.new(_animate_open, _animate_close, MapPanelAnimator.State.OPEN)
	_animator.open_started.connect(_on_open_started)
	_animator.close_started.connect(_on_close_started)
	_animator.opened.connect(opened.emit)
	_animator.closed.connect(closed.emit)
	set_process(false)

func _process(delta: float) -> void:
	_animator.step(delta)
	set_process(_animator.is_animating())

## Starts opening. Safe to call when already open.
func open() -> void:
	_animator.open()
	set_process(_animator.is_animating())

## Starts closing. Safe to call when already closed.
func close() -> void:
	_animator.close()
	set_process(_animator.is_animating())

func toggle() -> void:
	_animator.toggle()
	set_process(_animator.is_animating())

func is_open() -> bool:
	return _animator.is_open()

func is_animating() -> bool:
	return _animator.is_animating()

## Called once per frame while the minimap is opening. Return [code]true[/code] when
## the animation has finished. Override to supply your own.
func _animate_open(delta: float) -> bool:
	visible = true
	return _fade_towards(1.0, delta)

## Called once per frame while the minimap is closing. Return [code]true[/code] when
## the animation has finished. See [method _animate_open].
func _animate_close(delta: float) -> bool:
	var finished := _fade_towards(0.0, delta)
	if finished and hide_when_closed:
		visible = false
	return finished

func _fade_towards(target: float, delta: float) -> bool:
	if animation_duration <= 0.0:
		modulate.a = target
		return true

	_fade_elapsed = minf(_fade_elapsed + delta, animation_duration)
	modulate.a = lerpf(_fade_from, target, smoothstep(0.0, 1.0, _fade_elapsed / animation_duration))
	return _fade_elapsed >= animation_duration

func _on_open_started() -> void:
	_fade_from = modulate.a
	_fade_elapsed = 0.0
	open_started.emit()

func _on_close_started() -> void:
	_fade_from = modulate.a
	_fade_elapsed = 0.0
	close_started.emit()
