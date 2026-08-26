## Screen-wide effects, fired off with a single call from anywhere.
##
## Autoloaded as [code]CameraEffects[/code], so nothing has to be wired up, held or
## freed by the caller:
## [codeblock]
## CameraEffects.shake(12.0, 0.8)
## CameraEffects.flash(Color.WHITE, 0.05, 0.02, 0.6)
## [/codeblock]
##
## Everything here runs on its own [method _process] rather than a [Tween], because a
## custom [Curve] has to be sampled per frame and because a shake is noise around an
## envelope rather than an interpolation between two values. Processing is switched
## off whenever nothing is playing, so an idle [CameraEffects] costs nothing.
##
## It also runs while the tree is paused ([constant Node.PROCESS_MODE_ALWAYS]), so a
## death sequence that pauses the game still gets its flash and its shake.
##
## [b]Shake[/b] is written to the active [Camera2D]'s [member Camera2D.offset], not
## its position, because [GameManager] rewrites the camera's position every frame to
## follow the player and the two must not fight. The offset in place when a shake
## starts is remembered and put back when the last one ends.
##
## [b]Pan[/b] rides on that same offset and composes with the shake rather than
## fighting it. Unlike a shake it holds where it is put until something moves it
## again, which is what lets a mantle lead the shot to where the player is about to
## land and then drop the offset on the frame they actually get there.
##
## [b]Flash[/b] is a [ColorRect] on a [CanvasLayer] of this script's own, above the
## HUD and above the loading screen (see [constant OVERLAY_LAYER]).
##
## [b]Darkness[/b] — the unlit-station vignette, see [Darkness] — is not fired like
## these two. It is a piece of world state that follows the station's power and the
## room the player is in, so what is offered here is a manual hold over it
## ([method darken], [method lighten]) and a way to hand it back
## ([method release_darkness]), rather than a one-shot.
extends Node

#region Easing

## The shapes an effect's strength can follow over its run. Each is described as the
## rise it makes from 0 to 1; a phase that runs the other way (a fade-out, a shake
## dying away) uses the same shape upside down.
##
## Anywhere one of these is taken, a [Curve] can be passed instead for a shape drawn
## by hand — see [method sample_shape].
enum Ease {
	LINEAR, ## A straight line. An even change from one end to the other.
	EASE_IN, ## Slow to start, fastest at the end.
	EASE_OUT, ## Fastest at the start, slow to finish.
	EASE_IN_OUT, ## Slow at both ends, fast through the middle.
	LOGARITHMIC, ## Nearly all of the change happens at once, then a long flat tail.
}

## How sharply [constant Ease.LOGARITHMIC] front-loads its change. Higher is sharper.
const LOG_STEEPNESS := 9.0

## Evaluates one of the [enum Ease] shapes at normalized time [param t], as a rise
## from 0 to 1. [param t] outside 0 to 1 is clamped.
static func ease_value(t: float, easing: Ease) -> float:
	t = clampf(t, 0.0, 1.0)
	match easing:
		Ease.EASE_IN:
			return t * t
		Ease.EASE_OUT:
			return 1.0 - (1.0 - t) * (1.0 - t)
		Ease.EASE_IN_OUT:
			if t < 0.5:
				return 2.0 * t * t
			return 1.0 - pow(-2.0 * t + 2.0, 2.0) * 0.5
		Ease.LOGARITHMIC:
			return log(1.0 + LOG_STEEPNESS * t) / log(1.0 + LOG_STEEPNESS)
		_:
			return t

## The strength an effect is at, [param t] of the way through the phase it belongs to.
##
## [param curve], when given, wins over [param easing] and is [b]read as the value
## itself[/b]: what is drawn is what is played, so a curve for something that dies
## away should be drawn falling from 1 to 0. The curve's own domain is mapped onto
## [param t], so it does not matter what horizontal range it was authored over.
##
## [param easing] is instead read as the phase's [i]progress[/i] and turned round by
## [param falling], which is what lets one [enum Ease] name the same shape whether it
## is a flash coming up or a shake going away.
static func sample_shape(t: float, easing: Ease, curve: Curve, falling: bool) -> float:
	t = clampf(t, 0.0, 1.0)
	if curve:
		return curve.sample_baked(lerpf(curve.min_domain, curve.max_domain, t))
	var value := ease_value(t, easing)
	return 1.0 - value if falling else value

#endregion

#region Shake

## Which way a shake moves the camera. The two axes are bit flags, so
## [code]HORIZONTAL | VERTICAL[/code] is [constant BOTH].
enum Axis {
	HORIZONTAL = 1, ## Left and right only.
	VERTICAL = 2, ## Up and down only.
	BOTH = 3, ## Both axes, each shaken independently of the other.
}

## One shake in flight. Several can overlap; their offsets add up.
##
## Data only — an inner class cannot see the enclosing script's scope, so the shape
## of a shake is read in [method _shake_offset] rather than here.
class Shake extends RefCounted:
	var intensity: float
	var duration: float
	var axis: int
	var easing: int
	var curve: Curve
	var elapsed := 0.0

	func _init(p_intensity: float, p_duration: float, p_axis: int, p_easing: int, p_curve: Curve) -> void:
		intensity = p_intensity
		duration = p_duration
		axis = p_axis
		easing = p_easing
		curve = p_curve

## Emitted when the last shake in flight ends and the camera is back where it was.
## Not emitted for a shake cut short by [method stop_shake].
signal shake_finished

var _shakes: Array[Shake] = []
## The camera being driven, so its offset can be put back on the exact node it was
## taken from even if the active camera changes mid-effect. Shared with the pan.
var _shaken_camera: Camera2D = null
## The offset [member _shaken_camera] had before we touched it.
var _base_offset := Vector2.ZERO
## What the shakes in flight add up to this frame. Kept apart from the pan so the
## two compose instead of overwriting each other.
var _shake_total := Vector2.ZERO

## Set while something else is placing the camera and will fold
## [method get_effect_offset] into the position it works out -- see
## [method use_external_applier].
var _external_applier := false

## Shakes the screen.
##
## [param intensity] is how far the camera is thrown at full strength, in pixels.
## [param duration] is how long the shake lasts, in seconds. [param axis] picks
## whether it moves horizontally, vertically or both.
##
## [param easing] shapes the fall-off: the shake starts at [param intensity] and is
## worn down to nothing along that shape, so [constant Ease.EASE_OUT] loses most of
## its force immediately and trails off quietly, while [constant Ease.EASE_IN] holds
## hard and then drops away at the end. Pass a [param curve] instead for a shape of
## your own, which is read as the strength directly — 1 is full [param intensity] and
## 0 is still, so it can swell, hold, or pulse rather than only decay.
##
## Calling this while another shake is playing adds to it rather than replacing it,
## so repeated hits stack the way they should. [method stop_shake] clears the lot.
func shake(intensity: float, duration: float, axis := Axis.BOTH, easing := Ease.LINEAR, curve: Curve = null) -> void:
	if intensity <= 0.0 or duration <= 0.0:
		return
	_shakes.append(Shake.new(intensity, duration, axis, easing, curve))
	set_process(true)

## Ends every shake at once and puts the camera's offset back, without emitting
## [signal shake_finished].
func stop_shake() -> void:
	_shakes.clear()
	_shake_total = Vector2.ZERO
	if _pan_is_idle():
		_release_camera()
	else:
		_sync_camera_offset()

## Whether any shake is in flight.
func is_shaking() -> bool:
	return not _shakes.is_empty()

func _process_shakes(delta: float) -> void:
	if _shakes.is_empty():
		return

	var total := Vector2.ZERO
	var finished := false
	for i in range(_shakes.size() - 1, -1, -1):
		var s := _shakes[i]
		s.elapsed += delta
		if s.elapsed >= s.duration:
			_shakes.remove_at(i)
			finished = true
			continue
		total += _shake_offset(s)

	_shake_total = total
	if _shakes.is_empty():
		_shake_total = Vector2.ZERO
		if finished:
			shake_finished.emit()

## How far [param s] throws the camera this frame: fresh noise on each axis it drives,
## bounded by whatever its shape says its strength is right now.
func _shake_offset(s: Shake) -> Vector2:
	var strength := s.intensity * sample_shape(s.elapsed / s.duration, s.easing, s.curve, true)
	var result := Vector2.ZERO
	if s.axis & Axis.HORIZONTAL:
		result.x = randf_range(-strength, strength)
	if s.axis & Axis.VERTICAL:
		result.y = randf_range(-strength, strength)
	return result

#region Who applies the offset
## Everything this script is currently adding to the shot: the shakes plus the pan.
##
## Whoever is placing the camera reads this and folds it in, so the effect goes
## through the same clamping as everything else. A shake near a room edge is worn
## down by the room's bounds rather than showing what is outside them.
func get_effect_offset() -> Vector2:
	return _shake_total + _pan_offset

## Tells this script that something else -- [GameManager] -- places the camera each
## frame and will apply [method get_effect_offset] itself, [i]inside[/i] the camera
## bounds, the axis regions and the hard boundaries.
##
## Without this the effects were written straight onto [member Camera2D.offset], which
## Godot adds after every limit has been applied. That is the one route by which a
## shake or a mantle's pan could show the outside of a room.
func use_external_applier(enabled: bool) -> void:
	if _external_applier == enabled:
		return
	_external_applier = enabled
	if enabled:
		# Hand back whatever offset we were holding; the applier owns it now.
		_release_camera()
	else:
		_sync_camera_offset()

func is_externally_applied() -> bool:
	return _external_applier
#endregion

## Writes everything this script is currently adding — the shakes and the pan — on
## top of the active camera's own offset, taking a fresh reading of that camera's
## untouched offset whenever the active camera changes under us.
##
## Does nothing while an external applier owns the camera: it reads
## [method get_effect_offset] instead.
func _sync_camera_offset() -> void:
	if _external_applier:
		return
	var camera := get_viewport().get_camera_2d()
	if camera != _shaken_camera:
		_release_camera()
		_shaken_camera = camera
		if camera:
			_base_offset = camera.offset
	if _shaken_camera:
		_shaken_camera.offset = _base_offset + _shake_total + _pan_offset

## Puts the driven camera back the way it was found, with nothing in flight.
func _release_camera() -> void:
	if is_instance_valid(_shaken_camera):
		_shaken_camera.offset = _base_offset
	_shaken_camera = null
	_base_offset = Vector2.ZERO

#endregion

#region Pan

## A held, animated shift of the shot, on the same [member Camera2D.offset] a shake
## rides on and composing with it rather than fighting it.
##
## Where a shake is noise that returns to nothing on its own, a pan [i]stays[/i]
## where it is put until something moves it again. That is what a mantle wants: the
## shot leads the vault to where the player is about to end up, and the moment they
## are actually teleported there the pan is dropped in the same frame, so the world
## never appears to move.
## [codeblock]
## CameraEffects.pan_to(Vector2(48, -48), 0.25)  # lead the vault
## CameraEffects.set_pan(Vector2.ZERO)           # player has arrived; drop it
## [/codeblock]

## Emitted when a pan reaches its destination. Not emitted for a pan replaced by
## another one or cut short by [method set_pan].
signal pan_finished

## Where the pan is right now. Composed into the camera offset every frame.
var _pan_offset := Vector2.ZERO
var _pan_from := Vector2.ZERO
var _pan_to := Vector2.ZERO
var _pan_duration := 0.0
var _pan_elapsed := 0.0
var _pan_ease := Ease.EASE_IN_OUT
var _pan_curve: Curve = null
var _panning := false

## Slides the shot to [param offset] over [param duration] seconds, and holds it
## there. [param easing] and [param curve] shape the slide exactly as they do for a
## flash's fade — a curve is read as the progress directly, from 0 at the start to 1
## at the destination.
##
## A pan while one is in flight replaces it, measured from where the shot has
## actually reached, so a change of mind mid-slide never jumps.
func pan_to(offset: Vector2, duration := 0.25, easing := Ease.EASE_IN_OUT, curve: Curve = null) -> void:
	if duration <= 0.0:
		set_pan(offset)
		return
	_pan_from = _pan_offset
	_pan_to = offset
	_pan_duration = duration
	_pan_elapsed = 0.0
	_pan_ease = easing
	_pan_curve = curve
	_panning = true
	set_process(true)

## Slides the shot [param offset] further from wherever it is heading now.
func pan_by(offset: Vector2, duration := 0.25, easing := Ease.EASE_IN_OUT, curve: Curve = null) -> void:
	var target := _pan_to if _panning else _pan_offset
	pan_to(target + offset, duration, easing, curve)

## Slides the shot back to centre. [param duration] of 0 drops it in one frame, which
## is what a teleport wants.
func pan_reset(duration := 0.25, easing := Ease.EASE_IN_OUT, curve: Curve = null) -> void:
	pan_to(Vector2.ZERO, duration, easing, curve)

## Puts the pan at [param offset] immediately, with nothing in flight.
func set_pan(offset: Vector2) -> void:
	_panning = false
	_pan_offset = offset
	_pan_from = offset
	_pan_to = offset
	if _pan_is_idle() and _shakes.is_empty():
		_release_camera()
		return
	set_process(true)
	_sync_camera_offset()

## Where the pan currently sits.
func get_pan() -> Vector2:
	return _pan_offset

## Whether a pan is currently sliding.
func is_panning() -> bool:
	return _panning

## True when the pan is neither moving nor holding the shot off centre, so there is
## nothing for it to keep the camera for.
func _pan_is_idle() -> bool:
	return not _panning and _pan_offset.is_zero_approx()

func _process_pan(delta: float) -> void:
	if not _panning:
		return

	_pan_elapsed += delta
	var t := clampf(_pan_elapsed / _pan_duration, 0.0, 1.0)
	# Read as progress rather than strength: a pan travels towards its destination,
	# so "falling" never applies to it.
	var weight := sample_shape(t, _pan_ease, _pan_curve, false)
	_pan_offset = _pan_from.lerp(_pan_to, weight)

	if t >= 1.0:
		_pan_offset = _pan_to
		_panning = false
		pan_finished.emit()

#endregion

#region Flash

## The layer the flash is drawn on. Above the HUD (layer 1) and the loading screen
## (layer 10), so a flash covers the whole screen and not just the world.
const OVERLAY_LAYER := 100

## Emitted when a flash finishes and the screen is clear again. Not emitted for a
## flash cut short by [method stop_flash] or replaced by another [method flash].
signal flash_finished

var _flash_rect: ColorRect
var _flashing := false
var _flash_color := Color.WHITE
var _flash_peak := 1.0
var _flash_in := 0.0
var _flash_hold := 0.0
var _flash_out := 0.0
var _flash_in_ease := Ease.LINEAR
var _flash_out_ease := Ease.LINEAR
var _flash_in_curve: Curve = null
var _flash_out_curve: Curve = null
var _flash_elapsed := 0.0

## Flashes the whole screen [param color].
##
## The flash comes up over [param fade_in] seconds, sits at full strength for
## [param hold] seconds, then clears over [param fade_out] seconds — so it is on
## screen for the three added together, and any of them may be 0.
##
## [param color]'s own alpha is the strength it reaches, so a fully opaque white
## whites the screen out while [code]Color(1, 1, 1, 0.4)[/code] only washes over it.
##
## [param fade_in_ease] and [param fade_out_ease] shape the two fades; each is read
## in the direction its own fade runs, so [constant Ease.EASE_OUT] means "quickest at
## the start" for both of them. [param fade_in_curve] and [param fade_out_curve]
## replace their easing with a shape of your own, read as the alpha directly, so a
## fade-out curve should be drawn falling from 1 to 0.
##
## A flash while one is already playing replaces it.
func flash(color: Color, hold := 0.0, fade_in := 0.05, fade_out := 0.25, fade_in_ease := Ease.LINEAR, fade_out_ease := Ease.LINEAR, fade_in_curve: Curve = null, fade_out_curve: Curve = null) -> void:
	_flash_color = color
	_flash_peak = color.a
	_flash_in = maxf(fade_in, 0.0)
	_flash_hold = maxf(hold, 0.0)
	_flash_out = maxf(fade_out, 0.0)
	_flash_in_ease = fade_in_ease
	_flash_out_ease = fade_out_ease
	_flash_in_curve = fade_in_curve
	_flash_out_curve = fade_out_curve
	_flash_elapsed = 0.0

	if _flash_in + _flash_hold + _flash_out <= 0.0 or _flash_peak <= 0.0:
		_clear_flash()
		return

	_flashing = true
	_draw_flash(0.0 if _flash_in > 0.0 else _flash_peak)
	set_process(true)

## Ends the flash at once and clears the screen, without emitting
## [signal flash_finished].
func stop_flash() -> void:
	_clear_flash()

## Whether a flash is on screen.
func is_flashing() -> bool:
	return _flashing

func _process_flash(delta: float) -> void:
	if not _flashing:
		return

	_flash_elapsed += delta
	var t := _flash_elapsed
	var alpha := 0.0

	if t < _flash_in:
		alpha = _flash_peak * sample_shape(t / _flash_in, _flash_in_ease, _flash_in_curve, false)
	elif t < _flash_in + _flash_hold:
		alpha = _flash_peak
	elif t < _flash_in + _flash_hold + _flash_out:
		alpha = _flash_peak * sample_shape((t - _flash_in - _flash_hold) / _flash_out, _flash_out_ease, _flash_out_curve, true)
	else:
		_clear_flash()
		flash_finished.emit()
		return

	_draw_flash(alpha)

func _draw_flash(alpha: float) -> void:
	_flash_color.a = clampf(alpha, 0.0, 1.0)
	_flash_rect.color = _flash_color
	_flash_rect.visible = true

## Takes the flash off the screen, with nothing in flight.
func _clear_flash() -> void:
	_flashing = false
	_flash_rect.visible = false
	_flash_rect.color = Color(_flash_color, 0.0)

#endregion

#region Darkness

## The unlit-station vignette, or null if the player is not in the tree.
##
## Held rather than fired, because it is world state rather than a one-shot: see the
## note at the top of this file and [Darkness] itself.
func get_darkness() -> Darkness:
	return get_tree().get_first_node_in_group(Darkness.GROUP) as Darkness

## Brings the darkness up and holds it there, whatever the station's power and the
## room say, until [method release_darkness]. [param animate] fades it in rather than
## snapping to it.
func darken(animate := true) -> void:
	var darkness := get_darkness()
	if darkness:
		darkness.hold(true, animate)

## Clears the darkness and holds it clear, whatever the station's power and the room
## say, until [method release_darkness]. [param animate] fades it out rather than
## snapping.
func lighten(animate := true) -> void:
	var darkness := get_darkness()
	if darkness:
		darkness.hold(false, animate)

## Hands the darkness back to the station's power and the current room, undoing a
## [method darken] or [method lighten].
func release_darkness(animate := true) -> void:
	var darkness := get_darkness()
	if darkness:
		darkness.release(animate)

#endregion

#region Lifecycle

func _ready() -> void:
	# A death sequence may pause the tree; its flash and shake still have to play.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_overlay()
	set_process(false)

func _build_overlay() -> void:
	var overlay := CanvasLayer.new()
	overlay.name = &"Overlay"
	overlay.layer = OVERLAY_LAYER
	add_child(overlay)

	_flash_rect = ColorRect.new()
	_flash_rect.name = &"Flash"
	_flash_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_flash_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash_rect.color = Color(1.0, 1.0, 1.0, 0.0)
	_flash_rect.visible = false
	overlay.add_child(_flash_rect)

func _process(delta: float) -> void:
	_process_shakes(delta)
	_process_pan(delta)
	_process_flash(delta)

	# One write per frame, so a shake and a pan add up on the camera instead of the
	# later of the two overwriting the earlier.
	if not _shakes.is_empty() or not _pan_is_idle():
		_sync_camera_offset()
	elif _shaken_camera != null:
		_release_camera()

	if _shakes.is_empty() and not _flashing and _pan_is_idle():
		set_process(false)

#endregion
