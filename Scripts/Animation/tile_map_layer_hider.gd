class_name Area2DHider extends Area2D

@export var fade_amount : float = 0.05
## A player move larger than this in a single frame is a teleport (spawn, room
## transition), never walking, so the layer snaps to its new state instead of
## animating across it.
const TELEPORT_DISTANCE : float = 128.0

# Functional
var player_is_in : bool
var is_anim : bool
var is_shown : bool
## Bumped by every snap. A fade that was already running compares against it and
## abandons its animation, leaving the snapped alpha alone.
var _state_id : int
## Our own collision shapes, cached. Overlap is measured against these with
## PlayerOverlap rather than through body_entered/exited, because the physics
## server cannot report a spawn overlap in time to keep the layer from flickering
## - see PlayerOverlap for why.
var _area_shapes : Array = []
var _last_player_pos : Vector2
var _tracking_player : bool

func _ready() -> void:
	is_anim = false
	_area_shapes = PlayerOverlap.collect_shapes(self)
	if _area_shapes.is_empty():
		push_warning("Area2DHider %s has no collision shapes, so it will never hide." % name)
	# Our own signals are unused, so don't make the physics server track us.
	monitoring = false
	# The state has to be correct for the very first frame we are drawn on, so
	# resolve it now and again once the frame's work is done but before it is
	# drawn: a room transition shifts the player onto its entrance immediately
	# after loading us, which would otherwise leave us a frame behind.
	_snap_to_player()
	_snap_to_player.call_deferred()
	GlobalSignals.player_spawned.connect(_snap_to_player)

func _process(_delta: float) -> void:
	var player := PlayerManager.player
	if not is_instance_valid(player) or not player.is_inside_tree():
		return

	var player_pos := player.global_position
	var teleported := _tracking_player and _last_player_pos.distance_to(player_pos) > TELEPORT_DISTANCE
	_last_player_pos = player_pos
	_tracking_player = true
	if teleported:
		_snap_to_player()
		return

	player_is_in = PlayerOverlap.with_shapes(_area_shapes)
	if is_shown and player_is_in:
		make_visible(false)
	elif not is_shown and not player_is_in:
		make_visible(true)

## Puts the layer straight into the state the player's current position calls
## for, without animating: there is nothing to fade from when the player arrives
## by teleport, and fading either way is the flicker we're avoiding.
func _snap_to_player() -> void:
	if not is_inside_tree():
		return
	_state_id += 1
	is_anim = false
	player_is_in = PlayerOverlap.with_shapes(_area_shapes)
	is_shown = not player_is_in
	modulate.a = 0 if player_is_in else 1

	var player := PlayerManager.player
	if is_instance_valid(player) and player.is_inside_tree():
		_last_player_pos = player.global_position
		_tracking_player = true

func iterate_on_alpha(delta_a: float) -> void:
	modulate.a = clamp(modulate.a + delta_a, 0, 1)

func make_visible(value: bool) -> void:
	if is_anim:
		return

	is_anim = true
	var state_id := _state_id
	var goal = 1 if value else 0
	var delta = fade_amount if value else -fade_amount
	# Animate
	while not modulate.a == goal:
		iterate_on_alpha(delta)
		await get_tree().process_frame
		# A snap took over mid-fade; its alpha is the one that should stand.
		if state_id != _state_id:
			return

	is_anim = false
	is_shown = value
