class_name Area2DHider extends Area2D

@export var fade_amount : float = 0.05
# Functional
var player_is_in : bool
var is_anim : bool
var is_shown : bool
## True once we know whether the player is standing inside us. Until then the
## layer stays fully transparent: overlaps aren't reported until the physics
## server has stepped with the player at its spawn point, and showing the layer
## in the meantime only to fade it out afterwards is a visible flicker.
var _overlap_known : bool
## Bumped every time the spawn state is re-resolved. Pending resolutions and
## in-flight fades compare against it and bail out if they were started before
## the most recent spawn.
var _state_id : int

func _ready() -> void:
	player_is_in = false
	is_anim = false
	is_shown = false
	_overlap_known = false
	modulate.a = 0
	# Connect here rather than in the editor: this script is usually added as a
	# custom-type Area2D, so scene-file connections don't come along with it.
	if not body_entered.is_connected(_on_body_entered):
		body_entered.connect(_on_body_entered)
	if not body_exited.is_connected(_on_body_exited):
		body_exited.connect(_on_body_exited)
	GlobalSignals.player_spawned.connect(_resolve_spawn_state)
	# A room can also be loaded around a player who is already standing inside
	# us (a room transition shifts the player right after the load), so resolve
	# on our own too instead of waiting for a signal that may never come.
	_resolve_spawn_state()

func _process(_delta: float) -> void:
	if not _overlap_known:
		return
	if is_shown and player_is_in:
		make_visible(false)
	elif not is_shown and not player_is_in:
		make_visible(true)

## Works out whether the player spawned on top of us and snaps straight to the
## matching alpha — no fade, since there is nothing to transition from. Both
## spawn paths happen behind the load or death screen, so the few frames spent
## transparent here are never on screen.
func _resolve_spawn_state() -> void:
	_state_id += 1
	var state_id := _state_id
	# Stay hidden and drop any fade that was running for the previous spawn.
	_overlap_known = false
	is_anim = false
	is_shown = false
	player_is_in = false
	modulate.a = 0
	# A teleport reaches the physics server on the next step, and the resulting
	# overlap is only reported on the step after that, so give it two.
	await get_tree().physics_frame
	await get_tree().physics_frame
	if state_id != _state_id or not is_inside_tree():
		return
	player_is_in = _player_is_overlapping()
	is_shown = not player_is_in
	modulate.a = 0 if player_is_in else 1
	_overlap_known = true

func _player_is_overlapping() -> bool:
	for body in get_overlapping_bodies():
		if body.is_in_group("player"):
			return true
	return false

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
		# A spawn happened mid-fade and already set the alpha it wants.
		if state_id != _state_id:
			return

	is_anim = false
	is_shown = value

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_is_in = true
		# An enter signal is authoritative, so if it beat our own overlap poll
		# we can stop waiting: we are hidden already, which is the right state.
		_overlap_known = true

func _on_body_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		player_is_in = false
