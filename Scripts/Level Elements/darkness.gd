# DECOUPLING THE ENTRY FADE-IN
# Everything that makes the darkness animate *on* lives behind [member animate_entry]
# and the "Entry fade-in" region at the bottom of this file. Nothing else depends on
# it. To drop the feature, either untick animate_entry in the inspector (the darkness
# then simply appears the moment the player enters the station), or delete the
# "Entry fade-in" export group and the region outright and replace the one call site
# marked "ENTRY FADE-IN" in _set_dark() with _apply_state(true).

## The unlit station.
##
## A screen-sized vignette parented to the player, so it travels with them for free,
## drawn over everything and faded in and out rather than spawned and freed.
##
## It is shown whenever both of these hold, and hidden the moment either stops:
## [br]- the station has no power yet, and
## [br]- the player is in a station room rather than one listed in
## [member non_station_rooms] (their own ship).
##
## That pair is re-read whenever either half can change — a room change, a spawn, or
## power coming back — so there is no state of its own to keep in sync or to save.
## Loading a save straight into a powered station, or into the player's ship, lands
## on the right answer without anything having to replay.
class_name Darkness
extends Sprite2D

## Rooms the darkness never appears in, as room scenes. The player's own ship is not
## part of the station, so it keeps its lights whatever the station is doing.
##
## Everything not listed here counts as station interior, which is deliberate: the
## station is most of the game, and a room accidentally left off a list of station
## rooms would silently stay lit, while a room accidentally left off this one merely
## goes dark like its neighbours.
@export_file("*.tscn") var non_station_rooms : Array[String] = [
	"res://Scenes/Rooms/Ship Internals/ship_internals.tscn",
]

@export_group("Power-on fade")

## How long the darkness takes to clear once the station powers back on.
@export_range(0.05, 5.0, 0.05, "or_greater") var power_on_seconds := 1.4

## How far the vignette opens out as it clears, as a multiple of its authored scale.
## The hole widening is what reads as light flooding in; without it the screen just
## gets less dark.
@export_range(1.0, 4.0, 0.05, "or_greater") var power_on_expansion := 1.8

@export_group("Entry fade-in")

## Whether entering the station fades the darkness in. Off, it simply appears.
## See the note at the top of this file.
@export var animate_entry := true

## How long the darkness takes to close in after the player steps into the station.
@export_range(0.05, 5.0, 0.05, "or_greater") var entry_seconds := 1.0

## How far out the vignette starts before closing in, as a multiple of its authored
## scale. The power-on fade played backwards.
@export_range(1.0, 4.0, 0.05, "or_greater") var entry_expansion := 1.8

## The scale the scene was authored at. Both fades are measured from it, so neither
## can drift the vignette off its true size by ending on a value it computed.
var _base_scale : Vector2

## What we are currently showing or heading towards, so a repeated read of the same
## state doesn't restart a fade that is already playing it.
var _dark := false

## Null whenever nothing is in flight, so "is a fade playing" is a single read.
var _fade : Tween

func _ready() -> void:
	_base_scale = scale
	# At engine start there is no save and no room — the main menu is still up — so
	# start clear and let the first spawn settle us.
	_apply_state(false)

	MetSys.room_changed.connect(_on_room_changed)
	GlobalSignals.player_spawned.connect(_on_player_spawned)
	GlobalSignals.RestoreStationPower.connect(_on_station_power_restored)

## A spawn is a placement rather than a move: the player is teleported in behind a
## load screen or a respawn, so the darkness is simply already right when the screen
## comes back, with no fade to catch the eye.
func _on_player_spawned() -> void:
	_set_dark(_should_be_dark(), false)

func _on_room_changed(_new_room: String) -> void:
	_set_dark(_should_be_dark(), true)

## Clears the darkness when the fuse goes in.
##
## This deliberately does not re-read [method GameManager.is_station_powered]. We sit
## deeper in the tree than [GameManager] and so connect to this signal first, which
## means we run while the save still says the station is unpowered. The signal itself
## is the fact; the save catches up a moment later.
func _on_station_power_restored() -> void:
	_set_dark(false, true)

## Whether the darkness belongs on screen right now.
func _should_be_dark() -> bool:
	return not GameManager.is_station_powered() and _is_in_station()

func _is_in_station() -> bool:
	var room := MetSys.get_current_room_name()
	if room.is_empty():
		# No room loaded: the menu, or a transition mid-swap. Nothing to be dark in.
		return false
	# MetSys names rooms relative to its map root while @export_file hands us a
	# res:// path, so accept either form.
	var full_path := MetSys.get_full_room_path(room)
	for excluded in non_station_rooms:
		if excluded == full_path or excluded == room:
			return false
	return true

## Moves the darkness to [param dark], fading if [param animate] and the relevant
## fade is enabled, snapping otherwise.
func _set_dark(dark: bool, animate: bool) -> void:
	if dark == _dark:
		return
	_dark = dark
	_stop_fade()

	if not animate:
		_apply_state(dark)
	elif dark:
		# ENTRY FADE-IN: see the note at the top of this file.
		if animate_entry:
			_fade_in()
		else:
			_apply_state(true)
	else:
		_fade_out()

## Puts the darkness fully on or fully off, with nothing in flight.
func _apply_state(dark: bool) -> void:
	scale = _base_scale
	modulate.a = 1.0 if dark else 0.0
	visible = dark

## Opens the vignette out as it clears, then puts it away.
func _fade_out() -> void:
	visible = true
	_fade = create_tween().set_parallel().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_fade.tween_property(self, "modulate:a", 0.0, power_on_seconds)
	_fade.tween_property(self, "scale", _base_scale * power_on_expansion, power_on_seconds)
	# Hidden rather than left at zero alpha, and back at its authored scale ready for
	# the next time it is needed.
	_fade.chain().tween_callback(_apply_state.bind(false))
	_fade.finished.connect(_clear_fade)

## Dropped once a fade plays out, so a killed and a completed fade leave the same
## state behind.
func _clear_fade() -> void:
	_fade = null

func _stop_fade() -> void:
	if is_instance_valid(_fade):
		_fade.kill()
	_fade = null

#region Entry fade-in
## Closes the vignette in from wide and clear, the power-on fade run backwards.
func _fade_in() -> void:
	scale = _base_scale * entry_expansion
	modulate.a = 0.0
	visible = true
	_fade = create_tween().set_parallel().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_fade.tween_property(self, "modulate:a", 1.0, entry_seconds)
	_fade.tween_property(self, "scale", _base_scale, entry_seconds)
	_fade.finished.connect(_clear_fade)
#endregion
