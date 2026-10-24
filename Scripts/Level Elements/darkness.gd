# DECOUPLING THE ENTRY FADE-IN
# Everything that makes the darkness animate *on* lives behind [member animate_entry]
# and the "Entry fade-in" region at the bottom of this file. Nothing else depends on
# it. To drop the feature, either untick animate_entry in the inspector (the darkness
# then simply appears the moment the player enters the station), or delete the
# "Entry fade-in" export group and the region outright and replace the one call site
# marked "ENTRY FADE-IN" in _set_dark() with _apply_state(true).

class_name Darkness
extends Sprite2D

const GROUP := &"darkness"

const BASE_GRADIENT := preload("res://GeneralArt/Darkness/easy_gradient.tres")
const HARD_GRADIENT := preload("res://GeneralArt/Darkness/hard_gradient.tres")
const BULLSHIT_GRADIENT := preload("res://GeneralArt/Darkness/bullshit_gradient.tres")

static var globle_darkness : Darkness

@export var alpha_for_difficulty : Array[ float ] = [ 150/255.0, 190/255.0, 190/255.0, 210/255.0 ]

var _dark_alpha : float:
	get(): return Difficulty.pick_from_difficulty(alpha_for_difficulty)

@export_file("*.tscn") var non_station_rooms : Array[String] = [
	"res://Scenes/Rooms/Ship Internals/ship_internals.tscn",
]

@export_group("Power-on fade")
@export_range(0.05, 5.0, 0.05, "or_greater") var power_on_seconds := 1.4
@export_range(1.0, 4.0, 0.05, "or_greater") var power_on_expansion := 1.8

@export_group("Entry fade-in")
@export var animate_entry := true
@export_range(0.05, 5.0, 0.05, "or_greater") var entry_seconds := 1.0
@export_range(1.0, 4.0, 0.05, "or_greater") var entry_expansion := 1.8

var _base_scale : Vector2
var _expanded_scale : Vector2
var _dark := false
var _fade : Tween
var _held := false
var _was_toggled := false

@onready var gradient := $TextureRect

func _input(event: InputEvent) -> void:
	if not Cheats.cheats: return
	if not event is InputEventKey: return
	if not event.keycode == KEY_SLASH: return
	if event.is_released():
		_was_toggled = false
		return
	if _was_toggled: return
	_was_toggled = true
	_apply_state( !_dark )

func _ready() -> void:
	globle_darkness = self
	add_to_group( GROUP )
	_base_scale = scale
	_expanded_scale = _base_scale * power_on_expansion
	_apply_state( false )
	handle_difficulty()
	
	MetSys.room_changed.connect(_on_room_changed)
	GlobalSignals.player_spawned.connect(_on_player_spawned)
	GlobalSignals.RestoreStationPower.connect(_on_station_power_restored)
	Difficulty.on_difficulty_changed.connect( handle_difficulty )

func handle_difficulty() -> void:
	var tex : GradientTexture2D = gradient.texture
	tex.gradient = Difficulty.pick_from_difficulty([BASE_GRADIENT, BASE_GRADIENT, HARD_GRADIENT, BULLSHIT_GRADIENT])
	update_opacity( _dark_alpha )

func _on_player_spawned() -> void:
	if _held: return
	_set_dark(_should_be_dark(MetSys.get_current_room_name()), false)

func _on_room_changed(new_room: String) -> void:
	if _held: return
	_set_dark(_should_be_dark(new_room), true)

func _on_station_power_restored() -> void:
	if _held: return
	_set_dark(false, true)

#region Manual hold
## Takes the darkness over and puts it to [param dark], fading if [param animate].
## It stays there through room changes and the station powering on until
## [method release] hands it back.
func hold(dark: bool, animate := true) -> void:
	_held = true
	_set_dark(dark, animate)

## Hands the darkness back to the station's power and the current room, moving it to
## whichever they call for.
func release(animate := true) -> void:
	if not _held: return
	_held = false
	_set_dark(_should_be_dark(MetSys.get_current_room_name()), animate)

## Whether something is currently driving the darkness by hand.
func is_held() -> bool:
	return _held
#endregion

## Whether the darkness belongs on screen with the player in [param room].
func _should_be_dark(room: String) -> bool:
	return not SaveManager.is_station_powered() and _is_in_station(room)

func _is_in_station(room: String) -> bool:
	if room.is_empty(): return false
	var relative := MetSys.map_data.get_uid_room(room)
	var full_path := MetSys.get_full_room_path(relative)
	var uid := _room_uid(full_path)
	for excluded in non_station_rooms:
		if excluded == full_path or excluded == relative: return false
		if not uid.is_empty() and uid == _room_uid(excluded): return false
	return true

static func _room_uid(path: String) -> String:
	var id := ResourceLoader.get_resource_uid(path)
	if id == ResourceUID.INVALID_ID: return ""
	return ResourceUID.id_to_text(id)

## Moves the darkness to [param dark], fading if [param animate] and the relevant
## fade is enabled, snapping otherwise.
func _set_dark(dark: bool, animate: bool) -> void:
	if dark == _dark: return
	_dark = dark
	_stop_fade()

	if not animate:
		_apply_state( dark )
	elif dark:
		if animate_entry: _fade_in()
		else: _apply_state( true )
	else:
		_fade_out()

## Puts the darkness fully on or fully off, with nothing in flight.
func _apply_state(dark: bool) -> void:
	_dark = dark
	scale = _base_scale
	modulate.a = _dark_alpha if dark else 0.0
	visible = dark

func update_opacity(alpha: float) -> void:
	if not _dark: return
	modulate.a = alpha

## Opens the vignette out as it clears, then puts it away.
func _fade_out() -> void:
	visible = true
	_fade = create_tween().set_parallel().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_fade.tween_property(self, "modulate:a", 0.0, power_on_seconds)
	_fade.tween_property(self, "scale", _expanded_scale, power_on_seconds)
	_fade.chain().tween_callback(_apply_state.bind(false))
	_fade.finished.connect(_clear_fade)

func _clear_fade() -> void:
	_fade = null

func _stop_fade() -> void:
	if is_instance_valid(_fade): _fade.kill()
	_fade = null

func fade_manual(percent: float) -> void:
	if not _held: return
	modulate.a = _dark_alpha * percent
	scale = _expanded_scale - (_expanded_scale - _base_scale) * percent 

#region Entry fade-in
## Closes the vignette in from wide and clear, the power-on fade run backwards.
func _fade_in() -> void:
	scale = _expanded_scale
	modulate.a = 0.0
	visible = true
	_fade = create_tween().set_parallel().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_fade.tween_property(self, "modulate:a", _dark_alpha, entry_seconds)
	_fade.tween_property(self, "scale", _base_scale, entry_seconds)
	_fade.finished.connect(_clear_fade)
#endregion
